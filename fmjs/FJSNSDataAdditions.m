//
//  FJSNSDataAdditions.m
//  fmjs
//
//  Created by August Mueller on 4/30/19.
//  Copyright © 2019 Flying Meat Inc. All rights reserved.
//

#import "FJSNSDataAdditions.h"
#import "FJS.h"
#import "FJSSymbol.h"

@implementation NSData (FJSNSDataAdditions)


static void FJSTypedArrayNSDataDeallocator(void* bytes, void* deallocatorContext) {
    CFRelease(deallocatorContext);
}

static void FJSTypedArrayBytesDeallocator(void* bytes, void* deallocatorContext) {
    free(bytes);
}

- (FJSValue*)toTypedArrayOfType:(FJSValue*)typeValue inFJSRuntime:(FJSRuntime*)runtime {
    
    
    JSType t = JSValueGetType([runtime contextRef], [typeValue JSValueRef]);
    
    if (t != kJSTypeObject) {
        NSLog(@"Invalid type pasted to drawableImageAccumulatorWithTypedArrayType: %d. Returning undefined.", t);
        return [FJSValue valueWithUndefinedInRuntime:runtime];
    }
    
    NSString *functionName = [[typeValue objectForKeyedSubscript:@"name"] toObject];
    
    JSTypedArrayType arrayType = [NSData JSTypedArrayTypeFromTypedArrayName:functionName];
    
    if (arrayType == kJSTypedArrayTypeNone) {
        NSLog(@"Unknown typed array function: %@. Returning undefined.", functionName);
        return [FJSValue valueWithUndefinedInRuntime:runtime];
    }
    
    
    JSObjectRef ar = JSObjectMakeTypedArray([runtime contextRef], arrayType, [self length], NULL);
    memcpy(JSObjectGetTypedArrayBytesPtr([runtime contextRef], ar, nil), [self bytes], [self length]);
    return [FJSValue valueWithJSValueRef:ar inRuntime:runtime];
}

- (FJSValue*)toTypedArrayNoCopyOfType:(FJSValue*)typeValue inFJSRuntime:(FJSRuntime*)runtime {
    
    
    JSType t = JSValueGetType([runtime contextRef], [typeValue JSValueRef]);
    
    if (t != kJSTypeObject) {
        NSLog(@"Invalid type pasted to drawableImageAccumulatorWithTypedArrayType: %d. Returning undefined.", t);
        return [FJSValue valueWithUndefinedInRuntime:runtime];
    }
    
    NSString *functionName = [[typeValue objectForKeyedSubscript:@"name"] toObject];
    
    JSTypedArrayType arrayType = [NSData JSTypedArrayTypeFromTypedArrayName:functionName];
    
    if (arrayType == kJSTypedArrayTypeNone) {
        NSLog(@"Unknown typed array function: %@. Returning undefined.", functionName);
        return [FJSValue valueWithUndefinedInRuntime:runtime];
    }
    
    
    CFRetain((__bridge CFTypeRef)(self));
    
    JSObjectRef ar = JSObjectMakeTypedArrayWithBytesNoCopy([runtime contextRef], arrayType, (void*)[self bytes], [self length], FJSTypedArrayNSDataDeallocator, (__bridge void *)(self), NULL);
    return [FJSValue valueWithJSValueRef:ar inRuntime:runtime];
    
}





- (FJSValue*)toTypedArray:(JSTypedArrayType)type runtime:(FJSRuntime*)runtime {
    
    JSObjectRef ar = JSObjectMakeTypedArray([runtime contextRef], type, [self length], NULL);
    memcpy(JSObjectGetTypedArrayBytesPtr([runtime contextRef], ar, nil), [self bytes], [self length]);
    return [FJSValue valueWithJSValueRef:ar inRuntime:runtime];
}

- (FJSValue*)toTypedArrayNoCopy:(JSTypedArrayType)type runtime:(FJSRuntime*)runtime {
    
    CFRetain((__bridge CFTypeRef)(self));
    
    JSObjectRef ar = JSObjectMakeTypedArrayWithBytesNoCopy([runtime contextRef], type, (void*)[self bytes], [self length], FJSTypedArrayNSDataDeallocator, (__bridge void *)(self), NULL);
    return [FJSValue valueWithJSValueRef:ar inRuntime:runtime];
}

- (FJSValue*)toInt8ArrayInFJSRuntime:(FJSRuntime*)runtime {
    return [self toTypedArray:kJSTypedArrayTypeInt8Array runtime:runtime];
}

- (FJSValue*)toUint8ArrayInFJSRuntime:(FJSRuntime*)runtime {
    return [self toTypedArray:kJSTypedArrayTypeUint8Array runtime:runtime];
}

- (FJSValue*)toInt16ArrayInFJSRuntime:(FJSRuntime*)runtime {
    return [self toTypedArray:kJSTypedArrayTypeInt16Array runtime:runtime];
}

- (FJSValue*)toUint16ArrayInFJSRuntime:(FJSRuntime*)runtime {
    return [self toTypedArray:kJSTypedArrayTypeUint16Array runtime:runtime];
}

- (FJSValue*)toInt32ArrayInFJSRuntime:(FJSRuntime*)runtime {
    return [self toTypedArray:kJSTypedArrayTypeInt32Array runtime:runtime];
}

