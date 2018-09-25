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
    
    if ([self isInstance] && _cValue.value.pointerValue && ![[[self symbol] symbolType] isEqualToString:@"constant"]) {
        
        id obj = (__bridge id)(_cValue.value.pointerValue);
        if ([obj isKindOfClass:[NSData class]]) {
            obj = [NSString stringWithFormat:@"%@ of %ld bytes", NSStringFromClass([obj class]), [(NSData*)obj length]];
        }
        
        debug(@"FJSValue dealloc releasing %@", obj);
        CFRelease(_cValue.value.pointerValue);
    }
    
#ifdef DEBUG
    if ([self isInstance] && !_weakInstance && !_isWeakReference && !_cValue.value.pointerValue && !_isJSNative) {
        debug(@"Why am I an instance without anything to point to?! %p", self);
        FMAssert(NO);
    }
#endif
    
}

+ (instancetype)valueWithNullInRuntime:(FJSRuntime*)runtime {
    return [self valueForJSObject:(JSObjectRef)JSValueMakeNull([runtime contextRef]) inRuntime:runtime];
}

+ (instancetype)valueWithUndefinedInRuntime:(FJSRuntime*)runtime {
    return [self valueForJSObject:(JSObjectRef)JSValueMakeUndefined([runtime contextRef]) inRuntime:runtime];
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

+ (instancetype)valueWithConstantPointer:(void*)p ofType:(char)type inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    FJSValue *cw = [[self alloc] init];
    cw->_cValue.type = type;
    cw->_cValue.value.pointerValue = p;
    
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

+ (instancetype)valueWithCValue:(FJSObjCValue)cvalue inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    FJSValue *cw = [[self alloc] init];
    [cw setCValue:cvalue];
    
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
    
#ifdef DEBUG
    if (_weakInstance || _cValue.value.pointerValue) {
        FMAssert([self isInstance] || [self isClass]);
    }
#endif
    
    if (_weakInstance) {
        return _weakInstance;
    }
    
    return (__bridge id)_cValue.value.pointerValue;
}

- (Class)rtClass {
    return (__bridge Class)_cValue.value.pointerValue;
}

- (void)setInstance:(nullable CFTypeRef)o {
    FMAssert(!_weakInstance);
    FMAssert(!_cValue.value.pointerValue);
    //debug(@"FJSValue retaining %@ currently at %ld", o, CFGetRetainCount(o));
    
    if (o) { // If a null or underfined jsvalue is pushed to native- well, we get here.
        CFRetain(o);
    }
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
        
        vr = FJSNativeObjectToJSValue([self instance], [_runtime contextRef]);
        
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


- (NSString*)description {
    
    NSString *obj = [self toObject];
    if ([obj isKindOfClass:[NSData class]]) {
        obj = [NSString stringWithFormat:@"%@ of %ld bytes", NSStringFromClass([obj class]), [(NSData*)obj length]];
    }
    
    return [NSString stringWithFormat:@"%@ - %@ (%@ native)", [super description], obj, _isJSNative ? @"js" : @"c"];
}

#pragma message "FIXME: Should FFIType move to FJSSymbol?"

- (ffi_type*)FFIType {
    return [self FFITypeWithHint:nil];
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
        
        char type = _cValue.type;
        
        if (!type) {
            FMAssert(_jsValueType);
            FMAssert(_nativeJSObj);
            
            switch (_jsValueType) {
                case kJSTypeUndefined:
                case kJSTypeNull:
                    type = _C_UNDEF;
                    break;
                    
                case kJSTypeBoolean:
                    type = _C_BOOL;
                    break;
                    
                case kJSTypeNumber:
                    type = _C_DBL;
                    break;
                    
                case kJSTypeString:
                case kJSTypeObject:
                    type = _C_ID;
                    break;
                    
                default:
                    FMAssert(NO);
                    break;
            }
        }
        
        return FJSNativeObjectFromJSValue(_nativeJSObj, [NSString stringWithFormat:@"%c", type], [_runtime contextRef]);
    }
    
    if ([self isInstance]) {
        return [self instance];
    }
    
    if (_cValue.value.pointerValue) {
        debug(@"Haven't implemented toObject for %c yet", _cValue.type);
        return nil;
    }
    
    FMAssert(_symbol); // Why else would we be here?
    
    return nil;
}

