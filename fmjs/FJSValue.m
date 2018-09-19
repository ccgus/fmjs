//
//  FJSJSWrapper.m
//  yd
//
//  Created by August Mueller on 8/21/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import "FJS.h"
#import "FJSValue.h"
#import "FJSFFI.h"
#import "FJSUtil.h"

#import <objc/runtime.h>


@interface FJSValue ()

@property (weak) FJSRuntime *runtime;
@property (assign) JSObjectRef nativeJSObj;

@property (weak) id weakInstance;

#ifdef DEBUG
@property (assign) BOOL isWeakReference;
#endif


@end

@implementation FJSValue

- (instancetype)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)dealloc {
    
    if ([self isInstance] && _cValue.value.pointerValue) {
        debug(@"FJSValue dealloc releasing %@", _cValue.value.pointerValue);
        CFRelease(_cValue.value.pointerValue);
    }
    
#ifdef DEBUG
    if ([self isInstance] && !_weakInstance && !_isWeakReference && !_cValue.value.pointerValue) {
        debug(@"Why am I an instance without anything to point to?! %p", self);
        FMAssert(NO);
    }
#endif
    
}

+ (instancetype)valueForJSObject:(nullable JSObjectRef)jso inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    if (!jso) {
        return nil;
    }
    
    if (JSValueIsObject([runtime contextRef], jso)) {
        FJSValue *wr = (__bridge FJSValue *)(JSObjectGetPrivate(jso));
        if (wr) {
            return wr;
        }
    }
    
    FJSValue *native = [FJSValue new];
    [native setNativeJSObj:jso];
    [native setIsJSNative:YES];
    [native setRuntime:runtime];
    [native setJsValueType:JSValueGetType([runtime contextRef], jso)];
    return native;
}

+ (instancetype)valueWithSymbol:(FJSSymbol*)sym inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    FJSValue *cw = [[self alloc] init];
    [cw setSymbol:sym];
    [cw setRuntime:runtime];
    
    if ([[sym symbolType] isEqualToString:@"retval"]) {
        cw->_cValue.type = [[sym runtimeType] UTF8String][0];
    }
    
    return cw;
}

+ (instancetype)valueWithClass:(Class)c inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    FJSValue *cw = [[self alloc] init];
    [cw setClass:c];
    [cw setRuntime:runtime];
    
    return cw;
}

+ (instancetype)valueWithInstance:(CFTypeRef)instance inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    FJSValue *cw = [[self alloc] init];
    [cw setInstance:instance];
    [cw setRuntime:runtime];
    
    return cw;
}

+ (instancetype)valueWithWeakInstance:(id)instance inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    FJSValue *cw = [[self alloc] init];
    [cw setWeakInstance:instance];
    [cw setIsWeakReference:YES];
    
    cw->_cValue.type = _C_ID;
    
    [cw setRuntime:runtime];
    //debug(@"weak value: %p", cw);
    
    return cw;
}

- (BOOL)isClass {
    return _cValue.type == _C_CLASS;
}

- (BOOL)isInstance {
    return _cValue.type == _C_ID;
}

- (id)instance {
    
    if (_weakInstance) {
        return _weakInstance;
    }
    
    return (__bridge id)_cValue.value.pointerValue;
}

- (Class)rtClass {
    return (__bridge Class)_cValue.value.pointerValue;
}

- (void)setInstance:(CFTypeRef)o {
    FMAssert(!_weakInstance);
    FMAssert(!_cValue.value.pointerValue);
    //debug(@"FJSValue retaining %@ currently at %ld", o, CFGetRetainCount(o));
    
    CFRetain(o);
    _cValue.type = _C_ID;
    _cValue.value.pointerValue = (void*)o;
}

- (void)retainReturnValue {
    
    FMAssert([[_symbol symbolType] isEqualToString:@"retval"]); // Why are we here otherwise?
    
    if ([[_symbol symbolType] isEqualToString:@"retval"] && [[_symbol runtimeType] isEqualToString:@"@"]) {
        // OK, we've got an instance set in the return storage, but it hasn't been retained yet. Let's make that happen.
        CFRetain((CFTypeRef)_cValue.value.pointerValue);
    }
    
}

