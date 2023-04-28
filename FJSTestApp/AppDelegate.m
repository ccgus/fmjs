//
//  AppDelegate.m
//  FJSTestApp
//
//  Created by August Mueller on 9/17/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import "AppDelegate.h"
#import "FJSConsoleController.h"
#import <FMJS/FJS.h>

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@property (strong) FJSConsoleController *consoleController;
@property (strong) FJSRuntime *rt;

@end


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    _rt = [FJSRuntime new];
    _consoleController = [FJSConsoleController consoleControllerWithRuntime:_rt];
    
    [_consoleController appendToConsole:@"Hello World."];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (IBAction)runScriptAction:(id)sender {
    
    FMAssert(_textView);
    
    [_rt evaluateScript:[_textView string]];
    
}

@end


