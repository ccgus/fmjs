//
//  FJSRuntime.m
//  yd
//
//  Created by August Mueller on 8/20/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//
// I wish we could dynamically add the JSExport protocol to things at runtime, but it requires extended type info :(
// https://brandonevans.ca/post/text/dynamically-exporting-objective-c-classes-to/
//

#import "FJS.h"
#import "FJSRuntime.h"
#import "FJSPrivate.h"


#import <objc/runtime.h>
#import <dlfcn.h>

NSString *FMJavaScriptExceptionName = @"FMJavaScriptException";
const CGRect FJSRuntimeTestCGRect = {74, 78, 11, 16};
static const void * const kDispatchQueueSpecificKey = &kDispatchQueueSpecificKey;

@interface FJSRuntime () {
    
}

@property (weak) FJSRuntime *previousRuntime;
@property (assign) JSGlobalContextRef jsContext;
@property (assign) JSClassRef globalClass;
@property (strong) dispatch_queue_t evaluateQueue;

@end

#define FJSRuntimeLookupKey @"fmjs"

static FJSRuntime *FJSCurrentRuntime;

static void FJS_initialize(JSContextRef ctx, JSObjectRef object);
static void FJS_finalize(JSObjectRef object);
JSValueRef FJS_getProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS, JSValueRef *exception);
static bool FJS_hasProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName);
static JSValueRef FJS_callAsFunction(JSContextRef ctx, JSObjectRef functionJS, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception);

@implementation FJSRuntime

+ (FJSRuntime*)currentRuntime {
    return FJSCurrentRuntime;
}

+ (instancetype)runtimeInContext:(JSContextRef)context {
    
    JSValueRef exception = NULL;
    
    JSStringRef jsName = JSStringCreateWithUTF8CString([FJSRuntimeLookupKey UTF8String]);
    JSValueRef jsValue = JSObjectGetProperty(context, JSContextGetGlobalObject(context), jsName, &exception);
    JSStringRelease(jsName);
    
    if (exception != NULL) {
        FMAssert(NO);
        return NULL;
    }
    
    FJSValue *value = (__bridge FJSValue *)JSObjectGetPrivate((JSObjectRef)jsValue);
    
    return [value instance];
}


- (instancetype)init {
    self = [super init];
    if (self) {
        
        NSString *FMJSBridgeSupportPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"FJS" ofType:@"bridgesupport"];
        
        if (FMJSBridgeSupportPath) {
            [[FJSSymbolManager sharedManager] parseBridgeFileAtPath:FMJSBridgeSupportPath];
        }
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [FJSRuntime loadFrameworkAtPath:@"/System/Library/Frameworks/Foundation.framework"];
            [FJSRuntime loadFrameworkAtPath:@"/System/Library/Frameworks/AppKit.framework"];
            [FJSRuntime loadFrameworkAtPath:@"/System/Library/Frameworks/CoreGraphics.framework"];
            [FJSRuntime loadFrameworkAtPath:@"/System/Library/Frameworks/CoreImage.framework"];
            
            NSString *xml =
                @"<signatures version='1.0'>"
                    "<function name='print'>"
                        "<arg type='@'/>"
                    "</function>"
                "</signatures>";
            
            [[FJSSymbolManager sharedManager] parseBridgeString:xml];
            
        });
        
        _evaluateQueue = dispatch_queue_create([[NSString stringWithFormat:@"fmjs.evaluateQueue.%p", self] UTF8String], NULL);
        dispatch_queue_set_specific(_evaluateQueue, kDispatchQueueSpecificKey, (__bridge void *)self, NULL);

        [self setupJS];
    }
    
    return self;
}

- (void)dealloc {
    [self shutdown];
}

