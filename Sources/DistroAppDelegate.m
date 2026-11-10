//
//  DistroAppDelegate.m
//  Distro — Detroit Automation Academy application store (Project 07)
//

#import "DistroAppDelegate.h"
#import "DistroInstalledRecords.h"
#import "DistroStoreController.h"
#import "DistroWelcomeController.h"
#import "DistroLogoView.h"

@implementation DistroAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Deep links (DISTRO-DL1): register for GetURL events first, so
    // a cold launch through academy-distro://app/<id> is captured.
    [[NSAppleEventManager sharedAppleEventManager]
        setEventHandler:self
            andSelector:@selector(handleGetURLEvent:withReplyEvent:)
          forEventClass:kInternetEventClass
             andEventID:kAEGetURL];
    [self buildMenu];
    _records = [[DistroInstalledRecords alloc] init];

    // SDS-8: welcome screen first, at every launch; the store window
    // opens only on the user's Continue.
    _welcomeController = [[DistroWelcomeController alloc] init];
    DistroAppDelegate *selfRef = self;
    [_welcomeController setOnContinue:^{
        [selfRef openStore];
    }];
    [_welcomeController showWindow:self];
    [[_welcomeController window] makeKeyAndOrderFront:self];
}

- (void)openStore {
    if (_storeController == nil) {
        _storeController = [[DistroStoreController alloc] initWithRecords:_records];
    }
    [_storeController showWindow:self];
    [[_storeController window] makeKeyAndOrderFront:self];
    [_storeController loadCatalog];
    if (_pendingDeepLinkAppID != nil) {
        // The controller holds the id until its catalog lands.
        [_storeController showDetailForAppID:_pendingDeepLinkAppID];
        [_pendingDeepLinkAppID release];
        _pendingDeepLinkAppID = nil;
    }
    // The welcome controller's job is done.
    [_welcomeController release];
    _welcomeController = nil;
}

#pragma mark - Deep links (DISTRO-DL1)

// academy-distro://app/<catalog-id> routes to that app's detail
// pane (Distro files/24 section 4). The URL is data, never code:
// the scheme and host must match exactly, the id must be a single
// path component, and DistroStoreController matches it against the
// live catalog — an unknown id lands on a status line. A link only
// selects; it starts no operation, so the store's one-operation
// rule is untouched.
- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event
          withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject]
        stringValue];
    NSURL *url = [NSURL URLWithString:urlString != nil ? urlString : @""];
    if (![[[url scheme] lowercaseString] isEqualToString:@"academy-distro"]) {
        return;
    }
    if (![[[url host] lowercaseString] isEqualToString:@"app"]) {
        return;
    }
    NSString *appID = [[url path] stringByRemovingPercentEncoding];
    if ([appID hasPrefix:@"/"]) {
        appID = [appID substringFromIndex:1];
    }
    if ([appID length] == 0 ||
        [appID rangeOfString:@"/"].location != NSNotFound) {
        return;
    }
    [self routeDeepLinkToAppID:appID];
}

