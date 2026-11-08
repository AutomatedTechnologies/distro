//
//  DistroWelcomeController.h
//  Distro — Detroit Automation Academy application store (Project 07)
//
//  The standard animated-logo welcome screen (SDS-8): presented at
//  every launch, before the store window — the animated DAADV2 logo
//  mark (static under Reduce Motion), the app name, the Detroit
//  Automation Academy signature line, one line of verified-state copy,
//  and a single user-driven Continue action (button; Return and Escape
//  also dismiss). No auto-dismiss timer, no blocking delay.
//
//  macOS 10.13 floor. Objective-C, manual retain/release.
//

#import <Cocoa/Cocoa.h>

typedef void (^DistroWelcomeContinueHandler)(void);

@interface DistroWelcomeController : NSWindowController {
@private
    DistroWelcomeContinueHandler _onContinue; // copied
    NSSound *_startupSound; // retained while playing
    BOOL _soundPlayed;
}

@property (nonatomic, copy) DistroWelcomeContinueHandler onContinue;

- (id)init;

@end
