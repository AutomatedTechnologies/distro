//
//  DistroWelcomeController.m
//  Distro — Detroit Automation Academy application store (Project 07)
//

#import "DistroWelcomeController.h"
#import <QuartzCore/QuartzCore.h>
#import "DistroLogoView.h"

static NSTextField *DistroLabel(NSString *text, CGFloat size, BOOL bold, NSColor *color) {
    NSTextField *label = [[[NSTextField alloc] initWithFrame:NSZeroRect] autorelease];
    [label setStringValue:text];
    [label setFont:bold ? [NSFont boldSystemFontOfSize:size]
                        : [NSFont systemFontOfSize:size]];
    [label setTextColor:color];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setAlignment:NSTextAlignmentCenter];
    return label;
}

// SDS-9 capsule for the sheet's primary control: the layer carries
// the shape (paper fill, ink hairline border, radius = half the
// height); the button cell draws only its title. Flat tints only.
static void DistroWelcomeStyleCapsule(NSButton *button) {
    [button setBordered:NO];
    [button setWantsLayer:YES];
    CALayer *layer = [button layer];
    [layer setCornerRadius:NSHeight([button frame]) / 2.0];
    [layer setBorderWidth:1.0];
    [layer setBorderColor:[[NSColor blackColor] CGColor]];
    [layer setBackgroundColor:[[NSColor colorWithCalibratedWhite:1.0 alpha:1.0] CGColor]];
}

static void DistroWelcomeAddStrip(NSView *parent, NSRect frame, NSColor *color) {
    NSView *strip = [[[NSView alloc] initWithFrame:frame] autorelease];
    [strip setWantsLayer:YES];
    [[strip layer] setBackgroundColor:[color CGColor]];
    [parent addSubview:strip];
}

@implementation DistroWelcomeController

@synthesize onContinue = _onContinue;

