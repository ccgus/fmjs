//
//  FJSConsoleController.h
//  FJSTestApp
//
//  Created by August Mueller on 4/23/23.
//  Copyright © 2023 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <FMJS/FJS.h>

NS_ASSUME_NONNULL_BEGIN

@interface FJSConsoleController : NSWindowController

@property (weak) IBOutlet NSTextView *outputTextView;
@property (weak) IBOutlet NSTextField *consoleInputField;

+ (instancetype)consoleControllerWithRuntime:(FJSRuntime*)runtime;

- (void)appendToConsole:(NSString*)string;

@end

NS_ASSUME_NONNULL_END
