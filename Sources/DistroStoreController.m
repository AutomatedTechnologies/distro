//
//  DistroStoreController.m
//  Distro — Detroit Automation Academy application store (Project 07)
//

#import "DistroStoreController.h"
#import "DistroCatalog.h"
#import "DistroAppEntry.h"
#import "DistroInstalledRecords.h"
#import "DistroInstaller.h"
#import "DistroLogoView.h"

static NSColor *DistroMutedColor(void) {
    return [NSColor colorWithCalibratedWhite:0.27 alpha:1.0];
}
static NSColor *DistroPanelColor(void) {
    return [NSColor colorWithCalibratedWhite:0.957 alpha:1.0];
}
static NSColor *DistroFaintColor(void) {
    return [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
}

static NSTextField *DistroMakeLabel(NSString *text, CGFloat size, BOOL bold, NSColor *color) {
    NSTextField *label = [[[NSTextField alloc] initWithFrame:NSZeroRect] autorelease];
    [label setStringValue:text != nil ? text : @""];
    [label setFont:bold ? [NSFont boldSystemFontOfSize:size]
                        : [NSFont systemFontOfSize:size]];
    [label setTextColor:color];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    return label;
}

#pragma mark - App row view

@interface DistroAppRowView : NSTableCellView {
@private
    NSImageView *_iconView;
    NSTextField *_nameLabel;
    NSTextField *_taglineLabel;
    NSTextField *_versionLabel;
    NSButton *_stateButton;
    DistroAppEntry *_entry;
}
@property (nonatomic, retain) DistroAppEntry *entry;
@property (nonatomic, readonly) NSButton *stateButton;
- (void)setIcon:(NSImage *)icon name:(NSString *)name tagline:(NSString *)tagline
        version:(NSString *)version;
@end

@implementation DistroAppRowView

@synthesize entry = _entry;
@synthesize stateButton = _stateButton;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(10, 9, 40, 40)];
        [_iconView setImageScaling:NSImageScaleProportionallyUpOrDown];
        [self addSubview:_iconView];

        _nameLabel = [DistroMakeLabel(@"", 13, YES, [NSColor blackColor]) retain];
        [_nameLabel setFrame:NSMakeRect(60, 31, 430, 18)];
        [self addSubview:_nameLabel];

        _taglineLabel = [DistroMakeLabel(@"", 11, NO, DistroMutedColor()) retain];
        [_taglineLabel setFrame:NSMakeRect(60, 12, 430, 15)];
        [self addSubview:_taglineLabel];

        _versionLabel = [DistroMakeLabel(@"", 11, NO, DistroMutedColor()) retain];
        [_versionLabel setAlignment:NSTextAlignmentRight];
        [_versionLabel setFrame:NSMakeRect(496, 21, 130, 15)];
        [self addSubview:_versionLabel];

        _stateButton = [[NSButton alloc] initWithFrame:NSMakeRect(640, 14, 118, 30)];
        [_stateButton setBezelStyle:NSBezelStyleRounded];
        [_stateButton setFont:[NSFont systemFontOfSize:12]];
        [self addSubview:_stateButton];
    }
    return self;
}

- (void)dealloc {
    [_iconView release];
    [_nameLabel release];
    [_taglineLabel release];
    [_versionLabel release];
    [_stateButton release];
    [_entry release];
    [super dealloc];
}

- (void)setIcon:(NSImage *)icon name:(NSString *)name tagline:(NSString *)tagline
        version:(NSString *)version {
    [_iconView setImage:icon];
    [_nameLabel setStringValue:name != nil ? name : @""];
    [_taglineLabel setStringValue:tagline != nil ? tagline : @""];
    [_versionLabel setStringValue:version != nil ? version : @""];
}

@end

#pragma mark - Store controller

// Row states (charter §7: the button label is the app's true state).
enum {
    DistroStateComingSoon = 0,
    DistroStateGet,
    DistroStateUpdate,
    DistroStateOpen,
    DistroStateInstalledPkg,
    DistroStateReplaced // bundle-collision correction (2026-11-08): this
                        // entry's bundle is on disk, but a sibling entry
                        // sharing the bundle identity owns it now
};

@implementation DistroStoreController

- (id)initWithRecords:(DistroInstalledRecords *)records {
    NSRect frame = NSMakeRect(0, 0, 1020, 660);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                   NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
          backing:NSBackingStoreBuffered
            defer:NO] autorelease];
    [window setTitle:@"Distro — Detroit Automation Academy"];
    [window setMinSize:NSMakeSize(880, 560)];
    [window setReleasedWhenClosed:NO];
    self = [super initWithWindow:window];
    if (self) {
        _records = [records retain];
        _downloader = [[DistroDownloader alloc] init];
        [_downloader setDelegate:self];
        _iconCache = [[NSMutableDictionary alloc] init];
        _placeholderCache = [[NSMutableDictionary alloc] init];
        _iconFetchesInFlight = [[NSMutableSet alloc] init];
        _activeFilter = [@"all" retain];
        [self buildInterface];
        [window center];
    }
    return self;
}

- (void)dealloc {
    [_records release];
    [_downloader release];
    [_entries release];
    [_visibleEntries release];
    [_sidebarItems release];
    [_activeFilter release];
    [_iconCache release];
    [_placeholderCache release];
    [_iconFetchesInFlight release];
    [_busyAppID release];
    [super dealloc];
}

#pragma mark - Interface construction