- (void)setupJS {
    
    FMAssert(!_jsContext);
    if (_jsContext) {
        NSLog(@"Attempting to recreate a JSGlobalContext on %@ when one already exists", self);
        return;
    }
    
    
    JSClassDefinition COSGlobalClassDefinition  = kJSClassDefinitionEmpty;
    COSGlobalClassDefinition.className          = "FMJSClass";
    COSGlobalClassDefinition.getProperty        = FJS_getProperty;
    COSGlobalClassDefinition.initialize         = FJS_initialize;
    COSGlobalClassDefinition.finalize           = FJS_finalize;
    COSGlobalClassDefinition.hasProperty        = FJS_hasProperty; // If we don't have this, getProperty gets called twice.
    COSGlobalClassDefinition.callAsFunction     = FJS_callAsFunction;
    
    _globalClass                                = JSClassCreate(&COSGlobalClassDefinition);
    
    _jsContext = JSGlobalContextCreate(_globalClass);
    
    FJSValue *value = [FJSValue valueWithWeakInstance:self inRuntime:self];
    
    JSValueRef jsValue = [value JSValue];
    
    JSValueRef exception = NULL;
    JSStringRef jsName = JSStringCreateWithUTF8CString([FJSRuntimeLookupKey UTF8String]);
    JSObjectSetProperty(_jsContext, JSContextGetGlobalObject(_jsContext), jsName, jsValue, kJSPropertyAttributeReadOnly|kJSPropertyAttributeDontEnum, &exception);
    JSStringRelease(jsName);
    
    FMAssert([self runtimeObjectWithName:FJSRuntimeLookupKey] == self);
    FMAssert([FJSRuntime runtimeInContext:_jsContext]  == self);
}

- (void)shutdown {
    
    if (_jsContext) {
        
        [self deleteRuntimeObjectWithName:FJSRuntimeLookupKey];
        JSClassRelease(_globalClass);
        
        [self garbageCollect];
        
        JSGlobalContextRelease(_jsContext);
        
        _jsContext = nil;
    }
}

- (void)pushAsCurrentFJS {
    // FIXME: This doesn't nest at all.
    [self setPreviousRuntime:FJSCurrentRuntime];
    FJSCurrentRuntime = self;
}

- (void)popAsCurrentFJS {
    FJSCurrentRuntime = [self previousRuntime];
}

- (void)reportNSException:(NSException*)e {
    
    if (_exceptionHandler) {
        _exceptionHandler(self, e);
    }
    else {
        NSLog(@"Unhandled exception in FJSRuntime! Please assign an exception handler");
        NSLog(@"%@", e);
        FMAssert(NO);
    }
    
}

- (void)reportPossibleJSException:(nullable JSValueRef)exception {
    
    if (!exception) {
        return;
    }
    
    // Taken from Mocha
    NSString *error = nil;
    JSStringRef resultStringJS = JSValueToStringCopy(_jsContext, exception, NULL);
    if (resultStringJS != NULL) {
        error = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, resultStringJS));
        JSStringRelease(resultStringJS);
    }
    
    if (JSValueGetType(_jsContext, exception) != kJSTypeObject) {
        [self reportNSException:[NSException exceptionWithName:FMJavaScriptExceptionName reason:error userInfo:nil]];
    }
    else {
        // Iterate over all properties of the exception
        JSObjectRef jsObject = JSValueToObject(_jsContext, exception, NULL);
        JSPropertyNameArrayRef jsNames = JSObjectCopyPropertyNames(_jsContext, jsObject);
        size_t count = JSPropertyNameArrayGetCount(jsNames);
        
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:count];
        
        for (size_t i = 0; i < count; i++) {
            JSStringRef jsName = JSPropertyNameArrayGetNameAtIndex(jsNames, i);
            NSString *name = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, jsName));
            
            JSValueRef jsValueRef = JSObjectGetProperty(_jsContext, jsObject, jsName, NULL);
            JSStringRef valueJS = JSValueToStringCopy(_jsContext, jsValueRef, NULL);
            NSString *value = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, valueJS));
            JSStringRelease(valueJS);
            
            [userInfo setObject:value forKey:name];
        }
        
        JSPropertyNameArrayRelease(jsNames);
        
        [self reportNSException:[NSException exceptionWithName:FMJavaScriptExceptionName reason:error userInfo:userInfo]];
    }

    
    
}



