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
    NSLog(@"%s:%d", __FUNCTION__, __LINE__);
    [super viewDidLoad];
    // Do view setup here.
    
    
    
    if (_messageString) {
        [_messageField setStringValue:_messageString];
    }
    else {
        [_messageField setStringValue:@""];
    }
    
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
    
    _textHeight += 22;
    
    return _textHeight;
}



@end

@implementation FJSConsoleEntryView

- (void)xdrawRect:(NSRect)dirtyRect {
    [[NSColor redColor] set];
    NSRectFill(dirtyRect);
}

@end