- (void)routeDeepLinkToAppID:(NSString *)appID {
    if (_storeController != nil) {
        [_storeController showWindow:self];
        [[_storeController window] makeKeyAndOrderFront:self];
        [_storeController showDetailForAppID:appID];
    } else {
        // The SDS-8 welcome still gates the store at launch; the
        // route applies when the owner continues into the store.
        [_pendingDeepLinkAppID release];
        _pendingDeepLinkAppID = [appID retain];
        [_welcomeController showWindow:self];
        [[_welcomeController window] makeKeyAndOrderFront:self];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)dealloc {
    [_records release];
    [_storeController release];
    [_welcomeController release];
    [_aboutWindow release];
    [_pendingDeepLinkAppID release];
    [super dealloc];
}

#pragma mark - Menu

// The menu bar (J directive 2026-11-10 16:31 EST; SDS-10 10.4): app
// menu (About — whose panel shows the runtime version — Reload
// Catalog, Quit ⌘Q), Window, and Help; every item wired to a working
// action. No Edit menu: the app has no editable text field anywhere
// (the store filters by sidebar selection; every text field is a
// label), so Edit items would be permanently dead.
- (void)buildMenu {
    NSMenu *mainMenu = [[[NSMenu alloc] initWithTitle:@"MainMenu"] autorelease];

    NSMenuItem *appMenuItem = [[[NSMenuItem alloc] init] autorelease];
    [mainMenu addItem:appMenuItem];
    NSMenu *appMenu = [[[NSMenu alloc] initWithTitle:@"Distro"] autorelease];
    NSMenuItem *about = [[[NSMenuItem alloc]
        initWithTitle:@"About Distro"
               action:@selector(showAboutPanel:)
        keyEquivalent:@""] autorelease];
    [about setTarget:self];
    [appMenu addItem:about];
    [appMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *reload = [[[NSMenuItem alloc]
        initWithTitle:@"Reload Catalog"
               action:@selector(reloadCatalog:)
        keyEquivalent:@"r"] autorelease];
    [reload setTarget:self];
    [appMenu addItem:reload];
    [appMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *quit = [[[NSMenuItem alloc]
        initWithTitle:@"Quit Distro"
               action:@selector(terminate:)
        keyEquivalent:@"q"] autorelease];
    [appMenu addItem:quit];
    [appMenuItem setSubmenu:appMenu];

    NSMenuItem *windowMenuItem = [[[NSMenuItem alloc] init] autorelease];
    [mainMenu addItem:windowMenuItem];
    NSMenu *windowMenu = [[[NSMenu alloc] initWithTitle:@"Window"] autorelease];
    [windowMenu addItem:[[[NSMenuItem alloc]
        initWithTitle:@"Minimize"
               action:@selector(performMiniaturize:)
        keyEquivalent:@"m"] autorelease]];
    [windowMenu addItem:[[[NSMenuItem alloc]
        initWithTitle:@"Zoom"
               action:@selector(zoom:)
        keyEquivalent:@""] autorelease]];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItem:[[[NSMenuItem alloc]
        initWithTitle:@"Close Window"
               action:@selector(performClose:)
        keyEquivalent:@"w"] autorelease]];
    [windowMenuItem setSubmenu:windowMenu];
    [NSApp setWindowsMenu:windowMenu];

    NSMenuItem *helpMenuItem = [[[NSMenuItem alloc] init] autorelease];
    [mainMenu addItem:helpMenuItem];
    NSMenu *helpMenu = [[[NSMenu alloc] initWithTitle:@"Help"] autorelease];
    NSMenuItem *help = [[[NSMenuItem alloc]
        initWithTitle:@"Distro Help"
               action:@selector(showHelp:)
        keyEquivalent:@""] autorelease];
    [help setTarget:self];
    [helpMenu addItem:help];
    NSMenuItem *site = [[[NSMenuItem alloc]
        initWithTitle:@"Detroit Automation Academy Website"
               action:@selector(showAcademySite:)
        keyEquivalent:@""] autorelease];
    [site setTarget:self];
    [helpMenu addItem:site];
    [helpMenuItem setSubmenu:helpMenu];
    [NSApp setHelpMenu:helpMenu];

    [NSApp setMainMenu:mainMenu];
}

// Reload Catalog is live only once the store exists; before Continue
// there is no catalog session to reload.
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(reloadCatalog:)) {
        return _storeController != nil;
    }
    return YES;
}

- (void)reloadCatalog:(id)sender {
    [_storeController loadCatalog];
}

- (void)showHelp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:
        [NSURL URLWithString:@"https://detroitautomationacademy.com/store/"]];
}

- (void)showAcademySite:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:
        [NSURL URLWithString:@"https://detroitautomationacademy.com/"]];
}

#pragma mark - About panel (DAAD signature surface)