- (JSContextRef)contextRef {
    return _jsContext;
}


- (BOOL)hasFunctionNamed:(NSString*)name {
    
    JSValueRef exception = nil;
    JSStringRef jsFunctionName = JSStringCreateWithUTF8CString([name UTF8String]);
    JSValueRef jsFunctionValue = JSObjectGetProperty(_jsContext, JSContextGetGlobalObject(_jsContext), jsFunctionName, &exception);
    JSStringRelease(jsFunctionName);
    
    return jsFunctionValue && (JSValueGetType(_jsContext, jsFunctionValue) == kJSTypeObject);
}

- (JSObjectRef)functionWithName:(NSString *)name {
    JSValueRef exception = NULL;
    
    // Get function as property of global object
    JSStringRef jsFunctionName = JSStringCreateWithUTF8CString([name UTF8String]);
    JSValueRef jsFunctionValue = JSObjectGetProperty(_jsContext, JSContextGetGlobalObject(_jsContext), jsFunctionName, &exception);
    JSStringRelease(jsFunctionName);
    
    if (exception) {
        [self reportPossibleJSException:exception];
        return nil;
    }
    
    return JSValueToObject(_jsContext, jsFunctionValue, NULL);
}

- (FJSValue *)callFunctionNamed:(NSString*)name withArguments:(NSArray*)arguments {
    
    FJSValue *returnValue = nil;
    
    @try {
        
        [self pushAsCurrentFJS];
        
        
        JSValueRef *jsArgumentsArray = nil;
        NSUInteger argumentsCount = [arguments count];
        if (argumentsCount) {
            jsArgumentsArray = calloc(argumentsCount, sizeof(JSValueRef));
            
            for (NSUInteger i=0; i<argumentsCount; i++) {
                id argument = [arguments objectAtIndex:i];
                
                FJSValue *v = [FJSValue valueWithInstance:(__bridge CFTypeRef)(argument) inRuntime:self];
                jsArgumentsArray[i] = [v JSValue];
            }
        }
        
        JSObjectRef jsFunction = [self functionWithName:name];
        assert((JSValueGetType(_jsContext, jsFunction) == kJSTypeObject));
        JSValueRef exception = NULL;
        //debug(@"calling function");
        JSValueRef jsFunctionReturnValue = JSObjectCallAsFunction(_jsContext, jsFunction, NULL, argumentsCount, jsArgumentsArray, &exception);
        //debug(@"called");
        
        if (jsArgumentsArray) {
            free(jsArgumentsArray);
        }
        
        if (exception) {
            [self reportPossibleJSException:exception];
            [self popAsCurrentFJS];
            return nil;
        }
        
        returnValue = [FJSValue valueForJSObject:(JSObjectRef)jsFunctionReturnValue inRuntime:self];
    }
    @catch (NSException * e) {
        
        [self reportNSException:e];
        
//        NSDictionary *d = [e userInfo];
//        if ([_errorController respondsToSelector:@selector(coscript:hadError:onLineNumber:atSourceURL:)]) {
//            [_errorController coscript:self hadError:[e reason] onLineNumber:[[d objectForKey:@"line"] integerValue] atSourceURL:nil];
//        }
    }
    
    [self popAsCurrentFJS];
    
    return returnValue;
}





- (void)deleteRuntimeObjectWithName:(NSString*)name {
    JSValueRef exception = NULL;
    JSStringRef jsName = JSStringCreateWithUTF8CString([name UTF8String]);
    JSObjectDeleteProperty(_jsContext, JSContextGetGlobalObject(_jsContext), jsName, &exception);
    JSStringRelease(jsName);
    
    [self reportPossibleJSException:exception];
    
}



