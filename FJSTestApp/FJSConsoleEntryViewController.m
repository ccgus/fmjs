//
//  FJSConsoleEntryViewController.m
//  FJSTestApp
//
//  Created by August Mueller on 4/27/23.
//  Copyright © 2023 Flying Meat Inc. All rights reserved.
//

#import "FJSConsoleEntryViewController.h"

@interface FJSConsoleEntryViewController ()

@property (assign) CGFloat textHeight;
@end

@implementation FJSConsoleEntryViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    if (_messageString) {
        [_messageField setStringValue:_messageString];
    }
    else {
        [_messageField setStringValue:@""];
    }
    
    [self setMessageType:_messageType];
}

- (void)setMessageType:(FJSConsoleEntryType)type {
    _messageType = type;
    
    [_topLine setHidden:_messageType != FJSConsoleEntryTypeInput];
    
    BOOL isDarkMode = [[[NSApp effectiveAppearance] name] isEqualToString:NSAppearanceNameDarkAqua];
    
    NSColor *textColor = [NSColor controlTextColor];
    NSColor *promptColor = [NSColor controlTextColor];
    NSString *prompt = @"➥";
    if (_messageType == FJSConsoleEntryTypeInput) {
        ;
    }
    else if (_messageType == FJSConsoleEntryTypeOutput) {
        textColor = isDarkMode ? [NSColor colorWithRed:0.584 green:0.506 blue:0.969 alpha:1.0] : [NSColor colorWithRed:0.086 green:0.016 blue:0.769 alpha:1.0];
        promptColor = [NSColor grayColor];
        prompt = @"❤";
    }
    else if (_messageType == FJSConsoleEntryTypeError) {
        textColor = [NSColor redColor];
        promptColor = [NSColor redColor];
        prompt = @"‽";
    }
    else if (_messageType == FJSConsoleEntryTypeInformative) {
        textColor = [NSColor blueColor];
        promptColor = [NSColor blueColor];
        prompt = @"ℹ";
    }
    else {
        NSAssert(NO, @"Unknown value in setMessageType: %ld", type);
    }
    
    [_ioIndicator setStringValue:prompt];
    [_ioIndicator setTextColor:promptColor];
    [_messageField setTextColor:textColor];
}

- (CGFloat)calculatedHeight {
    
    if (_textHeight > 1) {
        return _textHeight;
    }
    
    if (![_messageString length]) {
        _textHeight = 2;
        return _textHeight;
    }
    
    _textHeight = [_messageString sizeWithAttributes:[[_messageField attributedStringValue] attributesAtIndex:0 effectiveRange:nil]].height;
    
    _textHeight += 6;
    
    return _textHeight;
}


@end

@implementation FJSConsoleEntryView

- (void)xdrawRect:(NSRect)dirtyRect {
    [[NSColor redColor] set];
    NSRectFill(dirtyRect);
}

@end


@implementation FJSColoredView

- (void)drawRect:(NSRect)dirtyRect {
    [_backgroundColor set];
    NSRectFill(dirtyRect);
}


@end
