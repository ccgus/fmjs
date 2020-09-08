#import "FJSRuntimeCallbacks.h"
#import "FJS.h"
#import "FJSPrivate.h"
#import <objc/runtime.h>
#import <dlfcn.h>


static void FJS_initialize(JSContextRef ctx, JSObjectRef object);
static void FJS_finalize(JSObjectRef object);
JSValueRef FJS_getProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS, JSValueRef *exception);
static bool FJS_setProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS, JSValueRef value, JSValueRef* exception);
static bool FJS_hasProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName);
static JSObjectRef FJS_callAsConstructor(JSContextRef ctx, JSObjectRef constructor, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);
static JSValueRef FJS_callAsFunction(JSContextRef ctx, JSObjectRef functionJS, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception);
static JSValueRef FJS_convertToType(JSContextRef ctx, JSObjectRef object, JSType type, JSValueRef* exception);
static bool FJS_deleteProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception);
static void FJS_getPropertyNames(JSContextRef ctx, JSObjectRef object, JSPropertyNameAccumulatorRef propertyNames);
static bool FJS_hasInstance(JSContextRef ctx, JSObjectRef constructor, JSValueRef possibleInstance, JSValueRef* exception);

static JSValueRef FJSPrototypeForOBJCInstance(JSContextRef ctx, id instance, NSString *name);

@implementation FJSRuntime (JSCallbacks)


- (void)setupJSCallbacks {
    
    JSClassDefinition COSGlobalClassDefinition  = kJSClassDefinitionEmpty;
    COSGlobalClassDefinition.className          = "FMJSClass";
    COSGlobalClassDefinition.initialize         = FJS_initialize;
    COSGlobalClassDefinition.finalize           = FJS_finalize;
    COSGlobalClassDefinition.hasProperty        = FJS_hasProperty; // If we don't have this, getProperty gets called twice.
    COSGlobalClassDefinition.getProperty        = FJS_getProperty;
    COSGlobalClassDefinition.setProperty        = FJS_setProperty;
    COSGlobalClassDefinition.deleteProperty     = FJS_deleteProperty;
    COSGlobalClassDefinition.getPropertyNames   = FJS_getPropertyNames;
    
    COSGlobalClassDefinition.callAsFunction     = FJS_callAsFunction;
    COSGlobalClassDefinition.callAsConstructor  = FJS_callAsConstructor;
    COSGlobalClassDefinition.hasInstance        = FJS_hasInstance;
    
    COSGlobalClassDefinition.convertToType      = FJS_convertToType;
    
    [self setGlobalClass:JSClassCreate(&COSGlobalClassDefinition)];
}



- (void)initializeJSObjectRef:(JSObjectRef)object {
    
}



