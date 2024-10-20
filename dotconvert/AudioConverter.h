#import <Foundation/Foundation.h>

@interface AudioConverter : NSObject

- (instancetype)initWithFilePath:(NSString *)filePath currentFormat:(NSString *)currentFormat targetFormat:(NSString *)targetFormat;
- (NSString *)convert;

@end
