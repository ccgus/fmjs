//
//  FJSConsoleController.m
//  FJSTestApp
//
//  Created by August Mueller on 4/23/23.
//  Copyright © 2023 Flying Meat Inc. All rights reserved.
//

#import "FJSConsoleController.h"
#import "FJSConsoleEntryViewController.h"

@interface FJSConsoleController ()

@property (weak) FJSRuntime *rt;
@property (strong) NSMutableArray *entryViewControllers;
@property (weak) IBOutlet FJSColoredView *inputColoredView;
@end

@implementation FJSConsoleController

+ (instancetype)consoleControllerWithRuntime:(FJSRuntime*)runtime {
    
    FJSConsoleController *cc = [[FJSConsoleController alloc] initWithWindowNibName:@"FJSConsoleController"];
    
    [cc setRt:runtime];
    
    [cc setupHandlers];
    
    return cc;
}

- (void)awakeFromNib {
    
    FMAssert(_outputTableView);
    
    _entryViewControllers = [NSMutableArray array];
    
    [_outputTableView setUsesAutomaticRowHeights:YES];
    [_outputTableView setDataSource:self];
    [_outputTableView setDelegate:self];
    [_outputTableView reloadData];
    
}

- (IBAction)clearConsole:(id)sender {
    [_entryViewControllers removeAllObjects];
    [_outputTableView reloadData];
}

- (IBAction)evaluateTextFieldAction:(id)sender {
    
    if (![[_consoleInputField stringValue] length]) {
        return;
    }
    
    
    [self appendToConsole:[_consoleInputField stringValue] inputType:FJSConsoleEntryTypeInput];
    
    FJSValue *v = [_rt evaluateScript:[_consoleInputField stringValue]];
    
    if (v && !([v isNull] || [v isUndefined])) {
        [self appendToConsole:[NSString stringWithFormat:@"%@", [v toObject]]];
    }
    
    [_consoleInputField setStringValue:@""];
}

- (void)popOutWindow {
    
    if (![[self window] isVisible]) {
        
        [[self window] makeKeyAndOrderFront:self];
    }
}

- (void)setupHandlers {
    
    __weak __typeof__(self) weakSelf = self;
    
    [_rt setExceptionHandler:^(FJSRuntime * _Nonnull runtime, NSException * _Nonnull exception) {
        [weakSelf appendToConsole:[NSString stringWithFormat:@"%@: %@", [exception description], [exception userInfo]] inputType:FJSConsoleEntryTypeError];
    }];
    
    [_rt setPrintHandler:^(FJSRuntime * _Nonnull runtime, NSString * _Nonnull stringToPrint) {
        [weakSelf appendToConsole:stringToPrint];
    }];
}

- (void)appendToConsole:(NSString*)string {
    [self appendToConsole:string inputType:FJSConsoleEntryTypeOutput];
}

- (void)appendToConsole:(NSString*)string inputType:(FJSConsoleEntryType)inputType  {
    
    if (!string) {
        NSLog(@"%s:%d", __FUNCTION__, __LINE__);
        NSLog(@"Missing string for appendToConsole:");
        return;
    }
    
    [self popOutWindow];
    
    FJSConsoleEntryViewController *c = [[FJSConsoleEntryViewController alloc] initWithNibName:@"FJSConsoleEntryViewController" bundle:nil];
    
    [c setMessageType:inputType];
    [c setMessageString:string];
    
    [_entryViewControllers addObject:c];
    
    [_outputTableView reloadData];
    [_outputTableView scrollToEndOfDocument:nil];
    
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [_entryViewControllers count];
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    
    FJSConsoleEntryViewController *controller = [_entryViewControllers objectAtIndex:row];
    
    return [controller view];
    
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    //NSLog(@"Height: %g", rowView.fittingSize.height);
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    return [[_entryViewControllers objectAtIndex:row] calculatedHeight];
}

- (void)console:(FJSConsoleInputField*)f didKepressUp:(id)sender {
    
    [_entryViewControllers enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(FJSConsoleEntryViewController *controller, NSUInteger idx, BOOL * _Nonnull stop) {
       
        if ([controller messageType] == FJSConsoleEntryTypeInput) {
            
            [_consoleInputField setStringValue:[controller messageString]];
            
            *stop = YES;
        }
    }];
}

@end


@implementation FJSConsoleInputField

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    
    if (commandSelector == @selector(moveUp:)) {
        
        [[self target] console:self didKepressUp:self];
        
        return YES;
    }
    
    return NO;
}

@end
