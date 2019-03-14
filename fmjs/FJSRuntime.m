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
#import "FJSRuntimeCallbacks.h"
#import "FJSPrivate.h"
#import "FJSRunLoopThread.h"

#import <objc/runtime.h>
#import <dlfcn.h>

BOOL FMJSUseSynchronousGarbageCollectForDebugging;
BOOL FJSTraceFunctionCalls;
NSString *FMJavaScriptExceptionName = @"FMJavaScriptException";
const CGRect FJSRuntimeTestCGRect = {74, 78, 11, 16};
static const void * const kDispatchQueueSpecificKey = &kDispatchQueueSpecificKey;

@interface FJSRuntime () {
    
}

@property (assign) JSGlobalContextRef jsContext;
@property (assign) JSClassRef globalClass;
@property (strong) NSMutableSet<NSString*> *runtimeObjectNames;
@property (strong) NSMutableDictionary *cachedModules;
@property (strong) FJSRunLoopThread *runloopThread;

@end


@implementation FJSRuntime


+ (instancetype)runtimeInContext:(JSContextRef)context {
    
    JSValueRef exception = NULL;
    
    JSStringRef jsName = JSStringCreateWithUTF8CString([FJSRuntimeLookupKey UTF8String]);
    JSValueRef jsValue = JSObjectGetProperty(context, JSContextGetGlobalObject(context), jsName, &exception);
    JSStringRelease(jsName);
    
    if (exception != NULL) {
        FMAssert(NO);
        return NULL;
    }
    
    if (JSValueIsObject(context, jsValue)) {
        FJSValue *value = (__bridge FJSValue *)JSObjectGetPrivate((JSObjectRef)jsValue);
        return [value instance];
    }
    
    return nil;
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
            
            // The order this happens in is important, so when CG or CF function return values and arguments are unmangled,
            // the right CFTypes are swapped in. Search for 98335485-e79d-4ad3-b2d1-91a4c4c56da1 
            [FJSRuntime loadFrameworkAtPath:@"/System/Library/Frameworks/Foundation.framework"];
            [FJSRuntime loadFrameworkAtPath:@"/System/Library/Frameworks/CoreFoundation.framework"];
            [FJSRuntime loadFrameworkAtPath:@"/System/Library/Frameworks/CoreGraphics.framework"];
            [FJSRuntime loadFrameworkAtPath:@"/System/Library/Frameworks/ImageIO.framework"];
            [FJSRuntime loadFrameworkAtPath:@"/System/Library/Frameworks/AppKit.framework"];
            [FJSRuntime loadFrameworkAtPath:@"/System/Library/Frameworks/CoreImage.framework"];
            
            /* If we have custom functions again, we'll need this.
            NSString *xml =
                @"<signatures version='1.0'>"
                "</signatures>";
            
            [[FJSSymbolManager sharedManager] parseBridgeString:xml];
            */
        });
        
        _evaluateQueue = dispatch_queue_create([[NSString stringWithFormat:@"fmjs.evaluateQueue.%p", self] UTF8String], NULL);
        dispatch_queue_set_specific(_evaluateQueue, kDispatchQueueSpecificKey, (__bridge void *)self, NULL);
        
        _runtimeObjectNames = [NSMutableSet set];
        _cachedModules = [NSMutableDictionary dictionary];
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
    
    [self setupJSCallbacks];
    
    _jsContext = JSGlobalContextCreate(_globalClass);
    
    FJSValue *value = [FJSValue valueWithWeakInstance:self inRuntime:self];
    
    JSValueRef jsValue = [value JSValueRef];
    
    JSValueRef exception = NULL;
    JSStringRef jsName = JSStringCreateWithUTF8CString([FJSRuntimeLookupKey UTF8String]);
    JSObjectSetProperty(_jsContext, JSContextGetGlobalObject(_jsContext), jsName, jsValue, kJSPropertyAttributeReadOnly|kJSPropertyAttributeDontEnum, &exception);
    JSStringRelease(jsName);
    
    [_runtimeObjectNames addObject:FJSRuntimeLookupKey]; // This is so we can have auto-cleanup later on.
    
    FMAssert([[self objectForKeyedSubscript:FJSRuntimeLookupKey] instance] == self);
    FMAssert([FJSRuntime runtimeInContext:_jsContext]  == self);
    
    __weak FJSRuntime *weakSelf = self;
    self[@"print"] = ^(id s) {
        
        if ([weakSelf printHandler]) {
            [weakSelf printHandler](weakSelf, [s description]);
        }
        else {
            
            if (!s) {
                s = @"<null>";
            }
            
            printf("%s\n", [[s description] UTF8String]);
        }
    };
    
    self[@"printjsv"] = ^(FJSValue *v) {
        FMAssert([v isKindOfClass:[FJSValue class]]);
    };
    
    self[@"require"] = ^(NSString *modulePath) {
        return [weakSelf require:modulePath];
    };
    
    [self evaluateScript:@"var console={}; console.log=print;"];
    
}