- (void)setClass:(Class)c {
    _cValue.type = _C_CLASS;
    _cValue.value.pointerValue = (__bridge void * _Nonnull)(c);
}

- (BOOL)isInstanceMethod {
    return [[_symbol symbolType] isEqualToString:@"method"];
}

- (BOOL)isClassMethod {
    return [[_symbol symbolType] isEqualToString:@"method"] && [_symbol isClassMethod];
}

- (BOOL)isSymbol {
    return _symbol != nil;
}

- (BOOL)isFunction {
    return [[_symbol symbolType] isEqualToString:@"function"];
}

- (BOOL)hasClassMethodNamed:(NSString*)m {
    return [[self rtClass] respondsToSelector:NSSelectorFromString(m)];
}

- (id)callMethod {
    
    return nil;
}

- (nullable JSValueRef)JSValue {
    
    if (_nativeJSObj) {
        return _nativeJSObj;
    }
    
    JSValueRef vr = nil;
    
    if ([self isInstance]) {
        
        vr = [FJSValue nativeObjectToJSValue:[self instance] inJSContext:[_runtime contextRef]];
        
        if (vr) {
            return vr;
        }
        
        FMAssert(_runtime);
        
        vr = [_runtime newJSValueForWrapper:self];
        
        FMAssert(vr);
        return vr;
    }
    
    switch (_cValue.type) {
            
        case _C_BOOL:
            vr = JSValueMakeBoolean([_runtime contextRef], _cValue.value.boolValue);
            break;
            
        case _C_CHR:
        case _C_UCHR:
        case _C_SHT:
        case _C_USHT:
        case _C_INT:
        case _C_UINT:
        case _C_LNG:
        case _C_ULNG:
        case _C_LNG_LNG:
        case _C_ULNG_LNG:
        case _C_FLT:
        case _C_DBL: {
            double number = 0;
            switch (_cValue.type) {
                case _C_CHR:        number = _cValue.value.charValue; break;
                case _C_UCHR:       number = _cValue.value.ucharValue; break;
                case _C_SHT:        number = _cValue.value.shortValue; break;
                case _C_USHT:       number = _cValue.value.ushortValue; break;
                case _C_INT:        number = _cValue.value.intValue; break;
                case _C_UINT:       number = _cValue.value.uintValue; break;
                case _C_LNG:        number = _cValue.value.longValue; break;
                case _C_ULNG:       number = _cValue.value.unsignedLongValue; break;
                case _C_LNG_LNG:    number = _cValue.value.longLongValue; break;
                case _C_ULNG_LNG:   number = _cValue.value.unsignedLongLongValue; break;
                case _C_FLT:        number = _cValue.value.floatValue; break;
                case _C_DBL:        number = _cValue.value.doubleValue; break;
            }
            vr = JSValueMakeNumber([_runtime contextRef], number);
            break;
        }
        
        default:
            FMAssert(NO);
    
    }
    
    
    if (!vr) {
        debug(@"Returning nil JSValue for %@", self);
    }
    
    return vr;
}

- (void*)objectStorage {
    
    FMAssert(_cValue.type);
    return  &_cValue.value;
}

- (ffi_type*)FFIType {
    return [self FFITypeWithHint:nil];
}

- (NSString*)description {
    return [NSString stringWithFormat:@"%@ - %@ (%@ native)", [super description], [self toObject], _isJSNative ? @"js" : @"c"];
}

- (ffi_type*)FFITypeWithHint:(nullable NSString*)typeEncoding {
    
    if (_symbol) {
        
        char c = [[_symbol runtimeType] characterAtIndex:0];
        
        if (c) {
            return [FJSFFI ffiTypeAddressForTypeEncoding:c];
        }
    }
    
    if ([typeEncoding isEqualToString:@"@"]) {
        return &ffi_type_pointer;
    }
    
    debug(@"NO SYMBOL IN WRAPPER: %@", self);
    
    if (_cValue.type == _C_ID) {
        return &ffi_type_pointer;
    }
    
    return &ffi_type_void;
}

