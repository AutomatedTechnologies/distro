//
//  DistroInstaller.h
//  Distro — Detroit Automation Academy application store (Project 07)
//
//  Verify-then-install (charter §5/§6). Every install begins with the
//  size + SHA-256 check via DistroVerifier; a mismatch deletes the
//  downloaded file and stops — there is no override, here or in the UI.
//
//    .zip -> ditto-unzip (NSTask, no shell) -> find the .app -> move it
//            to /Applications when writable, else ~/Applications; an
//            existing bundle is moved to Trash first, never deleted.
//    .pkg -> the verified file is opened with the system Installer;
//            the OS owns the flow from there (Gatekeeper, admin prompt).
//
//  Uninstall covers app-bundle installs Distro made: bundle to Trash,
//  record dropped. .pkg installs get honest removal guidance, not a
//  pretend undo. No privileged helper anywhere (charter §5.5).
//
//  macOS 10.13 floor. Objective-C, manual retain/release.
//

#import <Foundation/Foundation.h>

@class DistroAppEntry;
@class DistroInstalledRecords;

// Result dictionary keys (install completion):
extern NSString * const DistroInstallResultFormatKey;    // @"app" | @"pkg"
extern NSString * const DistroInstallResultBundlePathKey; // app flow only
extern NSString * const DistroInstallResultAppsDirKey;    // app flow only

typedef void (^DistroInstallCompletion)(NSDictionary *result, NSError *error);

@interface DistroInstaller : NSObject

// Verifies the downloaded file (size + SHA-256 hard fail; on failure
// the file is deleted) and installs it per its format. Runs off the
// main queue; completion is called on the main queue. For the .pkg
// flow, "success" means the verified package was handed to Installer;
// the caller confirms completion with the user before recording it.
+ (void)verifyAndInstallFileAtPath:(NSString *)path
                          forEntry:(DistroAppEntry *)entry
                        completion:(DistroInstallCompletion)completion;

// Moves the installed bundle for the record to Trash and drops the
// record. Returns YES on success; on failure error describes why.
// For .pkg records this returns NO with guidance in the error text.
+ (BOOL)uninstallEntry:(DistroAppEntry *)entry
               records:(DistroInstalledRecords *)records
                 error:(NSError **)error;

@end
