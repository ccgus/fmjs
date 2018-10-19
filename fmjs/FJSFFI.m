//
//  FJSFFI.m
//  yd
//
//  Created by August Mueller on 8/22/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import "FJS.h"
#import "FJSFFI.h"
#import "FJSPrivate.h"
#import "FJSRuntime.h"
#import "FJSUtil.h"
#import "TDConglomerate.h"
#import <objc/runtime.h>
#import <dlfcn.h>

@interface FJSFFI ()
@property (weak) FJSValue *f;
@property (weak) FJSValue *caller;
@property (strong) NSArray *args;
@property (weak) FJSRuntime *runtime;
@end

static NSMutableDictionary *FJSFFIStructureLookup;

@implementation FJSFFI


+ (instancetype)ffiWithFunction:(FJSValue*)f caller:(nullable FJSValue*)caller arguments:(NSArray*)args cos:(FJSRuntime*)cos {
    
    FJSFFI *ffi = [FJSFFI new];
    [ffi setF:f];
    [ffi setCaller:caller];
    [ffi setArgs:args];
    [ffi setRuntime:cos];
    
    return ffi;
}

- (nullable FJSValue*)blockInvoke {
    
    return nil;
}


- (nullable FJSValue*)objcInvoke {
    assert([_caller cValue].value.pointerValue);
    FJSSymbol *functionSymbol = [_f symbol];
    assert(functionSymbol);
    NSString *methodName = [functionSymbol name];
    FJSValue *returnFValue = nil;
    
    @try {
        
        SEL selector = NSSelectorFromString(methodName);
        
        id object = [_caller instance];
        
        NSMethodSignature *methodSignature = [object methodSignatureForSelector:selector];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
        
        [invocation retainArguments];
        [invocation setTarget:object];
        [invocation setSelector:selector];
        
        NSUInteger methodArgumentCount = [methodSignature numberOfArguments] - 2;
        if (methodArgumentCount != [_args count]) {
            debug(@"_args: %@", _args);
            NSString *reason = [NSString stringWithFormat:@"ObjC method %@ requires %lu %@, but JavaScript passed %zd %@", NSStringFromSelector(selector), methodArgumentCount, (methodArgumentCount == 1 ? @"argument" : @"arguments"), [_args count], ([_args count] == 1 ? @"argument" : @"arguments")];
            
            [_runtime reportNSException:[NSException exceptionWithName:FMJavaScriptExceptionName reason:reason userInfo:nil]];
            
            return [FJSValue valueWithUndefinedInRuntime:_runtime];
        }
        
        NSInteger currentArgIndex = 0;
        for (FJSValue *v in _args) {
            NSInteger objcIndex = currentArgIndex + 2;
            
            FJSSymbol *argSymbol = [[functionSymbol arguments] objectAtIndex:currentArgIndex];
            FMAssert([argSymbol runtimeType]);
            
            if ([v isJSNative]) {
                [v pushJSValueToNativeType:[argSymbol runtimeType]];
            }
            
            void *arg = [v objectStorage];
            [invocation setArgument:arg atIndex:objcIndex];
            currentArgIndex++;
        }
        
        // Invoke
        @try {
            [invocation invoke];
        }
        @catch (NSException *exception) {
            [_runtime reportNSException:exception];
        }
        
        const char *returnType = [methodSignature methodReturnType];
        JSValueRef returnValue = NULL;
        if (FJSCharEquals(returnType, @encode(void))) {
            returnValue = JSValueMakeUndefined([_runtime contextRef]);
            returnFValue = [FJSValue valueForJSValue:(JSObjectRef)returnValue inRuntime:_runtime];
        }
        // id
        else if (FJSCharEquals(returnType, @encode(id)) || FJSCharEquals(returnType, @encode(Class))) {
            
            // Using CFTypeRef with libffi is a great way to workaround ARC getting in the way of things.
            CFTypeRef cfobject = nil;
            [invocation getReturnValue:&cfobject];
            
            returnFValue = [FJSValue valueWithInstance:cfobject inRuntime:_runtime];
            
            if ([functionSymbol returnsRetained]) {
                // We're already +2 on the object now. Time to bring it back down with CFRelease
                CFRelease(cfobject);
            }
            
        }
        else  {
            #pragma message "FIXME: This obviously isn't going to work for structs and other things that we need to malloc memory on the stack for."
            FJSObjCValue cval;
            cval.type = returnType[0];
            FMAssert(cval.type);
            [invocation getReturnValue:&(cval.value.pointerValue)];
            
            returnFValue = [FJSValue valueWithCValue:cval inRuntime:_runtime];
            
        }
        
        
    }
    @catch (NSException *e) {
        [_runtime reportNSException:e];
        assert(NO);
        return NULL;
    }
    
    return returnFValue ? returnFValue : [FJSValue valueWithUndefinedInRuntime:_runtime];
}


