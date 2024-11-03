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

    // Get the sandboxed home directory
    NSString *sandboxedHome = NSHomeDirectory();
    // Extract real home directory by taking first two path components
    NSArray *pathComponents = [sandboxedHome pathComponents];
    NSString *homeDirectory = [NSString pathWithComponents:[pathComponents subarrayWithRange:NSMakeRange(0, 3)]];

    NSLog(@"Home directory: %@", homeDirectory);
    
    // Define the paths we want to monitor
    NSArray *subPathsToMonitorForHomeDir = @[
        @"Desktop",
        @"Documents",
        @"Downloads",
        @"Movies",
        @"Music",
        @"Pictures",
        @"Library/Mobile Documents/com~apple~CloudDocs/Documents",
        @"Library/Mobile Documents/com~apple~CloudDocs/Desktop"
    ];
    
    // Create full paths and filter existing ones
    NSMutableArray *pathsToWatch = [NSMutableArray array];

    if ([path isEqualToString:homeDirectory]) {
        for (NSString *subPath in subPathsToMonitorForHomeDir) {
            NSString *fullPath = [homeDirectory stringByAppendingPathComponent:subPath];
            if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
                [pathsToWatch addObject:fullPath];
            }
        }
    }
    
    // Only proceed if we have paths to watch
    if (pathsToWatch.count == 0) {
        //just watch the given path if no valid paths are found
        [pathsToWatch addObject:path];
    }

    // NSLog(@"Watching paths: %@", pathsToWatch);
    
    // Create and start the new stream
    FSEventStreamContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    
    self.eventStream = FSEventStreamCreate(NULL,
                                         &fsEventsCallback,
                                         &context,
                                         (__bridge CFArrayRef)pathsToWatch,
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
        NSLog(@"Started monitoring paths: %@", pathsToWatch);
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