- (id)runtimeObjectWithName:(NSString *)name {
    
    JSValueRef exception = NULL;
    
    JSStringRef jsName = JSStringCreateWithUTF8CString([name UTF8String]);
    JSValueRef jsValue = JSObjectGetProperty([self contextRef], JSContextGetGlobalObject([self contextRef]), jsName, &exception);
    JSStringRelease(jsName);
    
    if (exception) {
        [self reportPossibleJSException:exception];
        return NULL;
    }
    
    FJSValue *w = (__bridge FJSValue *)JSObjectGetPrivate((JSObjectRef)jsValue);
    
    return [w instance];
}

- (FJSValue*)setRuntimeObject:(nullable id)object withName:(NSString *)name {
    
    if (!object) {
        [self deleteRuntimeObjectWithName:name];
    }
    
    FJSValue *value = [FJSValue valueWithInstance:(__bridge CFTypeRef _Nonnull)(object) inRuntime:self];
    
    #pragma message "FIXME: Does this mean value is retained twice? What happens if we call JSValue on value?"
    JSValueRef jsValue = [self newJSValueForWrapper:value];
    
    // Set
    JSValueRef exception = NULL;
    JSStringRef jsName = JSStringCreateWithUTF8CString([name UTF8String]);
    JSObjectSetProperty([self contextRef], JSContextGetGlobalObject([self contextRef]), jsName, jsValue, kJSPropertyAttributeNone, &exception);
    JSStringRelease(jsName);
    
    if (exception != NULL) {
        FMAssert(NO);
        return NULL;
    }
    
    return value;
}

- (void)garbageCollect {
    JSGarbageCollect(_jsContext);
}

- (FJSValue*)evaluateScript:(NSString *)script withSourceURL:(nullable NSURL *)sourceURL {
    
    /* Get the currently executing queue (which should probably be nil, but in theory could be another DB queue
     * and then check it against self to make sure we're not about to deadlock. */
    FJSRuntime *currentSyncQueue = (__bridge id)dispatch_get_specific(kDispatchQueueSpecificKey);
    assert(currentSyncQueue != self && "evaluateScript: was called reentrantly on the same queue, which is a programmer error.");
    
    __block FJSValue *returnValue = nil;
    
    dispatch_sync(_evaluateQueue, ^{
        
        [self pushAsCurrentFJS];
        
        @try {
            
            
            JSStringRef jsString = JSStringCreateWithCFString((__bridge CFStringRef)script);
            JSStringRef jsScriptPath = (sourceURL != nil ? JSStringCreateWithUTF8CString([[sourceURL path] UTF8String]) : NULL);
            JSValueRef exception = NULL;
            
            JSValueRef result = JSEvaluateScript([self contextRef], jsString, NULL, jsScriptPath, 1, &exception);
            
            [self reportPossibleJSException:exception];
            
            if (jsString != NULL) {
                JSStringRelease(jsString);
            }
            
            if (jsScriptPath != NULL) {
                JSStringRelease(jsScriptPath);
            }
            
            returnValue = [FJSValue valueForJSObject:(JSObjectRef)result inRuntime:self];
            
        }
        @catch (NSException *exception) {
            debug(@"Exception: %@", exception);
            [self reportNSException:exception];
        }
        @finally {
            ;
        }
        
        [self popAsCurrentFJS];
        
    });
    
    return returnValue;
}

- (FJSValue*)evaluateScript:(NSString*)script {
    return [self evaluateScript:script withSourceURL:nil];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    debug(@"aSelector: '%@'?", NSStringFromSelector(aSelector));
    
    return [super respondsToSelector:aSelector];
}

