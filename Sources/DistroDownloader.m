//
//  DistroDownloader.m
//  Distro — Detroit Automation Academy application store (Project 07)
//

#import "DistroDownloader.h"
#import "DistroAppEntry.h"

static NSString * const DistroDownloaderErrorDomain = @"org.detroitautomationacademy.distro.download";

static BOOL DistroHostIsInitial(NSString *host) {
    return [host isEqualToString:@"detroitautomationacademy.com"] ||
           [host isEqualToString:@"www.detroitautomationacademy.com"] ||
           [host isEqualToString:@"github.com"];
}

static BOOL DistroHostIsRedirectTarget(NSString *host) {
    if (DistroHostIsInitial(host)) return YES;
    // GitHub serves release assets from *.githubusercontent.com.
    return [host hasSuffix:@".githubusercontent.com"] ||
           [host isEqualToString:@"githubusercontent.com"];
}

@implementation DistroDownloader

@synthesize delegate = _delegate;

- (id)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config =
            [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [[NSURLSession sessionWithConfiguration:config
                                                  delegate:self
                                             delegateQueue:nil] retain];
    }
    return self;
}

- (void)dealloc {
    [_session invalidateAndCancel];
    [_session release];
    [_activeEntry release];
    [_activeTask release];
    [_activeTempPath release];
    [super dealloc];
}

- (BOOL)busy {
    return _activeTask != nil;
}

- (BOOL)startDownloadForEntry:(DistroAppEntry *)entry {
    if ([self busy] || entry == nil) return NO;
    NSURL *url = [entry downloadURL];
    if (url == nil) return NO;
    if (![[url scheme] isEqualToString:@"https"]) return NO;
    if (!DistroHostIsInitial([url host])) return NO;

    NSString *dir = [NSTemporaryDirectory()
        stringByAppendingPathComponent:
            [NSString stringWithFormat:@"Distro-%@", entry.appID]];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    NSString *fileName = [[url path] lastPathComponent];
    if ([fileName length] == 0) fileName = @"download.bin";
    [_activeTempPath release];
    _activeTempPath = [[dir stringByAppendingPathComponent:fileName] retain];
    [_activeEntry release];
    _activeEntry = [entry retain];

    [_activeTask release];
    _activeTask = [[_session downloadTaskWithURL:url] retain];
    [_activeTask resume];
    return YES;
}

- (void)cancelActiveDownload {
    [_activeTask cancel];
}

- (void)clearActive {
    [_activeTask release]; _activeTask = nil;
    [_activeEntry release]; _activeEntry = nil;
    [_activeTempPath release]; _activeTempPath = nil;
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didFinishDownloadingToURL:(NSURL *)location {
    // Must move the file synchronously: the temp location is deleted
    // when this method returns.
    NSError *moveError = nil;
    [[NSFileManager defaultManager] removeItemAtPath:_activeTempPath error:NULL];
    BOOL ok = [[NSFileManager defaultManager] moveItemAtPath:[location path]
                                                      toPath:_activeTempPath
                                                       error:&moveError];
    DistroAppEntry *entry = [[_activeEntry retain] autorelease];
    NSString *path = ok ? [[_activeTempPath retain] autorelease] : nil;
    NSError *error = ok ? nil : moveError;
    [self clearActive];
    dispatch_async(dispatch_get_main_queue(), ^{
        [_delegate downloader:self
            didFinishDownloadForEntry:entry
                             filePath:path
                                error:error];
    });
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    double fraction = -1;
    int64_t expected = totalBytesExpectedToWrite;
    if (expected <= 0 && [_activeEntry sizeBytes] != nil) {
        expected = [[_activeEntry sizeBytes] longLongValue];
    }
    if (expected > 0) {
        fraction = (double)totalBytesWritten / (double)expected;
        if (fraction > 1) fraction = 1;
    }
    DistroAppEntry *entry = _activeEntry;
    dispatch_async(dispatch_get_main_queue(), ^{
        [_delegate downloader:self
            didUpdateProgressForEntry:entry
                             fraction:fraction];
    });
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    if (error == nil) return; // success is delivered by didFinishDownloadingToURL
    DistroAppEntry *entry = [[_activeEntry retain] autorelease];
    [self clearActive];
    dispatch_async(dispatch_get_main_queue(), ^{
        [_delegate downloader:self
            didFinishDownloadForEntry:entry
                             filePath:nil
                                error:error];
    });
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler {
    NSURL *url = [request URL];
    BOOL allowed = [[url scheme] isEqualToString:@"https"] &&
                   DistroHostIsRedirectTarget([url host]);
    completionHandler(allowed ? request : nil);
}

@end
