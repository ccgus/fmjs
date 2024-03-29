//
//  FJSSymbol.h
//  fmjs
//
//  Created by August Mueller on 10/19/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FJSStructSymbol;


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
@property (assign) BOOL isCFType;
@property (assign) BOOL cfTypeReturnsRetained;

- (void)addArgument:(FJSSymbol*)sym;

- (void)addClassMethod:(FJSSymbol*)sym;
- (void)addInstanceMethod:(FJSSymbol*)sym;

- (nullable FJSSymbol*)classMethodNamed:(NSString*)name;
- (nullable FJSSymbol*)instanceMethodNamed:(NSString*)name;
+ (nullable FJSSymbol*)symbolForName:(NSString*)name;
+ (nullable FJSSymbol*)symbolForName:(NSString*)name inObject:(nullable id)object;
+ (nullable FJSSymbol*)symbolForBlockTypeEncoding:(const char*)typeEncoding;
+ (nullable FJSSymbol*)symbolForCFType:(NSString*)cftype;

- (BOOL)returnsRetained;
- (BOOL)isPointer;

- (NSString*)structName;
- (NSArray*)structFields;
- (size_t)structSize;
- (nullable FJSStructSymbol*)structFieldNamed:(NSString*)name;

- (void)unmangleArgs;

@end

@interface FJSStructSymbol : NSObject
@property (assign) size_t size;
@property (assign) char type;
@property (strong) NSString *name;
@property (strong) NSString *structName;
@end


NS_ASSUME_NONNULL_END

