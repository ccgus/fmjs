//
//  FJSConsoleController.h
//  FJSTestApp
//
//  Created by August Mueller on 4/23/23.
//  Copyright © 2023 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FJS.h"
#import "FJSConsoleEntryViewController.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *FJSConsoleControllerIsRequestingInterpreterReloadNotification;

@interface FJSConsoleController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource, NSMenuItemValidation>

@property (weak) IBOutlet NSTableView *outputTableView;
@property (weak) IBOutlet NSTextField *consoleInputField;
@property (weak) IBOutlet NSButton    *consoleInputImageWidgetButton;
@property (weak) IBOutlet FJSColoredView *consoleBottomHack;

+ (instancetype)consoleControllerWithRuntime:(FJSRuntime*)runtime;
+ (instancetype)sharedConsoleController;

- (void)setupHandlersForRuntime:(FJSRuntime*)rt;

- (void)appendToConsole:(NSString*)string;
- (void)appendToConsole:(NSString*)string inputType:(FJSConsoleEntryType)inputType;

- (IBAction)clearConsole:(nullable id)sender;
- (void)clear;

- (void)popOutWindow;

@end

@interface FJSConsoleInputField : NSTextField

@end

NS_ASSUME_NONNULL_END