- (BOOL)object:(FJSValue*)objectValue hasProperty:(NSString *)propertyName {
    
    
    if ([objectValue isInstance]) {
        
        id objectValueInstance = [objectValue instance];
        
        if ([objectValueInstance respondsToSelector:@selector(hasFJSValueForKeyedSubscript:inRuntime:)]) {
            if ([objectValueInstance hasFJSValueForKeyedSubscript:propertyName inRuntime:self]) {
                return YES;
            }
        }
        
        // Only return true on finds, because otherwise we'll miss things like objectForKey: and objectAtIndex:
        if ([objectValueInstance respondsToSelector:@selector(objectForKeyedSubscript:)]) {
            if ([objectValueInstance objectForKeyedSubscript:propertyName]) {
                return YES;
            }
        }
        
        if (FJSStringIsNumber(propertyName) && [objectValueInstance respondsToSelector:@selector(objectAtIndexedSubscript:)]) {
            if ([objectValueInstance objectAtIndexedSubscript:[propertyName integerValue]]) {
                return YES;
            }
        }
        
        
//        if ([propertyName isEqualToString:@"Symbol.toPrimitive"]) {
//            return ([objectValueInstance isKindOfClass:[NSNumber class]] || [objectValueInstance isKindOfClass:[NSString class]]);
//        }
    }
    
    if ([objectValue isInstance] || [objectValue isClass]) {
        
        FJSSymbol *symbol = [FJSSymbol symbolForName:propertyName inObject:[objectValue instance]];
        
        if (symbol) {
            return YES;
        }
        
        if (![propertyName isEqualToString:@"Symbol.toPrimitive"]) {
            @try {
                [[objectValue instance] valueForKey:propertyName];
                return YES;
            } @catch (NSException *exception) {
                ;// pass
            }
        }
    }
    
    
    if ([objectValue isStruct]) {
        
        FJSSymbol *structSym = [objectValue symbol];
        FMAssert(structSym);
        
        NSString *name = [structSym structName];
        
        FJSSymbol *structInfoSym = [FJSSymbol symbolForName:name];
        
        return [structInfoSym structFieldNamed:propertyName] != nil;
    }
    
    FJSSymbol *symbol = [FJSSymbol symbolForName:propertyName];
    
    if (symbol) {
        return YES;
    }
    
    /*
    if ([propertyName isEqualToString:@"prototype"] && [objectValue isClass]) {
        return YES;
    }
    */
    
    id object = [objectValue isInstance] ? [objectValue toObject] : nil;
    if ([object isKindOfClass:[NSString class]] || [object isKindOfClass:[NSArray class]]) {
        // special case bridging of NSString & NSArray w/ JS functions
        
        if (FJSPrototypeForOBJCInstance([self contextRef], object, propertyName)) {
            return YES;
        }
        
        if ([object isKindOfClass:[NSArray class]]) {
            if ([propertyName isEqualToString:@"length"]) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (JSValueRef)getProperty:(NSString*)propertyName inObject:(FJSValue*)valueFromJSObject exception:(JSValueRef *)exception {
    
    if ([propertyName isEqualToString:@"toString"] || [propertyName isEqualToString:@"Symbol.toStringTag"]/* || [propertyName isEqualToString:@"Symbol.toPrimitive"]*/) {
        // This can be used in a debugger.
        return [valueFromJSObject toJSString];
    }
    
    // FIXME: package this up in FJSValue, or maybe some other function?
    // Hey, let's look for keyed subscripts!
    if ([valueFromJSObject isInstance]) {
        
        id objectUnwrapped = [valueFromJSObject toObject];
        id objcSubscriptedObjectToReturn = nil;
        
        if ([objectUnwrapped respondsToSelector:@selector(FJSValueForKeyedSubscript:inRuntime:)]) {
            FJSValue *v = [objectUnwrapped FJSValueForKeyedSubscript:propertyName inRuntime:self];
            if (v) {
                return [v JSValueRef];
            }
        }
        
        if (!objcSubscriptedObjectToReturn && [objectUnwrapped respondsToSelector:@selector(objectForKeyedSubscript:)]) {
            objcSubscriptedObjectToReturn = [objectUnwrapped objectForKeyedSubscript:propertyName];
        }
        
        if (!objcSubscriptedObjectToReturn && FJSStringIsNumber(propertyName) && [objectUnwrapped respondsToSelector:@selector(objectAtIndexedSubscript:)]) {
            objcSubscriptedObjectToReturn = [objectUnwrapped objectAtIndexedSubscript:[propertyName integerValue]];
        }
        
        #pragma message "FIXME: How are we going to add Symbol.toPrimitive to classes? maybe add a FMJSSymbolToPrimitive:(NSString*)hint to classes that want it?"
        // Symbol.toPrimitive needs to be a function, undefined, or null
        // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Symbol/toPrimitive
        /*
        if ([propertyName isEqualToString:@"Symbol.toPrimitive"]) {
            if ([objectUnwrapped isKindOfClass:[NSNumber class]] || [objectUnwrapped isKindOfClass:[NSString class]]) {
                
                FJSValue *v = self[@"FMJSSymbolToPrimative"];
                FMAssert(v);
                return [v JSValueRef];
                
                //objcSubscriptedObject = objectUnwrapped;
            }
            else {
                FMAssert(NO); // What else are we tryign to conver to a primative?
            }
        }*/
        
        if ([objectUnwrapped isKindOfClass:[NSString class]] || [objectUnwrapped isKindOfClass:[NSArray class]]) {
            // special case bridging of NSString & NSArray w/ JS functions
            
            JSValueRef jsPropertyValue = FJSPrototypeForOBJCInstance([self contextRef], objectUnwrapped, propertyName);
            if (jsPropertyValue) {
                return jsPropertyValue;
            }
            
            if ([objectUnwrapped isKindOfClass:[NSArray class]]) {
                // special case this property.
                if ([propertyName isEqualToString:@"length"]) {
                    return JSValueMakeNumber([self contextRef], [objectUnwrapped count]);
                }
            }
        }
        
        
        
        
        
        
        if (objcSubscriptedObjectToReturn) {
            
            JSValueRef subscriptedJSValue = nil;
            subscriptedJSValue = FJSNativeObjectToJSValue(objcSubscriptedObjectToReturn, [self contextRef]); // Check and see if we can convert objc numbers, strings, or NSNulls to native js types.
            if (!subscriptedJSValue) { // OK, we don't have a JS native type, so we'll wrap it up as it is.
                FJSValue *value = [FJSValue valueWithInstance:(__bridge CFTypeRef)(objcSubscriptedObjectToReturn) inRuntime:self];
                subscriptedJSValue = [value JSValueRef];
                // We were doing this, which does a +1 on the value. But… that's a leak, right?
                // subscriptedJSValue = [self newJSValueForWrapper:value];
            }
            return subscriptedJSValue;
        }
        
    }
    
    if ([valueFromJSObject isStruct]) {
        
        FJSValue *value = [valueFromJSObject valueFromStructFieldNamed:propertyName];
        
        return [value JSValueRef];
    }
    
    
    
    
    
    id objectLookup = ([valueFromJSObject isInstance] || [valueFromJSObject isClass]) ? [valueFromJSObject instance] : nil;
    
    FJSSymbol *sym = [FJSSymbol symbolForName:propertyName inObject:objectLookup];
    
    if (sym) {
        
        if ([[sym symbolType] isEqualToString:@"function"] || [[sym symbolType] isEqualToString:@"method"]) {
            
            FJSValue *value = [FJSValue valueWithSymbol:sym inRuntime:self];
            
            JSValueRef jsValue = [self newJSValueForWrapper:value];
            
            return jsValue;
        }
        else if ([[sym symbolType] isEqualToString:@"class"]) {
            
            Class class = NSClassFromString(propertyName);
            assert(class);
            
            FJSValue *value = [FJSValue valueWithSymbol:sym inRuntime:self];
            
            [value setClass:class];
            
            return [value JSValueRef];
        }
        else if ([[sym symbolType] isEqualToString:@"enum"]) {
            return JSValueMakeNumber([self contextRef], [[sym runtimeValue] doubleValue]);
        }
        else if ([[sym symbolType] isEqualToString:@"constant"]) {
            
            // Grab symbol
            void *dlsymbol = dlsym(RTLD_DEFAULT, [propertyName UTF8String]);
            assert(dlsymbol);
            
            if (dlsymbol) {
                
                FJSValue *value = [FJSValue valueWithConstantPointer:dlsymbol withSymbol:sym inRuntime:self];
                
                JSValueRef jsValue = [self newJSValueForWrapper:value];
                
                return jsValue;
                
            }
        }
    }
    
    if ([valueFromJSObject isInstance]) {
        @try {
            id object = [[valueFromJSObject instance] valueForKey:propertyName];
            
            FJSValue *value = [FJSValue valueWithInstance:(__bridge CFTypeRef _Nonnull)(object) inRuntime:self];
            
            return [value JSValueRef];
            
        } @catch (NSException *exception) {
            ;
        }
    }
    
    // Hey gus, if we want to be able to extend nsobjects, we need to do this:
    /*
    if ([propertyName isEqualToString:@"prototype"] && [valueFromJSObject isClass]) {
        
        JSStringRef jsName = JSStringCreateWithUTF8CString("Object");
        JSValueRef jsValue = JSObjectGetProperty([self contextRef], JSContextGetGlobalObject([self contextRef]), jsName, exception);
        JSStringRelease(jsName);
        
        jsName = JSStringCreateWithUTF8CString("prototype");
        JSValueRef jsPrototypeValue = JSObjectGetProperty([self contextRef], JSValueToObject([self contextRef], jsValue, nil), jsName, exception);
        JSStringRelease(jsName);
        
        return jsPrototypeValue;
    }
    */
    
    id object = [valueFromJSObject isInstance] ? [valueFromJSObject toObject] : nil;
    if ([object isKindOfClass:[NSString class]] || [object isKindOfClass:[NSArray class]]) {
        // special case bridging of NSString & NSArray w/ JS functions
        
        JSValueRef jsPropertyValue = FJSPrototypeForOBJCInstance([self contextRef], object, propertyName);
        if (jsPropertyValue) {
            return jsPropertyValue;
        }
        
        if ([object isKindOfClass:[NSArray class]]) {
            // special case this property.
            if ([propertyName isEqualToString:@"length"]) {
                return JSValueMakeNumber([self contextRef], [object count]);
            }
        }
    }
    
    
    return nil;
}


- (BOOL)setValue:(FJSValue*)arg forProperty:(NSString*)propertyName inObject:(FJSValue*)valueFromJSObject exception:(JSValueRef*)exception {
    
    if ([valueFromJSObject isStruct]) {
        BOOL worked = [valueFromJSObject setValue:arg onStructFieldNamed:propertyName];
        return worked;
    }
    
    if ([valueFromJSObject isInstance]) {
        // If we got here, it's probobably in the format foo.bar = 123; So let's rewrite it to setBar:?
        
        @try {
            
            if ([[valueFromJSObject instance] respondsToSelector:@selector(setFJSValue:forKeyedSubscript:inRuntime:)]) {
                if ([[valueFromJSObject instance] setFJSValue:arg forKeyedSubscript:propertyName inRuntime:self]) {
                    return YES;
                }
            }
            
            if ([[valueFromJSObject instance] respondsToSelector:@selector(setObject:forKeyedSubscript:)]) {
                [[valueFromJSObject instance] setObject:[arg toObject] forKeyedSubscript:propertyName];
                return YES;
            }
            
            if (FJSStringIsNumber(propertyName) && [[valueFromJSObject instance] respondsToSelector:@selector(setObject:atIndexedSubscript:)]) {
                [[valueFromJSObject instance] setObject:[arg toObject] atIndexedSubscript:[propertyName integerValue]];
                return YES;
            }
        }
        @catch (NSException * e) {
            [self reportNSException:e];
            return NO;
        }
        
        NSString *setName = [[propertyName substringToIndex:1] uppercaseString];
        setName = [setName stringByAppendingString:[propertyName substringFromIndex:1]];
        setName = [NSString stringWithFormat:@"set%@:", setName];
        
        if ([[valueFromJSObject instance] respondsToSelector:NSSelectorFromString(setName)]) {
            
            FJSSymbol *setterMethod = [FJSSymbol symbolForName:setName inObject:[valueFromJSObject instance]];
            FJSValue *setterValue = [FJSValue valueWithSymbol:setterMethod inRuntime:self];
            
            FJSFFI *ffi = [FJSFFI ffiWithFunction:setterValue caller:valueFromJSObject arguments:@[arg] runtime:self];
            
            [ffi callFunction];
            
            return YES;
        }
        
        NSError *outErr;
        id obj = [arg toObject];
        if ([[valueFromJSObject instance] validateValue:&obj forKey:propertyName error:&outErr]) {
            @try {
                [[valueFromJSObject instance] setValue:obj forKey:propertyName];
            }
            @catch (NSException *e) {
                
                *exception = FJSNativeObjectToJSValue(e, [self contextRef]);
                
                //[self reportNSException:e];
                return NO;
            }
            return YES;
        }
        
    }
    
    return NO;
}


- (JSValueRef)invokeFunction:(FJSValue*)function onObject:(FJSValue*)object withArguments:(NSArray*)args exception:(JSValueRef *)exception {
    
    BOOL needsToPushRuntime = ![FJSRuntime currentRuntime];
    if (needsToPushRuntime) {
        [self pushAsCurrentFJS];
    }
    else if ([FJSRuntime currentRuntime] != self) {
        // WTF is going on? Is one runtime calling into another? Oh wait- we've go tests set to multi-threaded. Yep, we can ocassionally crash here.
        assert(NO);
    }
    
    
    if (FJSTraceFunctionCalls) {
        NSLog(@"FJS_callAsFunction: '%@'", [[function symbol] name]);
    }
    
    
    FJSFFI *ffi = [FJSFFI ffiWithFunction:function caller:object arguments:args runtime:self];
    
    FJSValue *ret = [ffi callFunction];
    
    // unwrap does a +1 retain on the value returned. Otherwise it'll be quickly removed from the runtime.
    FMAssert([ret isKindOfClass:[FJSValue class]]);
    ret = [ret unwrapValue];
    
    FMAssert(ret);
    
    JSValueRef returnRef = [ret JSValueRef];
    FMAssert(returnRef);
    
    if (needsToPushRuntime) {
        [self popAsCurrentFJS];
    }
    
    return returnRef;
}

- (JSValueRef)convertObject:(FJSValue*)valueObject toType:(JSType)type exception:(JSValueRef*)exception {
    
    if ([valueObject isInstance] || [valueObject isBlock] || [valueObject isClass] || [[[valueObject symbol] runtimeType] hasPrefix:@"^{C"]) {
        
        id o = [valueObject instance];
        
        if (!o) {
            return JSValueMakeNull([self contextRef]);
        }
        
        if (type == kJSTypeNumber) {
            
            if ([o isKindOfClass:[NSNumber class]] || (([o isKindOfClass:[NSString class]] && FJSStringIsNumber(o)))) {
                return JSValueMakeNumber([self contextRef], [o doubleValue]);
            }
        }
        
        // Fuck it, you're getting a string.
        JSStringRef string = JSStringCreateWithCFString((__bridge CFStringRef)[o description]);
        JSValueRef value = JSValueMakeString([self contextRef], string);
        JSStringRelease(string);
        return value;
    }
    
    if ([valueObject isStruct]) {
        
        NSString *s = [valueObject structToString];
        
        if (s) {
            JSStringRef string = JSStringCreateWithCFString((__bridge CFStringRef)s);
            JSValueRef value = JSValueMakeString([self contextRef], string);
            JSStringRelease(string);
            return value;
        }
        
        return JSValueMakeNull([self contextRef]);
    }
    
    return JSValueMakeNumber([self contextRef], [valueObject toDouble]);
}


@end

static void FJS_initialize(JSContextRef ctx, JSObjectRef object) {
    
    FJSRuntime *runtime = [FJSRuntime runtimeInContext:ctx];
    [runtime initializeJSObjectRef:object];
    
}

static bool FJS_hasProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS) {
    NSString *propertyName = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, propertyNameJS));
    if ([propertyName isEqualToString:FJSRuntimeLookupKey] || [propertyName isEqualToString:@"Object"]) {
        return NO;
    }
    
    FJSRuntime *runtime = [FJSRuntime runtimeInContext:ctx];
    
    FJSValue *fobj = [FJSValue valueWithJSValueRef:object inRuntime:runtime];
    
    return [runtime object:fobj hasProperty:propertyName];
}


