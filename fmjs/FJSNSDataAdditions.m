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


static void FJSTypedArrayBytesDeallocator(void* bytes, void* deallocatorContext) {
    free(bytes);
}

- (BOOL)doFJSFunction:(FJSValue*)function inRuntime:(FJSRuntime*)runtime withValues:(NSArray<FJSValue*>*)values returning:(FJSValue*_Nullable __autoreleasing*_Nullable)returnValue {
    
    NSString *methodName = [[function symbol] name];
    SEL selector = NSSelectorFromString(methodName);
    
    if (selector == @selector(toArrayBuffer)) {
        
        //Wow, this isn't called because we're trying to do a property lookup and returning undefined or something here.
        void *b = malloc([self length]);
        [self getBytes:b length:[self length]];
        
        JSValueRef e;
        JSObjectRef jsobj = JSObjectMakeArrayBufferWithBytesNoCopy([runtime contextRef], b, [self length], FJSTypedArrayBytesDeallocator, nil, &e);
        
        *returnValue = [FJSValue valueWithJSValueRef:jsobj inRuntime:runtime];
        
        return YES;
    }
    else if (selector == @selector(toInt8Array)) {
        JSObjectRef ar = JSObjectMakeTypedArray([runtime contextRef], kJSTypedArrayTypeInt8Array, [self length], NULL);
        memcpy(JSObjectGetTypedArrayBytesPtr([runtime contextRef], ar, nil), [self bytes], [self length]);
        *returnValue = [FJSValue valueWithJSValueRef:ar inRuntime:runtime];
        return YES;
    }
    else if (selector == @selector(toUint8Array)) {
        JSObjectRef ar = JSObjectMakeTypedArray([runtime contextRef], kJSTypedArrayTypeUint8Array, [self length], NULL);
        memcpy(JSObjectGetTypedArrayBytesPtr([runtime contextRef], ar, nil), [self bytes], [self length]);
        *returnValue = [FJSValue valueWithJSValueRef:ar inRuntime:runtime];
        return YES;
    }
    else if (selector == @selector(toInt16Array)) {
        JSObjectRef ar = JSObjectMakeTypedArray([runtime contextRef], kJSTypedArrayTypeInt16Array, [self length], NULL);
        memcpy(JSObjectGetTypedArrayBytesPtr([runtime contextRef], ar, nil), [self bytes], [self length]);
        *returnValue = [FJSValue valueWithJSValueRef:ar inRuntime:runtime];
        return YES;
    }
    else if (selector == @selector(toUint16Array)) {
        JSObjectRef ar = JSObjectMakeTypedArray([runtime contextRef], kJSTypedArrayTypeUint16Array, [self length], NULL);
        memcpy(JSObjectGetTypedArrayBytesPtr([runtime contextRef], ar, nil), [self bytes], [self length]);
        *returnValue = [FJSValue valueWithJSValueRef:ar inRuntime:runtime];
        return YES;
    }
    else if (selector == @selector(toInt32Array)) {
        JSObjectRef ar = JSObjectMakeTypedArray([runtime contextRef], kJSTypedArrayTypeInt32Array, [self length], NULL);
        memcpy(JSObjectGetTypedArrayBytesPtr([runtime contextRef], ar, nil), [self bytes], [self length]);
        *returnValue = [FJSValue valueWithJSValueRef:ar inRuntime:runtime];
        return YES;
    }
    else if (selector == @selector(toUint32Array)) {
        JSObjectRef ar = JSObjectMakeTypedArray([runtime contextRef], kJSTypedArrayTypeUint32Array, [self length], NULL);
        memcpy(JSObjectGetTypedArrayBytesPtr([runtime contextRef], ar, nil), [self bytes], [self length]);
        *returnValue = [FJSValue valueWithJSValueRef:ar inRuntime:runtime];
        return YES;
    }
    else if (selector == @selector(toFloat32Array)) {
        JSObjectRef ar = JSObjectMakeTypedArray([runtime contextRef], kJSTypedArrayTypeFloat32Array, [self length], NULL);
        memcpy(JSObjectGetTypedArrayBytesPtr([runtime contextRef], ar, nil), [self bytes], [self length]);
        *returnValue = [FJSValue valueWithJSValueRef:ar inRuntime:runtime];
        return YES;
    }
    else if (selector == @selector(toFloat64Array)) {
        JSObjectRef ar = JSObjectMakeTypedArray([runtime contextRef], kJSTypedArrayTypeFloat64Array, [self length], NULL);
        memcpy(JSObjectGetTypedArrayBytesPtr([runtime contextRef], ar, nil), [self bytes], [self length]);
        *returnValue = [FJSValue valueWithJSValueRef:ar inRuntime:runtime];
        return YES;
    }
    /*
    else if (selector == @selector(timeoutF:m:)) {
        
        FMAssert(([values count] == 2));
        if ([values count] == 2) {
            FJSValue *callbackFunction = [values objectAtIndex:0];
            FJSValue *milliseconds     = [values objectAtIndex:1];
            
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, [milliseconds toLong] * NSEC_PER_MSEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^{
                [callbackFunction callWithArguments:nil];
            });
        }
        return YES;
    }*/
    
    return NO;
}


