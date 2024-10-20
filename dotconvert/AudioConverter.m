#import "AudioConverter.h"
#import <ffmpegkit/FFmpegKit.h>

@interface AudioConverter ()

@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSString *currentFormat;
@property (nonatomic, strong) NSString *targetFormat;

@end

@implementation AudioConverter

- (instancetype)initWithFilePath:(NSString *)filePath currentFormat:(NSString *)currentFormat targetFormat:(NSString *)targetFormat {
    self = [super init];
    if (self) {
        _filePath = filePath;
        _currentFormat = currentFormat;
        _targetFormat = targetFormat;
    }
    return self;
}

- (NSString *)convert {
    if ([self.currentFormat.lowercaseString isEqualToString:@"mp3"] && 
        [self.targetFormat.lowercaseString isEqualToString:@"ogg"]) {
        return [self convertMP3toOGG];
    } else if ([self.currentFormat.lowercaseString isEqualToString:@"ogg"] && 
               [self.targetFormat.lowercaseString isEqualToString:@"mp3"]) {
        return [self convertOGGtoMP3];
    }
    
    NSLog(@"Conversion from %@ to %@ is not supported", self.currentFormat, self.targetFormat);
    return nil;
}

- (NSString *)convertMP3toOGG {
    // Check file permissions
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager isReadableFileAtPath:self.filePath]) {
        NSLog(@"Error: No permission to read the file at path: %@", self.filePath);
        return nil;
    }

    NSString *outputPath = [self createTemporaryFilePathWithExtension:@"ogg"];
    
    NSString *ffmpegCommand = [NSString stringWithFormat:@"-i %@ -c:a libvorbis -q:a 4 %@", self.filePath, outputPath];
    
    FFmpegSession *session = [FFmpegKit execute:ffmpegCommand];
    ReturnCode *returnCode = [session getReturnCode];
    
    if ([ReturnCode isSuccess:returnCode]) {
        NSLog(@"Successfully converted %@ to OGG: %@", self.filePath, outputPath);
        return outputPath;
    } else {
        NSLog(@"Failed to convert MP3 to OGG. Error: %@", [session getOutput]);
        return nil;
    }
}

- (NSString *)convertOGGtoMP3 {
    // Check file permissions
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager isReadableFileAtPath:self.filePath]) {
        NSLog(@"Error: No permission to read the file at path: %@", self.filePath);
        return nil;
    }

    NSString *outputPath = [self createTemporaryFilePathWithExtension:@"mp3"];
    
    NSString *ffmpegCommand = [NSString stringWithFormat:@"-i %@ -acodec libmp3lame -b:a 192k %@", self.filePath, outputPath];
    
    FFmpegSession *session = [FFmpegKit execute:ffmpegCommand];
    ReturnCode *returnCode = [session getReturnCode];
    
    if ([ReturnCode isSuccess:returnCode]) {
        NSLog(@"Successfully converted %@ to MP3: %@", self.filePath, outputPath);
        return outputPath;
    } else {
        NSLog(@"Failed to convert OGG to MP3. Error: %@", [session getOutput]);
        return nil;
    }
}

- (NSString *)createTemporaryFilePathWithExtension:(NSString *)extension {
    NSString *tempDir = NSTemporaryDirectory();
    NSString *fileName = [[NSUUID UUID] UUIDString];
    return [tempDir stringByAppendingPathComponent:[fileName stringByAppendingPathExtension:extension]];
}

@end