- (void)buildInterface {
    NSView *content = [[self window] contentView];
    CGFloat W = 1020, H = 660;
    CGFloat statusH = 26, sidebarW = 210, detailH = 172;

    // ---- Status bar (always visible, SDS-5)
    NSView *statusBar = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, W, statusH)] autorelease];
    [statusBar setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    [content addSubview:statusBar];
    _statusLabel = [DistroMakeLabel(@"Starting…", 11, NO, DistroMutedColor()) retain];
    [_statusLabel setFrame:NSMakeRect(10, 5, 520, 16)];
    [statusBar addSubview:_statusLabel];
    _progress = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(545, 5, 200, 16)];
    [_progress setStyle:NSProgressIndicatorBarStyle];
    // Monochrome standard (DAADV2/SDS): the default control tint renders
    // this bar blue on 10.13 — graphite keeps the rendered app grayscale.
    [_progress setControlTint:NSGraphiteControlTint];
    [_progress setIndeterminate:NO];
    [_progress setMinValue:0];
    [_progress setMaxValue:1];
    [_progress setHidden:YES];
    [statusBar addSubview:_progress];
    NSButton *refresh = [[[NSButton alloc] initWithFrame:NSMakeRect(W - 116, 2, 106, 22)] autorelease];
    [refresh setTitle:@"Refresh"];
    [refresh setBezelStyle:NSBezelStyleRounded];
    [refresh setFont:[NSFont systemFontOfSize:11]];
    [refresh setTarget:self];
    [refresh setAction:@selector(refreshPressed:)];
    [refresh setAutoresizingMask:NSViewMinXMargin];
    [statusBar addSubview:refresh];

    // ---- Sidebar
    NSView *sidebar = [[[NSView alloc] initWithFrame:NSMakeRect(0, statusH, sidebarW, H - statusH)] autorelease];
    [sidebar setAutoresizingMask:NSViewHeightSizable | NSViewMaxXMargin];
    [content addSubview:sidebar];

    // Sidebar header = the standard lockup (SDS-4; prototype of record:
    // files/test2-header-prototype.svg). distro-test-1 defect V-1/V-2/V-3:
    // the wordmark frame (bottom at top-52+20) and the publisher frame
    // (top at top-70+26 = top-44) OVERLAPPED by 8 pt, so "Distro" drew
    // over "Detroit Automation" (owner screenshot, 2026-11-08 00:43);
    // and the sidebar table began 26 pt below the header block, leaving
    // a dead gap above CATEGORIES. Geometry below (sidebar-local, top =
    // H - statusH): mark 56x56, 14 pt top margin; wordmark top-aligned
    // with the mark; publisher stacked UNDER the wordmark with 3 pt
    // clear; table top 10 pt under the header block. No frame overlaps.
    DistroLogoView *logo = [[[DistroLogoView alloc]
        initWithFrame:NSMakeRect(14, H - statusH - 70, 56, 56)] autorelease];
    [logo setAutoresizingMask:NSViewMinYMargin];
    [sidebar addSubview:logo];
    NSTextField *wordmark = DistroMakeLabel(@"Distro", 15, YES, [NSColor blackColor]);
    [wordmark setFrame:NSMakeRect(80, H - statusH - 35, 124, 21)];
    [wordmark setAutoresizingMask:NSViewMinYMargin];
    [sidebar addSubview:wordmark];
    NSTextField *publisher = DistroMakeLabel(@"Detroit Automation Academy", 10.5, NO, DistroMutedColor());
    [publisher setFrame:NSMakeRect(80, H - statusH - 65, 124, 27)];
    [[publisher cell] setWraps:YES];
    [publisher setAutoresizingMask:NSViewMinYMargin];
    [sidebar addSubview:publisher];

    NSScrollView *sidebarScroll = [[[NSScrollView alloc]
        initWithFrame:NSMakeRect(0, 0, sidebarW, H - statusH - 80)] autorelease];
    [sidebarScroll setAutoresizingMask:NSViewHeightSizable];
    [sidebarScroll setHasVerticalScroller:YES];
    [sidebarScroll setBorderType:NSNoBorder];
    [sidebarScroll setDrawsBackground:NO];
    _sidebarTable = [[NSTableView alloc] initWithFrame:NSZeroRect];
    NSTableColumn *scol = [[[NSTableColumn alloc] initWithIdentifier:@"sidebar"] autorelease];
    [scol setWidth:sidebarW - 4];
    [_sidebarTable addTableColumn:scol];
    [_sidebarTable setHeaderView:nil];
    [_sidebarTable setRowHeight:24];
    [_sidebarTable setIntercellSpacing:NSMakeSize(0, 0)];
    [_sidebarTable setDataSource:self];
    [_sidebarTable setDelegate:self];
    [_sidebarTable setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
    [_sidebarTable setBackgroundColor:[NSColor clearColor]];
    [sidebarScroll setDocumentView:_sidebarTable];
    [sidebar addSubview:sidebarScroll];

    // Hairline between sidebar and content.
    NSView *vline = [[[NSView alloc] initWithFrame:NSMakeRect(sidebarW, statusH, 1, H - statusH)] autorelease];
    [vline setWantsLayer:YES];
    [[vline layer] setBackgroundColor:[[NSColor blackColor] CGColor]];
    [vline setAutoresizingMask:NSViewHeightSizable | NSViewMaxXMargin];
    [content addSubview:vline];

    // ---- App table
    NSScrollView *appScroll = [[[NSScrollView alloc]
        initWithFrame:NSMakeRect(sidebarW + 1, statusH + detailH, W - sidebarW - 1, H - statusH - detailH)] autorelease];
    [appScroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [appScroll setHasVerticalScroller:YES];
    [appScroll setBorderType:NSNoBorder];
    _appTable = [[NSTableView alloc] initWithFrame:NSZeroRect];
    NSTableColumn *acol = [[[NSTableColumn alloc] initWithIdentifier:@"app"] autorelease];
    [acol setWidth:W - sidebarW - 20];
    [_appTable addTableColumn:acol];
    [_appTable setHeaderView:nil];
    [_appTable setRowHeight:58];
    [_appTable setIntercellSpacing:NSMakeSize(0, 1)];
    [_appTable setDataSource:self];
    [_appTable setDelegate:self];
    [_appTable setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
    [_appTable setGridColor:DistroPanelColor()];
    [appScroll setDocumentView:_appTable];
    [content addSubview:appScroll];

    // ---- Detail view
    _detailView = [[NSView alloc] initWithFrame:NSMakeRect(sidebarW + 1, statusH, W - sidebarW - 1, detailH)];
    [_detailView setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
    [content addSubview:_detailView];
    NSView *hline = [[[NSView alloc] initWithFrame:NSMakeRect(0, detailH - 1, W - sidebarW - 1, 1)] autorelease];
    [hline setWantsLayer:YES];
    [[hline layer] setBackgroundColor:[[NSColor blackColor] CGColor]];
    [hline setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
    [_detailView addSubview:hline];
    CGFloat dw = W - sidebarW - 1;
    _detailName = [DistroMakeLabel(@"", 15, YES, [NSColor blackColor]) retain];
    [_detailName setFrame:NSMakeRect(14, detailH - 34, 300, 20)];
    [_detailView addSubview:_detailName];
    // Status word sits inside the title block, immediately after the
    // app name on the same baseline — distro-test-1 floated it at the
    // detail pane's far right edge, detached from the title.
    _detailStatus = [DistroMakeLabel(@"", 11, NO, DistroMutedColor()) retain];
    [_detailStatus setFrame:NSMakeRect(322, detailH - 33, dw - 336, 18)];
    [_detailStatus setAlignment:NSTextAlignmentLeft];
    [_detailView addSubview:_detailStatus];
    _detailDescription = [DistroMakeLabel(@"", 12, NO, [NSColor blackColor]) retain];
    [_detailDescription setFrame:NSMakeRect(14, detailH - 92, dw - 28, 52)];
    [[_detailDescription cell] setWraps:YES];
    [_detailView addSubview:_detailDescription];
    _detailMeta = [DistroMakeLabel(@"", 11, NO, DistroMutedColor()) retain];
    [_detailMeta setFrame:NSMakeRect(14, 62, dw - 28, 16)];
    [_detailView addSubview:_detailMeta];
    _detailHash = [DistroMakeLabel(@"", 11, NO, DistroMutedColor()) retain];
    [_detailHash setFont:[NSFont fontWithName:@"Menlo" size:11]];
    [_detailHash setFrame:NSMakeRect(14, 38, 300, 16)];
    [_detailView addSubview:_detailHash];
    _detailCopyButton = [[NSButton alloc] initWithFrame:NSMakeRect(318, 34, 64, 22)];
    [_detailCopyButton setTitle:@"Copy"];
    [_detailCopyButton setBezelStyle:NSBezelStyleRounded];
    [_detailCopyButton setFont:[NSFont systemFontOfSize:11]];
    [_detailCopyButton setTarget:self];
    [_detailCopyButton setAction:@selector(copyHashPressed:)];
    [_detailView addSubview:_detailCopyButton];
    _detailSourceButton = [[NSButton alloc] initWithFrame:NSMakeRect(392, 34, 84, 22)];
    [_detailSourceButton setTitle:@"Source"];
    [_detailSourceButton setBezelStyle:NSBezelStyleRounded];
    [_detailSourceButton setFont:[NSFont systemFontOfSize:11]];
    [_detailSourceButton setTarget:self];
    [_detailSourceButton setAction:@selector(sourcePressed:)];
    [_detailView addSubview:_detailSourceButton];
    _detailUninstallButton = [[NSButton alloc] initWithFrame:NSMakeRect(dw - 110, 34, 96, 22)];
    [_detailUninstallButton setTitle:@"Uninstall"];
    [_detailUninstallButton setBezelStyle:NSBezelStyleRounded];
    [_detailUninstallButton setFont:[NSFont systemFontOfSize:11]];
    [_detailUninstallButton setTarget:self];
    [_detailUninstallButton setAction:@selector(uninstallPressed:)];
    [_detailUninstallButton setAutoresizingMask:NSViewMinXMargin];
    [_detailView addSubview:_detailUninstallButton];
    [self updateDetail];
}

#pragma mark - Catalog

- (void)loadCatalog {
    [self setStatus:@"Loading the Academy catalog…"];
    DistroStoreController *selfRef = self;
    [DistroCatalog fetchCatalogFromURL:[DistroCatalog defaultCatalogURL]
        completion:^(NSArray *entries, NSError *error) {
            if (error != nil) {
                [selfRef setStatus:[NSString stringWithFormat:
                    @"Catalog could not be loaded: %@", [error localizedDescription]]];
                if ([selfRef->_entries count] == 0) {
                    [selfRef rebuildSidebarAndReload];
                }
                return;
            }
            [selfRef->_entries release];
            selfRef->_entries = [entries retain];
            [selfRef setStatus:[NSString stringWithFormat:
                @"Catalog loaded — %lu apps. Publisher: Detroit Automation Academy.",
                (unsigned long)[entries count]]];
            [selfRef rebuildSidebarAndReload];
            [selfRef fetchCatalogIcons];
        }];
}

- (void)setStatus:(NSString *)text {
    [_statusLabel setStringValue:text != nil ? text : @""];
}

- (void)refreshPressed:(id)sender {
    [self loadCatalog];
}

#pragma mark - Sidebar model + filtering

- (NSInteger)updatesCount {
    NSInteger n = 0;
    for (DistroAppEntry *entry in _entries) {
        if ([_records hasUpdateForID:[entry appID] catalogSHA256:[entry sha256]]) n++;
    }
    return n;
}

- (void)rebuildSidebarAndReload {
    NSMutableArray *items = [NSMutableArray array];
    [items addObject:[NSDictionary dictionaryWithObjectsAndKeys:
        @"header", @"kind", @"CATEGORIES", @"title", nil]];
    [items addObject:[NSDictionary dictionaryWithObjectsAndKeys:
        @"filter", @"kind", @"all", @"filter", @"All Apps", @"title", nil]];
    NSMutableSet *cats = [NSMutableSet set];
    for (DistroAppEntry *entry in _entries) {
        if ([entry category] != nil) [cats addObject:[entry category]];
    }
    for (NSString *cat in [[cats allObjects] sortedArrayUsingSelector:@selector(compare:)]) {
        [items addObject:[NSDictionary dictionaryWithObjectsAndKeys:
            @"filter", @"kind", cat, @"filter", cat, @"title", nil]];
    }
    [items addObject:[NSDictionary dictionaryWithObjectsAndKeys:
        @"header", @"kind", @"LIBRARY", @"title", nil]];
    [items addObject:[NSDictionary dictionaryWithObjectsAndKeys:
        @"filter", @"kind", @"installed", @"filter", @"Installed", @"title", nil]];
    NSInteger updates = [self updatesCount];
    NSString *updatesTitle = updates > 0
        ? [NSString stringWithFormat:@"Updates (%ld)", (long)updates]
        : @"Updates";
    [items addObject:[NSDictionary dictionaryWithObjectsAndKeys:
        @"filter", @"kind", @"updates", @"filter", updatesTitle, @"title", nil]];
    [_sidebarItems release];
    _sidebarItems = [items retain];
    [self applyFilter];
    [_sidebarTable reloadData];
    // Keep the sidebar selection on the active filter.
    for (NSUInteger i = 0; i < [_sidebarItems count]; i++) {
        NSDictionary *item = [_sidebarItems objectAtIndex:i];
        if ([[item objectForKey:@"filter"] isEqualToString:_activeFilter]) {
            [_sidebarTable selectRowIndexes:[NSIndexSet indexSetWithIndex:i]
                       byExtendingSelection:NO];
            break;
        }
    }
}

- (void)applyFilter {
    NSMutableArray *visible = [NSMutableArray array];
    for (DistroAppEntry *entry in _entries) {
        BOOL show = NO;
        if ([_activeFilter isEqualToString:@"all"]) {
            show = YES;
        } else if ([_activeFilter isEqualToString:@"installed"]) {
            // Honest Installed list: a replaced entry is not installed
            // (its sibling's build owns the shared bundle).
            NSInteger st = [self stateForEntry:entry];
            show = (st == DistroStateOpen || st == DistroStateInstalledPkg);
        } else if ([_activeFilter isEqualToString:@"updates"]) {
            show = [_records hasUpdateForID:[entry appID] catalogSHA256:[entry sha256]];
        } else {
            show = [[entry category] isEqualToString:_activeFilter];
        }
        if (show) [visible addObject:entry];
    }
    [_visibleEntries release];
    _visibleEntries = [visible retain];
    [_appTable reloadData];
    if ([_visibleEntries count] > 0) {
        [_appTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
               byExtendingSelection:NO];
    } else {
        _selectedEntry = nil;
        [self updateDetail];
    }
}

#pragma mark - App state

// Bundle-collision correction (2026-11-08, record files/05): two
// catalog entries can ship the SAME bundle identity — KisMac and the
// staged unified build both install KisMac2.app (com.igrsoft.kismac).
// One on-disk bundle can be only one entry's build: the one installed
// most recently. Identity is read from the records (bundlePath, or
// bundleID when both records carry it), never from catalog copy.

// The catalog entry for an app id, or nil.
- (DistroAppEntry *)entryForAppID:(NSString *)appID {
    for (DistroAppEntry *candidate in _entries) {
        if ([[candidate appID] isEqualToString:appID]) return candidate;
    }
    return nil;
}

// YES when records A and B describe the same installed bundle.
- (BOOL)record:(NSDictionary *)a sharesBundleWithRecord:(NSDictionary *)b {
    NSString *pathA = [a objectForKey:@"bundlePath"];
    NSString *pathB = [b objectForKey:@"bundlePath"];
    if (pathA != nil && [pathA isEqualToString:pathB]) return YES;
    NSString *idA = [a objectForKey:@"bundleID"];
    NSString *idB = [b objectForKey:@"bundleID"];
    return idA != nil && [idA isEqualToString:idB];
}

// When another entry's record owns this entry's bundle (same identity,
// installed later), returns that entry; nil when this entry owns its
// bundle or has none. The bundle must still exist on disk.
- (DistroAppEntry *)bundleOwnerOtherThan:(DistroAppEntry *)entry {
    NSDictionary *mine = [_records recordForID:[entry appID]];
    if (mine == nil) return nil;
    NSString *bundlePath = [mine objectForKey:@"bundlePath"];
    if (bundlePath == nil ||
        ![[NSFileManager defaultManager] fileExistsAtPath:bundlePath]) {
        return nil;
    }
    double myTime = [[mine objectForKey:@"installedAt"] doubleValue];
    DistroAppEntry *owner = nil;
    for (NSString *otherID in [_records installedIDs]) {
        if ([otherID isEqualToString:[entry appID]]) continue;
        NSDictionary *other = [_records recordForID:otherID];
        if (other == nil) continue;
        if (![self record:mine sharesBundleWithRecord:other]) continue;
        if ([[other objectForKey:@"installedAt"] doubleValue] >= myTime) {
            DistroAppEntry *candidate = [self entryForAppID:otherID];
            if (candidate != nil) owner = candidate;
        }
    }
    return owner;
}

// The bundle identity a path holds on disk right now, read from its
// own Info.plist: {bundleID, name, version} (any may be missing).
- (NSDictionary *)diskIdentityForBundleAtPath:(NSString *)bundlePath {
    NSString *plistPath = [[bundlePath stringByAppendingPathComponent:@"Contents"]
        stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    if (info == nil) return nil;
    NSMutableDictionary *identity = [NSMutableDictionary dictionary];
    NSString *bid = [info objectForKey:@"CFBundleIdentifier"];
    if (bid != nil) [identity setObject:bid forKey:@"bundleID"];
    NSString *name = [info objectForKey:@"CFBundleName"];
    if (name == nil) name = [[bundlePath lastPathComponent] stringByDeletingPathExtension];
    [identity setObject:name forKey:@"name"];
    NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
    if (version != nil) [identity setObject:version forKey:@"version"];
    return identity;
}

- (NSInteger)stateForEntry:(DistroAppEntry *)entry {
    if (![entry isInstallable]) return DistroStateComingSoon;
    NSDictionary *rec = [_records recordForID:[entry appID]];
    if (rec == nil) return DistroStateGet;
    if (![[rec objectForKey:@"sha256"] isEqualToString:[entry sha256]]) {
        return DistroStateUpdate;
    }
    if ([[rec objectForKey:@"format"] isEqualToString:@"pkg"]) {
        return DistroStateInstalledPkg;
    }
    NSString *bundlePath = [rec objectForKey:@"bundlePath"];
    if (bundlePath != nil &&
        [[NSFileManager defaultManager] fileExistsAtPath:bundlePath]) {
        // The bundle is on disk — but it may be a sibling entry's
        // build of the same bundle. Only the owning entry may read
        // Open; the replaced entry reads Get and says so in detail.
        if ([self bundleOwnerOtherThan:entry] != nil) {
            return DistroStateReplaced;
        }
        return DistroStateOpen;
    }
    return DistroStateGet; // record exists but the bundle is gone
}

- (NSString *)statusWordForEntry:(DistroAppEntry *)entry {
    if ([[entry status] isEqualToString:@"released"]) return @"Released";
    if ([[entry status] isEqualToString:@"testing"]) return @"Test build";
    return @"In development";
}

#pragma mark - Table data source / delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == _sidebarTable) return (NSInteger)[_sidebarItems count];
    return (NSInteger)[_visibleEntries count];
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    if (tableView == _sidebarTable) {
        NSDictionary *item = [_sidebarItems objectAtIndex:(NSUInteger)row];
        return [[item objectForKey:@"kind"] isEqualToString:@"filter"];
    }
    return YES;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    if (tableView == _sidebarTable) {
        NSDictionary *item = [_sidebarItems objectAtIndex:(NSUInteger)row];
        NSTableCellView *cell = [tableView makeViewWithIdentifier:@"sidebarCell" owner:self];
        if (cell == nil) {
            cell = [[[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)] autorelease];
            NSTextField *tf = [[[NSTextField alloc] initWithFrame:NSMakeRect(12, 3, 186, 17)] autorelease];
            [tf setBezeled:NO];
            [tf setDrawsBackground:NO];
            [tf setEditable:NO];
            [tf setSelectable:NO];
            [cell addSubview:tf];
            [cell setTextField:tf];
            [cell setIdentifier:@"sidebarCell"];
        }
        if ([[item objectForKey:@"kind"] isEqualToString:@"header"]) {
            [[cell textField] setStringValue:[item objectForKey:@"title"]];
            [[cell textField] setFont:[NSFont boldSystemFontOfSize:10]];
            [[cell textField] setTextColor:DistroFaintColor()];
        } else {
            [[cell textField] setStringValue:[item objectForKey:@"title"]];
            [[cell textField] setFont:[NSFont systemFontOfSize:12]];
            [[cell textField] setTextColor:[NSColor blackColor]];
        }
        return cell;
    }

    DistroAppEntry *entry = [_visibleEntries objectAtIndex:(NSUInteger)row];
    DistroAppRowView *cell = [tableView makeViewWithIdentifier:@"appCell" owner:self];
    if (cell == nil) {
        cell = [[[DistroAppRowView alloc] initWithFrame:NSMakeRect(0, 0, 768, 58)] autorelease];
        [cell setIdentifier:@"appCell"];
        [[cell stateButton] setTarget:self];
        [[cell stateButton] setAction:@selector(stateButtonPressed:)];
    }
    [cell setEntry:entry];
    [cell setIcon:[self iconForEntry:entry]
             name:[entry name]
          tagline:[entry tagline]
          version:[NSString stringWithFormat:@"%@", [entry version]]];
    NSButton *button = [cell stateButton];
    switch ([self stateForEntry:entry]) {
        case DistroStateGet:
            [button setTitle:@"Get"]; [button setEnabled:YES]; break;
        case DistroStateUpdate:
            [button setTitle:@"Update"]; [button setEnabled:YES]; break;
        case DistroStateOpen:
            [button setTitle:@"Open"]; [button setEnabled:YES]; break;
        case DistroStateReplaced:
            // Never "Open"/"Installed" for a replaced entry: Get is
            // the honest action — it restores this entry's build.
            [button setTitle:@"Get"]; [button setEnabled:YES]; break;
        case DistroStateInstalledPkg:
            [button setTitle:@"Installed"]; [button setEnabled:NO]; break;
        default:
            [button setTitle:@"Coming Soon"]; [button setEnabled:NO]; break;
    }
    if (_busyAppID != nil) {
        if ([_busyAppID isEqualToString:[entry appID]]) {
            [button setTitle:@"Working…"];
        }
        [button setEnabled:NO];
    }
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSTableView *tableView = [notification object];
    if (tableView == _sidebarTable) {
        NSInteger row = [_sidebarTable selectedRow];
        if (row < 0) return;
        NSDictionary *item = [_sidebarItems objectAtIndex:(NSUInteger)row];
        NSString *filter = [item objectForKey:@"filter"];
        if (filter != nil && ![filter isEqualToString:_activeFilter]) {
            [_activeFilter release];
            _activeFilter = [filter retain];
            [self applyFilter];
        }
    } else if (tableView == _appTable) {
        NSInteger row = [_appTable selectedRow];
        _selectedEntry = (row >= 0 && row < (NSInteger)[_visibleEntries count])
            ? [_visibleEntries objectAtIndex:(NSUInteger)row] : nil;
        [self updateDetail];
    }
}

#pragma mark - Catalog icons (iconURL fetch) + monogram fallback (SDS-3)

// distro-test-1 never loaded the catalog's iconURL images at all —
// rows always showed the drawn monograms, and because every
// /store/icons/*.png was then a 404 the fallback was all the owner
// ever saw (defect V-4). Test-2 fetches each entry's icon from the
// Academy host after the catalog loads, caches it, and keeps the
// in-house monogram strictly as the unreachable-icon fallback.
- (void)fetchCatalogIcons {
    for (DistroAppEntry *entry in _entries) {
        NSString *appID = [entry appID];
        NSURL *url = [entry iconURL];
        if (appID == nil || url == nil) continue;
        if ([_iconCache objectForKey:appID] != nil) continue;
        if ([_iconFetchesInFlight containsObject:appID]) continue;
        if (![[url scheme] isEqualToString:@"https"]) continue;
        NSString *host = [url host];
        if (![host isEqualToString:@"detroitautomationacademy.com"] &&
            ![host isEqualToString:@"www.detroitautomationacademy.com"]) continue;
        [_iconFetchesInFlight addObject:appID];
        NSString *key = [[appID retain] autorelease];
        // Assignment form, as in DistroCatalog's fetch (the chained
        // `... ] resume]` form does not parse under this SDK/clang).
        NSURLSessionDataTask *task =
            [[NSURLSession sharedSession] dataTaskWithURL:url
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                NSImage *image = nil;
                if (data != nil && error == nil) {
                    image = [[[NSImage alloc] initWithData:data] autorelease];
                    if (image != nil &&
                        ([image size].width < 1 || [image size].height < 1)) {
                        image = nil;
                    }
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_iconFetchesInFlight removeObject:key];
                    if (image != nil) {
                        [_iconCache setObject:image forKey:key];
                        [_appTable reloadData];
                    }
                });
            }];
        [task resume];
    }
}

- (NSImage *)iconForEntry:(DistroAppEntry *)entry {
    NSImage *cached = [_iconCache objectForKey:[entry appID]];
    if (cached != nil) return cached;
    NSImage *placeholder = [_placeholderCache objectForKey:[entry appID]];
    if (placeholder != nil) return placeholder;
    NSString *name = [entry name] != nil ? [entry name] : @"?";
    NSMutableString *initials = [NSMutableString string];
    for (NSString *word in [name componentsSeparatedByString:@" "]) {
        if ([word length] > 0 && [initials length] < 2) {
            [initials appendString:[[word substringToIndex:1] uppercaseString]];
        }
    }
    NSImage *image = [[[NSImage alloc] initWithSize:NSMakeSize(80, 80)] autorelease];
    [image lockFocus];
    NSRect rect = NSMakeRect(4, 4, 72, 72);
    [DistroPanelColor() setFill];
    [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:14 yRadius:14] fill];
    [[NSColor blackColor] setStroke];
    NSBezierPath *border = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:14 yRadius:14];
    [border setLineWidth:2];
    [border stroke];
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSFont boldSystemFontOfSize:30], NSFontAttributeName,
        [NSColor blackColor], NSForegroundColorAttributeName, nil];
    NSSize textSize = [initials sizeWithAttributes:attrs];
    [initials drawAtPoint:NSMakePoint((80 - textSize.width) / 2, (80 - textSize.height) / 2)
           withAttributes:attrs];
    [image unlockFocus];
    if (image != nil) [_placeholderCache setObject:image forKey:[entry appID]];
    return image;
}