JSValueRef FJS_getProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS, JSValueRef *exception) {
    NSString *propertyName = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, propertyNameJS));
    if ([propertyName isEqualToString:FJSRuntimeLookupKey] || [propertyName isEqualToString:@"Object"]) {
        return nil;
    }
    
    FJSRuntime *runtime = [FJSRuntime runtimeInContext:ctx];
    FJSValue *valueFromJSObject = [FJSValue valueWithJSValueRef:object inRuntime:runtime];
    
    JSValueRef propertyValueRef = [runtime getProperty:propertyName inObject:valueFromJSObject exception:exception];
    
    return propertyValueRef;
}

static bool FJS_deleteProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {
    return NO;
}

static void FJS_getPropertyNames(JSContextRef ctx, JSObjectRef object, JSPropertyNameAccumulatorRef propertyNames) {
    
}


static bool FJS_setProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS, JSValueRef value, JSValueRef* exception) {
    NSString *propertyName = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, propertyNameJS));
    if ([propertyName isEqualToString:FJSRuntimeLookupKey]) {
        return NO;
    }
    
    if (!JSObjectGetPrivate(object)) { // We didn't make this object.
        return NO;
    }
    
    FJSRuntime *runtime  = [FJSRuntime runtimeInContext:ctx];
    FJSValue *fvalue     = [FJSValue valueWithJSValueRef:value inRuntime:runtime];
    FJSValue *fobject    = [FJSValue valueWithJSValueRef:object inRuntime:runtime];
    
    return [runtime setValue:fvalue forProperty:propertyName inObject:fobject exception:exception];
}

