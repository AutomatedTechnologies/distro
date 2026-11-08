//
//  DistroInstaller.m
//  Distro — Detroit Automation Academy application store (Project 07)
//

#import "DistroInstaller.h"
#import "DistroAppEntry.h"
#import "DistroVerifier.h"
#import "DistroInstalledRecords.h"
#import <AppKit/AppKit.h>
#include <unistd.h>

NSString * const DistroInstallResultFormatKey = @"format";
NSString * const DistroInstallResultBundlePathKey = @"bundlePath";
NSString * const DistroInstallResultAppsDirKey = @"appsDir";

static NSString * const DistroInstallerErrorDomain = @"org.detroitautomationacademy.distro.install";

static NSError *DistroInstallError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:DistroInstallerErrorDomain code:code
        userInfo:[NSDictionary dictionaryWithObject:message
                                             forKey:NSLocalizedDescriptionKey]];
}

// Depth-first search (max depth 2 below root) for the first .app bundle.
static NSString *DistroFindAppBundle(NSString *root) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *top = [fm contentsOfDirectoryAtPath:root error:NULL];
    for (NSString *name in top) {
        if ([[name pathExtension] isEqualToString:@"app"]) {
            return [root stringByAppendingPathComponent:name];
        }
    }
    for (NSString *name in top) {
        NSString *sub = [root stringByAppendingPathComponent:name];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:sub isDirectory:&isDir] || !isDir) continue;
        NSArray *inner = [fm contentsOfDirectoryAtPath:sub error:NULL];
        for (NSString *innerName in inner) {
            if ([[innerName pathExtension] isEqualToString:@"app"]) {
                return [sub stringByAppendingPathComponent:innerName];
            }
        }
    }
    return nil;
}

@implementation DistroInstaller

+ (void)verifyAndInstallFileAtPath:(NSString *)path
                          forEntry:(DistroAppEntry *)entry
                        completion:(DistroInstallCompletion)completion {
    // Retain across the async boundary under MRR.
    NSString *filePath = [[path retain] autorelease];
    DistroAppEntry *theEntry = [[entry retain] autorelease];
    DistroInstallCompletion done = [[completion copy] autorelease];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSDictionary *result = nil;
        NSError *error = nil;
        NSFileManager *fm = [NSFileManager defaultManager];

        // ---- Verify (charter §5: hard fail, file deleted, no override)
        NSDictionary *attrs = [fm attributesOfItemAtPath:filePath error:NULL];
        unsigned long long actualSize = [attrs fileSize];
        if ([theEntry sizeBytes] != nil &&
            actualSize != (unsigned long long)[[theEntry sizeBytes] longLongValue]) {
            error = DistroInstallError(10,
                [NSString stringWithFormat:
                    @"Size check failed for %@: expected %lld bytes, got %llu. "
                    @"The download was deleted and nothing was installed.",
                    [theEntry name], [[theEntry sizeBytes] longLongValue], actualSize]);
        } else {
            NSError *verifyError = nil;
            BOOL match = [DistroVerifier fileAtPath:filePath
                                matchesSHA256Hex:[theEntry sha256]
                                           error:&verifyError];
            if (!match) {
                error = DistroInstallError(11,
                    [NSString stringWithFormat:
                        @"SHA-256 verification failed for %@. The download does "
                        @"not match the hash published in the Academy catalog, so "
                        @"it was deleted and nothing was installed. There is no "
                        @"way to install an unverified file from Distro.",
                        [theEntry name]]);
            }
        }
        if (error != nil) {
            [fm removeItemAtPath:filePath error:NULL];
            dispatch_async(dispatch_get_main_queue(), ^{ done(nil, error); });
            [pool drain];
            return;
        }

        // ---- Install per format
        NSString *ext = [[filePath pathExtension] lowercaseString];
        if ([ext isEqualToString:@"zip"]) {
            result = [self installZipAtPath:filePath forEntry:theEntry error:&error];
        } else if ([ext isEqualToString:@"pkg"]) {
            // Hand the verified file to the system Installer (main queue:
            // NSWorkspace). The OS owns the rest of the flow.
            NSString *pkgPath = [[filePath retain] autorelease];
            dispatch_async(dispatch_get_main_queue(), ^{
                BOOL opened = [[NSWorkspace sharedWorkspace] openFile:pkgPath];
                if (opened) {
                    done([NSDictionary dictionaryWithObject:@"pkg"
                                                     forKey:DistroInstallResultFormatKey], nil);
                } else {
                    done(nil, DistroInstallError(20,
                        @"The system Installer could not be opened for this package."));
                }
            });
            [pool drain];
            return;
        } else {
            error = DistroInstallError(12,
                [NSString stringWithFormat:
                    @"Unsupported download format '.%@' — Distro installs .zip app bundles and .pkg packages only.", ext]);
        }

        dispatch_async(dispatch_get_main_queue(), ^{ done(result, error); });
        [pool drain];
    });
}