#pragma mark - Detail view

- (NSString *)formattedSize:(NSNumber *)sizeBytes {
    if (sizeBytes == nil) return @"—";
    double bytes = [sizeBytes doubleValue];
    if (bytes < 1024) return [NSString stringWithFormat:@"%.0f bytes", bytes];
    if (bytes < 1024 * 1024) return [NSString stringWithFormat:@"%.1f KB", bytes / 1024];
    return [NSString stringWithFormat:@"%.2f MB", bytes / (1024 * 1024)];
}

- (void)updateDetail {
    DistroAppEntry *entry = (DistroAppEntry *)_selectedEntry;
    if (entry == nil) {
        [_detailName setStringValue:@""];
        [_detailStatus setStringValue:@""];
        [_detailDescription setStringValue:
            [NSString stringWithFormat:@"Select an app to see its details. "
             @"Distro installs only software published by Detroit Automation "
             @"Academy, and verifies every download by SHA-256 before install."]];
        [_detailMeta setStringValue:@""];
        [_detailHash setStringValue:@""];
        [_detailCopyButton setEnabled:NO];
        [_detailSourceButton setEnabled:NO];
        [_detailUninstallButton setEnabled:NO];
        return;
    }
    [_detailName setStringValue:[entry name]];
    [_detailStatus setStringValue:[self statusWordForEntry:entry]];
    [_detailDescription setStringValue:[entry entryDescription]];
    NSDictionary *rec = [_records recordForID:[entry appID]];
    NSString *installedNote = @"";
    DistroAppEntry *bundleOwner = nil;
    if (rec != nil &&
        [[rec objectForKey:@"sha256"] isEqualToString:[entry sha256]] &&
        ![[rec objectForKey:@"format"] isEqualToString:@"pkg"]) {
        bundleOwner = [self bundleOwnerOtherThan:entry];
    }
    if (bundleOwner != nil) {
        // Language of the correction: name what is actually on disk.
        NSString *bundleName = [rec objectForKey:@"bundleName"];
        if (bundleName == nil) bundleName = @"the shared bundle";
        installedNote = [NSString stringWithFormat:
            @" · Replaced by %@ — the installed %@ is the %@ build",
            [bundleOwner name], bundleName, [bundleOwner name]];
    } else if (rec != nil) {
        installedNote = [NSString stringWithFormat:@" · Installed: %@",
            [rec objectForKey:@"version"]];
    }
    [_detailMeta setStringValue:[NSString stringWithFormat:
        @"Version %@ · Size %@ · License %@ · Requires macOS %@ · Publisher: Detroit Automation Academy%@",
        [entry version], [self formattedSize:[entry sizeBytes]], [entry license],
        [entry minMacOS], installedNote]];
    if ([entry hasVerifiableHash]) {
        NSString *hash = [entry sha256];
        [_detailHash setStringValue:[NSString stringWithFormat:@"SHA-256: %@…",
            [hash substringToIndex:16]]];
        [_detailCopyButton setEnabled:YES];
    } else {
        [_detailHash setStringValue:@"SHA-256: not published (no verified build)"];
        [_detailCopyButton setEnabled:NO];
    }
    [_detailSourceButton setEnabled:[entry sourceURL] != nil];
    // A replaced entry must not uninstall its sibling's bundle: the
    // on-disk bundle belongs to the owning entry's record.
    [_detailUninstallButton setEnabled:(rec != nil && bundleOwner == nil)];
}