- (id)init {
    NSRect frame = NSMakeRect(0, 0, 480, 520);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
          backing:NSBackingStoreBuffered
            defer:NO] autorelease];
    [window setTitle:@"Welcome to Distro"];
    [window setReleasedWhenClosed:NO];
    self = [super initWithWindow:window];
    if (self) {
        NSView *content = [window contentView];
        CGFloat w = NSWidth(frame);

        // SDS-9 floating layer: the welcome sheet is paper, one tint
        // step above the store ground, with the glass hairline pair
        // on its top edge (ink hairline on the edge, shade strip
        // beneath it — the pair's readable form on a paper sheet).
        [content setWantsLayer:YES];
        [[content layer] setBackgroundColor:
            [[NSColor colorWithCalibratedWhite:1.0 alpha:1.0] CGColor]];
        DistroWelcomeAddStrip(content, NSMakeRect(0, 519, w, 1),
            [NSColor blackColor]);
        DistroWelcomeAddStrip(content, NSMakeRect(0, 518, w, 1),
            [NSColor colorWithCalibratedWhite:0.93 alpha:1.0]);

        DistroLogoView *logo = [[[DistroLogoView alloc]
            initWithFrame:NSMakeRect((w - 132) / 2, 520 - 60 - 132, 132, 132)] autorelease];
        [content addSubview:logo];

        NSTextField *name = DistroLabel(@"Distro", 28, YES, [NSColor blackColor]);
        [name setFrame:NSMakeRect(40, 520 - 60 - 132 - 52, w - 80, 36)];
        [content addSubview:name];

        NSTextField *signature = DistroLabel(@"Detroit Automation Academy", 13, NO,
            [NSColor colorWithCalibratedWhite:0.27 alpha:1.0]);
        [signature setFrame:NSMakeRect(40, NSMinY([name frame]) - 28, w - 80, 20)];
        [content addSubview:signature];

        NSTextField *copyLine = DistroLabel(
            @"Browse, install, and update Detroit Automation Academy software "
            @"on macOS High Sierra — every download is verified by SHA-256 "
            @"before it installs.", 12.5, NO, [NSColor blackColor]);
        [copyLine setFrame:NSMakeRect(50, NSMinY([signature frame]) - 74, w - 100, 62)];
        [[copyLine cell] setWraps:YES];
        [content addSubview:copyLine];

        // Security tagline (J directive 2026-11-08): the acceptance
        // rule stated where the user first meets the store. Sits in
        // the open space between the copy line and Continue; no
        // existing frame moves.
        NSTextField *tagline = DistroLabel(
            @"Disassembled. Scanned. Recompiled. Distro distributes only "
            @"apps carrying the Academy audit entry in their plist — "
            @"proof of the Academy pipeline.", 11.5, NO,
            [NSColor colorWithCalibratedWhite:0.27 alpha:1.0]);
        [tagline setFrame:NSMakeRect(50, NSMinY([copyLine frame]) - 58, w - 100, 44)];
        [[tagline cell] setWraps:YES];
        [tagline setAlignment:NSTextAlignmentCenter];
        [content addSubview:tagline];

        NSButton *continueButton = [[[NSButton alloc]
            initWithFrame:NSMakeRect((w - 140) / 2, 44, 140, 32)] autorelease];
        [continueButton setTitle:@"Continue"];
        [continueButton setBezelStyle:NSBezelStyleRounded];
        [continueButton setFont:[NSFont systemFontOfSize:13]];
        [continueButton setTarget:self];
        [continueButton setAction:@selector(continuePressed:)];
        [continueButton setKeyEquivalent:@"\r"];
        // SDS-9 fluid geometry: the primary control is a capsule.
        DistroWelcomeStyleCapsule(continueButton);
        [content addSubview:continueButton];
        // Monochrome standard (DAADV2/SDS): a window default button renders
        // blue (pulsing) on 10.13, so Continue is NOT set as the default
        // button cell — the Return key equivalent above still dismisses,
        // and the button renders in the standard gray bezel.

        // Version on the startup screen (J directive 2026-11-10 16:31
        // EST; SDS-10 10.2): the build's version, read from this
        // bundle's own Info.plist at runtime — never hardcoded — sits
        // at the foot of the welcome screen, under Continue.
        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        NSString *shortVersion = [info objectForKey:@"CFBundleShortVersionString"];
        NSString *build = [info objectForKey:@"CFBundleVersion"];
        NSTextField *version = DistroLabel(
            [NSString stringWithFormat:@"Version %@ (%@)",
                shortVersion != nil ? shortVersion : @"0.1.0",
                build != nil ? build : @"1"],
            11, NO, [NSColor colorWithCalibratedWhite:0.27 alpha:1.0]);
        [version setFrame:NSMakeRect(40, 14, w - 80, 16)];
        [content addSubview:version];

        [window center];
    }
    return self;
}

- (void)dealloc {
    [_onContinue release];
    [_startupSound stop];
    [_startupSound release];
    [super dealloc];
}

// The standard startup sound (design-v2/startup-sound.wav, bundled in
// Resources) plays ONCE when the welcome screen presents — system
// volume, no loop, no replay on Continue. A missing file proceeds
// silently; there is no error surface for it.
- (void)playStartupSoundOnce {
    if (_soundPlayed) return;
    _soundPlayed = YES;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"startup-sound"
                                                     ofType:@"wav"];
    if (path == nil) return;
    _startupSound = [[NSSound alloc] initWithContentsOfFile:path byReference:NO];
    [_startupSound play];
}

- (void)showWindow:(id)sender {
    [super showWindow:sender];
    [self playStartupSoundOnce];
}

- (void)continuePressed:(id)sender {
    DistroWelcomeContinueHandler handler = [[_onContinue retain] autorelease];
    [[self window] close];
    if (handler != nil) handler();
}

// Escape dismisses, exactly like Continue (SDS-8: user-driven dismissal).
- (void)cancelOperation:(id)sender {
    [self continuePressed:sender];
}

@end
