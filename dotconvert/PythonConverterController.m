#import "PythonConverterController.h"

@interface PythonConverterController ()
@property (nonatomic, strong) NSDictionary *formatsConfig;
@end

@implementation PythonConverterController

- (instancetype)init {
    self = [super init];
    if (self) {
        // Get Application Support directory URL
        NSURL *appSupportURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                                    inDomain:NSUserDomainMask
                                                           appropriateForURL:nil
                                                                    create:NO
                                                                     error:nil];
        NSURL *appURL = [appSupportURL URLByAppendingPathComponent:@"dotconvert"];
        
        // Load formats.plist if it exists
        NSString *formatsPlistPath = [appURL.path stringByAppendingPathComponent:@"formats.plist"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:formatsPlistPath]) {
            self.formatsConfig = [NSDictionary dictionaryWithContentsOfFile:formatsPlistPath];
        }
    }
    return self;
}

- (NSDictionary *)getConverterConfigForSourceFormat:(NSString *)sourceFormat 
                                      targetFormat:(NSString *)targetFormat {

    //if no formats config is loaded, return nil
    if (!self.formatsConfig) {
        return nil;
    }

    // Remove leading dots if present
    sourceFormat = [sourceFormat stringByReplacingOccurrencesOfString:@"." withString:@""];
    targetFormat = [targetFormat stringByReplacingOccurrencesOfString:@"." withString:@""];
    
    // Check if conversion is supported
    NSDictionary *formats = self.formatsConfig[@"formats"];
    NSDictionary *sourceFormats = formats[sourceFormat];
    NSDictionary *conversion = sourceFormats[targetFormat];
    
    if (!conversion) {
        return nil;
    }
    
    // Get Application Support directory for script path
    NSURL *appSupportURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                                inDomain:NSUserDomainMask
                                                       appropriateForURL:nil
                                                                create:NO
                                                                 error:nil];
    NSURL *appURL = [appSupportURL URLByAppendingPathComponent:@"dotconvert"];
    
    // Combine script path with app directory
    NSString *scriptPath = [appURL.path stringByAppendingPathComponent:conversion[@"script"]];
    
    // Return configuration dictionary
    return @{
        @"sourceFormat": sourceFormat,
        @"targetFormat": targetFormat,
        @"interpreter": conversion[@"interpreter"],
        @"script": scriptPath
    };
}

@end