- (void)showAboutPanel:(id)sender {
    if (_aboutWindow == nil) {
        NSRect frame = NSMakeRect(0, 0, 380, 330);
        _aboutWindow = [[NSWindow alloc] initWithContentRect:frame
            styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
              backing:NSBackingStoreBuffered
                defer:NO];
        [_aboutWindow setTitle:@"About Distro"];
        [_aboutWindow setReleasedWhenClosed:NO];
        NSView *content = [_aboutWindow contentView];
        CGFloat w = NSWidth(frame);

        DistroLogoView *logo = [[[DistroLogoView alloc]
            initWithFrame:NSMakeRect((w - 96) / 2, 330 - 36 - 96, 96, 96)] autorelease];
        [content addSubview:logo];

        NSTextField *name = [[[NSTextField alloc] initWithFrame:
            NSMakeRect(20, 330 - 36 - 96 - 40, w - 40, 28)] autorelease];
        [name setStringValue:@"Distro"];
        [name setFont:[NSFont boldSystemFontOfSize:22]];
        [name setAlignment:NSTextAlignmentCenter];
        [name setBezeled:NO]; [name setDrawsBackground:NO];
        [name setEditable:NO]; [name setSelectable:NO];
        [content addSubview:name];

        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        NSString *shortVersion = [info objectForKey:@"CFBundleShortVersionString"];
        NSString *build = [info objectForKey:@"CFBundleVersion"];
        NSTextField *version = [[[NSTextField alloc] initWithFrame:
            NSMakeRect(20, NSMinY([name frame]) - 24, w - 40, 17)] autorelease];
        [version setStringValue:[NSString stringWithFormat:@"Version %@ (%@)",
            shortVersion != nil ? shortVersion : @"0.1.0",
            build != nil ? build : @"1"]];
        [version setFont:[NSFont systemFontOfSize:12]];
        [version setTextColor:[NSColor colorWithCalibratedWhite:0.27 alpha:1.0]];
        [version setAlignment:NSTextAlignmentCenter];
        [version setBezeled:NO]; [version setDrawsBackground:NO];
        [version setEditable:NO]; [version setSelectable:NO];
        [content addSubview:version];

        NSTextField *blurb = [[[NSTextField alloc] initWithFrame:
            NSMakeRect(36, NSMinY([version frame]) - 58, w - 72, 48)] autorelease];
        [blurb setStringValue:@"The application store of Detroit Automation "
            @"Academy for macOS High Sierra. Every download is verified by "
            @"SHA-256 before install. No privileged helper, no telemetry."];
        [blurb setFont:[NSFont systemFontOfSize:11.5]];
        [blurb setAlignment:NSTextAlignmentCenter];
        [[blurb cell] setWraps:YES];
        [blurb setBezeled:NO]; [blurb setDrawsBackground:NO];
        [blurb setEditable:NO]; [blurb setSelectable:NO];
        [content addSubview:blurb];

        NSTextField *copyright = [[[NSTextField alloc] initWithFrame:
            NSMakeRect(20, 30, w - 40, 17)] autorelease];
        NSString *copyrightString = [info objectForKey:@"NSHumanReadableCopyright"];
        [copyright setStringValue:copyrightString != nil ? copyrightString
            : @"© 2026 Detroit Automation Academy"];
        [copyright setFont:[NSFont systemFontOfSize:11]];
        [copyright setTextColor:[NSColor colorWithCalibratedWhite:0.27 alpha:1.0]];
        [copyright setAlignment:NSTextAlignmentCenter];
        [copyright setBezeled:NO]; [copyright setDrawsBackground:NO];
        [copyright setEditable:NO]; [copyright setSelectable:NO];
        [content addSubview:copyright];

        [_aboutWindow center];
    }
    [_aboutWindow makeKeyAndOrderFront:self];
    // Nudge the logo in case Reduce Motion / occlusion state changed.
    for (NSView *sub in [[_aboutWindow contentView] subviews]) {
        if ([sub isKindOfClass:[DistroLogoView class]]) {
            [(DistroLogoView *)sub refreshAnimationState];
        }
    }
}

@end
