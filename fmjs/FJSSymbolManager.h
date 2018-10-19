//
//  FJSBridgeParser.h
//  yd
//
//  Created by August Mueller on 8/21/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FJSSymbol;

@interface FJSSymbolManager : NSObject <NSXMLParserDelegate>

+ (instancetype)sharedManager;

- (void)parseBridgeFileAtPath:(NSString*)bridgePath;

@end

NS_ASSUME_NONNULL_END
