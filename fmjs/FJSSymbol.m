//
//  FJSSymbol.m
//  fmjs
//
//  Created by August Mueller on 10/19/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import "FJSSymbol.h"
#import "FJSSymbolManager.h"
#import "FJS.h"
#import "FJSUtil.h"
#import "TDConglomerate.h"
#import <objc/runtime.h>


@interface FJSSymbolManager (Private)
@property (strong) NSMutableDictionary *symbols;
@property (strong) NSMutableDictionary *cfTypeToSymbolLUT;
- (void)addSymbol:(FJSSymbol*)symbol;
@end

@interface FJSSymbol ()

@property (strong) NSArray *structSymbols;

@end

@implementation FJSSymbol



- (id)copyWithZone:(NSZone *)zone {
    
    FJSSymbol *sym = [[[self class] allocWithZone:zone] init];
    
    sym->_structSymbols = _structSymbols;
    sym->_symbolType = _symbolType;
    sym->_name = _name;
    sym->_runtimeType = _runtimeType;
    sym->_runtimeValue = _runtimeValue;
    sym->_selector = _selector;
    sym->_arguments = _arguments;
    sym->_classMethods = _classMethods;
    sym->_instanceMethods = _instanceMethods;
    sym->_returnValue = _returnValue;
    sym->_isClassMethod = _isClassMethod;
    sym->_isCFType = _isCFType;
    sym->_cfTypeReturnsRetained = _cfTypeReturnsRetained;
    
    return sym;
    
}





- (void)parseStruct {
    
    if (!_structSymbols) {
        
        // _runtimeType is in the format of {CGPoint="x"d"y"d}
        //                               or {CGRect="origin"{CGPoint}"size"{CGSize}}
        
        if (![_runtimeType hasPrefix:@"{"]) {
            printf("Trying to parse a struct in an invalid format: '%s'\n", [_runtimeType UTF8String]);
            return;
        }
        
        NSMutableArray *symbols = [NSMutableArray array];
        
        
        FJSTDTokenizer *tokenizer  = [FJSTDTokenizer tokenizerWithString:_runtimeType];
        FJSTDToken *tok            = [tokenizer nextToken];
        NSString *sv               = [tok stringValue];
        FMAssert([sv isEqualToString:@"{"]);
        
        tok            = [tokenizer nextToken];
        sv             = [tok stringValue];
        FMAssert([sv isEqualToString:_name]);
        
        tok            = [tokenizer nextToken];
        sv             = [tok stringValue];
        FMAssert([sv isEqualToString:@"="]);
        
        //debug(@"_runtimeType: '%@'", _runtimeType);
        
        // Alright. Now we're into the meat of it I guess.
        while ((tok = [tokenizer nextToken]) != [FJSTDToken EOFToken]) {
            //debug(@"[tok stringValue]: '%@'", [tok stringValue]);
            
            if ([[tok stringValue] hasPrefix:@"\""]) { // Sweet. It's the name.
                FMAssert([[tok stringValue] hasSuffix:@"\""]);
                FJSTDToken *typeToken = [tokenizer nextToken];
                if (typeToken == [FJSTDToken EOFToken]) {
                    printf("Unexpected end to struct symbols. Ending parse.\n");
                    return;
                }
                
                NSString *name = [[tok stringValue] substringWithRange:NSMakeRange(1, [[tok stringValue] length] - 2)];
                NSString *type = [typeToken stringValue];
                
                FJSStructSymbol *sym = [FJSStructSymbol new];
                [sym setName:name];
                [sym setType:[type characterAtIndex:0]];
                
                if ([type characterAtIndex:0] == _C_STRUCT_B) {
                    // Well, shit.
                    NSString *structName = [[tokenizer nextToken] stringValue];
                    [sym setStructName:structName];
                    NSString *structEnd = [[tokenizer nextToken] stringValue];
                    
                    FMAssert([structEnd isEqualToString:@"}"]);
                }
                
                if ([sym type] == _C_STRUCT_B) {
                    
                    // Need to look up the struct type, and then figure out the size of that.
                    FMAssert([sym structName]);
                    FJSSymbol *subStructSymbol = [FJSSymbol symbolForName:[sym structName]];
                    FMAssert(subStructSymbol);
                    if (!subStructSymbol) {
                        printf("%s:%d Could not find symbol for %s. Aborting.\n", __FUNCTION__, __LINE__, [[sym structName] UTF8String]);
                        return;
                    }
                    
                    
                    size_t size = 0;
                    for (FJSStructSymbol *subStructSym in [subStructSymbol structFields]) {
                        size += [subStructSym size];
                    }
                    
                    FMAssert(size);
                    
                    [sym setSize:size];
                    [symbols addObject:sym];
                }
                else {
                    
                    size_t symbolSize;
                    if (FJSGetSizeOfTypeEncoding(&symbolSize, [sym type])) {
                        [sym setSize:symbolSize];
                        [symbols addObject:sym];
                    }
                    else {
                        printf("Could not determine size for type '%c'. Ending parse.\n", [sym type]);
                        return;
                    }
                }
            }
            
        }
        _structSymbols = [symbols copy];
    }
    


    
    
}

