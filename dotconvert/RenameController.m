#import "RenameController.h"
#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>
#import "ImageConverter.h"

@interface RenameController ()

@property (nonatomic, strong) NSMutableArray<NSDictionary *> *recentEvents;

@end

@implementation RenameController

- (instancetype)init {
    self = [super init];
    if (self) {
        _recentEvents = [NSMutableArray arrayWithCapacity:10];
    }
    return self;
}

- (void)processEventWithPath:(NSString *)path eventId:(uint64_t)eventId fileId:(uint64_t)fileId {
    NSString *extension = [path pathExtension];
    if ([extension length] == 0) {
        return; // Ignore if it has no file extension
    }
    
    NSDictionary *event = @{
        @"path": path,
        @"eventId": @(eventId),
        @"fileId": @(fileId)
    };
    
    [self.recentEvents addObject:event];
    if (self.recentEvents.count > 10) {
        [self.recentEvents removeObjectAtIndex:0];
    }
    
    [self checkForRenameAction];
}

- (void)checkForRenameAction {
    NSUInteger count = self.recentEvents.count;
    if (count < 2) return;
    
    NSDictionary *latestEvent = [self.recentEvents lastObject];
    uint64_t latestFileId = [latestEvent[@"fileId"] unsignedLongLongValue];
    NSString *latestPath = latestEvent[@"path"];
    
    for (NSInteger i = count - 2; i >= 0; i--) {
        NSDictionary *event = self.recentEvents[i];
        uint64_t fileId = [event[@"fileId"] unsignedLongLongValue];
        NSString *path = event[@"path"];
        
        if (fileId == latestFileId) {
            NSString *oldExtension = [self getFileExtension:path];
            NSString *newExtension = [self getFileExtension:latestPath];
            if (![self getFileExtension:oldExtension isEqualTo:newExtension]) {
                // NSLog(@"---\nFile extension changed for fileId %llu", fileId);
                // NSLog(@"Old extension: %@", oldExtension);
                // NSLog(@"New extension: %@", newExtension);
                // NSLog(@"are equal: %d\n---", [self getFileExtension:oldExtension isEqualTo:newExtension]);
                [self performRenameActionWithFileId:fileId oldPath:path currentPath:latestPath];
            } else {
                NSLog(@"Will not perform action, file name for %llu changed, but not extension", fileId);
            }
            break;
        }
    }
}

- (NSString *)getFileExtension:(NSString *)path {
    return [path pathExtension];
}

- (BOOL)getFileExtension:(NSString *)ext1 isEqualTo:(NSString *)ext2 {
    return [ext1.lowercaseString isEqualToString:ext2.lowercaseString];
}

- (void)performRenameActionWithFileId:(uint64_t)fileId oldPath:(NSString *)oldPath currentPath:(NSString *)currentPath {
    NSString *oldExtension = [oldPath pathExtension];
    NSString *newExtension = [currentPath pathExtension];
    
    NSLog(@"Renamed file extension from .%@ to .%@", oldExtension, newExtension);
    
    // Play the default system send mail sound
    NSSound *sound = [NSSound soundNamed:@"Mail Sent"];
    [sound play];
    
    //convert
    [self convert:currentPath oldExtension:oldExtension newExtension:newExtension];
}

- (void)convert:(NSString *)filePath oldExtension:(NSString *)oldExtension newExtension:(NSString *)newExtension {
    //JPG -> PNG
    if ([oldExtension.lowercaseString isEqualToString:@"jpg"] && [newExtension.lowercaseString isEqualToString:@"png"]) {
        [self convertJPGtoPNG:filePath];
    } 
    //FALLBACK
    else {
        NSLog(@"Conversion from %@ to %@ is not supported", oldExtension, newExtension);
    }
}

- (void)convertJPGtoPNG:(NSString *)filePath {
    ImageConverter *converter = [[ImageConverter alloc] initWithFilePath:filePath
                                                           currentFormat:@"jpg"
                                                            targetFormat:@"png"];
    NSString *tempFilePath = [converter convert];
    
    if (tempFilePath) {
        NSLog(@"Successfully converted %@ from JPG to PNG. Temporary file: %@", filePath, tempFilePath);
        
        // TODO: Handle the temporary file (e.g., move it to the desired location)
        // For example:
        // NSString *newFilePath = [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"];
        // [[NSFileManager defaultManager] moveItemAtPath:tempFilePath toPath:newFilePath error:nil];
        
        // Don't forget to remove the temporary file if you're done with it:
        // [[NSFileManager defaultManager] removeItemAtPath:tempFilePath error:nil];
    } else {
        NSLog(@"Failed to convert %@ from JPG to PNG", filePath);
    }
}

@end
