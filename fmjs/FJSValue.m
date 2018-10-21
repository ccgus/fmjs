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
#import "FJSSymbol.h"

#import <objc/runtime.h>

@interface FJSValue ()

@property (weak) FJSRuntime *runtime;
@property (assign) JSValueRef nativeJSValue;

@property (weak) id weakInstance;
@property (assign) BOOL madePointerMemory;

@property (assign) BOOL isWeakReference;

@end

// This is used for the unit tests.
static size_t FJSValueLiveInstances = 0;
static NSPointerArray *FJSValueLiveWeakArray;

@implementation FJSValue

- (instancetype)init {
    self = [super init];
    if (self) {
        FJSValueLiveInstances++;
        
#ifdef DEBUG
        if (!FJSValueLiveWeakArray) {
            FJSValueLiveWeakArray = [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsWeakMemory];
        }
        [FJSValueLiveWeakArray addPointer:(__bridge void * _Nullable)(self)];
#endif
        
    }
    return self;
}

- (void)dealloc {
    
    FJSValueLiveInstances--;
    
    if (([self isInstance] || [self isBlock]) && _cValue.value.pointerValue && ![[[self symbol] symbolType] isEqualToString:@"constant"]) {
        
        id obj = (__bridge id)(_cValue.value.pointerValue);
        if ([obj isKindOfClass:[NSData class]]) {
            obj = [NSString stringWithFormat:@"%@ of %ld bytes", NSStringFromClass([obj class]), [(NSData*)obj length]];
        }
        
        CFRelease(_cValue.value.pointerValue);
    }
    
    if (_madePointerMemory) {
        FMAssert(_cValue.type == _C_STRUCT_B);
        free(_cValue.value.pointerValue);
    }
    
#ifdef DEBUG
    if (([self isInstance] || [self isBlock]) && !_weakInstance && !_isWeakReference && !_cValue.value.pointerValue && !_isJSNative) {
        debug(@"Why am I an instance without anything to point to?! %p", self);
        FMAssert(NO);
    }
#endif
    
}

+ (size_t)countOfLiveInstances { // This is used in unit testing.
    return FJSValueLiveInstances;
}

+ (NSPointerArray*)liveInstancesPointerArray {
    [FJSValueLiveWeakArray compact];
    return FJSValueLiveWeakArray;
}

+ (instancetype)valueWithNullInRuntime:(FJSRuntime*)runtime {
    return [self valueForJSValue:(JSObjectRef)JSValueMakeNull([runtime contextRef]) inRuntime:runtime];
}

+ (instancetype)valueWithUndefinedInRuntime:(FJSRuntime*)runtime {
    return [self valueForJSValue:(JSObjectRef)JSValueMakeUndefined([runtime contextRef]) inRuntime:runtime];
}

+ (instancetype)valueForJSValue:(nullable JSValueRef)jsValue inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    if (!jsValue) {
        return nil;
    }
    
    BOOL isObject = JSValueIsObject([runtime contextRef], jsValue);
    
    if (isObject) {
        FJSValue *wr = (__bridge FJSValue *)(JSObjectGetPrivate(JSValueToObject([runtime contextRef], jsValue, nil)));
        if (wr) {
            return wr;
        }
    }
    
    FJSValue *native = [FJSValue new];
    [native setNativeJSValue:jsValue];
    [native setIsJSNative:YES];
    [native setRuntime:runtime];
    [native setJsValueType:JSValueGetType([runtime contextRef], jsValue)];
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
    // In theory, we're going to do something special with consts in the future.
    return [self valueWithPointer:p ofType:type inRuntime:runtime];
}

+ (instancetype)valueWithPointer:(void*)p ofType:(char)type inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    FJSValue *cw = [[self alloc] init];
    cw->_cValue.type = type;
    cw->_cValue.value.pointerValue = p;
    
    [cw setRuntime:runtime];
    
    return cw;
}

+ (instancetype)valueWithBlock:(CFTypeRef)block inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    FJSValue *cw = [[self alloc] init];
    
    [cw setBlock:block];
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

- (BOOL)isBlock {
    return _cValue.type == _FJSC_BLOCK;
}

- (BOOL)isStruct {
    return _cValue.type == _C_STRUCT_B;
}

