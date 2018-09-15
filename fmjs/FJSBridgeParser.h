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

@interface FJSBridgeParser : NSObject <NSXMLParserDelegate>

@property (strong) NSMutableDictionary *symbols;

+ (instancetype)sharedParser;

- (void)parseBridgeFileAtPath:(NSString*)bridgePath;

+ (FJSSymbol*)symbolForName:(NSString*)name;

@end


@interface FJSSymbol : NSObject {
    
}

@property (strong) NSString *symbolType;
@property (strong) NSString *name;
@property (strong) NSString *runtimeType;
@property (strong) NSString *runtimeValue;
@property (assign) SEL selector;
@property (strong) NSMutableArray *arguments;
@property (strong) NSMutableArray *classMethods;
@property (strong) NSMutableArray *instanceMethods;
@property (strong) FJSSymbol *returnValue;
@property (assign) BOOL isClassMethod;

- (void)addArgument:(FJSSymbol*)sym;

- (void)addClassMethod:(FJSSymbol*)sym;
- (void)addInstanceMethod:(FJSSymbol*)sym;

- (FJSSymbol*)classMethodNamed:(NSString*)name;
- (FJSSymbol*)instanceMethodNamed:(NSString*)name;

@end

NS_ASSUME_NONNULL_END