- (void)shutdown {
    
    if (_jsContext) {
        
        [self removeRuntimeValueWithName:@"console"];
        
        for (NSString *name in [_runtimeObjectNames copy]) {
            [self removeRuntimeValueWithName:name];
        }
        
        [_cachedModules removeAllObjects];
        
        JSClassRelease(_globalClass);
        
        [self garbageCollect];
        
        JSGlobalContextRelease(_jsContext);
        
        _jsContext = nil;
    }
}

+ (BOOL)useSynchronousGarbageCollectForDebugging {
    return FMJSUseSynchronousGarbageCollectForDebugging;
}

+ (void)setUseSynchronousGarbageCollectForDebugging:(BOOL)flag {
    FMJSUseSynchronousGarbageCollectForDebugging = flag;
}


#define FJSThreadDictCurrentRuntimeStack @"fmjs.currentRuntime"
- (void)pushAsCurrentFJS {
    NSMutableArray *ar = [[[NSThread currentThread] threadDictionary] objectForKey:FJSThreadDictCurrentRuntimeStack];
    if (!ar) {
        ar = [NSMutableArray array];
        [[[NSThread currentThread] threadDictionary] setObject:ar forKey:FJSThreadDictCurrentRuntimeStack];
    }
    
    [ar addObject:self];
}

- (void)popAsCurrentFJS {
    
    FJSRuntime *rt = [[[[NSThread currentThread] threadDictionary] objectForKey:FJSThreadDictCurrentRuntimeStack] lastObject];
    FMAssert(rt == self);
    if (rt == self) {
        [[[[NSThread currentThread] threadDictionary] objectForKey:FJSThreadDictCurrentRuntimeStack] removeLastObject];
    }
    else {
        NSLog(@"popAsCurrentFJS: BAD THINGS ARE HAPPENING- trying to pop as current Runtime, when we're not the current runtime");
    }
}

+ (FJSRuntime*)currentRuntime {
    return [[[[NSThread currentThread] threadDictionary] objectForKey:FJSThreadDictCurrentRuntimeStack] lastObject];
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
    
    __block BOOL hasFunc = NO;
    
    dispatch_sync(_evaluateQueue, ^{
        JSValueRef exception = nil;
        JSStringRef jsFunctionName = JSStringCreateWithUTF8CString([name UTF8String]);
        JSValueRef jsFunctionValue = JSObjectGetProperty(self->_jsContext, JSContextGetGlobalObject(self->_jsContext), jsFunctionName, &exception);
        JSStringRelease(jsFunctionName);
        hasFunc = jsFunctionValue && (JSValueGetType(self->_jsContext, jsFunctionValue) == kJSTypeObject);
    });
    
    return hasFunc;
}

- (JSObjectRef)functionWithName:(NSString *)name {
    
    JSValueRef exception = NULL;
    
    // Get function as property of global object
    JSStringRef jsFunctionName = JSStringCreateWithUTF8CString([name UTF8String]);
    JSValueRef jsFunctionValue = JSObjectGetProperty(self->_jsContext, JSContextGetGlobalObject(self->_jsContext), jsFunctionName, &exception);
    JSStringRelease(jsFunctionName);
    
    if (exception) {
        [self reportPossibleJSException:exception];
        return nil;
    }
    
    return JSValueToObject(self->_jsContext, jsFunctionValue, NULL);
    
}

