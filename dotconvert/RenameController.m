#import "RenameController.h"
#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>
#import "ImageConverter.h"
#import "AudioConverter.h"

// At the top of the file, add this constant:
static NSString * const kAsyncConversionInProgress = @"AsyncConversionInProgress";

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
    
    // Convert and get the temp file path
    NSString *convertedTempFilePath = [self convert:currentPath oldExtension:oldExtension newExtension:newExtension];
    
    if ([convertedTempFilePath isEqualToString:kAsyncConversionInProgress]) {
        NSLog(@"Async conversion in progress for %@", currentPath);
        // The conversion is handled asynchronously, so we don't need to do anything else here
        return;
    }
    
    if (convertedTempFilePath) {
        NSError *error = nil;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        // Move the original file to trash
        NSURL *originalFileURL = [NSURL fileURLWithPath:currentPath];
        if ([fileManager trashItemAtURL:originalFileURL resultingItemURL:nil error:&error]) {
            // Move the converted temp file to the original file's location
            if ([fileManager moveItemAtPath:convertedTempFilePath toPath:currentPath error:&error]) {
                NSLog(@"Successfully replaced the original file with the converted file");
                
                // Dispatch the conversion done notification with source and target formats
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"ConversionDoneNotification"
                                                                        object:nil
                                                                      userInfo:@{@"sourceFormat": oldExtension,
                                                                                 @"targetFormat": newExtension}];
                });
            } else {
                NSLog(@"Error moving converted file: %@", error.localizedDescription);
            }
        } else {
            NSLog(@"Error moving original file to trash: %@", error.localizedDescription);
            // Clean up the temp file if we couldn't move the original to trash
            [fileManager removeItemAtPath:convertedTempFilePath error:nil];
        }
    }
}

- (NSString *)convert:(NSString *)filePath oldExtension:(NSString *)oldExtension newExtension:(NSString *)newExtension {
    // Post notification that conversion has started
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ConversionStartedNotification" object:nil];

    //JPG -> PNG
    if ([oldExtension.lowercaseString isEqualToString:@"jpg"] && [newExtension.lowercaseString isEqualToString:@"png"]) {
        return [self convertJPGtoPNG:filePath];
    } 
    //HEIC -> JPG
    else if ([oldExtension.lowercaseString isEqualToString:@"heic"] && [newExtension.lowercaseString isEqualToString:@"jpg"]) {
        return [self convertHEICtoJPG:filePath];
    }
    //MP3 -> OGG or OGG -> MP3
    else if (([oldExtension.lowercaseString isEqualToString:@"mp3"] && [newExtension.lowercaseString isEqualToString:@"ogg"]) ||
             ([oldExtension.lowercaseString isEqualToString:@"ogg"] && [newExtension.lowercaseString isEqualToString:@"mp3"])) {
        [self convertAudioAsync:filePath oldExtension:oldExtension newExtension:newExtension];
        return kAsyncConversionInProgress; // Return special value for async conversion
    }
    //MP3 -> M4A or M4A -> MP3
    else if (([oldExtension.lowercaseString isEqualToString:@"mp3"] && [newExtension.lowercaseString isEqualToString:@"m4a"]) ||
             ([oldExtension.lowercaseString isEqualToString:@"m4a"] && [newExtension.lowercaseString isEqualToString:@"mp3"])) {
        [self convertAudioAsync:filePath oldExtension:oldExtension newExtension:newExtension];
        return kAsyncConversionInProgress; // Return special value for async conversion
    }
    //FALLBACK
    else {
        // Post notification for unsupported conversion
        NSDictionary *userInfo = @{
            @"sourceFormat": oldExtension,
            @"targetFormat": newExtension
        };
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ConversionNotSupportedNotification" 
                                                            object:nil 
                                                            userInfo:userInfo];

        NSLog(@"Conversion from %@ to %@ is not supported (file: %@)", oldExtension, newExtension, filePath);
        return nil;
    }
}

- (void)convertAudioAsync:(NSString *)filePath oldExtension:(NSString *)oldExtension newExtension:(NSString *)newExtension {
    AudioConverter *converter = [[AudioConverter alloc] initWithFilePath:filePath
                                                           currentFormat:oldExtension
                                                            targetFormat:newExtension];
    
    [converter convertWithCompletionHandler:^(NSString *outputPath, NSError *error) {
        if (error) {
            NSLog(@"Audio conversion failed: %@", error.localizedDescription);
            // Post notification for conversion failure
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ConversionFailedNotification" 
                                                                object:nil 
                                                              userInfo:@{@"error": error}];
        } else {
            NSLog(@"Audio conversion successful. Output file: %@", outputPath);
            // Handle the successful conversion
            [self handleSuccessfulConversion:outputPath originalPath:filePath];
        }
    }];
}

- (void)handleSuccessfulConversion:(NSString *)convertedFilePath originalPath:(NSString *)originalPath {
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Move the original file to trash
    NSURL *originalFileURL = [NSURL fileURLWithPath:originalPath];
    if ([fileManager trashItemAtURL:originalFileURL resultingItemURL:nil error:&error]) {
        // Move the converted temp file to the original file's location
        if ([fileManager moveItemAtPath:convertedFilePath toPath:originalPath error:&error]) {
            NSLog(@"Successfully replaced the original file with the converted file");
            
            // Dispatch the conversion done notification with source and target formats
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ConversionDoneNotification"
                                                                    object:nil
                                                                  userInfo:@{@"sourceFormat": [originalPath pathExtension],
                                                                             @"targetFormat": [convertedFilePath pathExtension]}];
            });
        } else {
            NSLog(@"Error moving converted file: %@", error.localizedDescription);
        }
    } else {
        NSLog(@"Error moving original file to trash: %@", error.localizedDescription);
        // Clean up the temp file if we couldn't move the original to trash
        [fileManager removeItemAtPath:convertedFilePath error:nil];
    }
}

- (NSString *)convertHEICtoJPG:(NSString *)filePath {
    ImageConverter *converter = [[ImageConverter alloc] initWithFilePath:filePath
                                                           currentFormat:@"heic"
                                                            targetFormat:@"jpg"];
    NSString *tempFilePath = [converter convert];

    if (tempFilePath) {
        NSLog(@"Successfully converted %@ from HEIC to JPG. Temporary file: %@", filePath, tempFilePath);
    } else {
        NSLog(@"Failed to convert %@ from HEIC to JPG", filePath);
    }
    
    return tempFilePath;
}

- (NSString *)convertJPGtoPNG:(NSString *)filePath {
    ImageConverter *converter = [[ImageConverter alloc] initWithFilePath:filePath
                                                           currentFormat:@"jpg"
                                                            targetFormat:@"png"];
    NSString *tempFilePath = [converter convert];
    
    if (tempFilePath) {
        NSLog(@"Successfully converted %@ from JPG to PNG. Temporary file: %@", filePath, tempFilePath);
    } else {
        NSLog(@"Failed to convert %@ from JPG to PNG", filePath);
    }
    
    return tempFilePath;
}

@end
