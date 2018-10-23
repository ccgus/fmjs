//
//  FJSUtil.m
//  yd
//
//  Created by August Mueller on 9/13/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import "FJSUtil.h"
#import "FJSFFI.h"
#import "FJS.h"
#import "FJSPrivate.h"

@import ObjectiveC;

BOOL FJSCharEquals(const char *__s1, const char *__s2) {
    return (strcmp(__s1, __s2) == 0);
}

BOOL FJSStringIsNumber(NSString *s) {
    
    #pragma message "FIXME: we need a much better way to see if a string is a number. This is for looking up indexes on arrays and such."
    
    return [[NSString stringWithFormat:@"%ld", [s integerValue]] isEqualToString:s];
    
}

NSString *FJSStructNameFromRuntimeType(NSString *runtimeType) {
    
    if (![runtimeType hasPrefix:@"{"]) {
        FMAssert(NO);
        return nil;
    }
    
    NSRange r = [runtimeType rangeOfString:@"="];
    if (r.location == NSNotFound) {
        FMAssert(NO);
        return nil;
    }
    
    if  (r.location < 3) {
        return nil;
    }
    
    
    return [runtimeType substringWithRange:NSMakeRange(1, r.location - 1)];
}

NSArray *FJSNativeArrayFromJSObject(JSObjectRef arrayValue, JSContextRef ctx) {
    
    JSValueRef exception = NULL;
    JSStringRef lengthJS = JSStringCreateWithUTF8CString("length");
    NSUInteger length = JSValueToNumber(ctx, JSObjectGetProperty(ctx, arrayValue, lengthJS, NULL), &exception);
    JSStringRelease(lengthJS);
    
    if (exception) {
        return nil;
    }
    
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:length];
    
    for (NSUInteger i=0; i<length; i++) {
        id obj = nil;
        JSValueRef jsValue = JSObjectGetPropertyAtIndex(ctx, arrayValue, (unsigned int)i, &exception);
        if (exception != NULL) {
            return nil;
        }
        
        obj = FJSNativeObjectFromJSValue(jsValue, @"@", ctx);
        if (obj == nil) {
            obj = [NSNull null];
        }
        
        [array addObject:obj];
    }
    
    return [array copy];
}

NSDictionary *FJSNativeDictionaryFromJSObject(JSObjectRef jsObject, JSContextRef context) {
    JSPropertyNameArrayRef names = JSObjectCopyPropertyNames(context, jsObject);
    NSUInteger length = JSPropertyNameArrayGetCount(names);
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:length];
    JSValueRef exception = NULL;
    
    for (NSUInteger i=0; i<length; i++) {
        id obj = nil;
        JSStringRef name = JSPropertyNameArrayGetNameAtIndex(names, i);
        NSString *key = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, name));
        JSValueRef jsValue = JSObjectGetProperty(context, jsObject, name, &exception);
        
        if (exception != NULL) {
            return nil;
        }
        
        obj = FJSNativeObjectFromJSValue(jsValue, @"@", context);
        if (obj == nil) {
            obj = [NSNull null];
        }
        
        [dictionary setObject:obj forKey:key];
    }
    
    JSPropertyNameArrayRelease(names);
    
    return [dictionary copy];
}

BOOL FJSObjectIsArray(JSObjectRef jsObject, JSContextRef context) {
    
    JSStringRef scriptJS = JSStringCreateWithUTF8CString("return arguments[0].constructor == Array.prototype.constructor");
    JSObjectRef fn = JSObjectMakeFunction(context, NULL, 0, NULL, scriptJS, NULL, 1, NULL);
    JSValueRef result = JSObjectCallAsFunction(context, fn, NULL, 1, (JSValueRef *)&jsObject, NULL);
    JSStringRelease(scriptJS);
    
    return JSValueToBoolean(context, result);
}

