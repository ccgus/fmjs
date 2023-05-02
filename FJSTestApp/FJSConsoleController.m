//
//  FJSConsoleController.m
//  FJSTestApp
//
//  Created by August Mueller on 4/23/23.
//  Copyright © 2023 Flying Meat Inc. All rights reserved.
//

#import "FJSConsoleController.h"

@interface FJSConsoleController ()

@property (weak) FJSRuntime *lastRuntime;
@property (strong) NSMutableArray *entryViewControllers;
@property (weak) IBOutlet FJSColoredView *inputColoredView;
@end

@implementation FJSConsoleController

+ (instancetype)consoleControllerWithRuntime:(FJSRuntime*)runtime {
    
    FJSConsoleController *cc = [[FJSConsoleController alloc] initWithWindowNibName:@"FJSConsoleController"];
    
    [cc setupHandlersForRuntime:runtime];
    
    return cc;
}

+ (instancetype)sharedConsoleController {
    
    static FJSConsoleController *sharedConsole = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedConsole = [[FJSConsoleController alloc] initWithWindowNibName:@"FJSConsoleController"];
    });
    
    return sharedConsole;
}

- (void)awakeFromNib {
    
    FMAssert(_outputTableView);
    
    _entryViewControllers = [NSMutableArray array];
    
    [_outputTableView setUsesAutomaticRowHeights:YES];
    [_outputTableView setDataSource:self];
    [_outputTableView setDelegate:self];
    [_outputTableView reloadData];
    
    FMAssert(_consoleInputImageWidget);
    
    NSSize imgSize = [_consoleInputImageWidget bounds].size;
    NSImage *img = [NSImage imageWithSize:imgSize flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        
        
        [[NSColor controlBackgroundColor] set];
        
        NSRectFill(dstRect);
        
        [[[NSColor controlTextColor] colorWithAlphaComponent:.6] set];
        
        NSBezierPath *bp = [NSBezierPath bezierPath];
        
        [bp moveToPoint:NSMakePoint(10, 5)];
        [bp lineToPoint:NSMakePoint(imgSize.width / 2.0, imgSize.height / 2.0)];
        [bp lineToPoint:NSMakePoint(10, imgSize.height - 5)];
        [bp setLineWidth:2.5];
        [bp setLineCapStyle:NSLineCapStyleRound];
        [bp setLineJoinStyle:NSLineJoinStyleRound];
        [bp stroke];
        
        CGFloat diameter = 3;
        CGFloat radius = diameter / 2.0;
        NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(5, (imgSize.height / 2.0) - radius, diameter, diameter)];
        [[[NSColor controlAccentColor] colorWithAlphaComponent:.75] set];
        [circle fill];
        
        return YES;
        
    }];
    
    FMAssert(_consoleInputImageWidget);
    [_consoleInputImageWidget setImage:img];
    
    FMAssert(_consoleBottomHack);
    [_consoleBottomHack setBackgroundColor:[NSColor controlBackgroundColor]];
}

- (IBAction)clearConsole:(id)sender {
    [_entryViewControllers removeAllObjects];
    [_outputTableView reloadData];
}

- (IBAction)evaluateTextFieldAction:(id)sender {
    
    if (![[_consoleInputField stringValue] length]) {
        return;
    }
    
    if ([[_consoleInputField stringValue] isEqualToString:@"/clear"]) {
        [self clearConsole:self];
        [_consoleInputField setStringValue:@""];
        return;
    }
    
    if (!_lastRuntime) {
        [self appendToConsole:NSLocalizedString(@"Missing runtime.", @"Missing runtime.") inputType:FJSConsoleEntryTypeError];
        return;
    }
    
    [self appendToConsole:[_consoleInputField stringValue] inputType:FJSConsoleEntryTypeInput];
    
    FJSValue *v = [_lastRuntime evaluateScript:[_consoleInputField stringValue]];
    
    if (v && !([v isNull] || [v isUndefined])) {
        [self appendToConsole:[NSString stringWithFormat:@"%@", [v toObject]]];
    }
    
    [_consoleInputField setStringValue:@""];
}

- (void)popOutWindow {
    
    if (![[self window] isVisible]) {
        [[self window] makeKeyAndOrderFront:self];
        [[self window] makeFirstResponder:_consoleInputField];
    }
}

- (void)setupHandlersForRuntime:(FJSRuntime*)rt {
    
    _lastRuntime = rt;
    
    __weak __typeof__(self) weakSelf = self;
    
    [rt setExceptionHandler:^(FJSRuntime * _Nonnull runtime, NSException * _Nonnull exception) {
        [weakSelf appendToConsole:[NSString stringWithFormat:@"%@: %@", [exception description], [exception userInfo]] inputType:FJSConsoleEntryTypeError];
    }];
    
    [rt setPrintHandler:^(FJSRuntime * _Nonnull runtime, NSString * _Nonnull stringToPrint) {
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
    
    void (^block)(void) = ^void() {
        
        [self popOutWindow];
        
        FJSConsoleEntryViewController *c = [[FJSConsoleEntryViewController alloc] initWithNibName:@"FJSConsoleEntryViewController" bundle:nil];
        
        [c setMessageType:inputType];
        [c setMessageString:string];
        
        [_entryViewControllers addObject:c];
        
        [_outputTableView reloadData];
        [_outputTableView scrollToEndOfDocument:nil];
        
    };
    
    if ([NSThread isMainThread]) {
        block();
    }
    else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
    
    
    
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

// These are conveniences so we can set this guy to a global console object if we'd like.
- (void)print:(NSString*)s {
    [self appendToConsole:s];
}

- (void)log:(NSString*)s {
    [self appendToConsole:s];
}

- (void)write:(NSString*)s {
    [self appendToConsole:s];
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