static JSObjectRef FJS_callAsConstructor(JSContextRef ctx, JSObjectRef constructor, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception) {
    return nil;
}

static bool FJS_hasInstance(JSContextRef ctx, JSObjectRef constructor, JSValueRef possibleInstance, JSValueRef* exception) {
    return NO;
}


static JSValueRef FJS_callAsFunction(JSContextRef context, JSObjectRef functionJS, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception) {
    
    FJSRuntime *runtime = [FJSRuntime runtimeInContext:context];
    
    // FIXME: Is there anyway to tell the array that the FJSValues are read only?
    NSMutableArray *args = [NSMutableArray arrayWithCapacity:argumentCount];
    for (size_t idx = 0; idx < argumentCount; idx++) {
        JSValueRef jsArg = arguments[idx];
        FJSValue *arg = [FJSValue valueWithJSValueRef:jsArg inRuntime:runtime];
        assert(arg);
        [args addObject:arg];
    }
    
    FJSValue *objectToCall   = [FJSValue valueWithJSValueRef:thisObject inRuntime:runtime];
    FJSValue *functionToCall = [FJSValue valueWithJSValueRef:functionJS inRuntime:runtime];
    
    return [runtime invokeFunction:functionToCall onObject:objectToCall withArguments:args exception:exception];
}

