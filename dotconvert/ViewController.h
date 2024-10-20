//
//  ViewController.h
//  dotconvert
//
//  Created by Gero Embser on 20.10.24.
//

#import <Cocoa/Cocoa.h>

@interface ViewController : NSViewController

- (IBAction)selectDirectory:(id)sender;
@property (weak) IBOutlet NSPathControl *pathControl;

@end
