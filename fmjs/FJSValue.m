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
#import "FJSPrivate.h"

#import <objc/runtime.h>

@interface FJSValue ()

@property (weak) FJSRuntime *runtime;
@property (assign) JSValueRef jsValRef;
@property (assign) JSGlobalContextRef unprotectContextRef;
@property (assign) FJSObjCValue cValue;
@property (assign) JSType jsValueType;
@property (assign) BOOL debugFinalizeCalled;

#ifndef DEBUG
@property (assign) NSInteger protectCount; // Why our own protectCount? Because we've also got a unprotectContextRef to manage.
#endif

@property (weak) id weakInstance;
@property (assign) BOOL madePointerMemory;
@property (assign) size_t madePointerMemorySize;

@property (assign) BOOL isWeakReference;

@end

// This is used for the unit tests.
static size_t FJSValueLiveInstances = 0;
static NSPointerArray *FJSValueLiveWeakArray;
static BOOL FJSCaptureJSValueInstancesForDebugging;

@implementation FJSValue

- (instancetype)init {
    self = [super init];
    if (self) {
        FJSValueLiveInstances++;
        
        if (FJSCaptureJSValueInstancesForDebugging) {
            if (!FJSValueLiveWeakArray) {
                FJSValueLiveWeakArray = [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsWeakMemory];
            }
            [FJSValueLiveWeakArray addPointer:(__bridge void * _Nullable)(self)];
            
            _debugStackFromInit = [[NSThread callStackSymbols] description];
        }
    }
    return self;
}

- (void)dealloc {
    
    FJSValueLiveInstances--;
    
    if (([self isInstance] || [self isBlock]) && _cValue.value.pointerValue && ![[[self symbol] symbolType] isEqualToString:@"constant"]) {
#ifdef FJSAssociateValuesForEquality
        FMAssert(_runtime);
        //FJSTrace(@"Removing associated object (%@) from %@", (_cValue.value.pointerValue), self);
        objc_setAssociatedObject((__bridge id _Nonnull)(_cValue.value.pointerValue), (__bridge const void * _Nonnull)_runtime, nil, OBJC_ASSOCIATION_ASSIGN);
#endif

#ifdef FJSMapValuesForEquality
        
        // We don't need to do this really, since the pointers are weak… but we'll do it anyway to make it happen faster I guess?
        [[_runtime instanceMapTable] removeObjectForKey:self];
#endif
        
        //debug(@"FJSValue releasing %@ currently at %ld", (_cValue.value.pointerValue), CFGetRetainCount((_cValue.value.pointerValue)));

        FMAssert(![self isClass]);
        
        // FIXME: Gus write a test for this.
        if ([(__bridge id _Nonnull)(_cValue.value.pointerValue) isKindOfClass:[FJSValue class]]) {
            debug(@"%p NOPE", (__bridge void *)self);
        }
        else {
            
            CFRelease(_cValue.value.pointerValue);
        }
    }
    
    if (_unprotectContextRef) {
        FMAssert(_jsValRef);
        JSValueUnprotect(_unprotectContextRef, _jsValRef);
        JSGlobalContextRelease(_unprotectContextRef);
        _unprotectContextRef = nil;
    }
    
    if (_madePointerMemory) {
        FMAssert(_cValue.type == _C_STRUCT_B);
        free(_cValue.value.pointerValue);
    }
    
#ifdef DEBUG
    if (([self isInstance] || [self isBlock]) && !_weakInstance && !_isWeakReference && !_cValue.value.pointerValue && !_isJSNative) {
        debug(@"Why am I an instance without anything to point to?! %@", [super description]);
        debug(@"debugStackFromInit: '%@'", _debugStackFromInit);
        FMAssert(NO);
    }
#endif
    
}

+ (void)setCaptureJSValueInstancesForDebugging:(BOOL)b {
    FJSCaptureJSValueInstancesForDebugging = b;
}

+ (BOOL)captureJSValueInstancesForDebugging {
    return FJSCaptureJSValueInstancesForDebugging;
}



+ (size_t)countOfLiveInstances { // This is used in unit testing.
    return FJSValueLiveInstances;
}

+ (NSPointerArray*)liveInstancesPointerArray {
    [FJSValueLiveWeakArray compact];
    return FJSValueLiveWeakArray;
}

+ (instancetype)valueWithNewObjectInRuntime:(FJSRuntime*)runtime {
    return [self valueWithJSValueRef:JSObjectMake([runtime contextRef], nil, nil) inRuntime:runtime];
}

+ (instancetype)valueWithString:(NSString*)stringToConvertToJSString inRuntime:(FJSRuntime*)runtime {
    
    JSStringRef string = JSStringCreateWithCFString((__bridge CFStringRef)stringToConvertToJSString);
    JSValueRef value = JSValueMakeString([runtime contextRef], string);
    JSStringRelease(string);
    
    return [self valueWithJSValueRef:value inRuntime:runtime];
}

