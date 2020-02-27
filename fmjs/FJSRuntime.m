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
#import "FJSDispatch.h"

#import <objc/runtime.h>
#import <dlfcn.h>

BOOL FMJSUseSynchronousGarbageCollectForDebugging;
BOOL FJSTraceFunctionCalls;
NSString *FMJavaScriptExceptionName = @"FMJavaScriptException";
const CGRect FJSRuntimeTestCGRect = {{74, 78}, {11, 16}};
static const void * const kDispatchQueueSpecificKey = &kDispatchQueueSpecificKey;
static const void * const kDispatchQueueRecursiveSpecificKey = &kDispatchQueueRecursiveSpecificKey;

@interface FJSRuntime () {
    
}

@property (assign) JSGlobalContextRef jsContext;
@property (assign) JSClassRef globalClass;
@property (strong) NSMutableSet<NSString*> *runtimeObjectNames;
@property (strong) NSMutableDictionary *cachedModules;
@property (strong) NSMutableArray *moduleSearchPaths;
@property (strong) NSMutableArray<NSURL*> *currentlyLoadingModuleURL;
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
            
            
            NSString *xml =
                @"<signatures version='1.0'>"
                    @"<function name='FJSAssertObject'><arg type='@'/></function>"
                    @"<function name='FJSAssert'><arg type='B'/></function>"
             //       @"<class name='NSNumber'><method selector='Symbol.toPrimitive'><retval type64='@'/></method></class>"
             //       @"<class name='NSString'><method selector='Symbol.toPrimitive'><retval type64='@'/></method></class>"
                "</signatures>";
            
            [[FJSSymbolManager sharedManager] parseBridgeString:xml];
            
        });
        
        _evaluateQueue = dispatch_queue_create([[NSString stringWithFormat:@"fmjs.evaluateQueue.%p", (void*)self] UTF8String], NULL);
        dispatch_queue_set_specific(_evaluateQueue, kDispatchQueueSpecificKey, (__bridge void *)self, NULL);
        
        _runtimeObjectNames = [NSMutableSet set];
        _cachedModules = [NSMutableDictionary dictionary];
        _currentlyLoadingModuleURL = [NSMutableArray array];
        [self setupJS];
    }
    
    return self;
}

