//
//  DistroAppEntry.h
//  Distro — Detroit Automation Academy application store (Project 07)
//
//  One app entry in the Distro catalog. Fields mirror the catalog schema
//  defined in files/01-DISTRO-CHARTER.md §4 exactly — one property per
//  schema field, same names. No third-party code; Foundation only.
//
//  macOS 10.13 floor. Objective-C, manual retain/release.
//

#import <Foundation/Foundation.h>

@interface DistroAppEntry : NSObject {
@private
    NSString *_appID;
    NSString *_name;
    NSString *_tagline;
    NSString *_entryDescription;
    NSString *_version;
    NSString *_status;
    NSString *_category;
    NSString *_downloadURLString;
    NSString *_sha256;
    NSNumber *_sizeBytes;
    NSString *_minMacOS;
    NSString *_license;
    NSString *_sourceURLString;
    NSString *_iconURLString;
    NSString *_datePublished;
}

// Schema fields (see charter §4). downloadURLString / sourceURLString /
// iconURLString hold the raw catalog strings; the URL accessors below
// vended parsed NSURLs and return nil for null / placeholder values.
@property (nonatomic, copy) NSString *appID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *tagline;
@property (nonatomic, copy) NSString *entryDescription;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *status;          // released | testing | in-development
@property (nonatomic, copy) NSString *category;
@property (nonatomic, copy) NSString *downloadURLString;
@property (nonatomic, copy) NSString *sha256;
@property (nonatomic, retain) NSNumber *sizeBytes;     // nil iff no build exists
@property (nonatomic, copy) NSString *minMacOS;
@property (nonatomic, copy) NSString *license;
@property (nonatomic, copy) NSString *sourceURLString;
@property (nonatomic, copy) NSString *iconURLString;
@property (nonatomic, copy) NSString *datePublished;   // ISO-8601, nil iff no build exists

// Builds an entry from one catalog "apps" dictionary. Returns nil if any
// required field is missing or of the wrong type; unknown fields are
// ignored (charter §4 forward-compatibility rule).
+ (DistroAppEntry *)entryWithDictionary:(NSDictionary *)dictionary;

// Parsed URLs; nil when the catalog value is null or a placeholder.
- (NSURL *)downloadURL;
- (NSURL *)sourceURL;
- (NSURL *)iconURL;

// YES only when Distro may offer an install: status is not
// in-development, downloadURL is a real URL, and sha256 is a real
// 64-character lowercase hex string (not "PENDING-BUILD", not null).
// Charter §5: nothing is installable without a real hash to verify.
- (BOOL)isInstallable;

// YES when sha256 is a syntactically valid SHA-256 hex string.
- (BOOL)hasVerifiableHash;

@end