id FJSNativeObjectFromJSValue(JSValueRef jsValue, NSString *typeEncoding, JSContextRef context) {
    
    
    // typeEncoding could be '@"NSString"', thanks to blocks!.
    if ([typeEncoding hasPrefix:@"@"]) {
        
        if (JSValueIsString(context, jsValue)) {
            JSStringRef resultStringJS = JSValueToStringCopy(context, jsValue, NULL);
            id o = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, resultStringJS));
            JSStringRelease(resultStringJS);
            return o;
        }
        
        
        if (JSValueIsNumber(context, jsValue)) {
            double v = JSValueToNumber(context, jsValue, NULL);
            return @(v);
        }
        
        if (JSValueIsBoolean(context, jsValue)) {
            bool v = JSValueToBoolean(context, jsValue);
            return @(v);
        }
        
        
        if (JSValueIsNull(context, jsValue) || JSValueIsUndefined(context, jsValue)) {
            return nil;
        }
        
        
        if (JSValueIsObject(context, jsValue)) {
            
            JSObjectRef jsObject = JSValueToObject(context, jsValue, NULL);
            
            
            if (JSObjectGetPrivate(jsObject)) {
                FMAssert([(__bridge FJSValue *)JSObjectGetPrivate(jsObject) isKindOfClass:[FJSValue class]]);
                FJSValue *value = (__bridge FJSValue *)JSObjectGetPrivate(jsObject);
                
                if ([value isInstance]) {
                    return [value toObject];
                }
            }
            
            
            
            BOOL isFunction = JSObjectIsFunction(context, jsObject);
            
            if (isFunction) {
                JSStringRef resultStringJS = JSValueToStringCopy(context, jsValue, NULL);
                NSString *functionString = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, resultStringJS));
                JSStringRelease(resultStringJS);
                return functionString;
            }
            else if (FJSObjectIsArray(jsObject, context)) {
                return FJSNativeArrayFromJSObject(jsObject, context);
            }
            
            return FJSNativeDictionaryFromJSObject(jsObject, context);
        }
        
        JSType type = JSValueGetType(context, jsValue);
        debug(@"What am I supposed to do with %d?", type);
        FMAssert(NO);
        
    }
    
    
    
    if ([typeEncoding isEqualToString:@"B"]) {
        bool v = JSValueToBoolean(context, jsValue);
        return @(v);
    }
    
    if ([typeEncoding isEqualToString:@"s"]) {
        short v = JSValueToNumber(context, jsValue, NULL);
        return @(v);
    }
    
    if ([typeEncoding isEqualToString:@"S"]) {
        unsigned short v = JSValueToNumber(context, jsValue, NULL);
        return @(v);
    }
    
    if ([typeEncoding isEqualToString:@"i"]) {
        int v = JSValueToNumber(context, jsValue, NULL);
        return @(v);
    }
    
    if ([typeEncoding isEqualToString:@"I"]) {
        uint v = JSValueToNumber(context, jsValue, NULL);
        return @(v);
    }
    
    
    if ([typeEncoding isEqualToString:@"l"]) {
        long v = JSValueToNumber(context, jsValue, NULL);
        return @(v);
    }
    
    if ([typeEncoding isEqualToString:@"L"]) {
        unsigned long v = JSValueToNumber(context, jsValue, NULL);
        return @(v);
    }
    
    
    if ([typeEncoding isEqualToString:@"q"]) {
        //FMAssert(JSValueIsNumber(context, jsValue)); // See testStringToNumber
        double d = JSValueToNumber(context, jsValue, NULL);
        
        if (isnan(d)) {
            printf("Warning: cast overflow prevented in FJSNativeObjectFromJSValue. Returning 0 for long long\n");
            return @(0);
        }
        
        long long v = d;
        
        return @(v);
    }
    
    if ([typeEncoding isEqualToString:@"Q"]) {
        unsigned long long v = JSValueToNumber(context, jsValue, NULL);
        return @(v);
    }
    
    if ([typeEncoding isEqualToString:@"f"]) {
        float v = JSValueToNumber(context, jsValue, NULL);
        return @(v);
    }
    
    if ([typeEncoding isEqualToString:@"d"]) {
        double v = JSValueToNumber(context, jsValue, NULL);
        return @(v);
    }
    
    if ([typeEncoding isEqualToString:@"c"] || [typeEncoding isEqualToString:@"C"]) { // _C_CHR, _C_UCHR
        
        id f = FJSNativeObjectFromJSValue(jsValue, @"@", context);
        if ([f isKindOfClass:[NSString class]] && [f length]) {
            char c = [f UTF8String][0];
            NSNumber *n = @(c);
            FMAssert(FJSCharEquals([n objCType], @encode(char)));
            return n;
        }
        else if ([f isKindOfClass:[NSNumber class]]) {
            return f;
        }
        
        return nil;
    }
    
    if ([typeEncoding isEqualToString:@"?"]) { // _C_UNDEF
        return nil;
    }
    
    debug(@"Not sure what to do with type encoding '%@'", typeEncoding);
    
    //assert(NO);
    
    return nil;
}