+ (void)loadFrameworkAtPath:(NSString*)path {
    
    NSString *frameworkName = [[path lastPathComponent] stringByDeletingPathExtension];
    
    // Load the framework
    NSString *libPath = [path stringByAppendingPathComponent:frameworkName];
    void *address = dlopen([libPath UTF8String], RTLD_LAZY);
    if (!address) {
        NSLog(@"ERROR: Could not load framework dylib: %@, %@", frameworkName, libPath);
        return;
    }
    
    NSString *bridgeDylib = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"Resources/BridgeSupport/%@.dylib", frameworkName]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:bridgeDylib]) {
        address = dlopen([bridgeDylib UTF8String], RTLD_LAZY);
        if (!address) {
            NSLog(@"ERROR: Could not load BridgeSupport dylib: %@, %@", frameworkName, bridgeDylib);
        }
    }

    NSString *bridgeXML = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"Resources/BridgeSupport/%@.bridgesupport", frameworkName]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:bridgeXML]) {
        [[FJSSymbolManager sharedManager] parseBridgeFileAtPath:bridgeXML];
    }
}

- (JSValueRef)newJSValueForWrapper:(FJSValue*)value {
    
    // This should only be called for non-js objects.
    FMAssert(![value isJSNative]);
    
    JSObjectRef r = JSObjectMake(_jsContext, _globalClass, (__bridge void *)(value));
    CFRetain((__bridge void *)value);
    
    FMAssert(r);
    
    return r;
}

@end

static void FJS_initialize(JSContextRef ctx, JSObjectRef object) {
    
    // debug(@"initialize: %p", object);
    
    //debug(@"FJS_initialize: %@", [FJSJSWrapper wrapperForJSObject:object cos:[COScriptLite currentCOScriptLite]]);
    
    
//    debug(@"%s:%d", __FUNCTION__, __LINE__);
//    id private = (__bridge id)(JSObjectGetPrivate(object));
//    debug(@"private: '%@'", private);
//
//    if (private) {

//        CFRetain((__bridge CFTypeRef)private);

//        if (class_isMetaClass(object_getClass([private representedObject]))) {
//            debug(@"inited a global class object %@ - going to keep it protected", [private representedObject]);
//            JSValueProtect(ctx, [private JSObject]);
//        }
//    }


}

static bool FJS_hasProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS) {
    NSString *propertyName = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, propertyNameJS));
    if ([propertyName isEqualToString:FJSRuntimeLookupKey]) {
        return nil;
    }
    
    //debug(@"FJS_hasProperty: '%@'?", propertyName);
    
    FJSRuntime *runtime   = [FJSRuntime runtimeInContext:ctx];
    FJSValue *objectValue = [FJSValue valueForJSObject:object inRuntime:runtime];
    FJSSymbol *symbol     = [FJSSymbol symbolForName:propertyName inObject:[objectValue instance]];
    
    if (symbol) {
        return YES;
    }
    
    //debug(@"No property for %@", propertyName);
    
    return NO;
}


JSValueRef FJS_getProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS, JSValueRef *exception) {
    NSString *propertyName = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, propertyNameJS));
    if ([propertyName isEqualToString:FJSRuntimeLookupKey]) {
        return nil;
    }
    
    FJSRuntime *runtime = [FJSRuntime runtimeInContext:ctx];
    
    if ([propertyName isEqualToString:@"toString"] || [propertyName isEqualToString:@"Symbol.toStringTag"]/* || [propertyName isEqualToString:@"Symbol.toPrimitive"]*/) {
        FJSValue *w = [FJSValue valueForJSObject:object inRuntime:runtime];
        
        return [w toJSString];
    }
    
    FJSValue *valueFromJSObject = [FJSValue valueForJSObject:object inRuntime:runtime];
    FJSSymbol *sym = [FJSSymbol symbolForName:propertyName inObject:[valueFromJSObject instance]];
    
    if (sym) {
        
        if ([[sym symbolType] isEqualToString:@"function"] || [[sym symbolType] isEqualToString:@"method"]) {
            
            FJSValue *value = [FJSValue valueWithSymbol:sym inRuntime:runtime];
            
            JSValueRef jsValue = [runtime newJSValueForWrapper:value];
            
            return jsValue;
        }
        else if ([[sym symbolType] isEqualToString:@"class"]) {
            
            Class class = NSClassFromString(propertyName);
            assert(class);
            
            FJSValue *value = [FJSValue valueWithSymbol:sym inRuntime:runtime];
            
            [value setClass:class];
            
            JSValueRef jsValue = [runtime newJSValueForWrapper:value];
            
            return jsValue;
        }
        else if ([[sym symbolType] isEqualToString:@"enum"]) {
            return JSValueMakeNumber(ctx, [[sym runtimeValue] doubleValue]);
        }
        else if ([[sym symbolType] isEqualToString:@"constant"]) {
            
            // Grab symbol
            void *dlsymbol = dlsym(RTLD_DEFAULT, [propertyName UTF8String]);
            assert(dlsymbol);
            
            if (dlsymbol) {
                
                char type = [[sym runtimeType] characterAtIndex:0];
                
                // This is all wrong I just know it.
                void *p = type == _C_STRUCT_B ? dlsymbol : (*(void**)dlsymbol);
                
                FJSValue *value = [FJSValue valueWithConstantPointer:p ofType:type inRuntime:runtime];
                [value setSymbol:sym];
                
                JSValueRef jsValue = [runtime newJSValueForWrapper:value];
                
                return jsValue;
            }
        }
    }
    
    return nil;
}