- (id)instance {
    
#ifdef DEBUG
    if (_weakInstance || _cValue.value.pointerValue) {
        FMAssert([self isInstance] || [self isClass] || [self isBlock]);
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

- (void)setBlock:(nullable CFTypeRef)block {
    FMAssert(!_weakInstance);
    FMAssert(!_cValue.value.pointerValue);
    
    
    if (block) { // If a null or underfined jsvalue is pushed to native- well, we get here.
        id copyBlock = [(__bridge id)block copy];
        block = (__bridge CFTypeRef _Nullable)(copyBlock);
        CFRetain(block);
    }
    
    _cValue.type = _FJSC_BLOCK;
    _cValue.value.pointerValue = (void*)block;
}

- (void)setInstance:(nullable CFTypeRef)o {
    FMAssert(!_weakInstance);
    FMAssert(!_cValue.value.pointerValue);
    
    if (o) { // If a null or underfined jsvalue is pushed to native- well, we get here.
        //debug(@"FJSValue retaining %@ currently at %ld", o, CFGetRetainCount(o));
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
    
    if (_nativeJSValue) {
        return _nativeJSValue;
    }
    
    JSValueRef vr = nil;
    
    if ([self isInstance] || [self isBlock]) {
        
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
        
        case _C_CLASS:
        case _C_STRUCT_B: {
            vr = [_runtime newJSValueForWrapper:self];
            break;
        }
            
        case _C_VOID:
            vr = JSValueMakeUndefined([_runtime contextRef]);
            break;
        default:
            FMAssert(NO);
    
    }
    
    
    if (!vr) {
        debug(@"Returning nil JSValue for %@", self);
    }
    
    return vr;
}

- (void*)objectStorage {
    
    if (_cValue.type == _C_STRUCT_B) {
        
//        if (_cValue.value.pointerValue) {
//
//            FMAssert([[[self symbol] symbolType] isEqualToString:@"constant"]);
//            return _cValue.value.pointerValue;
//        }
        
        if (!_cValue.value.pointerValue) {
            #pragma message "FIXME: refactor out how we get the size of the struct somehow.There's too many lines below to pull it out."
            
            FJSSymbol *structSym = [self symbol];
            NSString *name = [structSym structName];
            FJSSymbol *structInfoSym = [FJSSymbol symbolForName:name];
            size_t size = [structInfoSym structSize];
            FMAssert(size);
            
            _cValue.value.pointerValue = calloc(1, size);
            _madePointerMemory = YES;
        }
        else {
            
        }
        
        return _cValue.value.pointerValue;
    }
    
    FMAssert(_cValue.type);
    return  &_cValue.value;
}


- (NSString*)description {
    
    NSString *obj = [self toObject];
    if ([obj isKindOfClass:[NSData class]]) {
        obj = [NSString stringWithFormat:@"%@ of %ld bytes", NSStringFromClass([obj class]), [(NSData*)obj length]];
    }
    
    if ([obj isKindOfClass:[NSValue class]]) {
        
        if ([[_symbol runtimeType] hasPrefix:@"{CGRect={CGPoint=dd}{CGSize=dd}}"]) {
            obj = [NSString stringWithFormat:@"nsvalue type rect '%c' %p (%@)", _cValue.type, [(NSValue*)obj pointerValue], NSStringFromRect([self toCGRect])];
        }
        else {
            obj = [NSString stringWithFormat:@"nsvalue type '%c' %p", _cValue.type, [(NSValue*)obj pointerValue]];
        }
    }
    
    return [NSString stringWithFormat:@"%@ - %@ (%@ native)", [super description], obj, _isJSNative ? @"js" : @"c"];
}

- (BOOL)setValue:(FJSValue*)value onStructFieldNamed:(NSString*)structFieldName {
    
#pragma message "FIXME: Need more tests for the setValue:onStructFieldNamed: types."
    FMAssert(_cValue.type == _C_STRUCT_B);
    
    FJSSymbol *structSym = [self symbol];
    FMAssert(structSym);
    
    NSString *name = [structSym structName];
    FMAssert(name);
    
    FJSSymbol *structInfoSym = [FJSSymbol symbolForName:name];
    FMAssert(structInfoSym);
    
    FJSStructSymbol *structFieldSym = [structInfoSym structFieldNamed:structFieldName];
    FMAssert(structFieldSym);
    
    
    
    FJSStructSymbol *foundType = nil;
    size_t offset = 0;
    
    for (FJSStructSymbol *ss in [structInfoSym structFields]) {
        if ([[ss name] isEqualToString:structFieldName]) {
            foundType = ss;
            break;
        }
        offset += [ss size];
    }
    
    void *loc = _cValue.value.pointerValue + offset;
    
    switch ([foundType type]) {
        case _C_DBL: {
            double d = [value toDouble];
            memcpy(loc, &d, sizeof(d));
            return YES;
        }
            break;
            /*
        case _C_FLT:
            cv.value.floatValue = *((float *)loc);
            break;
            
        case _C_INT:
            cv.value.intValue = *((int *)loc);
            break;
            
        case _C_UINT:
            cv.value.uintValue = *((unsigned int *)loc);
            break;
            
        case _C_LNG:
            cv.value.longValue = *((long *)loc);
            break;
            */
        case _C_ULNG: {
            unsigned long l = [value toLongLong];
            memcpy(loc, &l, sizeof(l));
            return YES;
        }
            break;
            /*
        case _C_LNG_LNG:
            cv.value.longLongValue = *((long long *)loc);
            break;
            */
        case _C_ULNG_LNG: {
            unsigned long long l = [value toLongLong];
            memcpy(loc, &l, sizeof(l));
            return YES;
        }
            break;
            
        case _C_STRUCT_B: {
            FMAssert(_madePointerMemory);
            FMAssert([self structSize] >= [value structSize]);
            memcpy(loc, [value structLocation], [self structSize]);
        }
            break;
        
        default:
            FMAssert(NO);
            break;
    }
    
    
    
    return NO;
}

- (size_t)structSize {
    FMAssert(_cValue.type == _C_STRUCT_B);
    
    size_t size = 0;
    FJSSymbol *structSym = [self symbol];
    NSString *name = [structSym structName];
    FJSSymbol *structInfoSym = [FJSSymbol symbolForName:name];
    for (FJSStructSymbol *ss in [structInfoSym structFields]) {
        size += [ss size];
    }
    
    FMAssert(size);
    
    return size;
}

- (FJSValue*)valueFromStructFieldNamed:(NSString*)structFieldName {
    
    FMAssert(_cValue.type == _C_STRUCT_B);

    FJSSymbol *structSym = [self symbol];
    FMAssert(structSym);

    NSString *name = [structSym structName];
    FMAssert(name);
    
    FJSSymbol *structInfoSym = [FJSSymbol symbolForName:name];
    FMAssert(structInfoSym);

    FJSStructSymbol *structFieldSym = [structInfoSym structFieldNamed:structFieldName];
    FMAssert(structFieldSym);

    
    
    FJSStructSymbol *foundType = nil;
    size_t offset = 0;
    
    for (FJSStructSymbol *ss in [structInfoSym structFields]) {
        if ([[ss name] isEqualToString:structFieldName]) {
            foundType = ss;
            break;
        }
        offset += [ss size];
    }
    
    void *loc = _cValue.value.pointerValue + offset;
    
    FJSObjCValue cv;
    cv.type = [foundType type];
    switch (cv.type) {
        case _C_DBL:
            cv.value.doubleValue = *((double *)loc);
            break;
            
        case _C_FLT:
            cv.value.floatValue = *((float *)loc);
            break;
            
        case _C_INT:
            cv.value.intValue = *((int *)loc);
            break;
            
        case _C_UINT:
            cv.value.uintValue = *((unsigned int *)loc);
            break;
            
        case _C_LNG:
            cv.value.longValue = *((long *)loc);
            break;
            
        case _C_ULNG:
            cv.value.unsignedLongValue = *((unsigned long *)loc);
            break;
            
        case _C_LNG_LNG:
            cv.value.longLongValue = *((long long *)loc);
            break;
            
        case _C_ULNG_LNG:
            cv.value.unsignedLongLongValue = *((unsigned long long *)loc);
            break;
        
        case _C_STRUCT_B: {
            // Whoa cool. We found a struct in a struct. CGRect maybe?
            cv.value.pointerValue = loc;
        }
            break;
            
        default:
            FMAssert(NO);
            break;
    }
    
    
    FJSValue *v = [FJSValue valueWithCValue:cv inRuntime:_runtime];
    
    if ([foundType structName]) {
        FJSSymbol *subStructSymbol = [FJSSymbol symbolForName:[foundType structName]];
        FMAssert(subStructSymbol);
        [v setSymbol:subStructSymbol];
        
    }
    
    return v;
}





- (ffi_type*)FFIType {
    return [self FFITypeWithHint:nil];
}

- (ffi_type*)FFITypeWithHint:(nullable NSString*)typeEncoding {
    
    if (_symbol) {
        
        char c = [[_symbol runtimeType] characterAtIndex:0];
        
        if (c) {
            
            if (c == _C_STRUCT_B) {
                return [FJSFFI ffiTypeForStructure:[_symbol runtimeType]];
            }
            else {
                return [FJSFFI ffiTypeAddressForTypeEncoding:c];
            }
        }
    }
    
    if ([typeEncoding isEqualToString:@"@"]) {
        return &ffi_type_pointer;
    }
    
    if (_cValue.type == _C_ID || _cValue.type == _FJSC_BLOCK) {
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
            
            FMAssert(_nativeJSValue);
            
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
        
        return FJSNativeObjectFromJSValue(_nativeJSValue, [NSString stringWithFormat:@"%c", type], [_runtime contextRef]);
    }
    
    if ([self isInstance]) {
        return [self instance];
    }
    
    if ([self isClass]) {
        return [self rtClass];
    }
    
    if (_cValue.type == _C_STRUCT_B && _cValue.value.pointerValue) {
        NSValue *v = [NSValue value:&_cValue.value.pointerValue withObjCType:@encode(void *)];
        return v;
    }
    
    if (_cValue.type == _FJSC_BLOCK) {
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
        _cValue.value.boolValue = [FJSNativeObjectFromJSValue(_nativeJSValue, type, [_runtime contextRef]) boolValue];
        return YES;
    }
    
    if ([type isEqualToString:@"s"]) {
        _cValue.type = _C_SHT;
        _cValue.value.shortValue = [FJSNativeObjectFromJSValue(_nativeJSValue, type, [_runtime contextRef]) shortValue];
        return YES;
    }
    
    if ([type isEqualToString:@"S"]) {
        _cValue.type = _C_USHT;
        _cValue.value.ushortValue = [FJSNativeObjectFromJSValue(_nativeJSValue, type, [_runtime contextRef]) unsignedShortValue];
        return YES;
    }
    
    if ([type isEqualToString:@"c"]) {
        _cValue.type = _C_CHR;
        _cValue.value.charValue = [FJSNativeObjectFromJSValue(_nativeJSValue, type, [_runtime contextRef]) charValue];
        return YES;
    }
    
    if ([type isEqualToString:@"C"]) {
        _cValue.type = _C_UCHR;
        _cValue.value.ucharValue = [FJSNativeObjectFromJSValue(_nativeJSValue, type, [_runtime contextRef]) unsignedCharValue];
        return YES;
    }
    
    if ([type isEqualToString:@"i"]) {
        _cValue.type = _C_INT;
        _cValue.value.intValue = [FJSNativeObjectFromJSValue(_nativeJSValue, type, [_runtime contextRef]) intValue];
        return YES;
    }
    
    if ([type isEqualToString:@"I"]) {
        _cValue.type = _C_UINT;
        _cValue.value.uintValue = [FJSNativeObjectFromJSValue(_nativeJSValue, type, [_runtime contextRef]) unsignedIntValue];
        return YES;
    }
    
    if ([type isEqualToString:@"l"]) {
        _cValue.type = _C_LNG;
        _cValue.value.longValue = [FJSNativeObjectFromJSValue(_nativeJSValue, type, [_runtime contextRef]) longValue];
        return YES;
    }
    
    if ([type isEqualToString:@"L"]) {
        _cValue.type = _C_ULNG;
        _cValue.value.unsignedLongValue = [FJSNativeObjectFromJSValue(_nativeJSValue, type, [_runtime contextRef]) unsignedLongValue];
        return YES;
    }
    
    if ([type isEqualToString:@"q"]) {
        _cValue.type = _C_LNG_LNG;
        _cValue.value.longLongValue = [FJSNativeObjectFromJSValue(_nativeJSValue, type, [_runtime contextRef]) longLongValue];
        return YES;
    }
    
    if ([type isEqualToString:@"Q"]) {
        _cValue.type = _C_ULNG_LNG;
        _cValue.value.unsignedLongLongValue = [FJSNativeObjectFromJSValue(_nativeJSValue, type, [_runtime contextRef]) unsignedLongLongValue];
        return YES;
    }
    
    if ([type isEqualToString:@"f"]) {
        _cValue.type = _C_FLT;
        _cValue.value.floatValue = [FJSNativeObjectFromJSValue(_nativeJSValue, type, [_runtime contextRef]) floatValue];
        return YES;
    }
    
    if ([type isEqualToString:@"d"]) {
        _cValue.type = _C_DBL;
        _cValue.value.doubleValue = [FJSNativeObjectFromJSValue(_nativeJSValue, type, [_runtime contextRef]) doubleValue];
        return YES;
    }
    
    if ([type isEqualToString:@"v"]) {
        _cValue.type = _C_VOID;
        _cValue.value.pointerValue = nil;
        return YES;
    }
    
    
    if ([type isEqualToString:@":"]) {
        
        if (JSValueIsString([_runtime contextRef], _nativeJSValue)) {
            JSStringRef resultStringJS = JSValueToStringCopy([_runtime contextRef], _nativeJSValue, NULL);
            id o = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, resultStringJS));
            JSStringRelease(resultStringJS);
            _cValue.type = _C_SEL;
            _cValue.value.selectorValue = NSSelectorFromString(o);
            return YES;
        }
        
        FMAssert(NO);
        return NO;
        
    }
    
    [self setInstance:(__bridge CFTypeRef)(FJSNativeObjectFromJSValue(_nativeJSValue, type, [_runtime contextRef]))];
    
    return [self instance] != nil;
}

- (BOOL)toBOOL {
    
    if (_isJSNative) {
        
        if (JSValueIsBoolean([_runtime contextRef], _nativeJSValue)) {
            return JSValueToBoolean([_runtime contextRef], _nativeJSValue);
        }
        
        return [FJSNativeObjectFromJSValue(_nativeJSValue, @"B", [_runtime contextRef]) boolValue];
    }
    
    
    if ([self isInstance] && [[self instance] respondsToSelector:@selector(boolValue)]) {
        return [[self instance] boolValue];
    }
    
    return _cValue.value.boolValue;
}

- (double)toDouble {
    
    if (_isJSNative) {
        return [FJSNativeObjectFromJSValue(_nativeJSValue, @"d", [_runtime contextRef]) doubleValue];
    }
    
    if ([self isInstance] && [[self instance] respondsToSelector:@selector(doubleValue)]) {
        return [[self instance] doubleValue];
    }
    
    if (_cValue.type == _C_PTR) {
        // We're probably pointing to a struct.
        double *d = _cValue.value.pointerValue;
        return *d;
    }
    
    FMAssert(_cValue.type == _C_DBL);
    return _cValue.value.doubleValue;
}

- (long long)toLongLong {
    if (_isJSNative) {
        return [FJSNativeObjectFromJSValue(_nativeJSValue, @"q", [_runtime contextRef]) longLongValue];
    }
    
    if ([self isInstance] && [[self instance] respondsToSelector:@selector(longLongValue)]) {
        return [[self instance] longLongValue];
    }
    
    FMAssert(_cValue.type);
    return _cValue.value.longLongValue;
}

- (long)toLong {
    
    
    if ([self isInstance] && [[self instance] respondsToSelector:@selector(longValue)]) {
        return [[self instance] longValue];
    }
    
    return [self toLongLong];
}

- (int)toInt {
    
    if ([self isInstance] && [[self instance] respondsToSelector:@selector(intValue)]) {
        return [[self instance] intValue];
    }
    
    return (int)[self toLongLong];
}

- (float)toFloat {
    
    if ([self isInstance] && [[self instance] respondsToSelector:@selector(floatValue)]) {
        return [[self instance] floatValue];
    }
    
    return [self toDouble];
}

- (nullable void*)pointer {
    FMAssert(_cValue.type);
    return _cValue.value.pointerValue;
}

- (CGPoint)toCGPoint {
    FMAssert(_cValue.type == _C_STRUCT_B);
    CGPoint *point = (CGPoint*)_cValue.value.pointerValue;
    return *point;
}

- (CGSize)toCGSize {
    FMAssert(_cValue.type == _C_STRUCT_B);
    CGSize size = *((CGSize*)_cValue.value.pointerValue);
    return size;
}

- (CGRect)toCGRect {
    FMAssert(_cValue.type == _C_STRUCT_B);
    CGRect *rect = (CGRect*)_cValue.value.pointerValue;
    return *rect;
}

- (nullable void*)structLocation {
    FMAssert(_cValue.type == _C_STRUCT_B);
    return _cValue.value.pointerValue;
}

@end



