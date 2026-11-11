//
//  DistroInstaller.h
//  Distro — Detroit Automation Academy application store (Project 07)
//
//  Verify-then-install (charter §5/§6). Every install begins with the
//  size + SHA-256 check via DistroVerifier; a mismatch deletes the
//  downloaded file and stops — there is no override, here or in the UI.
//  App bundles face a second gate (acceptance rule, 2026-11-08): the
//  bundle's Info.plist must carry the Academy audit entry
//  (com.detroitautomationacademy.audit — Disassembled, Scanned, and
//  Recompiled all true). SHA-256 proves the bytes are the catalogued
//  bytes; the audit entry proves the build passed the Academy
//  pipeline. No entry, no install.
//
//    .zip -> ditto-unzip (NSTask, no shell) -> find the .app -> move it
//            to /Applications when writable, else ~/Applications; an
//            existing bundle is moved to Trash first, never deleted.
//    .pkg -> the verified file is opened with the system Installer;
//            the OS owns the flow from there (Gatekeeper, admin prompt).
//
//  Pre-flight (standard, J directive 2026-11-10; charter §6). On every
//  app-bundle install/update — the per-app path and the Update All
//  queue alike, both of which route through this class — after the
//  SHA-256 and audit gates pass and before the new bundle is placed:
//  (1) every running process whose bundle ID is the new bundle's own
//  ID, the installed record's bundle ID for the entry, or one of the
//  entry's declared predecessorBundleIDs is closed — graceful
//  terminate, a 5-second grace, then force-terminate; still running
//  after that stops the install with nothing changed; (2) the
//  previous version's bundle is removed — the recorded install
//  location, any bundle in the Applications directories carrying an
//  identity being replaced, and any bundle at the destination — each
//  moved to Trash, never unlinked. Pre-flight removes bundles ONLY:
//  app data is stored separately (~/Library/Application Support/…)
//  and is never deleted, moved, or read by an install. Self-update:
//  Distro never terminates its own process mid-install (the installer
//  executes inside it) — the close step skips Distro's own process,
//  the swap proceeds under the running process, and the placed build
//  is what runs at next launch.
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
