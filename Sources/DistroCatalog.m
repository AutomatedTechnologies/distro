//
//  DistroCatalog.m
//  Distro — Detroit Automation Academy application store (Project 07)
//

#import "DistroCatalog.h"
#import "DistroAppEntry.h"

static NSString * const DistroCatalogErrorDomain = @"org.detroitautomationacademy.distro.catalog";

@implementation DistroCatalog

@synthesize catalogVersion = _catalogVersion;
@synthesize generated = _generated;
@synthesize entries = _entries;

- (void)dealloc {
    [_catalogVersion release];
    [_generated release];
    [_entries release];
    [super dealloc];
}

+ (NSURL *)defaultCatalogURL {
    return [NSURL URLWithString:@"https://detroitautomationacademy.com/store/catalog.json"];
}

+ (DistroCatalog *)catalogWithData:(NSData *)data error:(NSError **)error {
    id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (root == nil) return nil;
    if (![root isKindOfClass:[NSDictionary class]]) {
        if (error) *error = [NSError errorWithDomain:DistroCatalogErrorDomain code:1
            userInfo:[NSDictionary dictionaryWithObject:@"Catalog root is not a JSON object."
                                                 forKey:NSLocalizedDescriptionKey]];
        return nil;
    }
    id appsValue = [(NSDictionary *)root objectForKey:@"apps"];
    if (![appsValue isKindOfClass:[NSArray class]]) {
        if (error) *error = [NSError errorWithDomain:DistroCatalogErrorDomain code:2
            userInfo:[NSDictionary dictionaryWithObject:@"Catalog has no 'apps' array."
                                                 forKey:NSLocalizedDescriptionKey]];
        return nil;
    }
    NSMutableArray *entries = [NSMutableArray array];
    for (id item in (NSArray *)appsValue) {
        DistroAppEntry *entry = [DistroAppEntry entryWithDictionary:item];
        if (entry != nil) {
            [entries addObject:entry];
        } else {
            NSLog(@"Distro: skipping malformed catalog entry: %@", item);
        }
    }
    DistroCatalog *catalog = [[[DistroCatalog alloc] init] autorelease];
    id version = [(NSDictionary *)root objectForKey:@"catalogVersion"];
    catalog.catalogVersion = [version isKindOfClass:[NSNumber class]] ? version : nil;
    id generated = [(NSDictionary *)root objectForKey:@"generated"];
    catalog.generated = [generated isKindOfClass:[NSString class]] ? generated : nil;
    catalog.entries = entries;
    return catalog;
}

+ (void)fetchCatalogFromURL:(NSURL *)url completion:(DistroCatalogCompletion)completion {
    NSURLSessionDataTask *task =
        [[NSURLSession sharedSession] dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSArray *entries = nil;
            NSError *resultError = error;
            if (resultError == nil) {
                if ([response isKindOfClass:[NSHTTPURLResponse class]] &&
                    [(NSHTTPURLResponse *)response statusCode] != 200) {
                    resultError = [NSError errorWithDomain:DistroCatalogErrorDomain code:3
                        userInfo:[NSDictionary dictionaryWithObject:
                            [NSString stringWithFormat:@"Catalog fetch returned HTTP %ld.",
                                (long)[(NSHTTPURLResponse *)response statusCode]]
                            forKey:NSLocalizedDescriptionKey]];
                } else {
                    DistroCatalog *catalog = [DistroCatalog catalogWithData:data error:&resultError];
                    if (catalog != nil) entries = catalog.entries;
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(entries, resultError);
            });
        }];
    [task resume];
}

- (DistroAppEntry *)entryWithID:(NSString *)appID {
    for (DistroAppEntry *entry in _entries) {
        if ([entry.appID isEqualToString:appID]) return entry;
    }
    return nil;
}

- (NSArray *)entriesWithStatus:(NSString *)status {
    NSMutableArray *result = [NSMutableArray array];
    for (DistroAppEntry *entry in _entries) {
        if ([entry.status isEqualToString:status]) [result addObject:entry];
    }
    return result;
}

- (NSArray *)entriesInCategory:(NSString *)category {
    NSMutableArray *result = [NSMutableArray array];
    for (DistroAppEntry *entry in _entries) {
        if ([entry.category isEqualToString:category]) [result addObject:entry];
    }
    return result;
}

@end