// This function is only invoked when converting an object to number or string
static JSValueRef FJS_convertToType(JSContextRef context, JSObjectRef object, JSType type, JSValueRef* exception) {
    FJSRuntime *runtime       = [FJSRuntime runtimeInContext:context];
    FJSValue *objectToConvert = [FJSValue valueWithJSValueRef:object inRuntime:runtime];
    
    return [runtime convertObject:objectToConvert toType:type exception:exception];
    
}

static void FJS_finalize(JSObjectRef object) {
    
    CFTypeRef value = JSObjectGetPrivate(object);
    
    if (value) {
        
        if ([(__bridge id)value isKindOfClass:[FJSValue class]]) {
            FMAssert(![(__bridge FJSValue*)value isJSNative]); // Sanity.
            
            [(__bridge FJSValue*)value setDebugFinalizeCalled:YES];
            
            FJSRuntime *rt = [(__bridge FJSValue*)value runtime];
            
            if ([rt finalizeHandler]) {
                [rt finalizeHandler](rt, (__bridge FJSValue*)value);
            }
        }
        else {
            FMAssert([(__bridge id)value isKindOfClass:[FJSValue class]]); // When isn't this the case?
        }
        
        CFRelease(value);
    }
}


static JSValueRef FJSPrototypeForOBJCInstance(JSContextRef ctx, id instance, NSString *name) {
    
    char *propName = nil;
    if ([instance isKindOfClass:[NSString class]]) {
        propName = "String";
    }
    else if ([instance isKindOfClass:[NSArray class]]) {
        propName = "Array";
    }
    
    if (!propName) {
        return nil;
    }
    
    JSValueRef exception = nil;
    JSStringRef jsPropertyName = JSStringCreateWithUTF8CString(propName);
    JSValueRef jsPropertyValue = JSObjectGetProperty(ctx, JSContextGetGlobalObject(ctx), jsPropertyName, &exception);
    JSStringRelease(jsPropertyName);
    
    jsPropertyName = JSStringCreateWithUTF8CString("prototype");
    jsPropertyValue = JSObjectGetProperty(ctx, JSValueToObject(ctx, jsPropertyValue, nil), jsPropertyName, &exception);
    JSStringRelease(jsPropertyName);
    
    jsPropertyName = JSStringCreateWithUTF8CString([name UTF8String]);
    jsPropertyValue = JSObjectGetProperty(ctx, JSValueToObject(ctx, jsPropertyValue, nil), jsPropertyName, &exception);
    JSStringRelease(jsPropertyName);
    
    if (jsPropertyValue && JSValueGetType(ctx, jsPropertyValue) == kJSTypeObject) {
        // OK, there's a JS String method with the same name as propertyName.  Let's use that.
        return jsPropertyValue;
    }
    
    return nil;
}

