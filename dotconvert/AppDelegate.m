//
//  AppDelegate.m
//  dotconvert
//
//  Created by Gero Embser on 20.10.24.
//

#import "AppDelegate.h"
#import "ViewController.h"

@interface AppDelegate ()

@property (strong, nonatomic) NSImage *defaultIcon;
@property (strong, nonatomic) NSImage *checkmarkIcon;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Load icons
    self.defaultIcon = [NSImage imageWithSystemSymbolName:@"folder.badge.gearshape" accessibilityDescription:@"DotConvert"];
    self.checkmarkIcon = [NSImage imageWithSystemSymbolName:@"checkmark.circle" accessibilityDescription:@"Conversion Done"];
    
    [self setupMenuBarItem];

    // Register for notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(conversionDone:)
                                                 name:@"ConversionDoneNotification"
                                               object:nil];
}

- (void)setupMenuBarItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.image = self.defaultIcon;
    self.statusItem.button.action = @selector(togglePopover:);
    self.statusItem.button.target = self;
    
    self.popover = [[NSPopover alloc] init];
    self.popover.contentSize = NSMakeSize(300, 200);
    self.popover.behavior = NSPopoverBehaviorTransient;
    
    // Use NSStoryboard to initialize the ViewController
    NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    self.popover.contentViewController = [storyboard instantiateControllerWithIdentifier:@"ViewController"];
}

- (void)togglePopover:(id)sender {
    if (self.popover.isShown) {
        [self.popover performClose:sender];
    } else {
        [self.popover showRelativeToRect:self.statusItem.button.bounds ofView:self.statusItem.button preferredEdge:NSRectEdgeMinY];
        [self.popover.contentViewController.view.window makeKeyAndOrderFront:nil];
    }
}

- (void)conversionDone:(NSNotification *)notification {
    self.statusItem.button.image = self.checkmarkIcon;

    //print to console
    NSLog(@"Conversion done notification received");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.statusItem.button.image = self.defaultIcon;
    });
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
