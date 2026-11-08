//
//  DistroAppEntry.m
//  Distro — Detroit Automation Academy application store (Project 07)
//

#import "DistroAppEntry.h"

// Returns the string value for key, or nil when the value is NSNull or
// not a string. Returns a non-nil marker via *present when the key
// exists at all, so callers can distinguish "absent" from "null".
static NSString *DistroStringValue(NSDictionary *dict, NSString *key, BOOL *present) {
    id value = [dict objectForKey:key];
    if (present) *present = (value != nil);
    if ([value isKindOfClass:[NSString class]]) return value;
    return nil;
}

@implementation DistroAppEntry

@synthesize appID = _appID;
@synthesize name = _name;
@synthesize tagline = _tagline;
@synthesize entryDescription = _entryDescription;
@synthesize version = _version;
@synthesize status = _status;
@synthesize category = _category;
@synthesize downloadURLString = _downloadURLString;
@synthesize sha256 = _sha256;
@synthesize sizeBytes = _sizeBytes;
@synthesize minMacOS = _minMacOS;
@synthesize license = _license;
@synthesize sourceURLString = _sourceURLString;
@synthesize iconURLString = _iconURLString;
@synthesize datePublished = _datePublished;
@synthesize buildNotes = _buildNotes;

- (void)dealloc {
    [_appID release];
    [_name release];
    [_tagline release];
    [_entryDescription release];
    [_version release];
    [_status release];
    [_category release];
    [_downloadURLString release];
    [_sha256 release];
    [_sizeBytes release];
    [_minMacOS release];
    [_license release];
    [_sourceURLString release];
    [_iconURLString release];
    [_datePublished release];
    [_buildNotes release];
    [super dealloc];
}

+ (DistroAppEntry *)entryWithDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;

    // Required non-null string fields.
    NSArray *required = [NSArray arrayWithObjects:
        @"id", @"name", @"tagline", @"description", @"version",
        @"status", @"category", @"minMacOS", @"license", @"iconURL", nil];
    for (NSString *key in required) {
        BOOL present = NO;
        NSString *value = DistroStringValue(dictionary, key, &present);
        if (!present || value == nil) return nil;
    }

    NSString *status = DistroStringValue(dictionary, @"status", NULL);
    if (![status isEqualToString:@"released"] &&
        ![status isEqualToString:@"testing"] &&
        ![status isEqualToString:@"release-candidate"] &&
        ![status isEqualToString:@"in-development"]) return nil;

    // Nullable fields: key must exist; value must be string-or-null
    // (number-or-null for sizeBytes).
    NSArray *nullableStrings = [NSArray arrayWithObjects:
        @"downloadURL", @"sha256", @"sourceURL", @"datePublished", nil];
    for (NSString *key in nullableStrings) {
        id value = [dictionary objectForKey:key];
        if (value == nil) return nil;  // key absent entirely
        if (![value isKindOfClass:[NSString class]] &&
            ![value isKindOfClass:[NSNull class]]) return nil;
    }
    id sizeValue = [dictionary objectForKey:@"sizeBytes"];
    if (sizeValue == nil) return nil;
    if (![sizeValue isKindOfClass:[NSNumber class]] &&
        ![sizeValue isKindOfClass:[NSNull class]]) return nil;

    DistroAppEntry *entry = [[[DistroAppEntry alloc] init] autorelease];
    entry.appID = DistroStringValue(dictionary, @"id", NULL);
    entry.name = DistroStringValue(dictionary, @"name", NULL);
    entry.tagline = DistroStringValue(dictionary, @"tagline", NULL);
    entry.entryDescription = DistroStringValue(dictionary, @"description", NULL);
    entry.version = DistroStringValue(dictionary, @"version", NULL);
    entry.status = status;
    entry.category = DistroStringValue(dictionary, @"category", NULL);
    entry.downloadURLString = DistroStringValue(dictionary, @"downloadURL", NULL);
    entry.sha256 = DistroStringValue(dictionary, @"sha256", NULL);
    entry.sizeBytes = [sizeValue isKindOfClass:[NSNumber class]] ? sizeValue : nil;
    entry.minMacOS = DistroStringValue(dictionary, @"minMacOS", NULL);
    entry.license = DistroStringValue(dictionary, @"license", NULL);
    entry.sourceURLString = DistroStringValue(dictionary, @"sourceURL", NULL);
    entry.iconURLString = DistroStringValue(dictionary, @"iconURL", NULL);
    entry.datePublished = DistroStringValue(dictionary, @"datePublished", NULL);
    // Optional field: absent or null yields nil and the entry stays
    // valid; older catalogs without it parse unchanged.
    entry.buildNotes = DistroStringValue(dictionary, @"buildNotes", NULL);
    return entry;
}

- (NSURL *)downloadURL {
    if (_downloadURLString == nil ||
        [_downloadURLString isEqualToString:@"PENDING-BUILD"]) return nil;
    return [NSURL URLWithString:_downloadURLString];
}

- (NSURL *)sourceURL {
    if (_sourceURLString == nil) return nil;
    return [NSURL URLWithString:_sourceURLString];
}

- (NSURL *)iconURL {
    if (_iconURLString == nil) return nil;
    return [NSURL URLWithString:_iconURLString];
}

- (BOOL)hasVerifiableHash {
    if ([_sha256 length] != 64) return NO;
    NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
    for (NSUInteger i = 0; i < [_sha256 length]; i++) {
        if (![hex characterIsMember:[_sha256 characterAtIndex:i]]) return NO;
    }
    return YES;
}

- (BOOL)isInstallable {
    if ([_status isEqualToString:@"in-development"]) return NO;
    if ([self downloadURL] == nil) return NO;
    return [self hasVerifiableHash];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<DistroAppEntry %@ %@ status=%@ installable=%@>",
            _appID, _version, _status, [self isInstallable] ? @"YES" : @"NO"];
}

@end