JSValueRef FJSNativeObjectToJSValue(id o, JSContextRef context) {
    
    if ([o isKindOfClass:[NSString class]]) {
        
        JSStringRef string = JSStringCreateWithCFString((__bridge CFStringRef)o);
        JSValueRef value = JSValueMakeString(context, string);
        JSStringRelease(string);
        return value;
    }
    
    else if ([o isKindOfClass:[NSNumber class]]) {
        
        if (FJSCharEquals([o objCType], @encode(BOOL))) {
            return JSValueMakeBoolean(context, [o boolValue]);
        }
        else {
            return JSValueMakeNumber(context, [o doubleValue]);
        }
    }
    else if ([o isKindOfClass:[NSNull class]]) {
        return JSValueMakeNull(context);
    }
    
    return nil;
}


#pragma mark -
#pragma mark Type Encodings Stolen from Mocha

/*
 * __alignOf__ returns 8 for double, but its struct align is 4
 * use dummy structures to get struct alignment, each having a byte as first element
 */
typedef struct { char a; void* b; } struct_C_ID;
typedef struct { char a; char b; } struct_C_CHR;
typedef struct { char a; short b; } struct_C_SHT;
typedef struct { char a; int b; } struct_C_INT;
typedef struct { char a; long b; } struct_C_LNG;
typedef struct { char a; long long b; } struct_C_LNG_LNG;
typedef struct { char a; float b; } struct_C_FLT;
typedef struct { char a; double b; } struct_C_DBL;
typedef struct { char a; BOOL b; } struct_C_BOOL;

#pragma message "FIXME: Can we come up with a test that does alignment checks for us?"
BOOL FJSGetAlignmentOfTypeEncoding(size_t * alignmentPtr, char encoding) {
    BOOL success = YES;
    size_t alignment = 0;
    switch (encoding) {
        case _C_ID:         alignment = offsetof(struct_C_ID, b); break;
        case _C_CLASS:      alignment = offsetof(struct_C_ID, b); break;
        case _C_SEL:        alignment = offsetof(struct_C_ID, b); break;
        case _C_CHR:        alignment = offsetof(struct_C_CHR, b); break;
        case _C_UCHR:       alignment = offsetof(struct_C_CHR, b); break;
        case _C_SHT:        alignment = offsetof(struct_C_SHT, b); break;
        case _C_USHT:       alignment = offsetof(struct_C_SHT, b); break;
        case _C_INT:        alignment = offsetof(struct_C_INT, b); break;
        case _C_UINT:       alignment = offsetof(struct_C_INT, b); break;
        case _C_LNG:        alignment = offsetof(struct_C_LNG, b); break;
        case _C_ULNG:       alignment = offsetof(struct_C_LNG, b); break;
        case _C_LNG_LNG:    alignment = offsetof(struct_C_LNG_LNG, b); break;
        case _C_ULNG_LNG:   alignment = offsetof(struct_C_LNG_LNG, b); break;
        case _C_FLT:        alignment = offsetof(struct_C_FLT, b); break;
        case _C_DBL:        alignment = offsetof(struct_C_DBL, b); break;
        case _C_BOOL:       alignment = offsetof(struct_C_BOOL, b); break;
        case _C_PTR:        alignment = offsetof(struct_C_ID, b); break;
        case _C_CHARPTR:    alignment = offsetof(struct_C_ID, b); break;
        default:            success = NO; break;
    }
    if (success && alignmentPtr != NULL) {
        *alignmentPtr = alignment;
    }
    return success;
}

BOOL FJSGetSizeOfTypeEncoding(size_t *sizePtr, char encoding) {
    BOOL success = YES;
    size_t size = 0;
    switch (encoding) {
        case _C_ID:         size = sizeof(id); break;
        case _C_CLASS:      size = sizeof(Class); break;
        case _C_SEL:        size = sizeof(SEL); break;
        case _C_PTR:        size = sizeof(void*); break;
        case _C_CHARPTR:    size = sizeof(char*); break;
        case _C_CHR:        size = sizeof(char); break;
        case _C_UCHR:       size = sizeof(unsigned char); break;
        case _C_SHT:        size = sizeof(short); break;
        case _C_USHT:       size = sizeof(unsigned short); break;
        case _C_INT:        size = sizeof(int); break;
        case _C_LNG:        size = sizeof(long); break;
        case _C_UINT:       size = sizeof(unsigned int); break;
        case _C_ULNG:       size = sizeof(unsigned long); break;
        case _C_LNG_LNG:    size = sizeof(long long); break;
        case _C_ULNG_LNG:   size = sizeof(unsigned long long); break;
        case _C_FLT:        size = sizeof(float); break;
        case _C_DBL:        size = sizeof(double); break;
        case _C_BOOL:       size = sizeof(bool); break;
        case _C_VOID:       size = sizeof(void); break;
        default:            success = NO; break;
    }
    if (success && sizePtr != NULL) {
        *sizePtr = size;
    }
    return success;
}

