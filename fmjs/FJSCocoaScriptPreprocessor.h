//
//  FJSCocoaScriptPreProcessor.h
//  FMJS
//
//  Created by August Mueller on 4/29/20.
//  Copyright © 2020 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FJSCocoaScriptPreprocessor : NSObject {

}

+ (NSString*)preprocessCode:(NSString*)sourceString;

+ (NSString*)preprocessCode:(NSString*)sourceString withBaseURL:(NSURL*)base;

@end



@interface FJSTPSymbolGroup : NSObject {
    
    unichar _openSymbol;
    NSMutableArray *_args;
    FJSTPSymbolGroup *_parent;
}

@property (retain) NSMutableArray *args;
@property (retain) FJSTPSymbolGroup *parent;

- (void)addSymbol:(id)aSymbol;

@end

