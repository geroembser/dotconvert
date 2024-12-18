#import "RenameController.h"
#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>
#import "ImageConverter.h"
#import "AudioConverter.h"
#import "PythonConverterController.h"

// At the top of the file, add this constant:
static NSString * const kAsyncConversionInProgress = @"AsyncConversionInProgress";

@interface RenameController ()

@property (nonatomic, strong) NSMutableArray<NSDictionary *> *recentEvents;
@property (nonatomic, weak) PythonConverterController *pythonConverter;

@end

@implementation RenameController

- (instancetype)init {
    self = [super init];
    if (self) {
        _recentEvents = [NSMutableArray arrayWithCapacity:10];
        _pythonConverter = [PythonConverterController sharedController];
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

-(void)moveConvertedFile:(NSString *)convertedTempFilePath currentPath:(NSString *)currentPath oldExtension:(NSString *)oldExtension newExtension:(NSString *)newExtension {
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Create a temporary directory URL
    NSURL *currentURL = [NSURL fileURLWithPath:currentPath];
    NSURL *tempDirURL = [fileManager URLForDirectory:NSItemReplacementDirectory
                                            inDomain:NSUserDomainMask
                                    appropriateForURL:currentURL
                                            create:YES
                                            error:&error];
    
    if (!tempDirURL) {
        NSLog(@"Error creating temporary directory: %@", error.localizedDescription);
        return;
    }
    
    // Get the original filename without extension
    NSString *originalFilename = [[currentURL lastPathComponent] stringByDeletingPathExtension];
    
    // Create temporary path with old extension 
    NSString *tempPath = [[tempDirURL path] stringByAppendingPathComponent:originalFilename];
    tempPath = [tempPath stringByAppendingPathExtension:oldExtension];
    
    // First move original file to temp location with old extension
    if ([fileManager moveItemAtPath:currentPath toPath:tempPath error:&error]) {
        // Then move converted file to original location
        if ([fileManager moveItemAtPath:convertedTempFilePath toPath:currentPath error:&error]) {
            // Finally, trash the temp file with old extension
            NSURL *tempFileURL = [NSURL fileURLWithPath:tempPath];
            if ([fileManager trashItemAtURL:tempFileURL resultingItemURL:nil error:&error]) {
                NSLog(@"Successfully replaced the original file with the converted file");
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"ConversionDoneNotification"
                                                                    object:nil
                                                                    userInfo:@{@"sourceFormat": oldExtension,
                                                                            @"targetFormat": newExtension}];
                });
            } else {
                NSLog(@"Error moving temp file to trash: %@", error.localizedDescription);
            }
        } else {
            NSLog(@"Error moving converted file: %@", error.localizedDescription);
            // Try to restore original file if convert move failed
            [fileManager moveItemAtPath:tempPath toPath:currentPath error:nil];
        }
    } else {
        NSLog(@"Error moving original file to temp location: %@", error.localizedDescription);
        // Clean up the converted temp file if we couldn't move the original
        [fileManager removeItemAtPath:convertedTempFilePath error:nil];
    }
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
        [self moveConvertedFile:convertedTempFilePath currentPath:currentPath oldExtension:oldExtension newExtension:newExtension];
    }
}

- (NSString *)convert:(NSString *)filePath oldExtension:(NSString *)oldExtension newExtension:(NSString *)newExtension {
    // Post notification that conversion has started
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ConversionStartedNotification" object:nil];

    // Check for Python converter first
    NSDictionary *config = [self.pythonConverter getConverterConfigForSourceFormat:oldExtension 
                                                                    targetFormat:newExtension];
    if (config) {
        NSLog(@"Python converter available for %@ to %@: %@", oldExtension, newExtension, config);
        // return nil; // TODO: Implement actual Python conversion
        [self.pythonConverter convertFile:filePath withConfig:config completionHandler:^(NSString *outputPath, NSError *error) {
            if (error) {
                NSLog(@"Python conversion failed: %@", error.localizedDescription);
                // Post notification for conversion failure
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ConversionFailedNotification" 
                                                                    object:nil 
                                                                  userInfo:@{@"error": error}];
            } else {
                NSLog(@"Python conversion successful. Output file: %@", outputPath);
                [self handleSuccessfulConversion:outputPath originalPath:filePath oldExtension:oldExtension newExtension:newExtension];
            }
        }];

        return kAsyncConversionInProgress; // Return special value for async conversion
    }

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
            [self handleSuccessfulConversion:outputPath originalPath:filePath oldExtension:oldExtension newExtension:newExtension];
        }
    }];
}

- (void)handleSuccessfulConversion:(NSString *)convertedFilePath originalPath:(NSString *)originalPath oldExtension:(NSString *)oldExtension newExtension:(NSString *)newExtension {
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];

    [self moveConvertedFile:convertedFilePath currentPath:originalPath oldExtension:oldExtension newExtension:newExtension];
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