- (nullable JSValueRef)toJSString {
    // TODO: check for numbers, etc, and convert them to the right JS type
    debug(@"_instance: %@", [self instance]);
    JSStringRef string = JSStringCreateWithCFString((__bridge CFStringRef)[[self instance] description]);
    JSValueRef value = JSValueMakeString([_runtime contextRef], string);
    JSStringRelease(string);
    return value;
}

- (id)toObject {
    
    if (_isJSNative) {
        
        if (!_cValue.type) {
            FMAssert(_jsValueType);
            FMAssert(_nativeJSObj);
            
            switch (_jsValueType) {
                case kJSTypeUndefined:
                case kJSTypeNull:
                    _cValue.type = _C_UNDEF;
                    break;
                    
                case kJSTypeBoolean:
                    _cValue.type = _C_BOOL;
                    break;
                    
                case kJSTypeNumber:
                    _cValue.type = _C_DBL;
                    break;
                    
                case kJSTypeString:
                case kJSTypeObject:
                    _cValue.type = _C_ID;
                    break;
                    
                default:
                    FMAssert(NO);
                    break;
            }
        }
        
        return [FJSValue nativeObjectFromJSValue:_nativeJSObj ofType:[NSString stringWithFormat:@"%c", _cValue.type] inJSContext:[_runtime contextRef]];
    }
    
    if ([self isInstance]) {
        return [self instance];
    }
    
    debug(@"Haven't implemented toObject for %c yet", _cValue.type);
    
    return nil;
}

- (BOOL)pushJSValueToNativeType:(NSString*)type {
    
    if ([type isEqualToString:@"B"]) {
        _cValue.type = _C_BOOL;
        _cValue.value.boolValue = [[FJSValue nativeObjectFromJSValue:_nativeJSObj ofType:type inJSContext:[_runtime contextRef]] boolValue];
        return YES;
    }
    
    if ([type isEqualToString:@"s"]) {
        _cValue.type = _C_SHT;
        _cValue.value.shortValue = [[FJSValue nativeObjectFromJSValue:_nativeJSObj ofType:type inJSContext:[_runtime contextRef]] shortValue];
        return YES;
    }
    
    if ([type isEqualToString:@"S"]) {
        _cValue.type = _C_USHT;
        _cValue.value.ushortValue = [[FJSValue nativeObjectFromJSValue:_nativeJSObj ofType:type inJSContext:[_runtime contextRef]] unsignedShortValue];
        return YES;
    }
    
    if ([type isEqualToString:@"c"]) {
        _cValue.type = _C_CHR;
        _cValue.value.charValue = [[FJSValue nativeObjectFromJSValue:_nativeJSObj ofType:type inJSContext:[_runtime contextRef]] charValue];
        return YES;
    }
    
    if ([type isEqualToString:@"C"]) {
        _cValue.type = _C_UCHR;
        _cValue.value.ucharValue = [[FJSValue nativeObjectFromJSValue:_nativeJSObj ofType:type inJSContext:[_runtime contextRef]] unsignedCharValue];
        return YES;
    }
    
    if ([type isEqualToString:@"i"]) {
        _cValue.type = _C_INT;
        _cValue.value.intValue = [[FJSValue nativeObjectFromJSValue:_nativeJSObj ofType:type inJSContext:[_runtime contextRef]] intValue];
        return YES;
    }
    
    if ([type isEqualToString:@"I"]) {
        _cValue.type = _C_UINT;
        _cValue.value.uintValue = [[FJSValue nativeObjectFromJSValue:_nativeJSObj ofType:type inJSContext:[_runtime contextRef]] unsignedIntValue];
        return YES;
    }
    
    if ([type isEqualToString:@"l"]) {
        _cValue.type = _C_LNG;
        _cValue.value.longValue = [[FJSValue nativeObjectFromJSValue:_nativeJSObj ofType:type inJSContext:[_runtime contextRef]] longValue];
        return YES;
    }
    
    if ([type isEqualToString:@"L"]) {
        _cValue.type = _C_ULNG;
        _cValue.value.unsignedLongValue = [[FJSValue nativeObjectFromJSValue:_nativeJSObj ofType:type inJSContext:[_runtime contextRef]] unsignedLongValue];
        return YES;
    }
    
    if ([type isEqualToString:@"q"]) {
        _cValue.type = _C_LNG_LNG;
        _cValue.value.longLongValue = [[FJSValue nativeObjectFromJSValue:_nativeJSObj ofType:type inJSContext:[_runtime contextRef]] longLongValue];
        return YES;
    }
    
    if ([type isEqualToString:@"Q"]) {
        _cValue.type = _C_ULNG_LNG;
        _cValue.value.unsignedLongLongValue = [[FJSValue nativeObjectFromJSValue:_nativeJSObj ofType:type inJSContext:[_runtime contextRef]] unsignedLongLongValue];
        return YES;
    }
    
    if ([type isEqualToString:@"f"]) {
        _cValue.type = _C_FLT;
        _cValue.value.floatValue = [[FJSValue nativeObjectFromJSValue:_nativeJSObj ofType:type inJSContext:[_runtime contextRef]] floatValue];
        return YES;
    }
    
    if ([type isEqualToString:@"d"]) {
        _cValue.type = _C_DBL;
        _cValue.value.doubleValue = [[FJSValue nativeObjectFromJSValue:_nativeJSObj ofType:type inJSContext:[_runtime contextRef]] doubleValue];
        return YES;
    }
    
    if ([type isEqualToString:@"v"]) {
        _cValue.type = _C_VOID;
        _cValue.value.pointerValue = nil;
        return YES;
    }
    
    
    if ([type isEqualToString:@":"]) {
        
        if (JSValueIsString([_runtime contextRef], _nativeJSObj)) {
            JSStringRef resultStringJS = JSValueToStringCopy([_runtime contextRef], _nativeJSObj, NULL);
            id o = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, resultStringJS));
            JSStringRelease(resultStringJS);
            _cValue.type = _C_SEL;
            _cValue.value.selectorValue = NSSelectorFromString(o);
            return YES;
        }
        
        FMAssert(NO);
        return NO;
        
    }
    
    [self setInstance:(__bridge CFTypeRef)([FJSValue nativeObjectFromJSValue:_nativeJSObj ofType:type inJSContext:[_runtime contextRef]])];
    
    return [self instance] != nil;
}