- (nullable FJSValue*)callFunction {
    
    FMAssert(_f);
    FMAssert([_f isFunction] || [_f isClassMethod] || [_f isInstanceMethod] || [_f isBlock]);
    
    if ([_f isClassMethod] || [_f isInstanceMethod]) {
        return [self objcInvoke];
    }
    
    void *callAddress = nil;
    FJSSymbol *functionSymbol = nil;
    
    if ([_f isBlock]) {
        
        callAddress = FJSCallAddressForBlock([_f instance]);
        
        functionSymbol = [_f symbol];
        if (!functionSymbol) {
            const char *typeEncoding = FJSTypeEncodingForBlock([_f instance]);
            functionSymbol = [FJSSymbol symbolForBlockTypeEncoding:typeEncoding];
            [_f setSymbol:functionSymbol];
        }
        
        
        FMAssert(callAddress);
        FMAssert(functionSymbol);
    }
    else {
        
        functionSymbol = [_f symbol];
        FMAssert(functionSymbol);
        callAddress = dlsym(RTLD_DEFAULT, [[functionSymbol name] UTF8String]);
    }
    
    

    if (!callAddress) {
        debug(@"Can't find call address for '%@'", [functionSymbol name]);
        FMAssert(NO);
        return nil;
    }
    
    FMAssert(_runtime);
    
    // Prepare ffi
    ffi_cif cif;
    ffi_type** ffiArgs = NULL;
    void** ffiValues = NULL;
    
    size_t functionArgumentCount = [[functionSymbol arguments] count];
    if ([_args count] != functionArgumentCount) {
        NSString *reason = [NSString stringWithFormat:@"Method %@ requires %lu %@, but JavaScript passed %zd %@", [functionSymbol name], functionArgumentCount, (functionArgumentCount == 1 ? @"argument" : @"arguments"), [_args count], ([_args count] == 1 ? @"argument" : @"arguments")];
        
        [_runtime reportNSException:[NSException exceptionWithName:FMJavaScriptExceptionName reason:reason userInfo:nil]];
        
        return [FJSValue valueWithUndefinedInRuntime:_runtime];
    }
    
    
    // Build the arguments
    unsigned int ffiArgumentCount = (unsigned int)[_args count];

    if ([_f isBlock]) {
        ffiArgumentCount++;
    }
    
    if (ffiArgumentCount > 0) {
        ffiArgs = malloc(sizeof(ffi_type *) * ffiArgumentCount);
        ffiValues = malloc(sizeof(void *) * ffiArgumentCount);
        NSInteger ffiArgIndex = 0;
        if ([_f isBlock]) {
            ffiArgs[ffiArgIndex]   = &ffi_type_pointer;
            ffiValues[ffiArgIndex] = [_f objectStorage];
            ffiArgIndex++;
        }
        
        
        for (NSInteger symbolArgIndex = 0; ffiArgIndex < ffiArgumentCount; ffiArgIndex++, symbolArgIndex++) {
            FJSValue *arg     = [_args objectAtIndex:symbolArgIndex];
            FJSSymbol *argSym = [[[_f symbol] arguments] objectAtIndex:symbolArgIndex];
            assert(argSym);
            
            if ([arg isJSNative]) {
                // Convert this to the argSymTupe?
                [arg pushJSValueToNativeType:[argSym runtimeType]];
                [arg setSymbol:argSym];
            }
            
            ffi_type *type         = [arg FFITypeWithHint:[argSym runtimeType]];
            ffiArgs[ffiArgIndex]   = type;
            ffiValues[ffiArgIndex] = [arg objectStorage];
            //[FJSFFI describeFFIType:type];
        }
    }
    
    FJSValue *returnValue = [functionSymbol returnValue] ? [FJSValue valueWithSymbol:[functionSymbol returnValue] inRuntime:_runtime] : nil;
    
    ffi_type *returnType = returnValue ? [returnValue FFIType] : &ffi_type_void;
    
    ffi_status prep_status = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, ffiArgumentCount, returnType, ffiArgs);
    
    // Call
    if (prep_status == FFI_OK) {
        void *returnStorage = [returnValue objectStorage];
        
        @try {
            ffi_call(&cif, callAddress, returnStorage, ffiValues);
            
            [returnValue retainReturnValue];
        }
        @catch (NSException *e) {
            [_runtime reportNSException:e];
            returnValue = nil;
        }
        
        //[FJSFFI describeFFIType:returnType];
    }
    
    if (ffiArgumentCount > 0) {
        free(ffiArgs);
        free(ffiValues);
    }
    
    return returnValue ? returnValue : [FJSValue valueWithUndefinedInRuntime:_runtime];
}