- (NSString*)structName {
    
    FMAssert([_runtimeType hasPrefix:@"{"]);
    
    return FJSStructNameFromRuntimeType(_runtimeType);
}

- (FJSStructSymbol*)structFieldNamed:(NSString*)name {
    
    [self parseStruct];
    
    for (FJSStructSymbol *ss in _structSymbols) {
        if ([[ss name] isEqualToString:name]) {
            return ss;
        }
    }
    
    return nil;
}

- (NSArray*)structFields {
    [self parseStruct];
    return _structSymbols;
}

- (size_t)structSize {
    
    #pragma message "FIXME: Add an assertion that we're a struct, so we're not calling this on an argument symbol. Or maybe look up the original symbol if this is an argument?"
    
    [self parseStruct];
    
    size_t size = 0;
    for (FJSStructSymbol *ss in _structSymbols) {
        size += [ss size];
    }
    return size;
}

- (void)addArgument:(FJSSymbol*)sym {
    if (!_arguments) {
        _arguments = [NSMutableArray array];
    }
    
    [_arguments addObject:sym];
}

- (void)addClassMethod:(FJSSymbol*)sym {
    if (!_classMethods) {
        _classMethods = [NSMutableArray array];
    }
    
    [_classMethods addObject:sym];
}

- (void)addInstanceMethod:(FJSSymbol*)sym {
    if (!_instanceMethods) {
        _instanceMethods = [NSMutableArray array];
    }
    
    [_instanceMethods addObject:sym];
}

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@: %p %@ %@>", NSStringFromClass([self class]), (void*)self, _name, _runtimeType];
}

#pragma message "FIXME: We can't override init with initInFJSRuntime:, which is a bummer. How about flopping around the order of checks in methodNamed: so that we can?"
- (void)methodNamesForInFJSRuntime:(NSString*)methodName getNoArgs:(NSString*__autoreleasing*)noArgs getWithArgs:(NSString*__autoreleasing*)withArgs {
    // timeIntervalSinceNow      -> timeIntervalSinceNowInFJSRuntime:
    // dateByAddingTimeInterval  -> dateByAddingTimeInterval:inFJSRuntime:
    // dateByAddingTimeInterval: -> dateByAddingTimeInterval:inFJSRuntime:
    
    *noArgs   = [methodName stringByAppendingString:@"InFJSRuntime:"];
    *withArgs = [methodName stringByAppendingString:@":inFJSRuntime:"];
}


