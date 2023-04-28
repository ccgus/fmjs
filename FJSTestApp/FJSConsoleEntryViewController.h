//
//  FJSConsoleEntryViewController.h
//  FJSTestApp
//
//  Created by August Mueller on 4/27/23.
//  Copyright © 2023 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface FJSConsoleEntryViewController : NSViewController

@property (assign) BOOL isError;
@property (strong) NSString *messageString;

@property (assign) IBOutlet NSTextField *messageField;

- (CGFloat)calculatedHeight;

@end


@interface FJSConsoleEntryView : NSView

@end

NS_ASSUME_NONNULL_END