- (void)dealloc {
    [self shutdown];
    _evaluateQueue = nil;
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

    
    self[@"DispatchQueue"] = [FJSDispatch class];
    
    /*
    // Symbol.toPrimitive support
    self[@"FMJSSymbolToPrimativeFront"] = ^(id o) {
        return o;
    };
    
    self[@"FMJSSymbolToPrimative"] = [FJSValue valueWithSerializedJSFunction:@"FMJSSymbolToPrimativeFront(f)" inRuntime:self];
    */
    
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

- (void)dispatchOnQueue:(DISPATCH_NOESCAPE dispatch_block_t)block {
    
    FMAssert(_evaluateQueue);
    
    // We can't use kDispatchQueueSpecificKey, because if we do _evaluateQueue->_fmdbQueue->_evaluateQueue-> then dispatch_assert_queue_not is goign to fail, because dispatch_get_specific looks at the current queue, which might be _fmdbQueue or something else.
    FJSRuntime *currentRuntimeQueue = (__bridge id)dispatch_queue_get_specific(_evaluateQueue, kDispatchQueueRecursiveSpecificKey);
    if (currentRuntimeQueue == self) {
        block();
        return;
    }
    
    dispatch_assert_queue_not(_evaluateQueue);
    dispatch_sync(_evaluateQueue, ^{
        dispatch_queue_set_specific(self->_evaluateQueue, kDispatchQueueRecursiveSpecificKey, (__bridge void *)self, NULL);
        block();
        dispatch_queue_set_specific(self->_evaluateQueue, kDispatchQueueRecursiveSpecificKey, NULL, NULL);
    });
}

- (BOOL)hasFunctionNamed:(NSString*)name {
    
    __block BOOL hasFunc = NO;
    
    [self dispatchOnQueue:^{
        JSValueRef exception = nil;
        JSStringRef jsFunctionName = JSStringCreateWithUTF8CString([name UTF8String]);
        JSValueRef jsFunctionValue = JSObjectGetProperty(self->_jsContext, JSContextGetGlobalObject(self->_jsContext), jsFunctionName, &exception);
        JSStringRelease(jsFunctionName);
        hasFunc = jsFunctionValue && (JSValueGetType(self->_jsContext, jsFunctionValue) == kJSTypeObject);
    }];
    
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
    
    [self dispatchOnQueue:^{
        
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
    }];
    
    return returnValue;
}





- (void)removeRuntimeValueWithName:(NSString*)name inJSObject:(JSObjectRef)jsObject {
    
    [self dispatchOnQueue:^{
        JSValueRef exception = NULL;
        JSStringRef jsName = JSStringCreateWithUTF8CString([name UTF8String]);
        JSObjectDeleteProperty(self->_jsContext, jsObject, jsName, &exception);
        JSStringRelease(jsName);
        
        [self reportPossibleJSException:exception];
        [[self runtimeObjectNames] removeObject:name];
    }];
}

- (void)removeRuntimeValueWithName:(NSString*)name {
    [self setObject:nil forKeyedSubscript:name];
}

- (FJSValue*)objectForKeyedSubscript:(id)name inJSObject:(JSObjectRef)jsObject {
    
    __block FJSValue *obj = nil;
    
    [self dispatchOnQueue: ^{
        JSValueRef exception = NULL;
        
        JSStringRef jsName = JSStringCreateWithUTF8CString([name UTF8String]);
        JSValueRef jsValue = JSObjectGetProperty([self contextRef], jsObject, jsName, &exception);
        JSStringRelease(jsName);
        
        if (exception) {
            [self reportPossibleJSException:exception];
        }
        else {
            
            obj = [FJSValue valueWithJSValueRef:jsValue inRuntime:self];
        }
    }];
    
    // Should we call protectNative for these objects? Or mabye even if it isn't native?
    // What if we do, and then objectForKeyedSubscript is called multiple times? Maybe it should just be done once when
    // A new FJSValue is created, and then once on dealloc?
    
    return obj;
}

- (FJSValue*)objectForKeyedSubscript:(id)name {
    return [self objectForKeyedSubscript:name inJSObject:JSContextGetGlobalObject([self contextRef])];
}

- (void)setObject:(id)object forKeyedSubscript:(NSString *)name inJSObject:(JSObjectRef)jsObject {
    
    if (!object) {
        [self removeRuntimeValueWithName:name inJSObject:jsObject];
        return;
    }
    
    
    FJSValue *value = nil;
    
    if ([object isKindOfClass:[FJSValue class]]) {
        value = object;
    }
    else {
        value = [FJSValue valueWithInstance:(__bridge CFTypeRef _Nonnull)(object) inRuntime:self];
    }
    
    [self dispatchOnQueue: ^{
        
        JSValueRef jsValue = [value JSValueRef];
        
        FMAssert(jsValue);
        
        JSValueRef exception = NULL;
        JSStringRef jsName = JSStringCreateWithUTF8CString([name UTF8String]);
        JSObjectSetProperty([self contextRef], jsObject, jsName, jsValue, kJSPropertyAttributeNone, &exception);
        JSStringRelease(jsName);
        
        #pragma message "FIXME: [[self runtimeObjectNames] addObject:name]; is completely worthless now with the inJSObject:(JSObjectRef)jsObject param. We need to keep a map of things to kill based on the FJSValue we're setting these things on."
        if (!exception) {
            [[self runtimeObjectNames] addObject:name];
        }
        
        [self reportPossibleJSException:exception];
    }];
    
    
    
    
}

- (void)setObject:(id)object forKeyedSubscript:(NSString *)name {
    
    if (object == self) { printf("Nice try.\n"); FMAssert(NO); return; }
    
    [self setObject:object forKeyedSubscript:name inJSObject:JSContextGetGlobalObject([self contextRef])];
    
}

- (void)garbageCollect {
    
    [self dispatchOnQueue:^{
        
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
    }];
}

- (FJSValue*)evaluateNoQueue:(NSString *)script withSourceURL:(nullable NSURL *)sourceURL {
    
    [self pushAsCurrentFJS];
    
    FJSValue *returnValue = nil;
    
    @try {
        
        id fn = self[@"__filename"];
        id dn = self[@"__dirname"];
        
        self[@"__filename"] = [sourceURL path];
        self[@"__dirname"]  = [[sourceURL URLByDeletingLastPathComponent] path];
        
        
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
        
        
        self[@"__filename"] = [fn isUndefined] || [fn isNull] ? nil : fn;
        self[@"__dirname"]  = [dn isUndefined] || [dn isNull] ? nil : dn;
        
        
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
    
    [self dispatchOnQueue: ^{
        returnValue = [self evaluateNoQueue:script withSourceURL:sourceURL];
    }];
    
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

- (void)addURLToModuleSearchPath:(NSURL*)url {
    
    if (!_moduleSearchPaths) {
        _moduleSearchPaths = [NSMutableArray array];
    }
    
    if ([_moduleSearchPaths indexOfObject:url] == NSNotFound) {
        [_moduleSearchPaths addObject:url];
    }
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
            
            [_currentlyLoadingModuleURL addObject:scriptURL];
            
#define NODE_STYLE_WRAPPER 1
#ifdef NODE_STYLE_WRAPPER
            
            NSString *moduleWrapper = @"(function(__filename, __dirname) {\nvar module = { exports : {} }; var exports = module.exports;\n%@;\nreturn module.exports;})";
            
            moduleWrapper = [NSString stringWithFormat:moduleWrapper, script];
            
            FJSValue *moduleValueFunction  = [self evaluateNoQueue:moduleWrapper withSourceURL:scriptURL];
            
            FJSValue *moduleValue = [moduleValueFunction callWithArguments:@[[scriptURL path], [[scriptURL URLByDeletingLastPathComponent] path]]];
            
#else
            
            id fn = self[@"__filename"];
            id dn = self[@"__dirname"];
            
            // __filename and __dirname are node things. I wish we could pass them in as arguments, but I can't seem to massage the js so that'll happen.
            self[@"__filename"] = [scriptURL path];
            self[@"__dirname"]  = [[scriptURL URLByDeletingLastPathComponent] path];
            
            NSString *module = [NSString stringWithFormat:@"(function() { var module = { exports : {} }; var exports = module.exports; %@;\nreturn module.exports; })()", script];
            
            FJSValue *moduleValue = [self evaluateNoQueue:module withSourceURL:scriptURL];
            
            self[@"__filename"] = [fn isUndefined] || [fn isNull] ? nil : fn;
            self[@"__dirname"]  = [dn isUndefined] || [dn isNull] ? nil : dn;
#endif
            
            [_currentlyLoadingModuleURL removeLastObject];
            
            return moduleValue;
        }
        else if (error) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Cannot find module %@", scriptURL.path] userInfo:nil];
        }
    }
    
    return nil;
}



