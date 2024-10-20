#import <Foundation/Foundation.h>

@interface AudioConverter : NSObject

- (instancetype)initWithFilePath:(NSString *)filePath currentFormat:(NSString *)currentFormat targetFormat:(NSString *)targetFormat;
- (void)convertWithCompletionHandler:(void (^)(NSString *outputPath, NSError *error))completionHandler;

@end