- (BOOL)pushJSValueToNativeType:(NSString*)type {
    
    if ([type isEqualToString:@"B"]) {
        _cValue.type = _C_BOOL;
        _cValue.value.boolValue = [FJSNativeObjectFromJSValue(_nativeJSObj, type, [_runtime contextRef]) boolValue];
        return YES;
    }
    
    if ([type isEqualToString:@"s"]) {
        _cValue.type = _C_SHT;
        _cValue.value.shortValue = [FJSNativeObjectFromJSValue(_nativeJSObj, type, [_runtime contextRef]) shortValue];
        return YES;
    }
    
    if ([type isEqualToString:@"S"]) {
        _cValue.type = _C_USHT;
        _cValue.value.ushortValue = [FJSNativeObjectFromJSValue(_nativeJSObj, type, [_runtime contextRef]) unsignedShortValue];
        return YES;
    }
    
    if ([type isEqualToString:@"c"]) {
        _cValue.type = _C_CHR;
        _cValue.value.charValue = [FJSNativeObjectFromJSValue(_nativeJSObj, type, [_runtime contextRef]) charValue];
        return YES;
    }
    
    if ([type isEqualToString:@"C"]) {
        _cValue.type = _C_UCHR;
        _cValue.value.ucharValue = [FJSNativeObjectFromJSValue(_nativeJSObj, type, [_runtime contextRef]) unsignedCharValue];
        return YES;
    }
    
    if ([type isEqualToString:@"i"]) {
        _cValue.type = _C_INT;
        _cValue.value.intValue = [FJSNativeObjectFromJSValue(_nativeJSObj, type, [_runtime contextRef]) intValue];
        return YES;
    }
    
    if ([type isEqualToString:@"I"]) {
        _cValue.type = _C_UINT;
        _cValue.value.uintValue = [FJSNativeObjectFromJSValue(_nativeJSObj, type, [_runtime contextRef]) unsignedIntValue];
        return YES;
    }
    
    if ([type isEqualToString:@"l"]) {
        _cValue.type = _C_LNG;
        _cValue.value.longValue = [FJSNativeObjectFromJSValue(_nativeJSObj, type, [_runtime contextRef]) longValue];
        return YES;
    }
    
    if ([type isEqualToString:@"L"]) {
        _cValue.type = _C_ULNG;
        _cValue.value.unsignedLongValue = [FJSNativeObjectFromJSValue(_nativeJSObj, type, [_runtime contextRef]) unsignedLongValue];
        return YES;
    }
    
    if ([type isEqualToString:@"q"]) {
        _cValue.type = _C_LNG_LNG;
        _cValue.value.longLongValue = [FJSNativeObjectFromJSValue(_nativeJSObj, type, [_runtime contextRef]) longLongValue];
        return YES;
    }
    
    if ([type isEqualToString:@"Q"]) {
        _cValue.type = _C_ULNG_LNG;
        _cValue.value.unsignedLongLongValue = [FJSNativeObjectFromJSValue(_nativeJSObj, type, [_runtime contextRef]) unsignedLongLongValue];
        return YES;
    }
    
    if ([type isEqualToString:@"f"]) {
        _cValue.type = _C_FLT;
        _cValue.value.floatValue = [FJSNativeObjectFromJSValue(_nativeJSObj, type, [_runtime contextRef]) floatValue];
        return YES;
    }
    
    if ([type isEqualToString:@"d"]) {
        _cValue.type = _C_DBL;
        _cValue.value.doubleValue = [FJSNativeObjectFromJSValue(_nativeJSObj, type, [_runtime contextRef]) doubleValue];
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
    
    [self setInstance:(__bridge CFTypeRef)(FJSNativeObjectFromJSValue(_nativeJSObj, type, [_runtime contextRef]))];
    
    return [self instance] != nil;
}

- (BOOL)toBOOL {
    
    if (_isJSNative) {
        
        if (JSValueIsBoolean([_runtime contextRef], _nativeJSObj)) {
            return JSValueToBoolean([_runtime contextRef], _nativeJSObj);
        }
        
        return [FJSNativeObjectFromJSValue(_nativeJSObj, @"B", [_runtime contextRef]) boolValue];
    }
    
    return _cValue.value.boolValue;
}

- (double)toDouble {
    
    if (_isJSNative) {
        return [FJSNativeObjectFromJSValue(_nativeJSObj, @"d", [_runtime contextRef]) doubleValue];
    }
    
    FMAssert(_cValue.type);
    return _cValue.value.doubleValue;
}

- (long long)toLongLong {
    if (_isJSNative) {
        return [FJSNativeObjectFromJSValue(_nativeJSObj, @"q", [_runtime contextRef]) longLongValue];
    }
    
    FMAssert(_cValue.type);
    return _cValue.value.longLongValue;
}

- (long)toLong {
    return [self toLongLong];
}

- (float)toFloat {
    return [self toDouble];
}

- (nullable void*)pointer {
    FMAssert(_cValue.type);
    return _cValue.value.pointerValue;
}


@end



