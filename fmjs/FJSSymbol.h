//
//  FJSSymbol.h
//  fmjs
//
//  Created by August Mueller on 10/19/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


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
+ (FJSSymbol*)symbolForName:(NSString*)name;
+ (FJSSymbol*)symbolForName:(NSString*)name inObject:(nullable id)object;
+ (FJSSymbol*)symbolForBlockTypeEncoding:(const char*)typeEncoding;
- (BOOL)returnsRetained;

- (NSString*)structName;
- (BOOL)hasStructFieldNamed:(NSString*)name;

@end


NS_ASSUME_NONNULL_END
