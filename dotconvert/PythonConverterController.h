#import <Foundation/Foundation.h>

@interface PythonConverterController : NSObject

+ (instancetype)sharedController;
- (void)reloadFormatsConfig;
- (NSDictionary *)getConverterConfigForSourceFormat:(NSString *)sourceFormat 
                                      targetFormat:(NSString *)targetFormat;
- (void)convertFile:(NSString *)inputPath 
    withConfig:(NSDictionary *)config 
    completionHandler:(void (^)(NSString *outputPath, NSError *error))completionHandler;

@end