- (void)copyHashPressed:(id)sender {
    DistroAppEntry *entry = (DistroAppEntry *)_selectedEntry;
    if (entry == nil || ! [entry hasVerifiableHash]) return;
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString:[entry sha256] forType:NSPasteboardTypeString];
    [self setStatus:@"SHA-256 copied to the clipboard."];
}

- (void)sourcePressed:(id)sender {
    DistroAppEntry *entry = (DistroAppEntry *)_selectedEntry;
    if (entry != nil && [entry sourceURL] != nil) {
        [[NSWorkspace sharedWorkspace] openURL:[entry sourceURL]];
    }
}

- (void)uninstallPressed:(id)sender {
    DistroAppEntry *entry = (DistroAppEntry *)_selectedEntry;
    if (entry == nil) return;
    NSDictionary *rec = [_records recordForID:[entry appID]];
    if (rec == nil) return;
    if ([[rec objectForKey:@"format"] isEqualToString:@"pkg"]) {
        NSError *error = nil;
        [DistroInstaller uninstallEntry:entry records:_records error:&error];
        [self showAlertText:@"About uninstalling this app"
                    message:[error localizedDescription]];
        return;
    }
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:[NSString stringWithFormat:@"Uninstall %@?", [entry name]]];
    [alert setInformativeText:@"The app bundle will be moved to the Trash — "
        @"you can restore it from there. Distro's installed record is removed."];
    [alert addButtonWithTitle:@"Move to Trash"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSError *error = nil;
        if ([DistroInstaller uninstallEntry:entry records:_records error:&error]) {
            [self setStatus:[NSString stringWithFormat:@"%@ uninstalled (moved to Trash).",
                [entry name]]];
            [self rebuildSidebarAndReload];
            [self updateDetail];
        } else {
            [self showAlertText:@"Uninstall failed"
                        message:[error localizedDescription]];
        }
    }
}

