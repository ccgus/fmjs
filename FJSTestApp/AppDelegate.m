//
//  AppDelegate.m
//  FJSTestApp
//
//  Created by August Mueller on 9/17/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import "AppDelegate.h"
#import <FMJS/FJS.h>

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (IBAction)runScriptAction:(id)sender {
    
    NSOpenPanel *open = [NSOpenPanel openPanel];
    [open setAllowedFileTypes:@[(id)kUTTypeJavaScript]];
    [open beginWithCompletionHandler:^(NSModalResponse result) {
        
        if (result) {
            
            FJSRuntime *rt = [FJSRuntime new];
            
            NSString *s = [NSString stringWithContentsOfURL:[open URL] encoding:NSUTF8StringEncoding error:nil];
            [rt evaluateScript:s withSourceURL:[open URL]];
            
            
        }
    }];
    
}

@end