+ (NSDictionary *)installZipAtPath:(NSString *)zipPath
                          forEntry:(DistroAppEntry *)entry
                             error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *staging = [NSTemporaryDirectory() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"Distro-unzip-%@-%d", [entry appID], (int)getpid()]];
    [fm removeItemAtPath:staging error:NULL];
    if (![fm createDirectoryAtPath:staging withIntermediateDirectories:YES
                        attributes:nil error:error]) {
        return nil;
    }

    // Unzip with ditto via NSTask — a direct tool launch, no shell.
    NSTask *task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath:@"/usr/bin/ditto"];
    [task setArguments:[NSArray arrayWithObjects:@"-x", @"-k", zipPath, staging, nil]];
    [task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
    [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
    [task launch];
    [task waitUntilExit];
    if ([task terminationStatus] != 0) {
        [fm removeItemAtPath:staging error:NULL];
        if (error) *error = DistroInstallError(13,
            @"The downloaded archive could not be unpacked.");
        return nil;
    }

    NSString *bundle = DistroFindAppBundle(staging);
    if (bundle == nil) {
        [fm removeItemAtPath:staging error:NULL];
        if (error) *error = DistroInstallError(14,
            @"The archive did not contain an application bundle (.app).");
        return nil;
    }

    // Destination: /Applications if writable, else ~/Applications.
    NSString *appsDir = @"/Applications";
    if (![fm isWritableFileAtPath:appsDir]) {
        appsDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Applications"];
        [fm createDirectoryAtPath:appsDir withIntermediateDirectories:YES
                       attributes:nil error:NULL];
    }
    NSString *dest = [appsDir stringByAppendingPathComponent:[bundle lastPathComponent]];

    // Overwrite: the old bundle goes to Trash (recoverable), never rm.
    if ([fm fileExistsAtPath:dest]) {
        NSError *trashError = nil;
        if (![fm trashItemAtURL:[NSURL fileURLWithPath:dest]
               resultingItemURL:NULL error:&trashError]) {
            [fm removeItemAtPath:staging error:NULL];
            if (error) *error = DistroInstallError(15,
                [NSString stringWithFormat:
                    @"The existing copy at %@ could not be moved to the Trash: %@",
                    dest, [trashError localizedDescription]]);
            return nil;
        }
    }

    NSError *moveError = nil;
    if (![fm moveItemAtPath:bundle toPath:dest error:&moveError]) {
        [fm removeItemAtPath:staging error:NULL];
        if (error) *error = moveError;
        return nil;
    }
    [fm removeItemAtPath:staging error:NULL];
    [fm removeItemAtPath:zipPath error:NULL];

    return [NSDictionary dictionaryWithObjectsAndKeys:
        @"app", DistroInstallResultFormatKey,
        dest, DistroInstallResultBundlePathKey,
        appsDir, DistroInstallResultAppsDirKey,
        nil];
}

+ (BOOL)uninstallEntry:(DistroAppEntry *)entry
               records:(DistroInstalledRecords *)records
                 error:(NSError **)error {
    NSDictionary *rec = [records recordForID:[entry appID]];
    if (rec == nil) {
        if (error) *error = DistroInstallError(30, @"This app is not recorded as installed.");
        return NO;
    }
    NSString *format = [rec objectForKey:@"format"];
    if ([format isEqualToString:@"pkg"]) {
        if (error) *error = DistroInstallError(31,
            @"This app was installed by the system Installer from a .pkg, so "
            @"Distro cannot undo that transaction. To remove it, delete the "
            @"application from /Applications; system receipts live in "
            @"/var/db/receipts. Distro has left its installed record in place "
            @"so the catalog state stays honest.");
        return NO;
    }
    NSString *bundlePath = [rec objectForKey:@"bundlePath"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (bundlePath != nil && [fm fileExistsAtPath:bundlePath]) {
        NSError *trashError = nil;
        if (![fm trashItemAtURL:[NSURL fileURLWithPath:bundlePath]
               resultingItemURL:NULL error:&trashError]) {
            if (error) *error = trashError;
            return NO;
        }
    }
    [records removeRecordForID:[entry appID]];
    return YES;
}

@end
