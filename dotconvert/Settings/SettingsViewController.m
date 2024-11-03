//
//  SettingsViewController.m
//  dotconvert
//
//  Created by Gero Embser on 03.11.24.
//

#import "SettingsViewController.h"
#import "PythonConverterController.h"

@interface SettingsViewController ()

@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}
- (IBAction)onOpenPythonConvertersInFinder:(id)sender {
    NSURL *appSupportURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                                inDomain:NSUserDomainMask
                                                       appropriateForURL:nil
                                                                create:YES
                                                                 error:nil];
    NSURL *appURL = [appSupportURL URLByAppendingPathComponent:@"dotconvert"];

    NSLog(@"App URL: %@", appURL);
    
    // Create directory if it doesn't exist
    [[NSFileManager defaultManager] createDirectoryAtURL:appURL
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                 error:nil];

    //create a "formats.plist" file in the app directory, but only if it doesn't exist yet
    NSString *formatsPlistPath = [appURL.path stringByAppendingPathComponent:@"formats.plist"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:formatsPlistPath]) {
        [[NSFileManager defaultManager] createFileAtPath:formatsPlistPath contents:nil attributes:nil];
        
        //write some default values to the plist file
        NSDictionary *defaultValues = @{
            @"formats": @{
                @"md": @{
                    @"rtf": @{
                        @"interpreter": @"/usr/bin/python3",
                        @"script": @"md_rtf.py"
                    }
                }
            }
        };
        [defaultValues writeToFile:formatsPlistPath atomically:YES];
        
        // Reload the formats configuration
        [[PythonConverterController sharedController] reloadFormatsConfig];

        //copy the example md_rtf.py script to the app directory, but only if it doesn't exist yet
        NSString *exampleScriptPath = [[NSBundle mainBundle] pathForResource:@"md_rtf" ofType:@"py"];
        NSString *destinationPath = [appURL.path stringByAppendingPathComponent:@"md_rtf.py"];
        NSLog(@"Destination path: %@", destinationPath);
        if (![[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {
            NSLog(@"Copying example script to %@", destinationPath);
            [[NSFileManager defaultManager] copyItemAtPath:exampleScriptPath toPath:destinationPath error:nil];
        }
    }


    // Open in Finder
    [[NSWorkspace sharedWorkspace] openURL:appURL];
}

@end
