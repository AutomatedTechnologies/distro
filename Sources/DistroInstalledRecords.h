//
//  DistroInstalledRecords.h
//  Distro — Detroit Automation Academy application store (Project 07)
//
//  The installed-app record store (charter §6): a local plist at
//  ~/Library/Application Support/Distro/Installed.plist mapping catalog
//  id -> { version, sha256, format ("app" | "pkg"), bundlePath (apps) }.
//  Records are written only on user-confirmed completion of an install
//  flow. The Updates view derives its truth from catalog-vs-record
//  SHA-256 diff. No network, no telemetry — a local file only.
//
//  macOS 10.13 floor. Objective-C, manual retain/release.
//

#import <Foundation/Foundation.h>

@interface DistroInstalledRecords : NSObject {
@private
    NSMutableDictionary *_records; // id -> NSDictionary
    NSString *_filePath;
}

+ (NSString *)defaultRecordsPath;

// Loads the plist at path (an empty store when the file does not exist).
- (id)initWithFilePath:(NSString *)path;
- (id)init; // default path

- (NSDictionary *)recordForID:(NSString *)appID;   // nil when not installed
- (BOOL)isInstalled:(NSString *)appID;
- (NSArray *)installedIDs;

// Writes/replaces a record and saves. bundlePath may be nil (pkg flow).
- (void)setRecordForID:(NSString *)appID
               version:(NSString *)version
                sha256:(NSString *)sha256
                format:(NSString *)format
            bundlePath:(NSString *)bundlePath;

// Extended record (bundle-collision correction, 2026-11-08): also
// stores the installed bundle's identity (bundleID + bundleName, read
// from the bundle's own Info.plist at install time) and the install
// timestamp. Two catalog entries whose downloads contain the SAME
// bundle identity (e.g. KisMac and the staged unified build, both
// KisMac2.app / com.igrsoft.kismac) share one on-disk bundle; the
// identity + timestamp are what let the store say which entry's
// build actually owns that bundle now.
- (void)setRecordForID:(NSString *)appID
               version:(NSString *)version
                sha256:(NSString *)sha256
                format:(NSString *)format
            bundlePath:(NSString *)bundlePath
              bundleID:(NSString *)bundleID
            bundleName:(NSString *)bundleName;

// Drops a record and saves (uninstall).
- (void)removeRecordForID:(NSString *)appID;

// YES when a record exists and its sha256 differs from the catalog's —
// the charter §6 update condition.
- (BOOL)hasUpdateForID:(NSString *)appID catalogSHA256:(NSString *)catalogSHA256;

@end
