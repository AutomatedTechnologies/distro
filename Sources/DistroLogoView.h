//
//  DistroLogoView.h
//  Distro — Detroit Automation Academy application store (Project 07)
//
//  The Distro AppIcon mark (Resources/logo-mark.svg), drawn from
//  the same geometry as the bundle icon and animated: the download
//  arrow eases down and returns in grayscale (owner directive
//  2026-11-10 — the Dock icon is the app's icon on every surface).
//  Monochrome only (SDS-1).
//  Honors Reduce Motion — when NSWorkspace reports
//  accessibilityDisplayShouldReduceMotion, the mark is static.
//  Animation runs only while the view is in a visible, unoccluded
//  window; it stops on window close / occlusion / removal.
//
//  macOS 10.13 floor. Objective-C, manual retain/release.
//

#import <Cocoa/Cocoa.h>

@interface DistroLogoView : NSView {
@private
    NSTimer *_timer;
    NSTimeInterval _startTime;
    BOOL _animating;
}

// Starts the pulse if motion is allowed and the view is in a visible
// window; otherwise draws the static mark. Safe to call repeatedly.
- (void)refreshAnimationState;
- (void)stopAnimation;

@end
