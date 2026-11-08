//
//  DistroInstalledRecords.m
//  Distro — Detroit Automation Academy application store (Project 07)
//

#import "DistroInstalledRecords.h"

@implementation DistroInstalledRecords

+ (NSString *)defaultRecordsPath {
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(
        NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *base = [dirs count] > 0 ? [dirs objectAtIndex:0]
                                      : [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"];
    return [[base stringByAppendingPathComponent:@"Distro"]
             stringByAppendingPathComponent:@"Installed.plist"];
}

- (id)initWithFilePath:(NSString *)path {
    self = [super init];
    if (self) {
        _filePath = [path copy];
        NSDictionary *loaded = [NSDictionary dictionaryWithContentsOfFile:_filePath];
        _records = loaded != nil ? [loaded mutableCopy]
                                 : [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id)init {
    return [self initWithFilePath:[DistroInstalledRecords defaultRecordsPath]];
}

- (void)dealloc {
    [_records release];
    [_filePath release];
    [super dealloc];
}

- (BOOL)save {
    NSString *dir = [_filePath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    return [_records writeToFile:_filePath atomically:YES];
}

- (NSDictionary *)recordForID:(NSString *)appID {
    if (appID == nil) return nil;
    id rec = [_records objectForKey:appID];
    return [rec isKindOfClass:[NSDictionary class]] ? rec : nil;
}

- (BOOL)isInstalled:(NSString *)appID {
    return [self recordForID:appID] != nil;
}

- (NSArray *)installedIDs {
    return [_records allKeys];
}

- (void)setRecordForID:(NSString *)appID
               version:(NSString *)version
                sha256:(NSString *)sha256
                format:(NSString *)format
            bundlePath:(NSString *)bundlePath {
    if (appID == nil) return;
    NSMutableDictionary *rec = [NSMutableDictionary dictionary];
    if (version != nil) [rec setObject:version forKey:@"version"];
    if (sha256 != nil) [rec setObject:sha256 forKey:@"sha256"];
    if (format != nil) [rec setObject:format forKey:@"format"];
    if (bundlePath != nil) [rec setObject:bundlePath forKey:@"bundlePath"];
    [_records setObject:rec forKey:appID];
    [self save];
}

- (void)removeRecordForID:(NSString *)appID {
    if (appID == nil) return;
    [_records removeObjectForKey:appID];
    [self save];
}

- (BOOL)hasUpdateForID:(NSString *)appID catalogSHA256:(NSString *)catalogSHA256 {
    NSDictionary *rec = [self recordForID:appID];
    if (rec == nil || catalogSHA256 == nil) return NO;
    NSString *installed = [rec objectForKey:@"sha256"];
    return installed != nil && ![installed isEqualToString:catalogSHA256];
}

@end
