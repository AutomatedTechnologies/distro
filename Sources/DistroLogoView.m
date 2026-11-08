//
//  DistroLogoView.m
//  Distro — Detroit Automation Academy application store (Project 07)
//

#import "DistroLogoView.h"

// Geometry of record: design-v2/logo-mark.svg, viewBox 0 0 64 64.
// Crosspoint dots at (14|32|50, 14|32|50) r=3 except the center, which
// is the enlarged node r=6.5 at (32,32). Signal arcs are quarter arcs
// centered on the node: r=14 (32,18)->(46,32) and r=23 (32,9)->(55,32),
// stroke width 4.5, round caps. Pulse rings expand from the node.
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

- (void)drawDotAt:(NSPoint)p radius:(CGFloat)r color:(NSColor *)color {
    [color setFill];
    NSRect rect = NSMakeRect(p.x - r, p.y - r, r * 2, r * 2);
    [[NSBezierPath bezierPathWithOvalInRect:rect] fill];
}

- (void)drawQuarterArcRadius:(CGFloat)r stroke:(CGFloat)stroke color:(NSColor *)color {
    // Quarter arc in the NE quadrant of the node at (32,32): from the
    // point above the node (32, 32-r) to the point right of it (32+r, 32).
    // In flipped coordinates angles run clockwise: above = -90°, right = 0°.
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(32, 32)
                                     radius:r
                                 startAngle:-90
                                   endAngle:0
                                  clockwise:NO];
    [path setLineWidth:stroke];
    [path setLineCapStyle:NSRoundLineCapStyle];
    [color setStroke];
    [path stroke];
    // Round caps at both endpoints (SVG stroke-linecap="round").
    [self drawDotAt:NSMakePoint(32, 32 - r) radius:stroke / 2 color:color];
    [self drawDotAt:NSMakePoint(32 + r, 32) radius:stroke / 2 color:color];
}

- (void)drawPulseRings {
    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - _startTime;
    NSColor *ink = [NSColor blackColor];
    for (NSInteger i = 0; i < 2; i++) {
        CGFloat phase = (CGFloat)fmod(elapsed / DistroLogoPeriod + i * 0.5, 1.0);
        CGFloat radius = 9.0 + phase * 21.0;             // 9 -> 30 canvas units
        CGFloat alpha = 0.55 * (1.0 - phase) * (1.0 - phase);
        if (alpha < 0.02) continue;
        NSColor *ring = [ink colorWithAlphaComponent:alpha];
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(32, 32)
                                         radius:radius
                                     startAngle:-90
                                       endAngle:0
                                      clockwise:NO];
        [path setLineWidth:3.2];
        [path setLineCapStyle:NSRoundLineCapStyle];
        [ring setStroke];
        [path stroke];
        [self drawDotAt:NSMakePoint(32, 32 - radius) radius:1.6 color:ring];
        [self drawDotAt:NSMakePoint(32 + radius, 32) radius:1.6 color:ring];
    }
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

    NSColor *ink = [NSColor blackColor];
    if (_animating) [self drawPulseRings];

    // Crosspoint grid dots (all but the center).
    const CGFloat coords[3] = {14, 32, 50};
    for (int xi = 0; xi < 3; xi++) {
        for (int yi = 0; yi < 3; yi++) {
            if (coords[xi] == 32 && coords[yi] == 32) continue;
            [self drawDotAt:NSMakePoint(coords[xi], coords[yi]) radius:3 color:ink];
        }
    }
    // Signal arcs of record.
    [self drawQuarterArcRadius:14 stroke:4.5 color:ink];
    [self drawQuarterArcRadius:23 stroke:4.5 color:ink];
    // The broadcast node.
    [self drawDotAt:NSMakePoint(32, 32) radius:6.5 color:ink];
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
