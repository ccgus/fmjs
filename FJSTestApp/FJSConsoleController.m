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
    
    [self appendToConsole:@"Hello World.\nThis is a newline, as is this:\n*******(star)*******"];
    [self appendToConsole:@"B"];
    [self appendToConsole:@"x\ny\nz\n1\n2\n3B"];
    
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
    FJSValue *v = [_rt evaluateScript:[_consoleInputField stringValue]];
    
    [self appendToConsole:[NSString stringWithFormat:@"%@", [v toObject]]];
    
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
        [weakSelf popOutWindow];
        
        [weakSelf appendToConsole:[NSString stringWithFormat:@"%@: %@", [exception description], [exception userInfo]]];
    }];
    
    [_rt setPrintHandler:^(FJSRuntime * _Nonnull runtime, NSString * _Nonnull stringToPrint) {
        [weakSelf popOutWindow];
        [weakSelf appendToConsole:stringToPrint];
    }];
}

- (void)appendToConsole:(NSString*)string {
    
    if (!string) {
        NSLog(@"%s:%d", __FUNCTION__, __LINE__);
        NSLog(@"Missing string for appendToConsole:");
        return;
    }
    
    
    [self popOutWindow];
    
    FJSConsoleEntryViewController *c = [[FJSConsoleEntryViewController alloc] initWithNibName:@"FJSConsoleEntryViewController" bundle:nil];
    
    [c setMessageString:string];
    
    [_entryViewControllers addObject:c];
    
    [_outputTableView reloadData];
    
    //[[[_outputTextView textStorage] mutableString] appendFormat:@"\n%@", string];
    
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [_entryViewControllers count];
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    
    debug(@"%s:%d", __FUNCTION__, __LINE__);
    debug(@"vrow: %ld", row);
    
    FJSConsoleEntryViewController *controller = [_entryViewControllers objectAtIndex:row];
    
    debug(@"[controller view]: '%@'", [controller view]);
    debug(@"[controller view] bounds: %@", NSStringFromRect([[controller view] bounds]));
    
    return [controller view];
    
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    NSLog(@"Height: %g", rowView.fittingSize.height);
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    
    return [[_entryViewControllers objectAtIndex:row] calculatedHeight];
}

@end