- (FJSSymbol*)methodNamed:(NSString*)methodName isClass:(BOOL)isClassMethod {
    
    methodName = [methodName stringByReplacingOccurrencesOfString:@"_" withString:@":"];
    
    NSString *methodNameWithArgAdded = [methodName stringByAppendingString:@":"];
    NSString *inFJSRuntimeNA, *inFJSRuntimeA;
    [self methodNamesForInFJSRuntime:methodName getNoArgs:&inFJSRuntimeNA getWithArgs:&inFJSRuntimeA];

    assert([[self symbolType] isEqualToString:@"class"]);
    
    NSArray *methodLookupOrder = @[inFJSRuntimeNA, inFJSRuntimeA, methodName, methodNameWithArgAdded];
    for (FJSSymbol *sym in isClassMethod ? _classMethods : _instanceMethods) {
        for (NSString *methodLookup in methodLookupOrder) {
            if ([[sym name] isEqualToString:methodLookup]) {
                return sym;
            }
        }
    }
    
    // Let's look in bridge support for superclass instances of this method.
    Class superClass = [NSClassFromString(_name) superclass];
    while (superClass) {
        NSString *superClassName = NSStringFromClass(superClass);
        FJSSymbol *superClassSymbol = [FJSSymbol symbolForName:superClassName];
        if (superClassSymbol) {
            FJSSymbol *methodSymbol = [superClassSymbol methodNamed:methodName isClass:isClassMethod];
            if (methodSymbol) {
                return methodSymbol;
            }
        }
        
        superClass = [superClass superclass];
    }
    
    
    
    // OK, it wasn't part of the bridge xml file. Let's look it up in the runtime.
    Class c = NSClassFromString([self name]);
    assert(c); // We have to exist, right?
    
    SEL selector = nil;
    Method method = nil;
    
    for (NSString *methodLookup in methodLookupOrder) {
        selector = NSSelectorFromString(methodLookup);
        method = isClassMethod ? class_getClassMethod(c, selector) : class_getInstanceMethod(c, selector);
        if (method) {
            methodName = methodLookup;
            break;
        }
    }
    
    if (method) {
        
        FJSSymbol *methodSymbol = [FJSSymbol new];
        [methodSymbol setName:methodName];
        [methodSymbol setSymbolType:@"method"];
        
        NSMethodSignature *methodSignature = isClassMethod ? [c methodSignatureForSelector:selector] : [c instanceMethodSignatureForSelector:selector];
        assert(methodSignature);
        
        if ([methodSignature methodReturnType]) {
            FJSSymbol *returnValue = [FJSSymbol new];
            [returnValue setRuntimeType:[NSString stringWithFormat:@"%s", [methodSignature methodReturnType]]];
            [returnValue setSymbolType:@"retval"];
            [methodSymbol setReturnValue:returnValue];
        }
        
        
        for (NSUInteger idx = 2; idx < [methodSignature numberOfArguments]; idx++) {
            
            if (![methodSymbol arguments]) {
                [methodSymbol setArguments:[NSMutableArray array]];
            }
            
            FJSSymbol *argument = [FJSSymbol new];
            [argument setRuntimeType:[NSString stringWithFormat:@"%s", [methodSignature getArgumentTypeAtIndex:idx]]];
            [[methodSymbol arguments] addObject:argument];
        }
        
        
        [(isClassMethod ? [self classMethods] : [self instanceMethods]) addObject:methodSymbol];
        
        return methodSymbol;
    }
    
    return nil;
    
}

+ (FJSSymbol*)symbolForBlockTypeEncoding:(const char*)typeEncoding {
    
    NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:typeEncoding];