+ (instancetype)valueWithNullInRuntime:(FJSRuntime*)runtime {
    return [self valueWithJSValueRef:(JSObjectRef)JSValueMakeNull([runtime contextRef]) inRuntime:runtime];
}

+ (instancetype)valueWithUndefinedInRuntime:(FJSRuntime*)runtime {
    return [self valueWithJSValueRef:(JSObjectRef)JSValueMakeUndefined([runtime contextRef]) inRuntime:runtime];
}

+ (nullable instancetype)valueWithJSValueRef:(nullable JSValueRef)jsValue inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    if (!jsValue) {
        return nil;
    }
    
    BOOL isObject = JSValueIsObject([runtime contextRef], jsValue);
    
    if (isObject) {
        FJSValue *nativeCValue = (__bridge FJSValue *)(JSObjectGetPrivate(JSValueToObject([runtime contextRef], jsValue, nil)));
        if (nativeCValue) {
            return nativeCValue;
        }
    }
    
    FJSValue *nativeJSValue = [FJSValue new];
    [nativeJSValue setJsValRef:jsValue];
    [nativeJSValue setIsJSNative:YES];
    [nativeJSValue setRuntime:runtime];
    [nativeJSValue setJsValueType:JSValueGetType([runtime contextRef], jsValue)];
    return nativeJSValue;
}

+ (instancetype)valueWithSymbol:(FJSSymbol*)sym inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    FJSValue *value = [[self alloc] init];
    [value setSymbol:sym];
    [value setRuntime:runtime];
    
    if ([[sym symbolType] isEqualToString:@"retval"]) {
        value->_cValue.type = [[sym runtimeType] UTF8String][0];
    }
    
    return value;
}

+ (instancetype)valueWithClass:(Class)c inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    FJSValue *value = [[self alloc] init];
    [value setClass:c];
    [value setRuntime:runtime];
    
    return value;
}

+ (instancetype)valueWithConstantPointer:(void*)p withSymbol:(FJSSymbol*)sym inRuntime:(FJSRuntime*)runtime {
    // In theory, we're going to do something special with consts in the future.
    
    FJSValue *value = [[self alloc] init];
    [value setRuntime:runtime];
    
    [value setSymbol:sym];
    
    
    char type = [[sym runtimeType] characterAtIndex:0];
    value->_cValue.type = type;
    
    if (type == _C_PTR) {
        value->_cValue.value.pointerValue = (*(void**)p);
    }
    else {
        size_t copySize = 0;
    
        if (type == _C_STRUCT_B) {
            [value objectStorage]; // Prime up the struct memory location
            copySize = [value madePointerMemorySize];
            FMAssert(copySize);
        }
        else if (!FJSGetSizeOfTypeEncoding(&copySize, type)) {
            printf("Couldn't get size of type encoding: '%c'\n", type);
            FMAssert(NO);
            return nil;
        }
        
        FMAssert(copySize);
        memcpy([value objectStorage], p, copySize);
    }
    
    // https://developer.apple.com/documentation/code_diagnostics/undefined_behavior_sanitizer/misaligned_pointer?language=objc
    
    return value;
}

+ (instancetype)valueWithPointer:(void*)p ofType:(char)type inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    FJSValue *value = [[self alloc] init];
    value->_cValue.type = type;
    value->_cValue.value.pointerValue = p;
    
    [value setRuntime:runtime];
    
    return value;
}

+ (instancetype)valueWithBlock:(CFTypeRef)block inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    FJSValue *value = [[self alloc] init];
    
    [value setBlock:block];
    [value setRuntime:runtime];
    
    return value;
}


#ifdef FJSAssociateValuesForEquality
// see testSharedInstanceEquality for why we are doign this.
+ (instancetype)associatedValueInInstance:(CFTypeRef)instance inRuntime:(FJSRuntime*)runtime {

    id v = objc_getAssociatedObject((__bridge id)instance, (__bridge const void * _Nonnull)runtime);
    if (v) {
        return v;
    }

    return nil;
}
#endif


