//
//  ViewController.m
//  dotconvert
//
//  Created by Gero Embser on 20.10.24.
//

#import "ViewController.h"
#import <CoreServices/CoreServices.h>
#import "RenameController.h"

@interface ViewController ()

@property (nonatomic, assign) FSEventStreamRef eventStream;
@property (nonatomic, strong) RenameController *renameController;
@property (nonatomic, strong) NSURL *monitoredDirectoryURL;
@property (nonatomic, strong) NSButton *selectButton;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.renameController = [[RenameController alloc] init];
    
    self.selectButton = [[NSButton alloc] initWithFrame:NSMakeRect(50, 50, 200, 30)];
    [self.selectButton setTitle:@"Select Directory"];
    [self.selectButton setTarget:self];
    [self.selectButton setAction:@selector(selectDirectory:)];
    [self.view addSubview:self.selectButton];
}

- (IBAction)selectDirectory:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.canChooseDirectories = YES;
    openPanel.canChooseFiles = NO;
    openPanel.allowsMultipleSelection = NO;
    openPanel.prompt = @"Select Folder to Monitor";
    
    [openPanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            NSURL *selectedURL = openPanel.URLs.firstObject;
            self.monitoredDirectoryURL = selectedURL;
            self.pathControl.URL = selectedURL;
            self.pathControl.hidden = false;
            [self startMonitoringPath:selectedURL.path];
            
            // Update button title
            [self.selectButton setTitle:@"Change Directory"];
        }
    }];
}

- (void)startMonitoringPath:(NSString *)path {
    [self setupEventStreamForPath:path];
}

- (void)setupEventStreamForPath:(NSString *)path {
    // Stop any existing stream
    [self stopMonitoring];
    
    // Create and start the new stream
    FSEventStreamContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    CFArrayRef pathsToWatch = (__bridge CFArrayRef)@[path];
    
    self.eventStream = FSEventStreamCreate(NULL,
                                           &fsEventsCallback,
                                           &context,
                                           pathsToWatch,
                                           kFSEventStreamEventIdSinceNow,
                                           0.3,  // 300 ms latency
                                           kFSEventStreamCreateFlagFileEvents | 
                                           kFSEventStreamCreateFlagMarkSelf |
                                           kFSEventStreamCreateFlagUseCFTypes |
                                           kFSEventStreamCreateFlagUseExtendedData |
                                           kFSEventStreamCreateWithDocID);
    
    if (self.eventStream) {
        FSEventStreamScheduleWithRunLoop(self.eventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        FSEventStreamStart(self.eventStream);
        NSLog(@"Started monitoring path: %@", path);
    } else {
        NSLog(@"Failed to create FSEventStream");
    }
}

- (void)stopMonitoring {
    if (self.eventStream) {
        FSEventStreamStop(self.eventStream);
        FSEventStreamInvalidate(self.eventStream);
        FSEventStreamRelease(self.eventStream);
        self.eventStream = NULL;
    }
}

void fsEventsCallback(ConstFSEventStreamRef streamRef,
                      void *clientCallBackInfo,
                      size_t numEvents,
                      void *eventPaths,
                      const FSEventStreamEventFlags eventFlags[],
                      const FSEventStreamEventId eventIds[]) {
    ViewController *viewController = (__bridge ViewController *)clientCallBackInfo;
    CFArrayRef events = (CFArrayRef)eventPaths;
    
    for (size_t i = 0; i < numEvents; i++) {
        CFDictionaryRef eventDict = CFArrayGetValueAtIndex(events, i);
        CFStringRef path = CFDictionaryGetValue(eventDict, kFSEventStreamEventExtendedDataPathKey);
        CFNumberRef fileID = CFDictionaryGetValue(eventDict, kFSEventStreamEventExtendedFileIDKey);
        
        if (eventFlags[i] & kFSEventStreamEventFlagItemRenamed) {
            NSString *pathString = (__bridge NSString *)path;
            uint64_t eventId = eventIds[i];
            uint64_t fileIDValue = 0;
            
            if (fileID) {
                CFNumberGetValue(fileID, kCFNumberSInt64Type, &fileIDValue);
            }
            
            [viewController.renameController processEventWithPath:pathString eventId:eventId fileId:fileIDValue];
        }
    }
}

- (void)dealloc {
    [self stopMonitoring];
}

@end
