//
//  DistroLogoView.m
//  Distro — Detroit Automation Academy application store (Project 07)
//

#import "DistroLogoView.h"

// Geometry of record: Resources/logo-mark.svg, viewBox 0 0 64 64 —
// the Distro AppIcon artwork itself (owner directive 2026-11-10:
// "distro dock icon and app icon different. use dock icon"). The
// mark this view draws is the bundle AppIcon composition, measured
// from the committed AppIcon.iconset master (1024 px): a white
// rounded tile (inset 5.75, size 52.5, corner radius 11.7), a black
// rounded square centered in it (inset 18.55, size 26.9, corner
// radius 4.0), and the white download arrow (shaft half-width 2.5
// from y 24.5, head top edge y 32.9 at half-width 7.75, tip y 41.9).
// Every in-app surface that presents Distro's own icon — the SDS-8
// welcome screen, the About window, the store sidebar — draws
// through this view, so the icon is one glyph everywhere. The
// SDS-8 motion is a download cue: while animating, the arrow eases
// down 1.1 canvas units and returns over the 2 s period.
// Monochrome only (SDS-1).
static const CGFloat DistroLogoCanvas = 64.0;
static const NSTimeInterval DistroLogoPeriod = 2.0;

@implementation DistroLogoView

- (BOOL)isFlipped {
    return YES; // match SVG's top-left origin
}

- (void)dealloc {
    [self stopAnimation];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)drawIconWithArrowOffset:(CGFloat)dy {
    // The tile: white rounded square, as in the AppIcon artwork.
    NSRect tileRect = NSMakeRect(5.75, 5.75, 52.5, 52.5);
    [[NSColor whiteColor] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:tileRect
                                     xRadius:11.7
                                     yRadius:11.7] fill];

    // The inset black rounded square.
    NSRect squareRect = NSMakeRect(18.55, 18.55, 26.9, 26.9);
    [[NSColor blackColor] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:squareRect
                                     xRadius:4.0
                                     yRadius:4.0] fill];

    // The download arrow, in white, on the black square.
    NSBezierPath *arrow = [NSBezierPath bezierPath];
    [arrow moveToPoint:NSMakePoint(29.5, 24.5 + dy)];
    [arrow lineToPoint:NSMakePoint(34.5, 24.5 + dy)];
    [arrow lineToPoint:NSMakePoint(34.5, 32.9 + dy)];
    [arrow lineToPoint:NSMakePoint(39.75, 32.9 + dy)];
    [arrow lineToPoint:NSMakePoint(32.0, 41.9 + dy)];
    [arrow lineToPoint:NSMakePoint(24.25, 32.9 + dy)];
    [arrow lineToPoint:NSMakePoint(29.5, 32.9 + dy)];
    [arrow closePath];
    [[NSColor whiteColor] setFill];
    [arrow fill];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    NSRect bounds = [self bounds];
    CGFloat scale = MIN(NSWidth(bounds), NSHeight(bounds)) / DistroLogoCanvas;
    NSAffineTransform *t = [NSAffineTransform transform];
    [t translateXBy:(NSWidth(bounds) - DistroLogoCanvas * scale) / 2
                yBy:(NSHeight(bounds) - DistroLogoCanvas * scale) / 2];
    [t scaleBy:scale];
    [t concat];

    CGFloat dy = 0;
    if (_animating) {
        NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - _startTime;
        CGFloat phase = (CGFloat)fmod(elapsed / DistroLogoPeriod, 1.0);
        dy = (CGFloat)(1.1 * (0.5 - 0.5 * cos(2.0 * M_PI * phase)));
    }
    [self drawIconWithArrowOffset:dy];
}

#pragma mark - Animation lifecycle

- (BOOL)motionAllowed {
    return ![[NSWorkspace sharedWorkspace] accessibilityDisplayShouldReduceMotion];
}

- (BOOL)windowVisibleAndUnoccluded {
    NSWindow *w = [self window];
    if (w == nil || ![w isVisible]) return NO;
    return ([w occlusionState] & NSWindowOcclusionStateVisible) != 0;
}

- (void)refreshAnimationState {
    if ([self motionAllowed] && [self windowVisibleAndUnoccluded]) {
        if (!_animating) {
            _animating = YES;
            _startTime = [NSDate timeIntervalSinceReferenceDate];
            [_timer invalidate];
            [_timer release];
            _timer = [[NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0
                                                       target:self
                                                     selector:@selector(tick:)
                                                     userInfo:nil
                                                      repeats:YES] retain];
        }
    } else {
        [self stopAnimation];
    }
    [self setNeedsDisplay:YES];
}

- (void)stopAnimation {
    _animating = NO;
    [_timer invalidate];
    [_timer release];
    _timer = nil;
}

- (void)tick:(NSTimer *)timer {
    if (![self windowVisibleAndUnoccluded] || ![self motionAllowed]) {
        [self refreshAnimationState];
        return;
    }
    [self setNeedsDisplay:YES];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSWindowDidChangeOcclusionStateNotification
                                                  object:nil];
    if ([self window] != nil) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(refreshAnimationState)
                                                     name:NSWindowDidChangeOcclusionStateNotification
                                                   object:[self window]];
    }
    [self refreshAnimationState];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    [super viewWillMoveToWindow:newWindow];
    if (newWindow == nil) [self stopAnimation];
}

@end