+ (id)nativeObjectFromJSValue:(JSValueRef)jsValue ofType:(NSString*)typeEncoding inJSContext:(JSContextRef)context {
    
    if ([typeEncoding isEqualToString:@"@"]) {
        
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
        
        
        if (JSValueIsObject(context, jsValue)) {
            
            JSStringRef resultStringJS = JSValueToStringCopy(context, jsValue, NULL);
            id o = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, resultStringJS));
            JSStringRelease(resultStringJS);
            return [NSString stringWithFormat:@"%@ (native js object)", o];
        }
        
        JSType type = JSValueGetType(context, jsValue);
        debug(@"What am I supposed to do with %d?", type);
        
        
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
        long long v = JSValueToNumber(context, jsValue, NULL);
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
        
        id f = [self nativeObjectFromJSValue:jsValue ofType:@"@" inJSContext:context];
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
    
    debug(@"Not sure what to do with type encoding '%@'", typeEncoding);
    
    assert(NO);
    
    return nil;
}

+ (JSValueRef)nativeObjectToJSValue:(id)o inJSContext:(JSContextRef)context {
    
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

+ (BOOL)getAlignment:(size_t *)alignmentPtr ofTypeEncoding:(char)encoding {
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

+ (BOOL)getSize:(size_t *)sizePtr ofTypeEncoding:(char)encoding {
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

+ (ffi_type *)ffiTypeForTypeEncoding:(char)encoding {
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

+ (NSString *)descriptionOfTypeEncoding:(char)encoding {
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

+ (NSString *)descriptionOfTypeEncoding:(char)typeEncoding fullTypeEncoding:(NSString *)fullTypeEncoding {
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
            FMAssert(NO);
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




@end