ffi_type * FJSFFITypeForTypeEncoding(char encoding) {
    switch (encoding) {
        case _C_ID:
        case _C_CLASS:
        case _C_SEL:
        case _C_PTR:
        case _C_CHARPTR:    return &ffi_type_pointer;
        case _C_CHR:        return &ffi_type_sint8;
        case _C_UCHR:       return &ffi_type_uint8;
        case _C_SHT:        return &ffi_type_sint16;
        case _C_USHT:       return &ffi_type_uint16;
        case _C_INT:
        case _C_LNG:        return &ffi_type_sint32;
        case _C_UINT:
        case _C_ULNG:       return &ffi_type_uint32;
        case _C_LNG_LNG:    return &ffi_type_sint64;
        case _C_ULNG_LNG:   return &ffi_type_uint64;
        case _C_FLT:        return &ffi_type_float;
        case _C_DBL:        return &ffi_type_double;
        case _C_BOOL:       return &ffi_type_sint8;
        case _C_VOID:       return &ffi_type_void;
    }
    return NULL;
}

NSString *FJSDescriptionOfTypeEncoding(char encoding) {
    switch (encoding) {
        case _C_ID:         return @"id";
        case _C_CLASS:      return @"Class";
        case _C_SEL:        return @"SEL";
        case _C_PTR:        return @"void*";
        case _C_CHARPTR:    return @"char*";
        case _C_CHR:        return @"char";
        case _C_UCHR:       return @"unsigned char";
        case _C_SHT:        return @"short";
        case _C_USHT:       return @"unsigned short";
        case _C_INT:        return @"int";
        case _C_LNG:        return @"long";
        case _C_UINT:       return @"unsigned int";
        case _C_ULNG:       return @"unsigned long";
        case _C_LNG_LNG:    return @"long long";
        case _C_ULNG_LNG:   return @"unsigned long long";
        case _C_FLT:        return @"float";
        case _C_DBL:        return @"double";
        case _C_BOOL:       return @"bool";
        case _C_VOID:       return @"void";
        case _C_UNDEF:      return @"(unknown)";
    }
    return nil;
}

NSString *FJSDescriptionOfTypeEncodingWithFullEncoding(char typeEncoding, NSString *fullTypeEncoding) {
    switch (typeEncoding) {
        case _C_VOID:       return @"void";
        case _C_ID:         return @"id";
        case _C_CLASS:      return @"Class";
        case _C_CHR:        return @"char";
        case _C_UCHR:       return @"unsigned char";
        case _C_SHT:        return @"short";
        case _C_USHT:       return @"unsigned short";
        case _C_INT:        return @"int";
        case _C_UINT:       return @"unsigned int";
        case _C_LNG:        return @"long";
        case _C_ULNG:       return @"unsigned long";
        case _C_LNG_LNG:    return @"long long";
        case _C_ULNG_LNG:   return @"unsigned long long";
        case _C_FLT:        return @"float";
        case _C_DBL:        return @"double";
        case _C_STRUCT_B: {
            return @"struct";
            //FMAssert(NO);
            //return [MOFunctionArgument structureTypeEncodingDescription:fullTypeEncoding];
        }
        case _C_SEL:        return @"selector";
        case _C_CHARPTR:    return @"char*";
        case _C_BOOL:       return @"bool";
        case _C_PTR:        return @"void*";
        case _C_UNDEF:      return @"(unknown)";
    }
    return nil;
}

// Thanks, clang!
struct FJSBlock_descriptor {
    unsigned long reserved;
    unsigned long size;
    void *rest[1];
};

struct FJSBlock_literal {
    void *isa;
    int flags;
    int reserved;
    void *invoke;
    struct FJSBlock_descriptor *descriptor;
};

void *FJSCallAddressForBlock(id block) {
    FMAssert([block isKindOfClass:NSClassFromString(@"NSBlock")]);
    return ((__bridge struct FJSBlock_literal *)block)->invoke;
}

const char *FJSTypeEncodingForBlock(id theBlock) {
    struct FJSBlock_literal *block = (__bridge struct FJSBlock_literal *)theBlock;
    struct FJSBlock_descriptor *descriptor = block->descriptor;
    
    int copyDisposeFlag = 1 << 25;
    int signatureFlag = 1 << 30;
    
    assert(block->flags & signatureFlag);
    
    int index = 0;
    if (block->flags & copyDisposeFlag) {
        index += 2;
    }
    
    return descriptor->rest[index];
}

NSString *FJSUUID(void) {
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidString = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);
    
    return [uuidString lowercaseString];
}