- (FJSValue *)callFunctionNamed:(NSString*)name withArguments:(NSArray*)arguments {
    
    __block FJSValue *returnValue = nil;
    
    dispatch_sync(_evaluateQueue, ^{
        
        @try {
            
            [self pushAsCurrentFJS];
            
            
            #pragma message "FIXME: Replace this with the on on FJSValue?"
            
            JSValueRef *jsArgumentsArray = nil;
            NSUInteger argumentsCount = [arguments count];
            if (argumentsCount) {
                jsArgumentsArray = calloc(argumentsCount, sizeof(JSValueRef));
                
                for (NSUInteger i=0; i<argumentsCount; i++) {
                    id argument = [arguments objectAtIndex:i];
                    
                    FJSValue *v = [FJSValue valueWithInstance:(__bridge CFTypeRef)(argument) inRuntime:self];
                    jsArgumentsArray[i] = [v JSValueRef];
                }
            }
            
            JSObjectRef jsFunction = [self functionWithName:name];
            assert((JSValueGetType(self->_jsContext, jsFunction) == kJSTypeObject));
            JSValueRef exception = NULL;
            //debug(@"calling function");
            JSValueRef jsFunctionReturnValue = JSObjectCallAsFunction(self->_jsContext, jsFunction, NULL, argumentsCount, jsArgumentsArray, &exception);
            //debug(@"called");
            
            if (jsArgumentsArray) {
                free(jsArgumentsArray);
            }
            
            if (exception) {
                [self reportPossibleJSException:exception];
                [self popAsCurrentFJS];
            }
            else {
                returnValue = [FJSValue valueWithJSValueRef:(JSObjectRef)jsFunctionReturnValue inRuntime:self];
            }
        }
        @catch (NSException * e) {
            
            [self reportNSException:e];
            
            //        NSDictionary *d = [e userInfo];
            //        if ([_errorController respondsToSelector:@selector(coscript:hadError:onLineNumber:atSourceURL:)]) {
            //            [_errorController coscript:self hadError:[e reason] onLineNumber:[[d objectForKey:@"line"] integerValue] atSourceURL:nil];
            //        }
        }
        
        [self popAsCurrentFJS];
    });
    
    return returnValue;
}





- (void)removeRuntimeValueWithName:(NSString*)name {
    
    dispatch_sync(_evaluateQueue, ^{
        JSValueRef exception = NULL;
        JSStringRef jsName = JSStringCreateWithUTF8CString([name UTF8String]);
        JSObjectDeleteProperty(self->_jsContext, JSContextGetGlobalObject(self->_jsContext), jsName, &exception);
        JSStringRelease(jsName);
        
        [self reportPossibleJSException:exception];
        [[self runtimeObjectNames] removeObject:name];
    });
}



- (FJSValue*)objectForKeyedSubscript:(id)name {
    
    __block FJSValue *obj = nil;
    
    //dispatch_sync(_evaluateQueue, ^{
        JSValueRef exception = NULL;
        
        JSStringRef jsName = JSStringCreateWithUTF8CString([name UTF8String]);
        JSValueRef jsValue = JSObjectGetProperty([self contextRef], JSContextGetGlobalObject([self contextRef]), jsName, &exception);
        JSStringRelease(jsName);
        
        if (exception) {
            [self reportPossibleJSException:exception];
        }
        else {
            obj = [FJSValue valueWithJSValueRef:jsValue inRuntime:self];
        }
    //});
    
    #pragma message "FIXME: Should we call protectNative for these objects? Or mabye even if it isn't native?"
    
    return obj;
}

- (void)setObject:(id)object forKeyedSubscript:(NSString *)name {
    
    if (object == self) { printf("Nice try.\n"); FMAssert(NO); return; }
    
    if (!object) {
        [self removeRuntimeValueWithName:name];
        return;
    }
    
    FJSValue *value = nil;
    
    if ([object isKindOfClass:[FJSValue class]]) {
        value = object;
    }
    else if ([object isKindOfClass:NSClassFromString(@"NSBlock")]) {
        value = [FJSValue valueWithBlock:(__bridge CFTypeRef _Nonnull)(object) inRuntime:self];
    }
    else {
        value = [FJSValue valueWithInstance:(__bridge CFTypeRef _Nonnull)(object) inRuntime:self];
    }
    
    
    dispatch_sync(_evaluateQueue, ^{
        
        JSValueRef jsValue = [value JSValueRef];
        
        FMAssert(jsValue);
        
        JSValueRef exception = NULL;
        JSStringRef jsName = JSStringCreateWithUTF8CString([name UTF8String]);
        JSObjectSetProperty([self contextRef], JSContextGetGlobalObject([self contextRef]), jsName, jsValue, kJSPropertyAttributeNone, &exception);
        JSStringRelease(jsName);
        
        [[self runtimeObjectNames] addObject:name];
        
        [self reportPossibleJSException:exception];
    });
}

- (void)garbageCollect {
    
    dispatch_sync(_evaluateQueue, ^{
        
        if (FMJSUseSynchronousGarbageCollectForDebugging) {
        
            // We could also define `JS_EXPORT void JSSynchronousGarbageCollectForDebugging(JSContextRef);` instead of using runtime lookups. But this feels a little safer in case JSSynchronousGarbageCollectForDebugging goes away some day.
            void *callAddress = dlsym(RTLD_DEFAULT, "JSSynchronousGarbageCollectForDebugging");
            if (callAddress) {
                void (*syncGC)(JSContextRef) = (void (*)(JSContextRef))callAddress;
                syncGC([self jsContext]);
            }
        }
        else {
            JSGarbageCollect([self jsContext]);
        }
    });
}

