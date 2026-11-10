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
    NSTextField *_detailBuildNotes;
    NSTextField *_detailMeta;
    NSTextField *_detailHash;
    NSButton *_detailCopyButton;
    NSButton *_detailSourceButton;
    NSButton *_detailUninstallButton;
    NSTextField *_statusLabel;
    NSProgressIndicator *_progress;
    id _selectedEntry;         // DistroAppEntry (retained via _entries)
    NSString *_busyAppID;
    NSString *_pendingDeepLinkAppID;  // DISTRO-DL1 id awaiting the catalog

    // Update All (J directive 2026-11-08): a sequential queue through
    // the existing per-app update path — one operation at a time,
    // every app keeping its own SHA-256 verification and audit gate.
    NSButton *_updateAllButton;
    NSMutableArray *_updateQueue;   // DistroAppEntry objects not yet started
    NSMutableArray *_updatedNames;  // NSString outcomes for the summary
    NSMutableArray *_failedLines;   // NSString outcomes ("name — reason")
    NSInteger _queueTotal;
    NSInteger _queueDone;           // 1-based position of the running item
}

- (id)initWithRecords:(DistroInstalledRecords *)records;
- (void)loadCatalog;   // fetch (or refetch) the live catalog

// Deep links (DISTRO-DL1): select the catalog entry with this id
// and show its detail pane. Selection only — never starts an
// operation. If the catalog has not loaded yet, the id is held and
// applied when the load completes.
- (void)showDetailForAppID:(NSString *)appID;

@end
