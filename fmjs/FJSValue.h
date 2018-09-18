//
//  FJSJSWrapper.h
//  yd
//
//  Created by August Mueller on 8/21/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <ffi/ffi.h>
#import "FJSSymbolManager.h"
#import "FJSRuntime.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    char type;
    union {
        char charValue;
        unsigned char ucharValue;
        short shortValue;
        unsigned short ushortValue;
        int intValue;
        int uintValue;
        long longValue;
        unsigned long unsignedLongValue;
        long long longLongValue;
        unsigned long long unsignedLongLongValue;
        float floatValue;
        double doubleValue;
        BOOL boolValue;
        SEL selectorValue;
        void *pointerValue;
        void *structLocation;
        char *cStringLocation;
    } value;
} FJSObjCValue;

@interface FJSValue : NSObject

@property (assign) BOOL isJSNative;
@property (strong) FJSSymbol *symbol;
@property (assign) FJSObjCValue cValue;


+ (instancetype)valueForJSObject:(nullable JSObjectRef)jso inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithSymbol:(FJSSymbol*)sym inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithInstance:(CFTypeRef)instance inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithWeakInstance:(id)instance inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithClass:(Class)c inRuntime:(FJSRuntime*)runtime;

- (BOOL)isClass;
- (BOOL)isInstance;

- (BOOL)isSymbol;
- (BOOL)isFunction;
- (BOOL)isInstanceMethod;
- (BOOL)isClassMethod;

- (BOOL)hasClassMethodNamed:(NSString*)m;

- (nullable JSValueRef)JSValue;
- (nullable JSValueRef)toJSString;

- (id)instance;
- (Class)rtClass;
//- (void)setInstance:(id)o;
- (void)setClass:(Class)c;
- (void)retainReturnValue;

- (void*)objectStorage;
- (BOOL)pushJSValueToNativeType:(NSString*)type;

- (ffi_type*)FFIType;
- (ffi_type*)FFITypeWithHint:(nullable NSString*)typeEncoding;

- (id)toObject;

@end

NS_ASSUME_NONNULL_END