- (FJSValue*)evaluateNoQueue:(NSString *)script withSourceURL:(nullable NSURL *)sourceURL {
    
    [self pushAsCurrentFJS];
    
    FJSValue *returnValue = nil;
    
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
        
        returnValue = [FJSValue valueWithJSValueRef:result inRuntime:self];
    }
    @catch (NSException *exception) {
        debug(@"Exception: %@", exception);
        [self reportNSException:exception];
    }
    @finally {
        ;
    }
    
    [self popAsCurrentFJS];
    
    return returnValue;
}

- (FJSValue*)evaluateScript:(NSString *)script withSourceURL:(nullable NSURL *)sourceURL {
    
    /* Get the currently executing queue (which should probably be nil, but in theory could be another DB queue
     * and then check it against self to make sure we're not about to deadlock. */
    FJSRuntime *currentSyncQueue = (__bridge id)dispatch_get_specific(kDispatchQueueSpecificKey);
    assert(currentSyncQueue != self && "evaluateScript: was called reentrantly on the same queue, which is a programmer error.");
    
    __block FJSValue *returnValue = nil;
    
    dispatch_sync(_evaluateQueue, ^{
        returnValue = [self evaluateNoQueue:script withSourceURL:sourceURL];
    });
    
    return returnValue;
}

- (FJSValue*)evaluateScript:(NSString*)script {
    return [self evaluateScript:script withSourceURL:nil];
}

- (BOOL)xrespondsToSelector:(SEL)aSelector {
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

- (FJSValue*)evaluateAsModule:(NSString*)script {
    #pragma message "FIXME: If evaluateAsModule is called outside of a script, it needs to be on the queue"
    NSString *module = [NSString stringWithFormat:@"(function() { var module = { exports : {} }; var exports = module.exports; %@ ; return module.exports; })()", script];
    
    FJSValue *moduleValue = [self evaluateNoQueue:module withSourceURL:nil];
    
    return moduleValue;
}

- (FJSValue*)evaluateModuleAtURL:(NSURL*)scriptURL {
    
    if (scriptURL) {
        NSError *error;
        NSString *script = [NSString stringWithContentsOfURL:scriptURL encoding:NSUTF8StringEncoding error:&error];
        
        if (script) {
            NSString *module = [NSString stringWithFormat:@"(function() { var module = { exports : {} }; var exports = module.exports; %@ ; return module.exports; })()", script];
            
            FJSValue *moduleValue = [self evaluateNoQueue:module withSourceURL:scriptURL];
            
            return moduleValue;
        }
        else if (error) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Cannot find module %@", scriptURL.path] userInfo:nil];
        }
    }
    
    return nil;
}

// FIXME: Should we put this in a queue if we're not in one already?
- (FJSValue*)require:(NSString*)modulePath {
    
    NSString *fullPath = FJSResolveModuleAtPath(modulePath, [[NSFileManager defaultManager] currentDirectoryPath]);
    
    if (!fullPath) {
        FMAssert(NO);
        return [FJSValue valueWithUndefinedInRuntime:self];
    }
    
    if ([_cachedModules objectForKey:fullPath]) {
        return [_cachedModules objectForKey:fullPath];
    }
    
    
    FJSValue *v = [self evaluateModuleAtURL:[NSURL fileURLWithPath:fullPath]];
    if (v) {
        [_cachedModules setObject:v forKey:fullPath];
        return v;
    }
    
    
    //        JSModule *module = [JSModule require:arg atPath:[[NSFileManager defaultManager] currentDirectoryPath]];
    //        if (!module) {
    //            [[JSContext currentContext] evaluateScript:@"throw 'not found'"];
    //            return [JSValue valueWithUndefinedInContext:[JSContext currentContext]];
    //        }
    //        return module.exports;
    return [FJSValue valueWithNewObjectInRuntime:self];
    
}

- (void)installRunloop {
    
    // Why a runloop? I think it'll help with some memory things in background threads.
    // Maybe.
    // That's the theory anyway.
    _runloopThread = [[FJSRunLoopThread alloc] initWithRuntime:self];
    [_runloopThread start];
    [_runloopThread join];
}

@end


void FJSAssert(BOOL b) {
    FMAssert(b);
}

void FJSAssertObject(id o) {
    FMAssert(o);
};

