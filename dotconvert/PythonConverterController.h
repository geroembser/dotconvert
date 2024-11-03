#import <Foundation/Foundation.h>

@interface PythonConverterController : NSObject

- (instancetype)init;
- (NSDictionary *)getConverterConfigForSourceFormat:(NSString *)sourceFormat 
                                      targetFormat:(NSString *)targetFormat;

@end
