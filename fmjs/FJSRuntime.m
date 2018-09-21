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

@interface FJSRuntime () {
    
}

@property (weak) FJSRuntime *previousRuntime;
@property (assign) JSGlobalContextRef jsContext;
@property (assign) JSClassRef globalClass;

@end

#define FJSRuntimeLookupKey @"__FJSRuntimeLookupKey__"

static FJSRuntime *FJSCurrentCOScriptLite;

static void FJS_initialize(JSContextRef ctx, JSObjectRef object);
static void FJS_finalize(JSObjectRef object);
JSValueRef FJS_getProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS, JSValueRef *exception);
static bool FJS_hasProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName);
static JSValueRef FJS_callAsFunction(JSContextRef ctx, JSObjectRef functionJS, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception);

@implementation FJSRuntime

+ (FJSRuntime*)currentCOScriptLite {
    return FJSCurrentCOScriptLite;
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
        FMAssert(FMJSBridgeSupportPath);
        
        [[FJSSymbolManager sharedManager] parseBridgeFileAtPath:FMJSBridgeSupportPath];
        
        [self loadFrameworkAtPath:@"/System/Library/Frameworks/Foundation.framework"];
        [self loadFrameworkAtPath:@"/System/Library/Frameworks/AppKit.framework"];
        [self loadFrameworkAtPath:@"/System/Library/Frameworks/CoreGraphics.framework"];
        [self loadFrameworkAtPath:@"/System/Library/Frameworks/CoreImage.framework"];
        
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
    COSGlobalClassDefinition.className          = "CocoaScriptLite";
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
        JSValueRef exception = NULL;
        JSStringRef jsName = JSStringCreateWithUTF8CString([FJSRuntimeLookupKey UTF8String]);
        JSObjectDeleteProperty(_jsContext, JSContextGetGlobalObject(_jsContext), jsName, &exception);
        JSStringRelease(jsName);
        
        JSClassRelease(_globalClass);
        
        JSGarbageCollect(_jsContext);
        
        JSGlobalContextRelease(_jsContext);
        
        _jsContext = nil;
    }
}

- (void)pushAsCurrentFJS {
    [self setPreviousRuntime:FJSCurrentCOScriptLite];
    FJSCurrentCOScriptLite = self;
}

- (void)popAsCurrentFJS {
    FJSCurrentCOScriptLite = [self previousRuntime];
}

- (JSContextRef)contextRef {
    return _jsContext;
}

- (id)runtimeObjectWithName:(NSString *)name {
    
    JSValueRef exception = NULL;
    
    JSStringRef jsName = JSStringCreateWithUTF8CString([name UTF8String]);
    JSValueRef jsValue = JSObjectGetProperty([self contextRef], JSContextGetGlobalObject([self contextRef]), jsName, &exception);
    JSStringRelease(jsName);
    
    if (exception != NULL) {
        FMAssert(NO);
        return NULL;
    }
    
    FJSValue *w = (__bridge FJSValue *)JSObjectGetPrivate((JSObjectRef)jsValue);
    
    return [w instance];
}

- (JSValueRef)setRuntimeObject:(nullable id)object withName:(NSString *)name {
    
    if (!object) {
        JSValueRef exception = NULL;
        JSStringRef jsName = JSStringCreateWithUTF8CString([name UTF8String]);
        JSObjectDeleteProperty([self contextRef], JSContextGetGlobalObject([self contextRef]), jsName, &exception);
        JSStringRelease(jsName);
        return nil;
    }
    
    FJSValue *w = [FJSValue valueWithInstance:(__bridge CFTypeRef _Nonnull)(object) inRuntime:self];
    
    JSValueRef jsValue = [self newJSValueForWrapper:w];
    
    // Set
    JSValueRef exception = NULL;
    JSStringRef jsName = JSStringCreateWithUTF8CString([name UTF8String]);
    JSObjectSetProperty([self contextRef], JSContextGetGlobalObject([self contextRef]), jsName, jsValue, kJSPropertyAttributeNone, &exception);
    JSStringRelease(jsName);
    
    if (exception != NULL) {
        FMAssert(NO);
        return NULL;
    }
    
    return jsValue;
}

- (void)garbageCollect {
    JSGarbageCollect(_jsContext);
}

- (FJSValue*)evaluateScript:(NSString *)script withSourceURL:(nullable NSURL *)sourceURL {
    
    FJSValue *returnValue = nil;
    
    [self pushAsCurrentFJS];
    
    @try {
        
        
        JSStringRef jsString = JSStringCreateWithCFString((__bridge CFStringRef)script);
        JSStringRef jsScriptPath = (sourceURL != nil ? JSStringCreateWithUTF8CString([[sourceURL path] UTF8String]) : NULL);
        JSValueRef exception = NULL;
        
        JSValueRef result = JSEvaluateScript([self contextRef], jsString, NULL, jsScriptPath, 1, &exception);
        
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
    }
    @finally {
        ;
    }
    
    [self popAsCurrentFJS];
    
    return returnValue;
}

- (FJSValue*)evaluateScript:(NSString*)script {
    
    return [self evaluateScript:script withSourceURL:nil];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    debug(@"aSelector: '%@'?", NSStringFromSelector(aSelector));
    
    return [super respondsToSelector:aSelector];
}

- (void)loadFrameworkAtPath:(NSString*)path {

    
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
        address = dlopen([libPath UTF8String], RTLD_LAZY);
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
    
    debug(@"FJS_hasProperty: '%@'?", propertyName);
    
    FJSRuntime *runtime   = [FJSRuntime runtimeInContext:ctx];
    FJSValue *objectValue = [FJSValue valueForJSObject:object inRuntime:runtime];
    FJSSymbol *symbol     = [FJSSymbol symbolForName:propertyName inObject:[objectValue instance]];
    
    if (symbol) {
        return YES;
    }
    
    debug(@"No property for %@", propertyName);
    
    return NO;
}


