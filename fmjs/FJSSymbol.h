//
//  FJSSymbol.h
//  fmjs
//
//  Created by August Mueller on 10/19/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FJSStructSymbol;

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
- (NSArray*)structFields;
- (FJSStructSymbol*)structFieldNamed:(NSString*)name;



@end

@interface FJSStructSymbol : NSObject
@property (assign) size_t size;
@property (assign) char type;
@property (strong) NSString *name;
@end
