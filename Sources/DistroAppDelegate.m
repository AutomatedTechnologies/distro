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
    // The welcome controller's job is done.
    [_welcomeController release];
    _welcomeController = nil;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)dealloc {
    [_records release];
    [_storeController release];
    [_welcomeController release];
    [_aboutWindow release];
    [super dealloc];
}

#pragma mark - Menu

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
    NSMenuItem *quit = [[[NSMenuItem alloc]
        initWithTitle:@"Quit Distro"
               action:@selector(terminate:)
        keyEquivalent:@"q"] autorelease];
    [appMenu addItem:quit];
    [appMenuItem setSubmenu:appMenu];
    [NSApp setMainMenu:mainMenu];
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