/// This aims to implement the require resolution algorithm from NodeJS.
/// Given a `module` string required by a given script at the `currentURL`
/// using `require('./path/to/module')`, this method returns a URL
/// corresponding to the `module`.
/// `module` could also be the name of a core module that we shipped with the app
/// (for example `util`), in which case, it will return the URL to that one
/// and set `isRequiringCore` to YES.
- (NSURL*)resolveModule:(NSString*)module currentURL:(NSURL*)currentURL isRequiringCoreModule:(BOOL*)isRequiringCore {
    if (![module hasPrefix:@"."] && ![module hasPrefix:@"/"] && ![module hasPrefix:@"~"]) {
        *isRequiringCore = YES;
        return _coreModuleMap[module];
    }
    
    *isRequiringCore = NO;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isRelative = [module hasPrefix: @"."];
    NSString *modulePath = [module stringByStandardizingPath];
    NSURL *moduleURL = isRelative ? [NSURL URLWithString:modulePath relativeToURL:currentURL] : [NSURL fileURLWithPath:modulePath];
    
    if (moduleURL == nil) {
        return nil;
    }
    
    BOOL isDir;
    
    if ([fileManager fileExistsAtPath:moduleURL.path isDirectory:&isDir]) {
        if (!isDir) {
            // if the module is a proper path to a file, just use it
            return moduleURL;
        }
        // if it's a path to a directory, let's try to find a package.json
        NSURL *packageJSONURL = [moduleURL URLByAppendingPathComponent:@"package.json"];
        NSData *jsonData = [[NSData alloc] initWithContentsOfFile:packageJSONURL.path];
        if (jsonData != nil) {
            id packageJSON = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:nil];
            if (packageJSON != nil) {
                // we have a package.json, so let's find the `main` key
                NSString *main = [packageJSON objectForKey:@"main"];
                if (main) {
                    // main is always a relative path, so let's transform it to one
                    if ([module hasPrefix: @"/"]) {
                        main = [@"." stringByAppendingString:main];
                    } else if (![module hasPrefix: @"."]) {
                        main = [@"./" stringByAppendingString:main];
                    }
                    return [self resolveModule:[moduleURL URLByAppendingPathComponent:main].path currentURL:currentURL isRequiringCoreModule:isRequiringCore];
                }
            }
        }
        
        // default to index.js otherwise
        NSURL *indexURL = [moduleURL URLByAppendingPathComponent:@"index.js"];
        if ([fileManager fileExistsAtPath:indexURL.path isDirectory:&isDir] && !isDir) {
            return indexURL;
        }
        
        // couldn't find anything :(
        return nil;
    }
    
    // try by adding the js extension which can be ommited
    NSURL *jsURL = [moduleURL URLByAppendingPathExtension:@"js"];
    if ([fileManager fileExistsAtPath:jsURL.path isDirectory:&isDir] && !isDir) {
        return jsURL;
    }
    
    // unlucky :(
    return nil;
}









