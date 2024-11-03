//
//  AppDelegate.m
//  dotconvert
//
//  Created by Gero Embser on 20.10.24.
//

#import "AppDelegate.h"
#import "ViewController.h"
#import <UserNotifications/UserNotifications.h>
#import "ImageConverter.h"

@interface AppDelegate () <UNUserNotificationCenterDelegate>

@property (strong, nonatomic) NSImage *defaultIcon;
@property (strong, nonatomic) NSImage *conversionIcon;
@property (strong, nonatomic) NSImage *checkmarkIcon;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Load icons
    self.defaultIcon = [NSImage imageWithSystemSymbolName:@"folder.badge.gearshape" accessibilityDescription:@"DotConvert"];
    self.conversionIcon = [NSImage imageWithSystemSymbolName:@"gearshape.arrow.triangle.2.circlepath" accessibilityDescription:@"Converting"];
    self.checkmarkIcon = [NSImage imageWithSystemSymbolName:@"checkmark.circle" accessibilityDescription:@"Conversion Done"];
    
    [self setupMenuBarItem];

    // Request notification permission
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self;
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (!granted) {
            NSLog(@"Notification permission denied");
        }
    }];

    // Register for notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(conversionStarted:)
                                                 name:@"ConversionStartedNotification"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(conversionDone:)
                                                 name:@"ConversionDoneNotification"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(conversionNotSupported:)
                                                 name:@"ConversionNotSupportedNotification"
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

- (void)setupProgressWindow {
    self.progressWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 200, 70)
                                                    styleMask:NSWindowStyleMaskBorderless
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
    
    self.progressWindow.backgroundColor = [NSColor controlBackgroundColor];
    self.progressWindow.level = NSFloatingWindowLevel;
    
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 40, 180, 20)];
    label.stringValue = @"Conversion in progress...";
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.editable = NO;
    label.selectable = NO;
    
    NSButton *linkButton = [[NSButton alloc] initWithFrame:NSMakeRect(10, 10, 180, 20)];
    [linkButton setTitle:@"Learned your maths today?"];
    [linkButton setButtonType:NSButtonTypeMomentaryLight];
    [linkButton setBordered:NO];
    [linkButton setTarget:self];
    [linkButton setAction:@selector(openWaitingURL:)];
    [linkButton.cell setBackgroundColor:[NSColor clearColor]];
    [linkButton setAttributedTitle:[[NSAttributedString alloc] initWithString:@"Learned your maths today?" 
        attributes:@{NSForegroundColorAttributeName: [NSColor linkColor]}]];
    
    [self.progressWindow.contentView addSubview:label];
    [self.progressWindow.contentView addSubview:linkButton];
}

- (void)setupCompletionWindow {
    self.completionWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 200, 40)
                                                      styleMask:NSWindowStyleMaskBorderless
                                                        backing:NSBackingStoreBuffered
                                                          defer:NO];
    
    self.completionWindow.backgroundColor = [NSColor controlBackgroundColor];
    self.completionWindow.level = NSFloatingWindowLevel;
    
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 10, 180, 20)];
    label.stringValue = @"Conversion completed!";
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.editable = NO;
    label.selectable = NO;
    
    [self.completionWindow.contentView addSubview:label];
}

- (void)showCompletionWindow {
   // Show completion window
    if (!self.completionWindow) {
        [self setupCompletionWindow];
    }
    
    // Position completion window
    NSRect statusItemRect = [self.statusItem.button.window convertRectToScreen:self.statusItem.button.frame];
    NSRect completionFrame = self.completionWindow.frame;
    NSPoint windowPosition = NSMakePoint(
        statusItemRect.origin.x - (completionFrame.size.width - statusItemRect.size.width) / 2,
        statusItemRect.origin.y - completionFrame.size.height - 5
    );
    
    [self.completionWindow setFrameOrigin:windowPosition];
    [self.completionWindow orderFront:nil];
    
    // Hide completion window after 2 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.completionWindow orderOut:nil];
    });
}

- (void)conversionStarted:(NSNotification *)notification {
     NSLog(@"Conversion started notification received");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusItem.button.image = self.conversionIcon;
        
        // Show progress window
        if (!self.progressWindow) {
            [self setupProgressWindow];
        }
        
        // Position window above status item
        NSRect statusItemRect = [self.statusItem.button.window convertRectToScreen:self.statusItem.button.frame];
        NSRect progressFrame = self.progressWindow.frame;
        NSPoint windowPosition = NSMakePoint(
            statusItemRect.origin.x - (progressFrame.size.width - statusItemRect.size.width) / 2,
            statusItemRect.origin.y - progressFrame.size.height - 5
        );
        
        [self.progressWindow setFrameOrigin:windowPosition];
        [self.progressWindow orderFront:nil];
    });
}

- (void)conversionDone:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Hide progress window
        [self.progressWindow orderOut:nil];
        
        [self showCompletionWindow];
        
        self.statusItem.button.image = self.checkmarkIcon;
        
        // Rest of the existing notification code...
        NSDictionary *userInfo = notification.userInfo;
        NSString *sourceFormat = userInfo[@"sourceFormat"];
        NSString *targetFormat = userInfo[@"targetFormat"];
        
        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.title = @"Conversion Complete";
        content.body = [NSString stringWithFormat:@"Converted from %@ to %@", sourceFormat, targetFormat];
        content.sound = [UNNotificationSound defaultSound];
        
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"ConversionNotification"
                                                                            content:content
                                                                            trigger:nil];
        
        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
                                                               withCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error showing notification: %@", error.localizedDescription);
            }
        }];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.statusItem.button.image = self.defaultIcon;
        });
    });
}

- (void)conversionNotSupported:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Hide progress window if shown
        [self.progressWindow orderOut:nil];
        
        self.statusItem.button.image = self.defaultIcon;
        
        // Print to console
        NSLog(@"Conversion not supported notification received");
        
        // Show push notification
        NSDictionary *userInfo = notification.userInfo;
        NSString *sourceFormat = userInfo[@"sourceFormat"];
        NSString *targetFormat = userInfo[@"targetFormat"];
        
        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.title = @"Conversion Not Supported";
        content.body = [NSString stringWithFormat:@"Conversion from %@ to %@ is not supported", sourceFormat, targetFormat];
        content.sound = [UNNotificationSound soundNamed:@"Basso"];
        
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"ConversionNotSupportedNotification"
                                                                              content:content
                                                                              trigger:nil];
        
        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
                                                               withCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error showing notification: %@", error.localizedDescription);
            }
        }];
    });
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}

- (void)openWaitingURL:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://swipemath.com"]];
}

@end
