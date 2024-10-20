#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImageConverter : NSObject

- (instancetype)initWithFilePath:(NSString *)filePath
                   currentFormat:(NSString *)currentFormat
                    targetFormat:(NSString *)targetFormat;

- (NSString *)convert;

@end

NS_ASSUME_NONNULL_END
