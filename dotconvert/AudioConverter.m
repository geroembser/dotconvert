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

- (void)convertWithCompletionHandler:(void (^)(NSString *outputPath, NSError *error))completionHandler {
    if ([self.currentFormat.lowercaseString isEqualToString:@"mp3"] && 
        [self.targetFormat.lowercaseString isEqualToString:@"ogg"]) {
        [self convertMP3toOGGWithCompletionHandler:completionHandler];
    } else if ([self.currentFormat.lowercaseString isEqualToString:@"ogg"] && 
               [self.targetFormat.lowercaseString isEqualToString:@"mp3"]) {
        [self convertOGGtoMP3WithCompletionHandler:completionHandler];
    } else {
        NSLog(@"Conversion from %@ to %@ is not supported", self.currentFormat, self.targetFormat);
        completionHandler(nil, [NSError errorWithDomain:@"AudioConverterErrorDomain" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Unsupported conversion"}]);
    }
}

- (void)convertMP3toOGGWithCompletionHandler:(void (^)(NSString *outputPath, NSError *error))completionHandler {
    // Check file permissions
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager isReadableFileAtPath:self.filePath]) {
        NSLog(@"Error: No permission to read the file at path: %@", self.filePath);
        completionHandler(nil, [NSError errorWithDomain:@"AudioConverterErrorDomain" code:2 userInfo:@{NSLocalizedDescriptionKey: @"No permission to read the file"}]);
        return;
    }

    NSString *outputPath = [self createTemporaryFilePathWithExtension:@"ogg"];
    
    NSString *ffmpegCommand = [NSString stringWithFormat:@"-i %@ -c:a libvorbis -q:a 4 %@", self.filePath, outputPath];
    
    [FFmpegKit executeAsync:ffmpegCommand withCompleteCallback:^(FFmpegSession* session) {
        ReturnCode *returnCode = [session getReturnCode];
        if ([ReturnCode isSuccess:returnCode]) {
            NSLog(@"Successfully converted %@ to OGG: %@", self.filePath, outputPath);
            completionHandler(outputPath, nil);
        } else {
            NSLog(@"Failed to convert MP3 to OGG. Error: %@", [session getOutput]);
            completionHandler(nil, [NSError errorWithDomain:@"AudioConverterErrorDomain" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Failed to convert MP3 to OGG"}]);
        }
    } withLogCallback:^(Log *log) {
        NSLog(@"FFmpeg Log: %@", [log getMessage]);
    } withStatisticsCallback:nil];
}

- (void)convertOGGtoMP3WithCompletionHandler:(void (^)(NSString *outputPath, NSError *error))completionHandler {
    // Check file permissions
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager isReadableFileAtPath:self.filePath]) {
        NSLog(@"Error: No permission to read the file at path: %@", self.filePath);
        completionHandler(nil, [NSError errorWithDomain:@"AudioConverterErrorDomain" code:2 userInfo:@{NSLocalizedDescriptionKey: @"No permission to read the file"}]);
        return;
    }

    NSString *outputPath = [self createTemporaryFilePathWithExtension:@"mp3"];
    
    NSString *ffmpegCommand = [NSString stringWithFormat:@"-i %@ -acodec libmp3lame -b:a 192k %@", self.filePath, outputPath];
    
    [FFmpegKit executeAsync:ffmpegCommand withCompleteCallback:^(FFmpegSession* session) {
        ReturnCode *returnCode = [session getReturnCode];
        if ([ReturnCode isSuccess:returnCode]) {
            NSLog(@"Successfully converted %@ to MP3: %@", self.filePath, outputPath);
            completionHandler(outputPath, nil);
        } else {
            NSLog(@"Failed to convert OGG to MP3. Error: %@", [session getOutput]);
            completionHandler(nil, [NSError errorWithDomain:@"AudioConverterErrorDomain" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Failed to convert OGG to MP3"}]);
        }
    } withLogCallback:^(Log *log) {
        NSLog(@"FFmpeg Log: %@", [log getMessage]);
    } withStatisticsCallback:nil];
}

- (NSString *)createTemporaryFilePathWithExtension:(NSString *)extension {
    NSString *tempDir = NSTemporaryDirectory();
    NSString *fileName = [[NSUUID UUID] UUIDString];
    return [tempDir stringByAppendingPathComponent:[fileName stringByAppendingPathExtension:extension]];
}

@end