+ (BOOL)doFJSFunction:(FJSValue*)function inRuntime:(FJSRuntime*)runtime withValues:(NSArray<FJSValue*>*)values returning:(FJSValue*_Nullable __autoreleasing*_Nullable)returnValue {
    
    NSString *methodName = [[function symbol] name];
    SEL selector = NSSelectorFromString(methodName);
    
    if (selector == @selector(dataFromInt8Array:)  || selector == @selector(dataFromUint8Array:) ||
        selector == @selector(dataFromInt16Array:) || selector == @selector(dataFromUint16Array:) ||
        selector == @selector(dataFromInt32Array:) || selector == @selector(dataFromUint32Array:) ||
        selector == @selector(dataFromFloat32Array:) || selector == @selector(dataFromFloat64Array:)) {
        
        // FIXME: Can we check the types here? var a = new Int8Array([-122, 343, -567]); NSData.dataFromInt16Array(a); will segfault when you grab the values because the types aren't matching.
        
        FJSValue *array = [values firstObject];
        if (![array isJSNative]) {
            return NO;
        }
        
        JSValueRef outErr;
        JSObjectRef jsArrayObject = [array JSObjectRef];
        
#ifdef DEBUG
        size_t byteOffset = JSObjectGetTypedArrayByteOffset([runtime contextRef], jsArrayObject, &outErr);
        FMAssert(!byteOffset);
#endif
        
        size_t len = JSObjectGetTypedArrayByteLength([runtime contextRef], jsArrayObject, &outErr);
        
        void *b = JSObjectGetTypedArrayBytesPtr([runtime contextRef], jsArrayObject, &outErr);
        
        NSData *d = [NSData dataWithBytes:b length:len];
        
        FJSValue *ret = [FJSValue valueWithInstance:(__bridge CFTypeRef _Nonnull)(d) inRuntime:runtime];
        *returnValue = ret;
        
        return YES;
    }
    
    
    return NO;
}





// Completely private.
- (void)timeoutF:(FJSValue *)callbackFunction m:(FJSValue *)milliseconds {
    FMAssert(NO);
}



- (FJSValue*)toArrayBuffer {
    FMAssert(NO);
    return nil;
}

- (FJSValue*)toInt8Array {
    FMAssert(NO);
    return nil;
}

- (FJSValue*)toUint8Array {
    FMAssert(NO);
    return nil;
}

- (FJSValue*)toInt16Array {
    FMAssert(NO);
    return nil;
}

- (FJSValue*)toUint16Array {
    FMAssert(NO);
    return nil;
}

- (FJSValue*)toInt32Array {
    FMAssert(NO);
    return nil;
}

- (FJSValue*)toUint32Array {
    FMAssert(NO);
    return nil;
}

- (FJSValue*)toFloat32Array {
    FMAssert(NO);
    return nil;
}

- (FJSValue*)toFloat64Array {
    FMAssert(NO);
    return nil;
}

+ (FJSValue*)dataFromInt8Array:(FJSValue*)array {
    FMAssert(NO);
    return nil;
}

+ (FJSValue*)dataFromUint8Array:(FJSValue*)array {
    FMAssert(NO);
    return nil;
}

+ (FJSValue*)dataFromInt16Array:(FJSValue*)array {
    FMAssert(NO);
    return nil;
}

+ (FJSValue*)dataFromUint16Array:(FJSValue*)array {
    FMAssert(NO);
    return nil;
}

+ (FJSValue*)dataFromInt32Array:(FJSValue*)array {
    FMAssert(NO);
    return nil;
}

+ (FJSValue*)dataFromUint32Array:(FJSValue*)array {
    FMAssert(NO);
    return nil;
}

+ (FJSValue*)dataFromFloat32Array:(FJSValue*)array {
    FMAssert(NO);
    return nil;
}

+ (FJSValue*)dataFromFloat64Array:(FJSValue*)array {
    FMAssert(NO);
    return nil;
}

@end
