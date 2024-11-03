//
//  AppDelegate.h
//  dotconvert
//
//  Created by Gero Embser on 20.10.24.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSPopover *popover;
@property (strong, nonatomic) NSWindow *progressWindow;
@property (strong, nonatomic) NSWindow *completionWindow;

@end
