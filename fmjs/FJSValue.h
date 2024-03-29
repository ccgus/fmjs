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
        unsigned int uintValue;
        long longValue;
        unsigned long unsignedLongValue;
        long long longLongValue;
        unsigned long long unsignedLongLongValue;
        float floatValue;
        double doubleValue;
        BOOL boolValue;
        SEL selectorValue;
        void *pointerValue;
        char *cStringLocation;
    } value;
} FJSObjCValue;

// Blocks are instances. But blocks are are special yo. So let's keep track of that.
#define _FJSC_BLOCK '7'

@interface FJSValue : NSObject

@property (strong) FJSSymbol *symbol;
@property (assign) BOOL isJSNative;

@property (strong) NSString *debugStackFromInit;
#ifdef DEBUG
@property (assign) NSInteger protectCount;
#endif

+ (nullable instancetype)valueWithJSValueRef:(nullable JSValueRef)jso inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithInstance:(CFTypeRef)instance inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithNewObjectInRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithString:(NSString*)stringToConvertToJSString inRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithBlock:(CFTypeRef)block inRuntime:(FJSRuntime*)runtime;

+ (instancetype)valueWithNullInRuntime:(FJSRuntime*)runtime;
+ (instancetype)valueWithUndefinedInRuntime:(FJSRuntime*)runtime;

- (nullable id)toObject;
- (BOOL)toBOOL;
- (float)toFloat;
- (double)toDouble;
- (int)toInt;
- (long)toLong;
- (long long)toLongLong;
- (nullable void*)pointer NS_RETURNS_INNER_POINTER;
- (nullable void*)structLocation NS_RETURNS_INNER_POINTER;
- (CGPoint)toCGPoint;
- (CGSize)toCGSize;
- (CGRect)toCGRect;
- (CFTypeRef)CFTypeRef;

- (BOOL)isUndefined;
- (BOOL)isNull;
- (BOOL)isString;

- (BOOL)isCFunction;
- (BOOL)isJSFunction;

- (void*)objectStorage;
- (void*)objectStorageForSymbol:(nullable FJSSymbol *)argSymbol;
- (BOOL)pushJSValueToNativeType:(NSString*)type;

- (ffi_type*)FFIType;
- (ffi_type*)FFITypeWithHint:(nullable NSString*)typeEncoding;

- (FJSValue*)valueFromStructFieldNamed:(NSString*)structFieldName;
- (BOOL)setValue:(FJSValue*)value onStructFieldNamed:(NSString*)structFieldName;

// Arguments to invokeMethodNamed:withArguments: and callWithArguments: can be either instances of classes, or FJSValue(s) wrapping a primative or other instance.
- (nullable FJSValue *)invokeMethodNamed:(NSString *)method withArguments:(nullable NSArray *)arguments;
- (nullable FJSValue *)callWithArguments:(nullable NSArray *)arguments;

- (nullable NSArray*)propertyNames;

- (instancetype)protect;
- (void)unprotect;

- (nullable JSValueRef)JSValueRef;
- (nullable JSValueRef)nativeJSValueRef;
- (nullable JSObjectRef)JSObjectRef; // Only valid if the FJSValue instance is backed by a native JSC JSValueRef

- (nullable FJSValue *)objectForKeyedSubscript:(NSString*)key;
- (void)setObject:(nullable id)object forKeyedSubscript:(NSObject <NSCopying> *)key;

//- (JSValue *)objectAtIndexedSubscript:(NSUInteger)index;
//- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)index;




@end

NS_ASSUME_NONNULL_END
