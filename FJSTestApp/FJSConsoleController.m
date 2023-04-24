//
//  FJSConsoleController.m
//  FJSTestApp
//
//  Created by August Mueller on 4/23/23.
//  Copyright © 2023 Flying Meat Inc. All rights reserved.
//

#import "FJSConsoleController.h"

@interface FJSConsoleController ()

@property (weak) FJSRuntime *rt;

@end

@implementation FJSConsoleController

+ (instancetype)consoleControllerWithRuntime:(FJSRuntime*)runtime {
    
    FJSConsoleController *cc = [[FJSConsoleController alloc] initWithWindowNibName:@"FJSConsoleController"];
    
    [cc setRt:runtime];
    
    [cc setupHandlers];
    
    return cc;
}

- (IBAction)clearConsole:(id)sender {
    [[[_outputTextView textStorage] mutableString] setString:@""];
}

- (IBAction)evaluateTextFieldAction:(id)sender {
    FJSValue *v = [_rt evaluateScript:[_consoleInputField stringValue]];
    
    [[[_outputTextView textStorage] mutableString] appendFormat:@"\n%@", [v toObject]];
    
    [_consoleInputField setStringValue:@""];
}

- (void)popOutWindow {
    
    if (![[self window] isVisible]) {
        
        [_outputTextView setSmartInsertDeleteEnabled:NO];
        [_outputTextView setAutomaticQuoteSubstitutionEnabled:NO];
        
        [[self window] makeKeyAndOrderFront:self];
    }
}

- (void)setupHandlers {
    
    __weak __typeof__(self) weakSelf = self;
    
    [_rt setExceptionHandler:^(FJSRuntime * _Nonnull runtime, NSException * _Nonnull exception) {
        [weakSelf popOutWindow];
        
        [[[_outputTextView textStorage] mutableString] appendFormat:@"\n%@: %@", [exception description], [exception userInfo]];
        
    }];
    
    [_rt setPrintHandler:^(FJSRuntime * _Nonnull runtime, NSString * _Nonnull stringToPrint) {
        [weakSelf popOutWindow];
        [[[_outputTextView textStorage] mutableString] appendFormat:@"\n%@", stringToPrint];
    }];
}

- (void)appendToConsole:(NSString*)string {
    [self popOutWindow];
    [[[_outputTextView textStorage] mutableString] appendFormat:@"\n%@", string];
    
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end
