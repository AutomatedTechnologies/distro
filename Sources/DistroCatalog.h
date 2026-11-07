//
//  DistroCatalog.h
//  Distro — Detroit Automation Academy application store (Project 07)
//
//  Fetches and parses the static catalog JSON (charter §3/§4). The
//  catalog is a single file on the Academy domain; there is no server,
//  no account, and no other endpoint. Parsing is strict about types and
//  forgiving about content: one malformed entry is skipped (logged),
//  never fatal to the whole catalog.
//
//  macOS 10.13 floor. Foundation only (NSURLSession, NSJSONSerialization).
//

#import <Foundation/Foundation.h>

@class DistroAppEntry;

typedef void (^DistroCatalogCompletion)(NSArray *entries, NSError *error);

@interface DistroCatalog : NSObject {
@private
    NSNumber *_catalogVersion;
    NSString *_generated;
    NSArray *_entries;
}

// The production catalog location (charter §3).
+ (NSURL *)defaultCatalogURL;

// Fetches url, parses it, and calls completion on the main queue with an
// array of DistroAppEntry (empty on parse-level success with no valid
// entries) or nil + error on transport/parse failure.
+ (void)fetchCatalogFromURL:(NSURL *)url completion:(DistroCatalogCompletion)completion;

// Parses catalog data already in memory (used by the fetcher; also the
// seam for tests and for a future bundled fallback catalog). On success
// returns a catalog whose entries hold every valid entry in file order.
+ (DistroCatalog *)catalogWithData:(NSData *)data error:(NSError **)error;

@property (nonatomic, retain) NSNumber *catalogVersion;
@property (nonatomic, copy) NSString *generated;
@property (nonatomic, retain) NSArray *entries;   // of DistroAppEntry

- (DistroAppEntry *)entryWithID:(NSString *)appID;
- (NSArray *)entriesWithStatus:(NSString *)status;   // of DistroAppEntry
- (NSArray *)entriesInCategory:(NSString *)category; // of DistroAppEntry

@end
