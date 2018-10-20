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
        char *cStringLocation;
    } value;
} FJSObjCValue;

// Blocks are instances. But blocks are are special yo. So let's keep track of that.
#define _FJSC_BLOCK '7'

@interface FJSValue : NSObject

// FIXME: These need to be private
@property (assign) BOOL isJSNative;
@property (strong) FJSSymbol *symbol;
@property (assign) FJSObjCValue cValue;
@property (assign) JSType jsValueType;

- (id)toObject;
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

- (void*)objectStorage;
- (BOOL)pushJSValueToNativeType:(NSString*)type;

- (ffi_type*)FFIType;
- (ffi_type*)FFITypeWithHint:(nullable NSString*)typeEncoding;

- (FJSValue*)valueFromStructFieldNamed:(NSString*)structFieldName;
- (BOOL)setValue:(FJSValue*)value onStructFieldNamed:(NSString*)structFieldName;

@end

NS_ASSUME_NONNULL_END