static JSValueRef FJS_callAsFunction(JSContextRef context, JSObjectRef functionJS, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception) {
    
    FJSRuntime *runtime = [FJSRuntime runtimeInContext:context];
    BOOL needsToPushRuntime = ![FJSRuntime currentRuntime];
    if (needsToPushRuntime) {
        [runtime pushAsCurrentFJS];
    }
    else if ([FJSRuntime currentRuntime] != runtime) {
        // WTF is going on? Is one runtime calling into another? NOPE
        assert(NO);
    }
    
    
    FJSValue *objectToCall = [FJSValue valueForJSObject:thisObject inRuntime:runtime];
    FJSValue *functionToCall = [FJSValue valueForJSObject:functionJS inRuntime:runtime];
    
    NSMutableArray *args = [NSMutableArray arrayWithCapacity:argumentCount];
    for (size_t idx = 0; idx < argumentCount; idx++) {
        JSValueRef jsArg = arguments[idx];
        FJSValue *arg = [FJSValue valueForJSObject:(JSObjectRef)jsArg inRuntime:runtime];
        assert(arg);
        [args addObject:arg];
    }
    
    FJSFFI *ffi = [FJSFFI ffiWithFunction:functionToCall caller:objectToCall arguments:args cos:runtime];
    
    FJSValue *ret = [ffi callFunction];
    FMAssert(ret);
    
    JSValueRef returnRef = [ret JSValue];
    FMAssert(returnRef);
    
    if (needsToPushRuntime) {
        [runtime popAsCurrentFJS];
    }
    
    return returnRef;
}

static void FJS_finalize(JSObjectRef object) {
    
    CFTypeRef value = JSObjectGetPrivate(object);
    
    if (value) {
        
        if ([(__bridge id)value isKindOfClass:[FJSValue class]]) {
            FMAssert(![(__bridge FJSValue*)value isJSNative]); // Sanity.
            FJSRuntime *rt = [(__bridge FJSValue*)value runtime];
            
            if ([rt finalizeHandler]) {
                [rt finalizeHandler](rt, (__bridge FJSValue*)value);
            }
        }
        
        CFRelease(value);
    }
}


void print(id s) {
    
    FJSRuntime *rt = [FJSRuntime currentRuntime];
    FMAssert(rt);
    if (!rt) {
        NSLog(@"No runtime found for print.");
    }
    
    if (!s) {
        s = @"<null>";
    }
    
    if ([rt printHandler]) {
        [rt printHandler](rt, [s description]);
    }
    else {
        printf("%s\n", [[s description] UTF8String]);
    }
    
}

void FJSAssert(BOOL b) {
    FMAssert(b);
}

void FJSAssertObject(id o) {
    FMAssert(o);
};