#pragma mark - State button: Get / Update / Open

- (void)stateButtonPressed:(id)sender {
    // Find the row view that owns this button.
    NSView *view = (NSView *)sender;
    while (view != nil && ![view isKindOfClass:[DistroAppRowView class]]) {
        view = [view superview];
    }
    if (view == nil) return;
    DistroAppEntry *entry = [(DistroAppRowView *)view entry];
    if (entry == nil) return;
    _selectedEntry = entry;
    [self updateDetail];

    NSInteger state = [self stateForEntry:entry];
    if (state == DistroStateOpen) {
        NSDictionary *rec = [_records recordForID:[entry appID]];
        NSString *bundlePath = [rec objectForKey:@"bundlePath"];
        if (bundlePath == nil) return;
        // Verify before opening (correction, 2026-11-08): read the
        // bundle's identity from disk and check it against what this
        // entry recorded. If a sibling entry shares the bundle, say
        // which build is actually being opened — this entry's own,
        // because stateForEntry only returns Open for the owner.
        NSDictionary *identity = [self diskIdentityForBundleAtPath:bundlePath];
        NSString *recordedID = [rec objectForKey:@"bundleID"];
        NSString *diskID = [identity objectForKey:@"bundleID"];
        if (recordedID != nil && diskID != nil &&
            ![recordedID isEqualToString:diskID]) {
            [self showAlertText:@"Not opening"
                        message:[NSString stringWithFormat:
                @"The bundle at %@ identifies as %@, not the %@ build "
                @"Distro recorded for %@. It will not be opened as %@.",
                bundlePath, diskID, [entry name], [entry name], [entry name]]];
            return;
        }
        [[NSWorkspace sharedWorkspace] launchApplicationAtURL:
            [NSURL fileURLWithPath:bundlePath]
            options:0 configuration:[NSDictionary dictionary] error:NULL];
        // If any other entry's record shares this bundle identity,
        // the status line names the build that was just opened.
        for (NSString *otherID in [_records installedIDs]) {
            if ([otherID isEqualToString:[entry appID]]) continue;
            NSDictionary *other = [_records recordForID:otherID];
            if (other != nil && [self record:rec sharesBundleWithRecord:other]) {
                DistroAppEntry *sibling = [self entryForAppID:otherID];
                [self setStatus:[NSString stringWithFormat:
                    @"Opened %@ — the %@ build (%@). This bundle is shared with %@.",
                    [identity objectForKey:@"name"], [entry name], [entry version],
                    sibling != nil ? [sibling name] : otherID]];
                break;
            }
        }
        return;
    }
    if (state != DistroStateGet && state != DistroStateUpdate &&
        state != DistroStateReplaced) return;
    if (![_downloader startDownloadForEntry:entry]) {
        [self setStatus:@"Another download is already in progress."];
        return;
    }
    [_busyAppID release];
    _busyAppID = [[entry appID] retain];
    [_progress setDoubleValue:0];
    [_progress setIndeterminate:NO];
    [_progress setHidden:NO];
    [self setStatus:[NSString stringWithFormat:@"Downloading %@ %@…",
        [entry name], [entry version]]];
    [_appTable reloadData];
}

