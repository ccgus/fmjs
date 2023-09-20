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
@property (strong) FJSRuntime *internalRuntime;
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
    
    FMAssert(_consoleInputImageWidgetButton);
    
    NSSize imgSize = [_consoleInputImageWidgetButton bounds].size;
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
    
    FMAssert(_consoleInputImageWidgetButton);
    [_consoleInputImageWidgetButton setImage:img];
    
    [_consoleInputImageWidgetButton setTarget:self];
    [_consoleInputImageWidgetButton setAction:@selector(showConsolePopupAction:)];
    
    FMAssert(_consoleInputField);
    
    FMAssert(_consoleBottomHack);
    [_consoleBottomHack setBackgroundColor:[NSColor controlBackgroundColor]];
}

- (IBAction)clearConsole:(id)sender {
    [_entryViewControllers removeAllObjects];
    [_outputTableView reloadData];
}


- (IBAction)copyConsole:(id)sender {
    
    NSMutableString *c = [NSMutableString string];
    
    for (FJSConsoleEntryViewController *controller in _entryViewControllers) {
        [c appendFormat:@"%@ %@\n", [[controller ioIndicator] stringValue], [controller messageString]];
    }
    
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    
    
    [pboard clearContents];
    
    [pboard addTypes:@[UTTypeUTF8PlainText.identifier] owner:nil];
    
    [pboard setString:c forType:UTTypeUTF8PlainText.identifier];
    
    
    [self appendToConsole:NSLocalizedString(@"Copied to clipboard!.", @"Copied to clipboard!.") inputType:FJSConsoleEntryTypeInformative];
}

- (void)showConsolePopupAction:(id)sender {
    
    [NSMenu popUpContextMenu:[_consoleInputImageWidgetButton menu] withEvent:[NSApp currentEvent] forView:_consoleInputImageWidgetButton];
}

- (IBAction)showHelpAction:(id)sender {
    [self appendToConsole:@"Enter '/clear' to clear the console." inputType:FJSConsoleEntryTypeInformative];
    [self appendToConsole:@"Enter '/copy' to copy the console to the clipboard." inputType:FJSConsoleEntryTypeInformative];
    [self appendToConsole:@"Enter '/help' to see this message." inputType:FJSConsoleEntryTypeInformative];
    [self appendToConsole:@"Enter any other JavaScript command if there's a runtime connected." inputType:FJSConsoleEntryTypeInformative];
}

- (void)parseAndSetDefaultsValue:(NSString*)string {
    
    NSArray *ar = [string componentsSeparatedByString:@" "];
    
    if ([ar count] < 3) {
        [self appendToConsole:@"Wrong number of entries for defaults action (I'll need at least 3)." inputType:FJSConsoleEntryTypeError];
        return;
    }
    
    
    NSString *command = ar[1];
    NSString *prefName = ar[2];
    
    if ([command isEqualToString:@"write"]) {
        
        
        if ([ar count] < 4) {
            [self appendToConsole:@"Wrong number of entries for defaults write (I'll need at least 4)." inputType:FJSConsoleEntryTypeError];
            return;
        }
        
        NSString *value = ar[3];
        
        [[NSUserDefaults standardUserDefaults] setObject:value forKey:prefName];
        
        [self appendToConsole:[NSString stringWithFormat:@"'%@' is now set to '%@'", prefName, value] inputType:FJSConsoleEntryTypeInformative];
    }
    else if ([command isEqualToString:@"read"]) {
        
        NSString *msg = [NSString stringWithFormat:@"%@ = '%@'", prefName, [[NSUserDefaults standardUserDefaults] objectForKey:prefName]];
        
        [self appendToConsole:msg inputType:FJSConsoleEntryTypeInformative];
    }
    else {
        NSString *msg = [NSString stringWithFormat:@"Unknown defaults command: '%@'. Use only 'write' or 'read'", command];
        [self appendToConsole:msg inputType:FJSConsoleEntryTypeError];
    }
}

- (IBAction)evaluateTextFieldAction:(id)sender {
    
    if (![[_consoleInputField stringValue] length]) {
        return;
    }
    
    if ([[_consoleInputField stringValue] hasPrefix:@"/"]) {
        
        if ([[_consoleInputField stringValue] isEqualToString:@"/clear"]) {
            [self clearConsole:self];
        }
        else if ([[_consoleInputField stringValue] isEqualToString:@"/copy"]) {
            [self copyConsole:self];
        }
        else if ([[_consoleInputField stringValue] isEqualToString:@"/help"]) {
            [self showHelpAction:self];
        }
        else if ([[_consoleInputField stringValue] hasPrefix:@"/defaults "]) {
            [self parseAndSetDefaultsValue:[_consoleInputField stringValue]];
        }
        else {
            
            NSString *msg = NSLocalizedString(@"Unknown command: '%@'", @"Unknown command: '%@'");
            
            msg = [NSString stringWithFormat:msg, [_consoleInputField stringValue]];
            
            [self appendToConsole:msg inputType:FJSConsoleEntryTypeError];
        }
        
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

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    
    debug(@"commandSelector: '%@'", NSStringFromSelector(commandSelector));
    
    if (commandSelector == @selector(moveUp:)) {
        debug(@"need the last command!");
        return YES;
    }
    
    return NO;
}


- (void)popOutWindow {
    
    if (![[self window] isVisible]) {
        [[self window] makeKeyAndOrderFront:self];
        [[self window] makeFirstResponder:_consoleInputField];
    }
}

- (void)setupHandlersForRuntime:(FJSRuntime*)rt {
    
    _lastRuntime = rt;
    
    NSString *junk = NSLocalizedString(@"Switching to JavaScript runtime %@.", @"Switching to JavaScript runtime %@.");
    junk = [NSString stringWithFormat:junk, rt];
    
    [self appendToConsole:junk inputType:FJSConsoleEntryTypeInformative];
    
    
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
        
        printf("%s\n", [string UTF8String]);
        
        [self window]; // Load the nib.
        
        FJSConsoleEntryViewController *c = [[FJSConsoleEntryViewController alloc] initWithNibName:@"FJSConsoleEntryViewController" bundle:nil];
        
        [c setMessageType:inputType];
        [c setMessageString:string];
        
        [self->_entryViewControllers addObject:c];
        
        [self->_outputTableView reloadData];
        [self->_outputTableView scrollToEndOfDocument:nil];
        
        if (inputType == FJSConsoleEntryTypeError) {
            [[self window] makeKeyAndOrderFront:nil];
        }
        
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
            
            NSText *t = [[f window] fieldEditor:NO forObject:f];
            
            if ([[t string] length]) {
                [t setSelectedRange:NSMakeRange([[t string] length], 0)];
            }
            
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

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    
    SEL action = [menuItem action];
    
    if (action == @selector(clearConsole:) || action == @selector(copyConsole:)) {
        [menuItem setState:NSControlStateValueOff];
    }
    
    return YES;
}

@end


@implementation FJSConsoleInputField

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    
    if (commandSelector == @selector(moveUp:)) {
        
        if ([[self stringValue] length] == 0) {
            
            [[self target] console:self didKepressUp:self];
            
            return YES;
        }
    }
    
    return NO;
}

@end