+ (ffi_type *)ffiTypeAddressForTypeEncoding:(char)encoding {
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
    
    // FFI_TYPE_STRUCT
    
    FMAssert(NO);
    
    return nil;
}

+ (NSArray *)ffiElementsForTokenizer:(FJSTDTokenizer*)tokenizer {
    
    // {CGRect={CGPoint=dd}{CGSize=dd}}
    // {_NSRange=QQ}

    FJSTDToken *tok = [tokenizer nextToken]; // name of struct.
    FMAssert(![tok isSymbol]);
    if ([tok isSymbol]) {
        return nil;
    }
    
    
    tok = [tokenizer nextToken]; // =
    FMAssert([tok isSymbol]);
    if (![tok isSymbol]) {
        return nil;
    }
    
    // Alright, now we're in the meat of the thing.
    
    NSMutableArray *elements = [NSMutableArray array];
    
    while ((tok = [tokenizer nextToken]) != [FJSTDToken EOFToken]) {
        
        if ([tok isSymbol]) {
            if ([[tok stringValue] isEqualToString:@"{"]){
                // structs in structs!
                [elements addObject:[self ffiElementsForTokenizer:tokenizer]];
            }
            else if ([[tok stringValue] isEqualToString:@"}"]) {
                // End of our struct, we'll be returning now, right?
                return elements;
            }
        }
        else {
            
            const char *s = [[tok stringValue] UTF8String];
            for (size_t idx = 0; idx < strlen(s); idx++) {
                [elements addObject:[NSString stringWithFormat:@"%c", s[idx]]];
            }
        }
    }
    
    return elements;
}

+ (ffi_type *)ffiTypeForArrayEncoding:(NSArray*)encodings {
    
    
    ffi_type *struct_type = calloc(sizeof(ffi_type), 1);
    
    // Build FFI type
    struct_type->size      = 0;
    struct_type->alignment = 0;
    struct_type->type      = FFI_TYPE_STRUCT;
    struct_type->elements  = calloc(sizeof(ffi_type *), [encodings count] + 1);
    
    size_t idx = 0;
    for (id type in encodings) {
        
        ffi_type *elementType;
        
        if ([type isKindOfClass:[NSArray class]]) {
            elementType = [self ffiTypeForArrayEncoding:type];
        }
        else {
            FMAssert([type isKindOfClass:[NSString class]]);
            elementType = [self ffiTypeAddressForTypeEncoding:[type characterAtIndex:0]];
        }
        
        FMAssert(elementType);
        
        struct_type->elements[idx] = elementType;
        
        idx++;
    }
    
    FMAssert(idx == [encodings count]);
    struct_type->elements[idx] = nil;
    
    return struct_type;
}