+ (instancetype)valueWithInstance:(CFTypeRef)instance inRuntime:(FJSRuntime*)runtime {
    
    // Don't check for NSNull class - because it's still and object and we need it to return an object?
    // I really need to write some docs on how this is handled.
    //  || [(__bridge id)instance isKindOfClass:[NSNull class]]
    if (!instance) {
        return [self valueWithNullInRuntime:runtime];
    }

#ifdef FJSAssociateValuesForEquality
    
    FJSValue *associated = [self associatedValueInInstance:instance inRuntime:runtime];
    if (associated) {
        FJSTrace(@"Found for associated value in %@", instance);
        return associated;
    }
#endif
    
#ifdef FJSMapValuesForEquality
    FJSValue *associated = [[runtime instanceMapTable] objectForKey:(__bridge id _Nullable)(instance)];
    if (associated) {
        return associated;
    }
#endif
    
    if (FJSInstanceIsBlock((__bridge id)instance)) {
        return [self valueWithBlock:instance inRuntime:runtime];
    }
    
    FMAssert(runtime);
    FJSValue *value = [[self alloc] init];
    
    if ([(__bridge id _Nullable)instance class] == instance) {
        debug(@"Whooops - using instance instead of a class? (%p)", (__bridge void *)value);
        FMAssert(NO);
        [value setClass:(__bridge Class _Nonnull)(instance)];
    }
    else {
        [value setInstance:instance];
    }
    
    
    [value setRuntime:runtime];

#ifdef FJSAssociateValuesForEquality
    FJSTrace(@"Setting associated value for %@", instance);
    objc_setAssociatedObject((__bridge id _Nonnull)(instance), (__bridge const void * _Nonnull)runtime, (value), OBJC_ASSOCIATION_ASSIGN);
#endif
    
#ifdef FJSMapValuesForEquality
    [[runtime instanceMapTable] setObject:value forKey:(__bridge id _Nonnull)instance];
#endif
    
    
    return value;
}

+ (instancetype)valueWithWeakInstance:(id)instance inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    FJSValue *value = [[self alloc] init];
    [value setWeakInstance:instance];
    [value setIsWeakReference:YES];
    
    value->_cValue.type = _C_ID;
    
    [value setRuntime:runtime];
    
    return value;
}

+ (instancetype)valueWithCValue:(FJSObjCValue)cvalue inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    FJSValue *value = [[self alloc] init];
    [value setCValue:cvalue];
    
    [value setRuntime:runtime];
    //debug(@"weak value: %p", cw);
    
    return value;
}

+ (nullable instancetype)valueWithSerializedJSFunction:(NSString*)function inRuntime:(FJSRuntime*)runtime {
    FMAssert(runtime);
    
    function = [NSString stringWithFormat:@"(%@)()", function];
    
    JSStringRef functionBody = JSStringCreateWithCFString((__bridge CFStringRef)function);
    JSValueRef exception = nil;
    JSObjectRef jsFunction = JSObjectMakeFunction([runtime contextRef], nil, 0, nil, functionBody, nil, 0, &exception);
    [runtime reportPossibleJSException:exception];
    
    JSStringRelease(functionBody);
    if (jsFunction) {
        return [self valueWithJSValueRef:jsFunction inRuntime:runtime];
    }
    
    return nil;
}

- (BOOL)isUndefined {
    
    if (_isJSNative) {
        FMAssert(_jsValRef);
        return _jsValueType == kJSTypeUndefined;
    }
    
    return NO;
}

- (BOOL)isNull {
    
    if (_isJSNative) {
        FMAssert(_jsValRef);
        return _jsValueType == kJSTypeNull;
    }
    
    return NO;
}

- (BOOL)isString {
    
    if (_isJSNative) {
        FMAssert(_jsValRef);
        return _jsValueType == kJSTypeString;
    }
    
    if ([self isInstance]) {
        return [[self toObject] isKindOfClass:[NSString class]];
    }
    
    return NO;
}

- (BOOL)isClass {
    return _cValue.type == _C_CLASS;
}

// <cftype gettypeid_func='CGImageGetTypeID' name='CGImageRef' tollfree='__NSCFType' type='^{CGImage=}'/>
// <cftype gettypeid_func='CFStringGetTypeID' name='CFStringRef' tollfree='__NSCFString' type='^{__CFString=}'/>

- (BOOL)isCFType {
    return [[self symbol] isCFType];
}

- (BOOL)isInstance {
    if (_cValue.type == _C_ID) {
        return YES;
    }
    
//    #pragma message "FIXME: How can we check and see if all CFTypes can bridge to an object?"
//    if (_cValue.type == _C_PTR && [[_symbol runtimeType] hasPrefix:@"^{C"]) {
//        return YES;
//    }
    
    
    return NO;
}

- (BOOL)isBlock {
    return _cValue.type == _FJSC_BLOCK;
}

- (BOOL)isStruct {
    return _cValue.type == _C_STRUCT_B;
}

- (nullable id)instance {
    
#ifdef DEBUG
    if (_weakInstance || _cValue.value.pointerValue) {
        FMAssert([self isInstance] || [self isClass] || [self isBlock] || ((_cValue.type == _C_PTR && [[_symbol runtimeType] hasPrefix:@"^{C"])));
    }
#endif
    
    if (_weakInstance) {
        return _weakInstance;
    }
    
    if (_cValue.type == _C_PTR && [[_symbol runtimeType] hasPrefix:@"^{C"]) {
        
        CFTypeRef r = _cValue.value.pointerValue;
        return (__bridge id)r;
    }
    
    return (__bridge id)_cValue.value.pointerValue;
}