#pragma message "FIXME: Refactor symbolForBlockTypeEncoding with methodNamed:(NSString*)methodName isClass:(BOOL)isClassMethod"
    FJSSymbol *methodSymbol = [FJSSymbol new];
    [methodSymbol setName:[NSString stringWithFormat:@"%s", typeEncoding]];
    [methodSymbol setSymbolType:@"block"];
    
    if ([methodSignature methodReturnType]) {
        FJSSymbol *returnValue = [FJSSymbol new];
        [returnValue setRuntimeType:[NSString stringWithFormat:@"%s", [methodSignature methodReturnType]]];
        [returnValue setSymbolType:@"retval"];
        [methodSymbol setReturnValue:returnValue];
    }
    
    for (NSUInteger idx = 1; idx < [methodSignature numberOfArguments]; idx++) {
        
        if (![methodSymbol arguments]) {
            [methodSymbol setArguments:[NSMutableArray array]];
        }
        
        FJSSymbol *argument = [FJSSymbol new];
        [argument setRuntimeType:[NSString stringWithFormat:@"%s", [methodSignature getArgumentTypeAtIndex:idx]]];
        [[methodSymbol arguments] addObject:argument];
    }
    
    return methodSymbol;
}

- (FJSSymbol*)classMethodNamed:(NSString*)name {
    return [self methodNamed:name isClass:YES];
}

- (FJSSymbol*)instanceMethodNamed:(NSString*)name {
    return [self methodNamed:name isClass:NO];
}


+ (FJSSymbol*)symbolForName:(NSString*)name {
    return [self symbolForName:name inObject:nil];
}

+ (FJSSymbol*)symbolForName:(NSString*)name inObject:(nullable id)object {
    
    if (!object) {
        // This is just a simple lookup.
        
        FJSSymbol *sym = [[[FJSSymbolManager sharedManager] symbols] objectForKey:name];
        
        if (!sym) {
            // Maybe we're looking for a class that's not in bridge support?
            // Let's check the objc runtime. Or should we look at superclasses?
            
            Class objCClass = NSClassFromString(name);
            if (objCClass) {
                sym = [[FJSSymbol alloc] init];
                [sym setSymbolType:@"class"];
                [sym setName:name];
                
                [[FJSSymbolManager sharedManager] addSymbol:sym];
            }
        }
        
        return sym;
    }
    
    return [self methodSymbolNamed:name inClass:[object class] isClassMethod:(object == [object class])];
    
}

+ (FJSSymbol*)methodSymbolNamed:(NSString*)name inClass:(Class)class isClassMethod:(BOOL)isClassMethod {
    
    FMAssert(name);
    FMAssert(class);
    
    // Let's find our class symbol first.
    FJSSymbol *classSymbol = [self symbolForName:NSStringFromClass(class) inObject:nil];
    
    FJSSymbol *methodSymbol = [classSymbol methodNamed:name isClass:isClassMethod];
    
    return methodSymbol;
}

+ (FJSSymbol*)symbolForCFType:(NSString*)cftype {
    
    cftype = [cftype stringByReplacingOccurrencesOfString:@"^{__" withString:@"^{"];
    
    return [[[FJSSymbolManager sharedManager] cfTypeToSymbolLUT] objectForKey:cftype];
}

- (BOOL)returnsRetained {
    
    if (_cfTypeReturnsRetained) {
        return YES;
    }
    
    // FIXME: Maybe look up the actual +1 rules. Isn't it create anywhere in the name? Holy shit I wish bridge.xml files had returns_retained in there.
    if ([_symbolType isEqualToString:@"method"]) {
        return ([_name isEqualToString:@"new"] || [_name isEqualToString:@"init"] || [_name isEqualToString:@"copy"] || [_name isEqualToString:@"mutableCopy"] || [_name hasPrefix:@"create"]);
    }
    
    NSLog(@"Programming error: asking if returnsRetained on a symbol of type: %@", _symbolType);
    FMAssert(NO);
    
    return NO;
}

- (BOOL)isPointer {
    
    if ([_runtimeType hasPrefix:@"^"]) {
        return YES;
    }
    
    return NO;
    
}


- (void)unmangleCFArgs {
    
    // ^{__CFAllocator=}'/>
    
    /*
    Gus, this is where you are promiting ^{CGImage=} to CGImageRef
    
    <function name='CGImageCreateCopy'>
    <arg type='^{CGImage=}'/>
    <retval already_retained='true' type='^{CGImage=}'/>
    </function>*/
}

@end


@implementation FJSStructSymbol

@end
