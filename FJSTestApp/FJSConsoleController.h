//
//  FJSConsoleController.h
//  FJSTestApp
//
//  Created by August Mueller on 4/23/23.
//  Copyright © 2023 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FJS.h"

NS_ASSUME_NONNULL_BEGIN

@interface FJSConsoleController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource>

@property (weak) IBOutlet NSTableView *outputTableView;
@property (weak) IBOutlet NSTextField *consoleInputField;

+ (instancetype)consoleControllerWithRuntime:(FJSRuntime*)runtime;
+ (instancetype)sharedConsoleController;

- (void)setupHandlersForRuntime:(FJSRuntime*)rt;

- (void)appendToConsole:(NSString*)string;

- (void)popOutWindow;

@end

@interface FJSConsoleInputField : NSTextField

@end

NS_ASSUME_NONNULL_END