- (CFTypeRef)CFTypeRef {
    return _cValue.value.pointerValue;
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
        FMAssert(![(__bridge id)o isKindOfClass:[self class]]);
        
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

- (BOOL)isCFunction {
    return [[_symbol symbolType] isEqualToString:@"function"];
}

- (BOOL)isJSFunction {
    if (!_jsValRef) {
        return NO;
    }
    
    if (JSValueGetType([_runtime contextRef], _jsValRef) != kJSTypeObject) {
        return NO;
    }
    
    JSObjectRef obj = JSValueToObject([_runtime contextRef], _jsValRef, nil);
    if (!obj) {
        return NO;
    }
    
    if ([self isCFunction] || [self isInstanceMethod] || [self isClassMethod] || [self isBlock]) {
        return NO;
    }
    
    return JSObjectIsFunction([_runtime contextRef], obj);
    
}

- (BOOL)hasClassMethodNamed:(NSString*)m {
    return [[self rtClass] respondsToSelector:NSSelectorFromString(m)];
}

// FIXME: Should JSObjectRef call JSValueRef and then make an object from that?
- (nullable JSObjectRef)JSObjectRef {
    
    if (!_jsValRef) {
        NSLog(@"-JSObjectRef called on a without a backing _jsValRef");
        FMAssert(NO);
        return nil;
    }
    
    
    return JSValueToObject([_runtime contextRef], _jsValRef, nil);
}

- (nullable JSValueRef)nativeJSValueRef {
    
    if (_isJSNative) {
        return [self JSValueRef];
    }
    
    
    JSValueRef ret = [self JSValueRef];
    
    if ([self isInstance]) {
        
        id instance = [self toObject];
        
        if ([instance isKindOfClass:[NSArray class]]) {
            return [self toJSArray];
        }
        
        return FJSNativeObjectToJSValue(instance, [[self runtime] jsContext]);
    }
    
    return ret;
}


- (nullable JSValueRef)JSValueRef {
    
    if (_jsValRef) {
        return _jsValRef;
    }
    
    if ([self isInstance] || [self isBlock]) {
        
        // for - (void)testStringPassing to work, we need to uncomment this and return a native object instead of a jsstring ( 5C54337E-CBF3-4323-9EDB-268DF924CF15 )
        // _jsValRef = FJSNativeObjectToJSValue([self instance], [_runtime contextRef]);
        
        if (!_jsValRef) {
            
            FMAssert(_runtime);
            
            _jsValRef = [_runtime newJSValueForWrapper:self];
            
        }
    }
    
    if (!_jsValRef) {
        
        switch (_cValue.type) {
                
            case _C_BOOL:
                _jsValRef = JSValueMakeBoolean([_runtime contextRef], _cValue.value.boolValue);
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
                _jsValRef = JSValueMakeNumber([_runtime contextRef], number);
                break;
            }
            
            case _C_CLASS:
            case _C_STRUCT_B:{
                _jsValRef = [_runtime newJSValueForWrapper:self];
                break;
            }
            case _C_PTR: {
                _jsValRef = [_runtime newJSValueForWrapper:self];
                break;
            }
                
            case _C_VOID:
                _jsValRef = JSValueMakeUndefined([_runtime contextRef]);
                break;
            default:
                debug(@"%p Unknown type: '%c'", (__bridge void *)self, _cValue.type);
                FMAssert(NO);
        
        }
    }
    
    if (!_jsValRef) {
        debug(@"Returning nil JSValue for %@", self);
    }
    
    return _jsValRef;
}

- (void*)objectStorage {
    return [self objectStorageForSymbol:nil];
}

// What we return here are pointers.
// If we've got a jsint, then we've 'pushed' that int to a JSValue in there, which is stored in our cValue. So we'll return the address of that.
// It's a objc object, cValue is a pointer to where the memory is allocated.
// if it's a struct, where those are usually allocated on the stack, we still return an address but it's not a pointer to a pointer like an object- rather it's the address where we allocated the memory. We generally handle those like we would an int, but since it's already pointing to an address…

// OK, what about CGRect* variables? Well those are wrapped in FJSPointer objects, which point to the object storage.

