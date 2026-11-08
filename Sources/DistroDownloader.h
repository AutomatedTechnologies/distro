//
//  DistroDownloader.h
//  Distro — Detroit Automation Academy application store (Project 07)
//
//  The download manager (charter §5/§6). One download at a time, to a
//  per-app temp directory, with progress callbacks on the main queue.
//  HTTPS only. Initial request hosts are restricted to
//  detroitautomationacademy.com and github.com; redirects are followed
//  only to HTTPS URLs on the Academy domain or GitHub's own asset hosts
//  (*.githubusercontent.com — where GitHub serves release assets).
//  Nothing else is contacted, ever. No background activity: downloads
//  start only from the user's button press.
//
//  macOS 10.13 floor. Objective-C, manual retain/release.
//

#import <Foundation/Foundation.h>

@class DistroAppEntry;
@class DistroDownloader;

@protocol DistroDownloaderDelegate <NSObject>
- (void)downloader:(DistroDownloader *)downloader
    didUpdateProgressForEntry:(DistroAppEntry *)entry
                     fraction:(double)fraction; // -1 when indeterminate
- (void)downloader:(DistroDownloader *)downloader
    didFinishDownloadForEntry:(DistroAppEntry *)entry
                     filePath:(NSString *)filePath
                        error:(NSError *)error; // exactly one of filePath/error
@end

@interface DistroDownloader : NSObject <NSURLSessionDownloadDelegate> {
@private
    NSURLSession *_session;
    DistroAppEntry *_activeEntry;
    NSURLSessionDownloadTask *_activeTask;
    NSString *_activeTempPath;
    id<DistroDownloaderDelegate> _delegate; // assign
}

@property (nonatomic, assign) id<DistroDownloaderDelegate> delegate;
@property (nonatomic, readonly) BOOL busy;

- (BOOL)startDownloadForEntry:(DistroAppEntry *)entry; // NO when busy/invalid
- (void)cancelActiveDownload;

@end
