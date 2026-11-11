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

// The Academy audit entry (acceptance rule, J directive 2026-11-08):
// Distro accepts and distributes only apps whose Info.plist carries
// the entry `com.detroitautomationacademy.audit` — a dictionary with
// Disassembled, Scanned, and Recompiled all true — attesting the
// build passed through the Academy pipeline (disassembled, scanned,
// and recompiled under Academy authority). SHA-256 proves the bytes
// are the catalogued bytes; this entry proves what the bytes ARE.
// No entry, no install — here or in the UI.
static BOOL DistroBundleCarriesAcademyAuditEntry(NSString *bundlePath) {
    NSString *plistPath = [[bundlePath stringByAppendingPathComponent:@"Contents"]
        stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    id audit = [info objectForKey:@"com.detroitautomationacademy.audit"];
    if (![audit isKindOfClass:[NSDictionary class]]) return NO;
    return [[audit objectForKey:@"Disassembled"] boolValue] &&
           [[audit objectForKey:@"Scanned"] boolValue] &&
           [[audit objectForKey:@"Recompiled"] boolValue];
}

// The bundle identity a bundle carries on disk (its Info.plist
// CFBundleIdentifier); nil when unreadable.
static NSString *DistroBundleIdentifierAtPath(NSString *bundlePath) {
    NSString *plistPath = [[bundlePath stringByAppendingPathComponent:@"Contents"]
        stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    id bid = [info objectForKey:@"CFBundleIdentifier"];
    return [bid isKindOfClass:[NSString class]] ? bid : nil;
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

// ---- Pre-flight (standard, J directive 2026-11-10; charter §6) ----
//
// Runs after the SHA-256 and audit gates pass, before the new bundle
// is placed. Returns YES when the way is clear; on NO the install
// stops with nothing changed and error says why.
//
// Close rule: a running process is closed for every bundle identity
// this install replaces — the new bundle's own ID, the bundle ID in
// the entry's installed record, and the entry's declared
// predecessorBundleIDs. The record is read fresh from the records
// file (the store saves it on every change), so pre-flight sees the
// same truth the store's state machine used, with no change to this
// class's public interface. This process is never a close target:
// the installer executes inside it. On a self-update the swap
// proceeds under the running process, which keeps executing from
// the inode it launched with after its bundle is moved to Trash,
// and the placed build is what runs at next launch; any OTHER
// process carrying the same bundle ID is closed as usual.
//
// Removal rule: bundles only, to Trash, never unlinked — the
// recorded install location (when the bundle on disk carries an
// identity being replaced; a stale record pointing at an unrelated
// app is never acted on), any bundle in /Applications or
// ~/Applications whose on-disk identity is being replaced, and any
// bundle already at the destination. App data is stored separately
// (~/Library/Application Support/<bundle ID> and its kin) and is
// never deleted, moved, or read here.
+ (BOOL)runPreflightForEntry:(DistroAppEntry *)entry
                stagedBundle:(NSString *)stagedBundle
                        dest:(NSString *)dest
                       error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];

    // The identity set this install replaces: the new bundle's own
    // ID, the previous record's bundle ID, declared predecessors.
    NSMutableArray *identities = [NSMutableArray array];
    NSMutableSet *identitySet = [NSMutableSet set];
    NSString *newBundleID = DistroBundleIdentifierAtPath(stagedBundle);
    if (newBundleID != nil) {
        [identities addObject:newBundleID];
        [identitySet addObject:newBundleID];
    }
    DistroInstalledRecords *records =
        [[[DistroInstalledRecords alloc] init] autorelease];
    NSDictionary *previous = [records recordForID:[entry appID]];
    NSString *previousPath = [previous objectForKey:@"bundlePath"];
    NSString *previousID = [previous objectForKey:@"bundleID"];
    if (previousID != nil && ![identitySet containsObject:previousID]) {
        [identities addObject:previousID];
        [identitySet addObject:previousID];
    }
    for (NSString *pred in [entry predecessorBundleIDs]) {
        if (![identitySet containsObject:pred]) {
            [identities addObject:pred];
            [identitySet addObject:pred];
        }
    }

    // (1) Close the app if it is running, for every identity.
    for (NSString *bundleID in identities) {
        NSArray *running =
            [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleID];
        for (NSRunningApplication *app in running) {
            if ([app processIdentifier] == getpid()) continue; // self
            if (![self closeRunningApplication:app
                                    bundleID:bundleID
                                   entryName:[entry name]
                                         error:error]) {
                return NO;
            }
        }
    }

    // (2) Remove the previous version's bundle(s): Trash, never rm.
    NSMutableArray *candidates = [NSMutableArray array];
    NSMutableSet *seenPaths = [NSMutableSet set];
    if (previousPath != nil && [fm fileExistsAtPath:previousPath] &&
        ![seenPaths containsObject:previousPath]) {
        NSString *onDiskID = DistroBundleIdentifierAtPath(previousPath);
        if (onDiskID != nil && [identitySet containsObject:onDiskID]) {
            [candidates addObject:previousPath];
            [seenPaths addObject:previousPath];
        }
    }
    NSArray *appsDirs = [NSArray arrayWithObjects:
        @"/Applications",
        [NSHomeDirectory() stringByAppendingPathComponent:@"Applications"],
        nil];
    for (NSString *dir in appsDirs) {
        NSArray *names = [fm contentsOfDirectoryAtPath:dir error:NULL];
        for (NSString *name in names) {
            if (![[name pathExtension] isEqualToString:@"app"]) continue;
            NSString *path = [dir stringByAppendingPathComponent:name];
            if ([seenPaths containsObject:path]) continue;
            NSString *onDiskID = DistroBundleIdentifierAtPath(path);
            if (onDiskID != nil && [identitySet containsObject:onDiskID]) {
                [candidates addObject:path];
                [seenPaths addObject:path];
            }
        }
    }
    if ([fm fileExistsAtPath:dest] && ![seenPaths containsObject:dest]) {
        [candidates addObject:dest];
        [seenPaths addObject:dest];
    }
    for (NSString *path in candidates) {
        NSError *trashError = nil;
        if (![fm trashItemAtURL:[NSURL fileURLWithPath:path]
               resultingItemURL:NULL error:&trashError]) {
            if (error) *error = DistroInstallError(15,
                [NSString stringWithFormat:
                    @"The existing copy at %@ could not be moved to the Trash: %@",
                    path, [trashError localizedDescription]]);
            return NO;
        }
    }
    return YES;
}

// Closes one running application: graceful terminate, a 5-second
// grace, then force-terminate; still running 3 seconds after that
// stops the install (error 17) — a bundle is never swapped under a
// running process.
+ (BOOL)closeRunningApplication:(NSRunningApplication *)app
                       bundleID:(NSString *)bundleID
                      entryName:(NSString *)entryName
                          error:(NSError **)error {
    if ([app isTerminated]) return YES;
    [app terminate];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
    while (![app isTerminated] &&
           [[NSDate date] compare:deadline] == NSOrderedAscending) {
        [NSThread sleepForTimeInterval:0.1];
    }
    if ([app isTerminated]) return YES;
    [app forceTerminate];
    deadline = [NSDate dateWithTimeIntervalSinceNow:3.0];
    while (![app isTerminated] &&
           [[NSDate date] compare:deadline] == NSOrderedAscending) {
        [NSThread sleepForTimeInterval:0.1];
    }
    if ([app isTerminated]) return YES;
    if (error) *error = DistroInstallError(17,
        [NSString stringWithFormat:
            @"%@ is running (%@) and did not quit, so the install "
            @"stopped before anything was changed. Quit %@ and try again.",
            entryName, bundleID, entryName]);
    return NO;
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

    // Academy audit gate (acceptance rule, 2026-11-08): the bundle
    // must carry the com.detroitautomationacademy.audit plist entry
    // attesting it was disassembled, scanned, and recompiled by the
    // Academy. Without it the install stops — nothing is installed.
    if (!DistroBundleCarriesAcademyAuditEntry(bundle)) {
        [fm removeItemAtPath:staging error:NULL];
        if (error) *error = DistroInstallError(16,
            @"Distro only distributes apps that carry the Academy audit "
            @"entry (com.detroitautomationacademy.audit in the app's "
            @"Info.plist — proof the build was disassembled, scanned, "
            @"and recompiled by Detroit Automation Academy). This build "
            @"does not carry it, so the install stopped. Nothing was installed.");
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

    // Pre-flight (standard, J directive 2026-11-10; charter §6):
    // close the app if it is running and remove the previous
    // version's bundle before the new bundle is placed. The
    // destination overwrite of the standing rule is one of
    // pre-flight's removal candidates. App data is stored
    // separately and is never touched.
    if (![self runPreflightForEntry:entry
                       stagedBundle:bundle
                               dest:dest
                              error:error]) {
        [fm removeItemAtPath:staging error:NULL];
        return nil;
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
