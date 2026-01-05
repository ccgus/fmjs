//
//  FJSConsoleEntryViewController.h
//  FJSTestApp
//
//  Created by August Mueller on 4/27/23.
//  Copyright © 2023 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM(NSUInteger, FJSConsoleEntryType) {
    FJSConsoleEntryTypeInput = 0,
    FJSConsoleEntryTypeOutput = 1,
    FJSConsoleEntryTypeError = 2,
    FJSConsoleEntryTypeInformative = 3,
};

@interface FJSConsoleEntryViewController : NSViewController

@property (assign, nonatomic) FJSConsoleEntryType messageType;
@property (strong) NSString *messageString;

@property (weak) IBOutlet NSTextField *messageField;
@property (weak) IBOutlet NSTextField *ioIndicator;
@property (weak) IBOutlet NSBox *topLine;

- (CGFloat)calculatedHeight;

@end


@interface FJSConsoleEntryView : NSView

@end


@interface FJSColoredView : NSView

@property (strong) NSColor *backgroundColor;

@end

NS_ASSUME_NONNULL_END