// FIXME: Should we put this in a queue if we're not in one already?
- (FJSValue*)require:(NSString*)module {
    
    debug(@"require: '%@'", module);
    
    NSURL *currentURL = [[_currentlyLoadingModuleURL lastObject] URLByDeletingLastPathComponent];
    BOOL isRequiringCore;
    NSURL *moduleURL = nil;
    
    if (_resolveModuleHandler) {
        moduleURL = _resolveModuleHandler(self, module);
    }
    
    if (!moduleURL) {
        moduleURL = [self resolveModule:module currentURL:currentURL isRequiringCoreModule:&isRequiringCore];
    }
    
    if (!moduleURL) {
        
        for (NSURL *url in _moduleSearchPaths) {
            
            // add the ./ so it's not resolved as a core module.
            moduleURL = [self resolveModule:[@"./" stringByAppendingString:module] currentURL:url isRequiringCoreModule:&isRequiringCore];
            
            if (moduleURL) {
                break;
            }
        }
    }
    
    if (!moduleURL) {
        debug(@"Could not find module '%@'", module);
        return [FJSValue valueWithUndefinedInRuntime:self];
        /*
        @throw [NSException
                exceptionWithName:NSInvalidArgumentException
                reason:isRequiringCore
                ? [NSString stringWithFormat:@"%@ is not a core package", module]
                : [NSString stringWithFormat:@"Cannot find module %@ from package %@", module, currentURL.path]
                userInfo:nil];*/
    }
    
    if ([_cachedModules objectForKey:moduleURL]) {
        return [_cachedModules objectForKey:moduleURL];
    }
    
    
    FJSValue *v = [self evaluateModuleAtURL:moduleURL];
    if (v) {
        [_cachedModules setObject:v forKey:moduleURL];
        
        if (_moduleWasLoadedHandler) {
            _moduleWasLoadedHandler(self, v, moduleURL);
        }
        
        return v;
    }
    
    return [FJSValue valueWithUndefinedInRuntime:self];
    
}

- (NSArray<FJSValue *>*)modules {
    return [_cachedModules allValues];
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


void FJSAssert(BOOL b);
void FJSAssert(BOOL b) {
    FMAssert(b);
}

void FJSAssertObject(id o);
void FJSAssertObject(id o) {
    FMAssert(o);
}

