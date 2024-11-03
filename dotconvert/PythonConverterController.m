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

- (NSString *)createTemporaryFilePathWithExtension:(NSString *)extension {
    NSString *tempDir = NSTemporaryDirectory();
    NSString *fileName = [[NSUUID UUID] UUIDString];
    return [tempDir stringByAppendingPathComponent:[fileName stringByAppendingPathExtension:extension]];
}

- (void)convertFile:(NSString *)inputPath 
    withConfig:(NSDictionary *)config 
    completionHandler:(void (^)(NSString *outputPath, NSError *error))completionHandler {
    
    // Create temporary output file path
    NSString *outputPath = [self createTemporaryFilePathWithExtension:config[@"targetFormat"]];
    
    // Create task with Python interpreter
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = config[@"interpreter"];
    task.arguments = @[config[@"script"], inputPath, outputPath];
    
    // Set up pipe for error output
    NSPipe *errorPipe = [NSPipe pipe];
    task.standardError = errorPipe;
    
    // Handle task completion
    task.terminationHandler = ^(NSTask *task) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (task.terminationStatus == 0) {
                // Success
                completionHandler(outputPath, nil);
            } else {
                // Error - read error message from pipe
                NSFileHandle *errorHandle = errorPipe.fileHandleForReading;
                NSData *errorData = [errorHandle readDataToEndOfFile];
                NSString *errorString = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
                
                NSError *error = [NSError errorWithDomain:@"PythonConverterErrorDomain"
                                                   code:task.terminationStatus
                                               userInfo:@{
                    NSLocalizedDescriptionKey: errorString ?: @"Python conversion failed"
                }];
                completionHandler(nil, error);
            }
        });
    };
    
    // Launch task
    @try {
        [task launch];
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"PythonConverterErrorDomain"
                                           code:-1
                                       userInfo:@{
            NSLocalizedDescriptionKey: exception.reason ?: @"Failed to launch Python converter"
        }];
        completionHandler(nil, error);
    }
}

@end