#pragma mark - Downloader delegate

- (void)downloader:(DistroDownloader *)downloader
    didUpdateProgressForEntry:(DistroAppEntry *)entry
                     fraction:(double)fraction {
    if (fraction < 0) {
        [_progress setIndeterminate:YES];
    } else {
        [_progress setIndeterminate:NO];
        [_progress setDoubleValue:fraction];
        [self setStatus:[NSString stringWithFormat:@"Downloading %@ — %.0f%%",
            [entry name], fraction * 100]];
    }
}

- (void)downloader:(DistroDownloader *)downloader
    didFinishDownloadForEntry:(DistroAppEntry *)entry
                     filePath:(NSString *)filePath
                        error:(NSError *)error {
    [_busyAppID release];
    _busyAppID = nil;
    [_progress setHidden:YES];
    [_appTable reloadData];
    if (error != nil || filePath == nil) {
        [self setStatus:[NSString stringWithFormat:@"Download failed for %@: %@",
            [entry name], [error localizedDescription]]];
        [self showAlertText:@"Download failed"
                    message:[error localizedDescription]];
        return;
    }
    [self setStatus:[NSString stringWithFormat:
        @"Downloaded %@ — verifying SHA-256 against the catalog…", [entry name]]];
    DistroStoreController *selfRef = self;
    [DistroInstaller verifyAndInstallFileAtPath:filePath
        forEntry:entry
        completion:^(NSDictionary *result, NSError *installError) {
            if (installError != nil) {
                [selfRef setStatus:[installError localizedDescription]];
                [selfRef showAlertText:@"Install stopped"
                                message:[installError localizedDescription]];
                return;
            }
            NSString *format = [result objectForKey:DistroInstallResultFormatKey];
            if ([format isEqualToString:@"pkg"]) {
                [selfRef confirmPkgInstallForEntry:entry];
            } else {
                NSString *installedPath =
                    [result objectForKey:DistroInstallResultBundlePathKey];
                NSDictionary *identity =
                    [selfRef diskIdentityForBundleAtPath:installedPath];
                [selfRef->_records setRecordForID:[entry appID]
                                          version:[entry version]
                                           sha256:[entry sha256]
                                           format:@"app"
                                       bundlePath:installedPath
                                         bundleID:[identity objectForKey:@"bundleID"]
                                       bundleName:[identity objectForKey:@"name"]];
                [selfRef setStatus:[NSString stringWithFormat:@"%@ installed.", [entry name]]];
                [selfRef rebuildSidebarAndReload];
                [selfRef updateDetail];
                [selfRef offerLaunchForEntry:entry
                                  bundlePath:[result objectForKey:DistroInstallResultBundlePathKey]
                                      appsDir:[result objectForKey:DistroInstallResultAppsDirKey]];
            }
        }];
}

