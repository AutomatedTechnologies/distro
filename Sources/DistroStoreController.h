//
//  DistroStoreController.h
//  Distro — Detroit Automation Academy application store (Project 07)
//
//  The store window (charter §7, SDS-5): one window, one sidebar
//  (Categories · Installed · Updates with count), app rows with one
//  state button whose label is the app's true state (Get / Update /
//  Open / Installed / Coming Soon), and a detail view (description,
//  version, size, license, source link, truncated copyable SHA-256,
//  publisher of record: Detroit Automation Academy). A status bar is
//  always visible. Monochrome v2 (SDS-1): ink / paper / panel / muted.
//
//  macOS 10.13 floor. Objective-C, manual retain/release.
//

#import <Cocoa/Cocoa.h>
#import "DistroDownloader.h"

@class DistroInstalledRecords;

@interface DistroStoreController : NSWindowController
    <NSTableViewDataSource, NSTableViewDelegate, DistroDownloaderDelegate> {
@private
    DistroInstalledRecords *_records;
    DistroDownloader *_downloader;
    NSArray *_entries;         // all catalog entries (DistroAppEntry)
    NSArray *_visibleEntries;  // after sidebar filter
    NSArray *_sidebarItems;    // NSDictionary rows
    NSString *_activeFilter;   // @"all" | @"installed" | @"updates" | category name
    NSMutableDictionary *_iconCache;          // fetched catalog icons, by appID
    NSMutableDictionary *_placeholderCache;   // drawn monogram fallbacks, by appID
    NSMutableSet *_iconFetchesInFlight;       // appIDs with an icon fetch running

    NSTableView *_sidebarTable;
    NSTableView *_appTable;
    NSView *_detailView;
    NSTextField *_detailName;
    NSView *_detailChip;      // SDS-9 capsule behind the status word
    NSTextField *_detailStatus;
    NSTextField *_detailDescription;
    NSTextField *_detailMeta;
    NSTextField *_detailHash;
    NSButton *_detailCopyButton;
    NSButton *_detailSourceButton;
    NSButton *_detailUninstallButton;
    NSTextField *_statusLabel;
    NSProgressIndicator *_progress;
    id _selectedEntry;         // DistroAppEntry (retained via _entries)
    NSString *_busyAppID;
}

- (id)initWithRecords:(DistroInstalledRecords *)records;
- (void)loadCatalog;   // fetch (or refetch) the live catalog

@end
