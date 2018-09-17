//
//  AppDelegate.m
//  FJSTestApp
//
//  Created by August Mueller on 9/17/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import "AppDelegate.h"
#import <FMJS/FJS.h>

static int AppDelegateTestDeallocs;

@interface AppDelegateTest : NSObject

@end

@implementation AppDelegateTest

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)dealloc {
    AppDelegateTestDeallocs++;
    NSLog(@"Gone! (%d)", AppDelegateTestDeallocs);
}

@end


@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    int count = 100;
    
    
    
    @autoreleasepool {
        FJSRuntime *runtime = [[FJSRuntime alloc] init];

        for (int i = 0; i < count; i++) {
            [runtime evaluateScript:@"c = AppDelegateTest.new();"];
        }

        debug(@"[NSRunLoop mainRunLoop: '%@'", [NSRunLoop mainRunLoop]);
        
        [runtime shutdown];
    }
    
    debug(@"We have more to do?");
    debug(@"Maybe. Just need a breakpoint here.");
    FMAssert(count == AppDelegateTestDeallocs);
    
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end