+ (ffi_type *)ffiTypeForStructure:(NSString*)structEncoding {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        FJSFFIStructureLookup = [NSMutableDictionary dictionary];
    });
    
    NSValue *v = [FJSFFIStructureLookup objectForKey:structEncoding];
    if (v) {
        return [v pointerValue];
    }
    
    FMAssert([structEncoding hasPrefix:@"{"]);
    if (![structEncoding hasPrefix:@"{"]) {
        NSLog(@"Struct '%@' has wrong prefix (needed '{')", structEncoding);
        return nil;
    }
    
    ffi_type *type = nil;
    
    @synchronized (self) {
        
        FJSTDTokenizer *tokenizer  = [FJSTDTokenizer tokenizerWithString:structEncoding];
        FJSTDToken *tok            = [tokenizer nextToken];
        NSString *sv               = [tok stringValue];
        FMAssert([sv isEqualToString:@"{"]);
        
        NSArray *elements = [self ffiElementsForTokenizer:tokenizer];
        
        while ((tok = [tokenizer nextToken]) != [FJSTDToken EOFToken]) {
            debug(@"remaining in structure, being ignored: '%@'", [tok stringValue]);
        }
        
        type = [self ffiTypeForArrayEncoding:elements];
        
        [FJSFFIStructureLookup setObject:[NSValue valueWithPointer:type] forKey:structEncoding];
    }
    
    FMAssert(type);
    
    return type;
    
    
}

/* Keep this around. We're caching the ffi_type now, but… well, we might need this again some day?
+ (void)freeFFIStructureType:(ffi_type*)structType {
 
    if (structType->type != FFI_TYPE_STRUCT) {
        NSLog(@"Attempt to free a ffi_type that's not a struct.");
        FMAssert(NO);
        return;
    }
    
    size_t idx = 0;
    ffi_type *curElement = structType->elements[idx];
    while (curElement) {
        
        if (curElement->type == FFI_TYPE_STRUCT) {
            [self freeFFIStructureType:curElement];
        }
        
        idx++;
        curElement = structType->elements[idx];
    }
    
    free(structType);
}
*/

+ (size_t)countOfElementsInType:(ffi_type*)type {
    
    if (!type->elements) {
        return 0;
    }
    
    size_t idx = 0;
    ffi_type *curElement = type->elements[idx];
    while (curElement) {
        idx++;
        curElement = type->elements[idx];
    }
    return idx;
}

+ (NSString*)FFIType:(unsigned short)type {
    
    switch (type) {
        case FFI_TYPE_VOID:
            return @"void";
            
        case FFI_TYPE_INT:
            return @"int";
            
        case FFI_TYPE_FLOAT:
            return @"float";
            
        case FFI_TYPE_DOUBLE:
            return @"double";
            
        case FFI_TYPE_LONGDOUBLE:
            return @"long double";
            
        case FFI_TYPE_UINT8:
            return @"uint8";
            
        case FFI_TYPE_SINT8:
            return @"sint8";
            
        case FFI_TYPE_UINT16:
            return @"uint16";
            
        case FFI_TYPE_SINT16:
            return @"sint16";
            
        case FFI_TYPE_UINT32:
            return @"uint32";
            
        case FFI_TYPE_SINT32:
            return @"sint32";
            
        case FFI_TYPE_UINT64:
            return @"uint64";
            
        case FFI_TYPE_SINT64:
            return @"sint64";
            
        case FFI_TYPE_STRUCT:
            return @"struct";
            
        case FFI_TYPE_POINTER:
            return @"pointer";
            
        default:
            break;
    }
    
    FMAssert(NO);
    
    return nil;
}

+ (void)describeFFIType:(ffi_type*)type prefix:(NSString*)prefix {
    
    
    printf("%stype:      %s (%d)\n", [prefix UTF8String], [[self FFIType:type->type] UTF8String], type->type);
    //printf("%ssize:      %ld\n", [prefix UTF8String], type->size);
    //printf("%salignment: %d\n", [prefix UTF8String], type->alignment);
    
    if (type->elements) {
        
        printf("%selements:  (%ld)\n", [prefix UTF8String], [self countOfElementsInType:type]);
        size_t idx = 0;
        ffi_type *curElement = type->elements[idx];
        while (curElement) {
            [self describeFFIType:curElement prefix:[prefix stringByAppendingString:@"  "]];
            idx++;
            curElement = type->elements[idx];
        }
    }
    
    
}

+ (void)describeFFIType:(ffi_type*)type {
    
    [self describeFFIType:type prefix:@""];
    
}

@end