JSValueRef FJS_getProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS, JSValueRef *exception) {
    NSString *propertyName = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, propertyNameJS));
    if ([propertyName isEqualToString:FJSRuntimeLookupKey]) {
        return nil;
    }
    
    //BOOL isGlobalLookup = object == JSContextGetGlobalObject(ctx);
    //debug(@"isGlobalLookup: %d (%@)", isGlobalLookup, propertyName);
    
    FJSRuntime *runtime = [FJSRuntime runtimeInContext:ctx];
    
    debug(@"Getting property: '%@' (%p)", propertyName, object);
    
    if ([propertyName isEqualToString:@"toString"] || [propertyName isEqualToString:@"Symbol.toStringTag"]/* || [propertyName isEqualToString:@"Symbol.toPrimitive"]*/) {
        FJSValue *w = [FJSValue valueForJSObject:object inRuntime:runtime];
        
        return [w toJSString];
    }
    
    FJSValue *objectWrapper = [FJSValue valueForJSObject:object inRuntime:runtime];
    FJSSymbol *sym = [FJSSymbol symbolForName:propertyName inObject:[objectWrapper instance]];
    
    
    if (sym) {
        
        if ([[sym symbolType] isEqualToString:@"function"] || [[sym symbolType] isEqualToString:@"method"]) {
            
            FJSValue *value = [FJSValue valueWithSymbol:sym inRuntime:runtime];
            
            JSValueRef r = [runtime newJSValueForWrapper:value];
            
            debug(@"returning function: %p", r);
            
            return r;
        }
        else if ([[sym symbolType] isEqualToString:@"class"]) {
            
            Class class = NSClassFromString(propertyName);
            assert(class);
            
            FJSValue *w = [FJSValue valueWithSymbol:sym inRuntime:runtime];
            
            
            [w setClass:class];
            
            JSValueRef val = [runtime newJSValueForWrapper:w];
            
            return val;
        }
        else if ([[sym symbolType] isEqualToString:@"enum"]) {
            return JSValueMakeNumber(ctx, [[sym runtimeValue] doubleValue]);
        }
        else if ([[sym symbolType] isEqualToString:@"constant"]) {
            
            // Grab symbol
            void *dlsymbol = dlsym(RTLD_DEFAULT, [propertyName UTF8String]);
            assert(dlsymbol);
            
            assert([[sym runtimeType] hasPrefix:@"@"]);
            
            id o = (__bridge id)(*(void**)dlsymbol);
            FJSValue *w = [FJSValue valueWithInstance:(__bridge CFTypeRef _Nonnull)(o) inRuntime:runtime];
            
            JSObjectRef r = JSObjectMake(ctx, [runtime globalClass], (__bridge void *)(w));
            
            CFRetain((__bridge void *)w);
            
            return r;
        }
    }
    
    if ([objectWrapper symbol]) {
        // We have a symbol of some sort!
        // Maybe we're going to call a method on a class.
        
        if ([[[objectWrapper symbol] symbolType] isEqualToString:@"class"]) {
            // Look up a method on it I guess?
            debug(@"looking up a method or property on %@", [[objectWrapper symbol] name]);
            
            FJSSymbol *classMethod = [[objectWrapper symbol] classMethodNamed:propertyName];
            debug(@"classMethod: '%@'", classMethod);
            
        }
    }
    
    return nil;
}


static JSValueRef FJS_callAsFunction(JSContextRef context, JSObjectRef functionJS, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception) {
    
    FJSRuntime *runtime = [FJSRuntime runtimeInContext:context];
    
    FJSValue *objectToCall = [FJSValue valueForJSObject:thisObject inRuntime:runtime];
    FJSValue *functionToCall = [FJSValue valueForJSObject:functionJS inRuntime:runtime];
    
    debug(@"Calling function '%@'", [[functionToCall symbol] name]);
    
    NSMutableArray *args = [NSMutableArray arrayWithCapacity:argumentCount];
    for (size_t idx = 0; idx < argumentCount; idx++) {
        JSValueRef jsArg = arguments[idx];
        FJSValue *arg = [FJSValue valueForJSObject:(JSObjectRef)jsArg inRuntime:runtime];
        assert(arg);
        [args addObject:arg];
    }
    
    FJSFFI *ffi = [FJSFFI ffiWithFunction:functionToCall caller:objectToCall arguments:args cos:runtime];
    
    FJSValue *ret = [ffi callFunction];
    
    if (!ret) { // Following JSValue.h's lead here.
        return JSValueMakeUndefined(context);
    }
    
    JSValueRef returnRef = [ret JSValue];
    
    FMAssert(returnRef);
    
    //debug(@"returnRef: %@ for function '%@' (%@)", returnRef, [[functionToCall symbol] name], ret);
    
    return returnRef;
}

static void FJS_finalize(JSObjectRef object) {
    debug(@"finalize: %p", object);
    
    CFTypeRef value = JSObjectGetPrivate(object);
    
    debug(@"value: '%@'", value);
    
    //FJSValue *value = (__bridge FJSValue *)(JSObjectGetPrivate(object));
    
    if (value) {
        CFRelease(value);
    }
}

void print(id s) {
    if (!s) {
        s = @"<null>";
    }
    
    printf("** %s\n", [[s description] UTF8String]);
}

void FJSAssert(BOOL b) {
    FMAssert(b);
}

void FJSAssertObject(id o) {
    FMAssert(o);
};

