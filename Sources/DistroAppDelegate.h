//
//  DistroAppDelegate.h
//  Distro — Detroit Automation Academy application store (Project 07)
//
//  App lifecycle: the SDS-8 welcome screen is presented first; the
//  store window opens on Continue. The About panel carries the DAAD
//  signature: publisher of record is Detroit Automation Academy.
//
//  macOS 10.13 floor. Objective-C, manual retain/release.
//

#import <Cocoa/Cocoa.h>

@class DistroInstalledRecords;
@class DistroStoreController;
@class DistroWelcomeController;

@interface DistroAppDelegate : NSObject <NSApplicationDelegate> {
@private
    DistroInstalledRecords *_records;
    DistroStoreController *_storeController;
    DistroWelcomeController *_welcomeController;
    NSWindow *_aboutWindow;
}

- (void)showAboutPanel:(id)sender;

@end