- (void)confirmPkgInstallForEntry:(DistroAppEntry *)entry {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:[NSString stringWithFormat:
        @"%@ was verified and opened in the system Installer.", [entry name]]];
    [alert setInformativeText:@"When the Installer finishes successfully, choose "
        @"Mark as Installed so Distro records this version. The Installer and "
        @"macOS own the install itself."];
    [alert addButtonWithTitle:@"Mark as Installed"];
    [alert addButtonWithTitle:@"Not Now"];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [_records setRecordForID:[entry appID]
                         version:[entry version]
                          sha256:[entry sha256]
                          format:@"pkg"
                      bundlePath:nil];
        [self setStatus:[NSString stringWithFormat:@"%@ recorded as installed.", [entry name]]];
    }
    [self rebuildSidebarAndReload];
    [self updateDetail];
}

- (void)offerLaunchForEntry:(DistroAppEntry *)entry
                 bundlePath:(NSString *)bundlePath
                     appsDir:(NSString *)appsDir {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:[NSString stringWithFormat:@"%@ installed.", [entry name]]];
    [alert setInformativeText:[NSString stringWithFormat:
        @"The verified app was placed in %@.", appsDir]];
    [alert addButtonWithTitle:@"Launch"];
    [alert addButtonWithTitle:@"Done"];
    if ([alert runModal] == NSAlertFirstButtonReturn && bundlePath != nil) {
        [[NSWorkspace sharedWorkspace] launchApplicationAtURL:
            [NSURL fileURLWithPath:bundlePath]
            options:0 configuration:[NSDictionary dictionary] error:NULL];
    }
}

- (void)showAlertText:(NSString *)title message:(NSString *)message {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:title];
    [alert setInformativeText:message != nil ? message : @""];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

@end