- (FJSValue*)toUint32ArrayInFJSRuntime:(FJSRuntime*)runtime {
    return [self toTypedArray:kJSTypedArrayTypeUint32Array runtime:runtime];
}

- (FJSValue*)toFloat32ArrayInFJSRuntime:(FJSRuntime*)runtime {
    return [self toTypedArray:kJSTypedArrayTypeFloat32Array runtime:runtime];
}

- (FJSValue*)toFloat64ArrayInFJSRuntime:(FJSRuntime*)runtime {
    return [self toTypedArray:kJSTypedArrayTypeFloat64Array runtime:runtime];
}

+ (FJSValue*)dataFromTypedArray:(FJSValue*)array inFJSRuntime:(FJSRuntime*)runtime {
    
    // FIXME: Can we check the types here? var a = new Int8Array([-122, 343, -567]); NSData.dataFromInt16Array(a); will segfault when you grab the values because the types aren't matching.
    
    JSValueRef outErr;
    JSObjectRef jsArrayObject = [array JSObjectRef];
    
#ifdef DEBUG
    size_t byteOffset = JSObjectGetTypedArrayByteOffset([runtime contextRef], jsArrayObject, &outErr);
    FMAssert(!byteOffset);
#endif
    
    size_t len = JSObjectGetTypedArrayByteLength([runtime contextRef], jsArrayObject, &outErr);
    
    void *b = JSObjectGetTypedArrayBytesPtr([runtime contextRef], jsArrayObject, &outErr);
    
    NSData *d = [NSData dataWithBytes:b length:len];
    
    return [FJSValue valueWithInstance:(__bridge CFTypeRef _Nonnull)(d) inRuntime:runtime];
}

+ (FJSValue*)dataFromInt8Array:(FJSValue*)array inFJSRuntime:(FJSRuntime*)runtime {
    return [self dataFromTypedArray:array inFJSRuntime:runtime];
}

+ (FJSValue*)dataFromUint8Array:(FJSValue*)array inFJSRuntime:(FJSRuntime*)runtime {
    return [self dataFromTypedArray:array inFJSRuntime:runtime];
}

+ (FJSValue*)dataFromInt16Array:(FJSValue*)array inFJSRuntime:(FJSRuntime*)runtime {
    return [self dataFromTypedArray:array inFJSRuntime:runtime];
}

+ (FJSValue*)dataFromUint16Array:(FJSValue*)array inFJSRuntime:(FJSRuntime*)runtime {
    return [self dataFromTypedArray:array inFJSRuntime:runtime];
}

+ (FJSValue*)dataFromInt32Array:(FJSValue*)array inFJSRuntime:(FJSRuntime*)runtime {
    return [self dataFromTypedArray:array inFJSRuntime:runtime];
}

+ (FJSValue*)dataFromUint32Array:(FJSValue*)array inFJSRuntime:(FJSRuntime*)runtime {
    return [self dataFromTypedArray:array inFJSRuntime:runtime];
}

+ (FJSValue*)dataFromFloat32Array:(FJSValue*)array inFJSRuntime:(FJSRuntime*)runtime {
    return [self dataFromTypedArray:array inFJSRuntime:runtime];
}

+ (FJSValue*)dataFromFloat64Array:(FJSValue*)array inFJSRuntime:(FJSRuntime*)runtime {
    return [self dataFromTypedArray:array inFJSRuntime:runtime];
}



- (FJSValue*)toArrayBufferInFJSRuntime:(FJSRuntime*)runtime {

    void *b = malloc([self length]);
    [self getBytes:b length:[self length]];
    
    JSValueRef e;
    JSObjectRef jsobj = JSObjectMakeArrayBufferWithBytesNoCopy([runtime contextRef], b, [self length], FJSTypedArrayBytesDeallocator, nil, &e);
    
    return [FJSValue valueWithJSValueRef:jsobj inRuntime:runtime];
}

+ (NSDictionary*)JSTypedArrayLUT {
    static NSDictionary *lut;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lut = @{
            @"Int8Array": @(kJSTypedArrayTypeInt8Array),
            @"Int16Array": @(kJSTypedArrayTypeInt16Array),
            @"Int32Array": @(kJSTypedArrayTypeInt32Array),
            @"Uint8Array": @(kJSTypedArrayTypeUint8Array),
            @"Uint8ClampedArray": @(kJSTypedArrayTypeUint8ClampedArray),
            @"Uint16Array": @(kJSTypedArrayTypeUint16Array),
            @"Uint32Array": @(kJSTypedArrayTypeUint32Array),
            @"Float32Array": @(kJSTypedArrayTypeFloat32Array),
            @"kJSTypedArrayTypeFloat64Array": @(kJSTypedArrayTypeFloat64Array),
            @"ArrayBuffer": @(kJSTypedArrayTypeArrayBuffer),
            [NSNull null]: @(kJSTypedArrayTypeNone),
        };
    });
    
    return lut;
}

+ (JSTypedArrayType)JSTypedArrayTypeFromTypedArrayName:(NSString*)name {
    
    if (name && [[self JSTypedArrayLUT] objectForKey:name]) {
        return [[[self JSTypedArrayLUT] objectForKey:name] intValue];
    }
    
    return kJSTypedArrayTypeNone;
}

+ (NSString*)FJSTypedArrayNameNameFromJSTypedArray:(JSTypedArrayType)type {
    
    return [[[self JSTypedArrayLUT] allKeysForObject:@(type)] firstObject];
}

@end