- (void*)objectStorageForSymbol:(nullable FJSSymbol *)argSymbol {
    
    // FIXME: Big problem- what if we're printing a CGRect? We need to push a native C value to an object."
    
    if ([argSymbol isPointer] && [self isInstance] && [[self instance] isKindOfClass:[FJSPointer class]]) {
        FJSPointer *p = [self instance];
        // We get a compiler warning about stack addresses if we don't jump through these hoops.
        
        // If we're a straight up object like NSError, then we're a pointer to the pointer.
        
        //Should FJSPointer just contain a FJSValue?
        
        //jkfdlsjfkl
        
        // If we made our own memory, like a struct, then we just return the pointer value, since that's already an address.
        
        
        return &(p->ptr);
        
        //return &(p->ptr);
        
        /*
         FJSValue *v = [p ptrValue];
        if ([v cValue].type == _C_STRUCT_B) {
            return &(p->ptr);
        }
        
        void *l1 = &(p->ptr);
        void *l2 = &l1;
        
        return l2;*/
    }
    
    if (_cValue.type == _C_STRUCT_B) {
        
        if (!_cValue.value.pointerValue) {
            // FIXME: refactor out how we get the size of the struct somehow.There's too many lines below to pull it out.
            
            FJSSymbol *structSym = [self symbol];
            NSString *name = [structSym structName];
            FJSSymbol *structInfoSym = [FJSSymbol symbolForName:name];
            FMAssert(structInfoSym);
            _madePointerMemorySize = [structInfoSym structSize];
            FMAssert(_madePointerMemorySize);
            
            _cValue.value.pointerValue = calloc(1, _madePointerMemorySize);
            
            _madePointerMemory = YES;
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
    
    if (_isJSNative) {
        obj = FJSNameForJSType(_jsValueType);
    }
    
    id objd = obj;
    
    if ((Class)obj == [obj class]) {
        objd = NSStringFromClass([obj class]);
    }
    
    
    return [NSString stringWithFormat:@"%@ - <%p> %@ (%@ native)", [super description], (__bridge void *)obj, objd, _isJSNative ? @"js" : @"c"];
}

- (BOOL)setValue:(FJSValue*)value onStructFieldNamed:(NSString*)structFieldName {
    
    // FIXME: Need more tests for the setValue:onStructFieldNamed: types."
    FMAssert(_cValue.type == _C_STRUCT_B);
    
    FJSSymbol *structSym = [self symbol];
    FMAssert(structSym);
    
    NSString *name = [structSym structName];
    FMAssert(name);
    
    FJSSymbol *structInfoSym = [FJSSymbol symbolForName:name];
    FMAssert(structInfoSym);
#ifdef DEBUG
    FJSStructSymbol *structFieldSym = [structInfoSym structFieldNamed:structFieldName];
    FMAssert(structFieldSym);
#endif
    
    
    FJSStructSymbol *foundType = nil;
    size_t offset = 0;
    
    for (FJSStructSymbol *ss in [structInfoSym structFields]) {
        if ([[ss name] isEqualToString:structFieldName]) {
            foundType = ss;
            break;
        }
        offset += [ss size];
    }
    
    void *loc = (char*)_cValue.value.pointerValue + offset;
    
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
            FMAssert(_madePointerMemorySize);
            FMAssert([self structSize] >= [value structSize]);
            memcpy(loc, [value structLocation], [value structSize]);
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
#ifdef DEBUG
    FJSStructSymbol *structFieldSym = [structInfoSym structFieldNamed:structFieldName];
    FMAssert(structFieldSym);
#endif
    
    
    FJSStructSymbol *foundType = nil;
    size_t offset = 0;
    
    for (FJSStructSymbol *ss in [structInfoSym structFields]) {
        if ([[ss name] isEqualToString:structFieldName]) {
            foundType = ss;
            break;
        }
        offset += [ss size];
    }
    
    void *loc = (char*)_cValue.value.pointerValue + offset;
    
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
    
    if (_cValue.type == _C_ID || _cValue.type == _FJSC_BLOCK || _cValue.type == _C_CLASS) {
        return &ffi_type_pointer;
    }
    
    return &ffi_type_void;
}

- (NSString*)structToString {
    FMAssert([self isStruct]);
    
    if ([[[self symbol] runtimeType] hasPrefix:@"{CGSize="]) {
        return NSStringFromSize([self toCGSize]);
    }
    else if ([[[self symbol] runtimeType] hasPrefix:@"{CGRect="]) {
        return NSStringFromRect([self toCGRect]);
    }
    else if ([[[self symbol] runtimeType] hasPrefix:@"{CGPoint="]) {
        return NSStringFromPoint([self toCGPoint]);
    }
    
    debug(@"[[self symbol] runtimeType]: '%@'", [[self symbol] runtimeType]);
    
    return [NSString stringWithFormat:@"<unable to parse %@>", [[self symbol] runtimeType]];
}

- (nullable JSValueRef)toJSString {
    // TODO: check for numbers, etc, and convert them to the right JS type
    debug(@"_instance: %@", [self instance]);
    JSStringRef string = JSStringCreateWithCFString((__bridge CFStringRef)[[self instance] description]);
    JSValueRef value = JSValueMakeString([_runtime contextRef], string);
    JSStringRelease(string);
    return value;
}

- (nullable JSValueRef)toJSArray {
    
    // FIXME: this needs some tests.
    
    NSArray *ar = [self instance];
    
    if (![ar isKindOfClass:[NSArray class]]) {
        return JSValueMakeUndefined([[self runtime] contextRef]);
    }
    
    JSValueRef *elements = malloc(sizeof(JSValueRef) * [ar count]);
    
    for (NSUInteger idx = 0; idx < [ar count]; idx++) {
        
        id o = [ar objectAtIndex:idx];
        
        FJSValue *v = [FJSValue valueWithInstance:(__bridge CFTypeRef _Nonnull)(o) inRuntime:[self runtime]];
        elements[idx] = [v nativeJSValueRef];
    }
    
    JSValueRef exception = nil;
    JSObjectRef arrayRef = JSObjectMakeArray([[self runtime] contextRef], [ar count], elements, &exception);
    [[self runtime] reportPossibleJSException:exception];
    
    return arrayRef;
}

- (nullable id)toObject {
    
    if (_isJSNative) {
        
        char type = _cValue.type;
        
        if (!type) {
            
            FMAssert(_jsValRef);
            
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
        
        return FJSNativeObjectFromJSValue(_jsValRef, [NSString stringWithFormat:@"%c", type], [_runtime contextRef]);
    }
    
    if ([self isInstance]) {
        
        if ([[self instance] isKindOfClass:[FJSPointer class]]) {
            FJSPointer *p = [self instance];
            
            if (p->cValue.type == _C_ID) {
                void **f = p->ptr;
            
                return (__bridge id)*f;
            }
            
            return nil;
        }
        
        
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
        
        // return types like CFURLRef can end up down here.
        if ([[_symbol runtimeType] hasPrefix:@"^{C"]) {
            return [self instance];
        }
        
        debug(@"Haven't implemented toObject for %c yet (_C_PTR)", _cValue.type);
        return nil;
    }
    
    FMAssert(_symbol); // Why else would we be here?
    
    return nil;
}

- (BOOL)pushJSValueToNativeType:(NSString*)type {
    
   if ([type isEqualToString:@"B"]) {
        _cValue.type = _C_BOOL;
        _cValue.value.boolValue = [FJSNativeObjectFromJSValue(_jsValRef, type, [_runtime contextRef]) boolValue];
        return YES;
    }
    
    if ([type isEqualToString:@"s"]) {
        _cValue.type = _C_SHT;
        _cValue.value.shortValue = [FJSNativeObjectFromJSValue(_jsValRef, type, [_runtime contextRef]) shortValue];
        return YES;
    }
    
    if ([type isEqualToString:@"S"]) {
        _cValue.type = _C_USHT;
        _cValue.value.ushortValue = [FJSNativeObjectFromJSValue(_jsValRef, type, [_runtime contextRef]) unsignedShortValue];
        return YES;
    }
    
    if ([type isEqualToString:@"c"]) {
        _cValue.type = _C_CHR;
        _cValue.value.charValue = [FJSNativeObjectFromJSValue(_jsValRef, type, [_runtime contextRef]) charValue];
        return YES;
    }
    
    if ([type isEqualToString:@"C"]) {
        _cValue.type = _C_UCHR;
        _cValue.value.ucharValue = [FJSNativeObjectFromJSValue(_jsValRef, type, [_runtime contextRef]) unsignedCharValue];
        return YES;
    }
    
    if ([type isEqualToString:@"i"]) {
        _cValue.type = _C_INT;
        _cValue.value.intValue = [FJSNativeObjectFromJSValue(_jsValRef, type, [_runtime contextRef]) intValue];
        return YES;
    }
    
    if ([type isEqualToString:@"I"]) {
        _cValue.type = _C_UINT;
        _cValue.value.uintValue = [FJSNativeObjectFromJSValue(_jsValRef, type, [_runtime contextRef]) unsignedIntValue];
        return YES;
    }
    
    if ([type isEqualToString:@"l"]) {
        _cValue.type = _C_LNG;
        _cValue.value.longValue = [FJSNativeObjectFromJSValue(_jsValRef, type, [_runtime contextRef]) longValue];
        return YES;
    }
    
    if ([type isEqualToString:@"L"]) {
        _cValue.type = _C_ULNG;
        _cValue.value.unsignedLongValue = [FJSNativeObjectFromJSValue(_jsValRef, type, [_runtime contextRef]) unsignedLongValue];
        return YES;
    }
    
    if ([type isEqualToString:@"q"]) {
        _cValue.type = _C_LNG_LNG;
        _cValue.value.longLongValue = [FJSNativeObjectFromJSValue(_jsValRef, type, [_runtime contextRef]) longLongValue];
        return YES;
    }
    
    if ([type isEqualToString:@"Q"]) {
        _cValue.type = _C_ULNG_LNG;
        _cValue.value.unsignedLongLongValue = [FJSNativeObjectFromJSValue(_jsValRef, type, [_runtime contextRef]) unsignedLongLongValue];
        return YES;
    }
    
    if ([type isEqualToString:@"f"]) {
        _cValue.type = _C_FLT;
        _cValue.value.floatValue = [FJSNativeObjectFromJSValue(_jsValRef, type, [_runtime contextRef]) floatValue];
        return YES;
    }
    
    if ([type isEqualToString:@"d"]) {
        _cValue.type = _C_DBL;
        _cValue.value.doubleValue = [FJSNativeObjectFromJSValue(_jsValRef, type, [_runtime contextRef]) doubleValue];
        return YES;
    }
    
    if ([type isEqualToString:@"v"]) {
        _cValue.type = _C_VOID;
        _cValue.value.pointerValue = nil;
        return YES;
    }
    
    
    if ([type isEqualToString:@":"]) {
        
        if (JSValueIsString([_runtime contextRef], _jsValRef)) {
            JSStringRef resultStringJS = JSValueToStringCopy([_runtime contextRef], _jsValRef, NULL);
            id o = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, resultStringJS));
            JSStringRelease(resultStringJS);
            _cValue.type = _C_SEL;
            _cValue.value.selectorValue = NSSelectorFromString(o);
            return YES;
        }
        
        FMAssert(NO);
        return NO;
        
    }
    
    if (JSValueIsNull([_runtime contextRef], _jsValRef)) {
        [self setInstance:nil];
        return YES;
    }
    
    [self setInstance:(__bridge CFTypeRef)(FJSNativeObjectFromJSValue(_jsValRef, type, [_runtime contextRef]))];
    
    return [self instance] != nil;
}

- (BOOL)toBOOL {
    
    if (_isJSNative) {
        
        if (JSValueIsBoolean([_runtime contextRef], _jsValRef)) {
            return JSValueToBoolean([_runtime contextRef], _jsValRef);
        }
        
        return [FJSNativeObjectFromJSValue(_jsValRef, @"B", [_runtime contextRef]) boolValue];
    }
    
    
    if ([self isInstance] && [[self instance] respondsToSelector:@selector(boolValue)]) {
        return [[self instance] boolValue];
    }
    
    return _cValue.value.boolValue;
}

- (double)toDouble {
    
    if (_isJSNative) {
        return [FJSNativeObjectFromJSValue(_jsValRef, @"d", [_runtime contextRef]) doubleValue];
    }
    
    if ([self isInstance] && [[self instance] respondsToSelector:@selector(doubleValue)]) {
        return [[self instance] doubleValue];
    }
    
    if (_cValue.type == _C_PTR) {
        // We're probably pointing to a struct.
        double *d = _cValue.value.pointerValue;
        return *d;
    }
    
    
    if ([self isInstance] && [[self instance] isKindOfClass:[FJSPointer class]]) {
        FJSPointer *p = [self instance];
        FMAssert(p->ptr);
        return p->cValue.value.doubleValue;
    }
    
    FMAssert(_cValue.type == _C_DBL);
    return _cValue.value.doubleValue;
}

- (long long)toLongLong {
    if (_isJSNative) {
        return [FJSNativeObjectFromJSValue(_jsValRef, @"q", [_runtime contextRef]) longLongValue];
    }
    
    if ([self isInstance] && [[self instance] respondsToSelector:@selector(longLongValue)]) {
        return [[self instance] longLongValue];
    }
    
    if ([self isInstance] && [[self instance] isKindOfClass:[FJSPointer class]]) {
        FJSPointer *p = [self instance];
        FMAssert(p->ptr);
        
        return p->cValue.value.longLongValue;
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

- (nullable void*)pointerPointer {
    FMAssert(_cValue.type);
    return &_cValue.value.pointerValue;
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

- (FJSValue*)unwrapValue __attribute__((cf_returns_retained)) {
    FMAssert(NO);
    if ([self isInstance] && [[self instance] isKindOfClass:[FJSValue class]]) {
        return CFRetain((__bridge CFTypeRef)([self instance]));
    }
    
    return self;
    
}

- (nullable FJSValue *)objectForKeyedSubscript:(NSString*)key {
    
    if (!_isJSNative) {
        
        if ([self isInstance]) {
            
            id o = [self toObject];
            
            id r = [o valueForKey:key];
            
            if (r) {
                return [FJSValue valueWithInstance:(__bridge CFTypeRef _Nonnull)(r) inRuntime:_runtime];
            }
            else {
                return [FJSValue valueWithNullInRuntime:_runtime];
            }
        }
        
        FMAssert(NO);
        
        return nil;
    }
    
    if (!JSValueIsObject([_runtime contextRef], _jsValRef)) {
        debug(@"%@ is not an object, so we're return nil from objectForKeyedSubscript: (%@) (%d)", key, self, JSValueGetType([_runtime contextRef], _jsValRef));
        return nil;
    }
    
    JSObjectRef selfObject = JSValueToObject([_runtime contextRef], _jsValRef, nil);
    return [_runtime objectForKeyedSubscript:key inJSObject:selfObject];
}

- (void)setObject:(id)object forKeyedSubscript:(NSString *)name {
    
    if (object == self) { printf("Nice try.\n"); FMAssert(NO); return; }
    
    JSValueRef exception = NULL;
    JSObjectRef selfObject = JSValueToObject([_runtime jsContext], [self JSValueRef], &exception);
    
    if (exception) {
        [_runtime reportPossibleJSException:exception];
        return;
    }
    
    [_runtime setObject:object forKeyedSubscript:name inJSObject:selfObject];
    
}


- (nullable FJSValue *)invokeMethodNamed:(NSString *)method withArguments:(NSArray *)arguments {
    
    if (!_isJSNative) {
        FMAssert(NO);
        return nil;
    }
    
    if (!JSValueIsObject([_runtime contextRef], _jsValRef)) {
        FMAssert(NO);
        return nil;
    }
    
    FJSValue *functionValue = [method length] ? self[method] : self;
    if (!functionValue) {
        return nil;
    }
    
    JSValueRef *jsArgumentsArray = nil;
    NSUInteger argumentsCount = [arguments count];
    if (argumentsCount) {
        jsArgumentsArray = calloc(argumentsCount, sizeof(JSValueRef));
        
        for (NSUInteger i=0; i<argumentsCount; i++) {
            FJSValue *v = [arguments objectAtIndex:i];
            
            if (![v isKindOfClass:[FJSValue class]])  {
                v = [FJSValue valueWithInstance:(__bridge CFTypeRef)(v) inRuntime:[self runtime]];
            }
            
            jsArgumentsArray[i] = [v JSValueRef];
        }
    }
    
    [_runtime pushAsCurrentFJS];
    
    __block JSValueRef jsFunctionReturnValue;
    __block JSValueRef exception = nil;
    
    [_runtime dispatchOnQueue:^{
        JSObjectRef jsFunction = JSValueToObject([self->_runtime contextRef], [functionValue jsValRef], nil);
        JSObjectRef thisObject = JSValueToObject([self->_runtime contextRef], self->_jsValRef, nil);
        
        jsFunctionReturnValue = JSObjectCallAsFunction([self->_runtime contextRef], jsFunction, thisObject, argumentsCount, jsArgumentsArray, &exception);
    }];
    
    if (jsArgumentsArray) {
        free(jsArgumentsArray);
    }
    
    FJSValue *returnValue = nil;
    if (exception) {
        [_runtime reportPossibleJSException:exception];
    }
    else {
        returnValue = [FJSValue valueWithJSValueRef:(JSObjectRef)jsFunctionReturnValue inRuntime:_runtime];
    }
    
    [_runtime popAsCurrentFJS];
    
    return returnValue;
    
}


- (nullable FJSValue *)callWithArguments:(NSArray *)arguments {
    return [self invokeMethodNamed:@"" withArguments:arguments];
}

- (nullable NSArray*)propertyNames {
    
    if (![self JSObjectRef]) {
        return nil;
    }
    
    NSMutableArray *ar = [NSMutableArray array];
    
    JSPropertyNameArrayRef a = JSObjectCopyPropertyNames([_runtime contextRef], [self JSObjectRef]);
    size_t ct = JSPropertyNameArrayGetCount(a);
    for (size_t i = 0; i < ct; i++) {
        JSStringRef sr = JSPropertyNameArrayGetNameAtIndex(a, i);
        NSString *s = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, sr));
        [ar addObject:s];
    }
    
    JSPropertyNameArrayRelease(a);
    
    return ar;
}

- (void)unprotect {
    
    if (!_jsValRef) {
        return;
    }
    
    _protectCount--;
    
    if (_protectCount < 0) {
        NSLog(@"unprotect called too many times for %@. Behavior is undefined for here on out.", self);
        [[NSException exceptionWithName:@"Unprotect Exception" reason:@"-unprotect called too many times" userInfo:nil] raise];
        return;
    }
    
    if (_protectCount == 0) {
        FMAssert(_unprotectContextRef);
        if (_unprotectContextRef) {
            JSValueUnprotect(_unprotectContextRef, _jsValRef);
            JSGlobalContextRelease(_unprotectContextRef);
            _unprotectContextRef = nil;
        }
    }
}

- (instancetype)protect {
    
    // FIXME: Should we keep a list of FJSObjects in the runtime that need to be unprotected?
    
    if (!_jsValRef) {
        return self;
    }
    
    if (_protectCount == 0) {
        FMAssert(!_unprotectContextRef);
        if (!_unprotectContextRef) {
            FMAssert(_runtime);
            FMAssert(!_protectCount);
            _unprotectContextRef = JSGlobalContextRetain((JSGlobalContextRef)[_runtime contextRef]);
            JSValueProtect(_unprotectContextRef, _jsValRef);
        }
    }
    
    _protectCount++;
    
    return self;
}

@end



