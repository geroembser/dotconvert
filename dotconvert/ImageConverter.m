#import "ImageConverter.h"
#import <AppKit/AppKit.h>

@interface ImageConverter ()

@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSString *currentFormat;
@property (nonatomic, strong) NSString *targetFormat;

@end

@implementation ImageConverter

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
    if ([self.currentFormat.lowercaseString isEqualToString:@"jpg"] || [self.currentFormat.lowercaseString isEqualToString:@"jpeg"]) {
        if ([self.targetFormat.lowercaseString isEqualToString:@"png"]) {
            return [self convertJPGtoPNG];
        }
    }
    
    NSLog(@"Conversion from %@ to %@ is not supported", self.currentFormat, self.targetFormat);
    return nil;
}

- (NSString *)convertJPGtoPNG {
    // Check file permissions
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager isReadableFileAtPath:self.filePath]) {
        NSLog(@"Error: No permission to read the file at path: %@", self.filePath);
        return nil;
    }

    NSImage *image = [[NSImage alloc] initWithContentsOfFile:self.filePath];
    if (!image) {
        NSLog(@"Failed to load image from file: %@", self.filePath);
        return nil;
    }
    
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
    NSData *pngData = [imageRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    
    if (!pngData) {
        NSLog(@"Failed to convert image to PNG data");
        return nil;
    }
    
    NSString *tempFilePath = [self createTemporaryFilePathWithExtension:@"png"];
    BOOL success = [pngData writeToFile:tempFilePath atomically:YES];
    
    if (success) {
        NSLog(@"Successfully converted %@ to PNG: %@", self.filePath, tempFilePath);
        return tempFilePath;
    } else {
        NSLog(@"Failed to write PNG file: %@", tempFilePath);
        return nil;
    }
}

- (NSString *)createTemporaryFilePathWithExtension:(NSString *)extension {
    NSString *tempDir = NSTemporaryDirectory();
    NSString *fileName = [[NSUUID UUID] UUIDString];
    return [tempDir stringByAppendingPathComponent:[fileName stringByAppendingPathExtension:extension]];
}

@end
