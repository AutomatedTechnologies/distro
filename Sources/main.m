//
//  main.m
//  Distro — Detroit Automation Academy application store (Project 07)
//
//  macOS 10.13 floor. Objective-C, manual retain/release.
//

#import <Cocoa/Cocoa.h>
#import "DistroAppDelegate.h"

int main(int argc, const char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [NSApplication sharedApplication];
    DistroAppDelegate *delegate = [[DistroAppDelegate alloc] init];
    [NSApp setDelegate:delegate];
    int result = NSApplicationMain(argc, argv);
    [delegate release];
    [pool drain];
    return result;
}
