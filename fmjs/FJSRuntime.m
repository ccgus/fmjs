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
#import "FJSValue.h"
#import "FJSBridgeParser.h"
#import "FJSFFI.h"
#import <objc/runtime.h>
#import <dlfcn.h>

@interface FJSRuntime () {
    
}


@property (weak) FJSRuntime *previousCoScript;

@end

#define FJSRuntimeLookupKey @"__cosRuntimeLookup__"

static FJSRuntime *FJSCurrentCOScriptLite;

static JSClassRef FJSGlobalClass = NULL;
static void FJS_initialize(JSContextRef ctx, JSObjectRef object);
static void FJS_finalize(JSObjectRef object);
JSValueRef FJS_getGlobalProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS, JSValueRef *exception);
//static bool FJS_hasProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName);
static JSValueRef FJS_callAsFunction(JSContextRef ctx, JSObjectRef functionJS, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception);

@implementation FJSRuntime


+ (void)initialize {
    if (self == [FJSRuntime class]) {
        JSClassDefinition COSGlobalClassDefinition      = kJSClassDefinitionEmpty;
        COSGlobalClassDefinition.className              = "CocoaScriptLite";
        COSGlobalClassDefinition.getProperty            = FJS_getGlobalProperty;
        COSGlobalClassDefinition.initialize             = FJS_initialize;
        COSGlobalClassDefinition.finalize               = FJS_finalize;
        //COSGlobalClassDefinition.hasProperty            = FJS_hasProperty; // If we don't have this, getProperty gets called twice.
        COSGlobalClassDefinition.callAsFunction         = FJS_callAsFunction;
        FJSGlobalClass                                 = JSClassCreate(&COSGlobalClassDefinition);

    }
}


+ (FJSRuntime*)currentCOScriptLite {
    return FJSCurrentCOScriptLite;
}

+ (instancetype)runtimeInContext:(JSContextRef)context {
//
//    JSContext *ctx = [JSContext contextWithJSGlobalContextRef:context];
//    debug(@"ctx: '%@'", ctx);
//
//    return [[ctx objectForKeyedSubscript:FJSRuntimeLookupKey] toObject];
//
    
    JSValueRef exception = NULL;
    
    JSStringRef jsName = JSStringCreateWithUTF8CString([FJSRuntimeLookupKey UTF8String]);
    JSValueRef jsValue = JSObjectGetProperty(context, JSContextGetGlobalObject(context), jsName, &exception);
    JSStringRelease(jsName);
    
    if (exception != NULL) {
        FMAssert(NO);
        return NULL;
    }
    
    FJSValue *w = (__bridge FJSValue *)JSObjectGetPrivate((JSObjectRef)jsValue);
    
    return [w instance];
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        
        NSString *FMJSBridgeSupportPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"FJS" ofType:@"bridgesupport"];
        FMAssert(FMJSBridgeSupportPath);
        
        [[FJSBridgeParser sharedParser] parseBridgeFileAtPath:FMJSBridgeSupportPath];
        
        
        [self loadFrameworkAtPath:@"/System/Library/Frameworks/Foundation.framework"];
        [self loadFrameworkAtPath:@"/System/Library/Frameworks/AppKit.framework"];
        [self loadFrameworkAtPath:@"/System/Library/Frameworks/CoreImage.framework"];
    }
    return self;
}



- (void)pushAsCurrentFJS {
    [self setPreviousCoScript:FJSCurrentCOScriptLite];
    FJSCurrentCOScriptLite = self;
}

- (void)popAsCurrentFJS {
    FJSCurrentCOScriptLite = [self previousCoScript];
}

- (JSContext*)context {
    if (!_jscContext) {
        JSGlobalContextRef globalContext = JSGlobalContextCreate(FJSGlobalClass);
        _jscContext = [JSContext contextWithJSGlobalContextRef:globalContext];
        
        [_jscContext setExceptionHandler:^(JSContext *context, JSValue *exception) {
            debug(@"Exception: %@", exception);
        }];
        
        [self setRuntimeObject:self withName:FJSRuntimeLookupKey];
        
        FMAssert([self runtimeObjectWithName:FJSRuntimeLookupKey] == self);
        FMAssert([FJSRuntime runtimeInContext:[self contextRef]]  == self);
        
    }
    
    return _jscContext;
}

- (JSContextRef)contextRef {
    return [[self context] JSGlobalContextRef];
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

- (JSValueRef)setRuntimeObject:(id)object withName:(NSString *)name {
    
    FJSValue *w = [FJSValue wrapperWithInstance:object runtime:self];
    
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
    JSGarbageCollect([_jscContext JSGlobalContextRef]);
}

- (id)evaluateScript:(NSString *)script withSourceURL:(NSURL *)sourceURL {
    
    [self pushAsCurrentFJS];
    
    @try {
        [[self context] evaluateScript:script withSourceURL:sourceURL];
    }
    @catch (NSException *exception) {
        debug(@"Exception: %@", exception);
    }
    @finally {
        ;
    }
    
    [self popAsCurrentFJS];
}

- (id)evaluateScript:(NSString*)script {
    
    [self pushAsCurrentFJS];
    
    @try {
        [[self context] evaluateScript:script];
    }
    @catch (NSException *exception) {
        debug(@"Exception: %@", exception);
    }
    @finally {
        ;
    }
    
    [self popAsCurrentFJS];
    
    return nil;
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
        [[FJSBridgeParser sharedParser] parseBridgeFileAtPath:bridgeXML];
    }
}

+ (void)testClassMethod {
    debug(@"%s:%d", __FUNCTION__, __LINE__);
}

- (JSValueRef)newJSValueForWrapper:(FJSValue*)w {
    
    // This should only be called for non-js objects.
    FMAssert(![w isJSNative]);
    
    JSObjectRef r = JSObjectMake([[self jscContext] JSGlobalContextRef], FJSGlobalClass, (__bridge void *)(w));
    CFRetain((__bridge void *)w);
    
    FMAssert(r);
    
    return r;
}

@end

static void FJS_initialize(JSContextRef ctx, JSObjectRef object) {
    
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

JSValueRef FJS_getGlobalProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS, JSValueRef *exception) {
    NSString *propertyName = (NSString *)CFBridgingRelease(JSStringCopyCFString(kCFAllocatorDefault, propertyNameJS));
    if ([propertyName isEqualToString:FJSRuntimeLookupKey]) {
        return nil;
    }
    
    FJSRuntime *runtime = [FJSRuntime runtimeInContext:ctx];
    
    //debug(@"propertyName: '%@' (%p)", propertyName, object);
    
    if ([propertyName isEqualToString:@"toString"] || [propertyName isEqualToString:@"Symbol.toStringTag"]/* || [propertyName isEqualToString:@"Symbol.toPrimitive"]*/) {
        FJSValue *w = [FJSValue wrapperForJSObject:object runtime:runtime];
        
        return [w toJSString];
    }
    
    FJSValue *objectWrapper = [FJSValue wrapperForJSObject:object runtime:runtime];
    FJSSymbol *symArgument = [objectWrapper symbol];
    
    debug(@"objectWrapper: '%@' (%p) %p %d", objectWrapper, object, JSContextGetGlobalObject(ctx), JSValueGetType(ctx, object));
    debug(@"propertyName: '%@'", propertyName);
    
    debug(@"symArgument: '%@'", symArgument);
    
    FJSSymbol *sym = [FJSBridgeParser symbolForName:propertyName];
    if (symArgument) {
        // Oh- we're probably calling something like NSFoo.new(). We should check and see if the symbol is a (class)method or property or whatever.
        sym = [symArgument classMethodNamed:propertyName];
    }
    
    if (sym) {
        
        if ([[sym symbolType] isEqualToString:@"function"] || [[sym symbolType] isEqualToString:@"method"]) {
            
            FJSValue *w = [FJSValue wrapperWithSymbol:sym runtime:runtime];
            
            return [runtime newJSValueForWrapper:w];
        }
        else if ([[sym symbolType] isEqualToString:@"class"]) {
            
            Class class = NSClassFromString(propertyName);
            assert(class);
            
            FJSValue *w = [FJSValue wrapperWithSymbol:sym runtime:runtime];
            
            
            [w setInstance:class];
            
            debug(@"FJSJSWrapper class: '%@'", w);
            
            JSValueRef val = [runtime newJSValueForWrapper:w];
            
            debug(@"JSValueRef: '%p'", val);
            
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
            FJSValue *w = [FJSValue wrapperWithInstance:o runtime:runtime];
            
            JSObjectRef r = JSObjectMake(ctx, FJSGlobalClass, (__bridge void *)(w));
            
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
    
    
    
    
//    Class objCClass = NSClassFromString(propertyName);
//    if (objCClass && ![propertyName isEqualToString:@"Object"] && ![propertyName isEqualToString:@"Function"]) {
//
//        FJSJSWrapper *w = [FJSJSWrapper wrapperWithClass:objCClass];
//
//        JSObjectRef r = JSObjectMake(ctx, FJSGlobalClass, (__bridge void *)(runtime));
//
//        JSObjectSetPrivate(r, (__bridge void *)(w));
//
//        CFRetain((__bridge void *)w);
//
//        return r;
//    }
//
//    if (existingWrap && [existingWrap isClass] && [existingWrap hasClassMethodNamed:propertyName]) {
//        debug(@"class lookup of something…");
//
//
//        FJSJSWrapper *w = [existingWrap wrapperForClassMethodNamed:propertyName];
//
//        JSObjectRef r = JSObjectMake(ctx, FJSGlobalClass, (__bridge void *)(runtime));
//
//        JSObjectSetPrivate(r, (__bridge void *)(w));
//
//        CFRetain((__bridge void *)w);
//
//        return r;
//    }
//
//
//
//    if ([propertyName isEqualToString:@"testClassMethod"]) {
//        debug(@"jfkldsajfklds %p", object);
//    }
    
    return nil;
}

//static bool FJS_hasProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS) {
//    NSString *propertyName = (NSString *)CFBridgingRelease(JSStringCopyCFString(NULL, propertyNameJS));
//    debug(@"propertyName: '%@'", propertyName);
//    debug(@"%s:%d", __FUNCTION__, __LINE__);
//    return NO;
//}

static JSValueRef FJS_callAsFunction(JSContextRef ctx, JSObjectRef functionJS, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef *exception) {
    
    FJSRuntime *runtime = [FJSRuntime runtimeInContext:ctx];
    
    FJSValue *objectToCall = [FJSValue wrapperForJSObject:thisObject runtime:runtime];
    FJSValue *functionToCall = [FJSValue wrapperForJSObject:functionJS runtime:runtime];
    
    debug(@"Calling function '%@'", [[functionToCall symbol] name]);
    
    NSMutableArray *args = [NSMutableArray arrayWithCapacity:argumentCount];
    for (size_t idx = 0; idx < argumentCount; idx++) {
        JSValueRef jsArg = arguments[idx];
        FJSValue *arg = [FJSValue wrapperForJSObject:(JSObjectRef)jsArg runtime:runtime];
        assert(arg);
        [args addObject:arg];
    }
    
    FJSFFI *ffi = [FJSFFI ffiWithFunction:functionToCall caller:objectToCall arguments:args cos:runtime];
    
    FJSValue *ret = [ffi callFunction];
    
    JSValueRef returnRef = [ret JSValue];
    
    if ([[[functionToCall symbol] name] isEqualToString:@"new"]) {
        assert(returnRef);
    }
    
    //debug(@"returnRef: %@ for function '%@' (%@)", returnRef, [[functionToCall symbol] name], ret);
    
    return returnRef;
}

static void FJS_finalize(JSObjectRef object) {
    FJSValue *objectToCall = (__bridge FJSValue *)(JSObjectGetPrivate(object));
    
    if (objectToCall) {
        CFRelease((__bridge CFTypeRef)(objectToCall));
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

/*
 
void FJS_exportClassJSExport(Class class) {
    // Create a protocol that inherits from JSExport and with all the public methods and properties of the class
 
    NSString *protocolName = [NSString stringWithFormat:@"%sJavaScriptMethods", class_getName(class)];
    Protocol *myProtocol = objc_allocateProtocol([protocolName UTF8String]);
 
    if (!myProtocol) { // We've already allocated it.
        return;
    }
 
    // Add the public methods of the class to the protocol
    unsigned int methodCount, classMethodCount, propertyCount;
    Method *methods, *classMethods;
    objc_property_t *properties;
 
    methods = class_copyMethodList(class, &methodCount);
//    for (NSUInteger methodIndex = 0; methodIndex < methodCount; ++methodIndex) {
//        Method method = methods[methodIndex];
//
////        if (method_getName(method) == @selector(init)) {
////            debug(@"skipping init");
////            continue;
////        }
//
//        //debug(@"instance: %@", NSStringFromSelector(method_getName(method)));
//        protocol_addMethodDescription(myProtocol, method_getName(method), method_getTypeEncoding(method), YES, YES);
//    }
 
    classMethods = class_copyMethodList(object_getClass(class), &classMethodCount);
    for (NSUInteger methodIndex = 0; methodIndex < classMethodCount; ++methodIndex) {
        Method method = classMethods[methodIndex];
 
        debug(@"class: %@", NSStringFromSelector(method_getName(method)));
        protocol_addMethodDescription(myProtocol, method_getName(method), method_getTypeEncoding(method), YES, NO);
    }
 
 
 
    properties = class_copyPropertyList(class, &propertyCount);
    for (NSUInteger propertyIndex = 0; propertyIndex < propertyCount; ++propertyIndex) {
        objc_property_t property = properties[propertyIndex];
 
        //debug(@"%s", property_getName(property));
 
        unsigned int attributeCount;
        objc_property_attribute_t *attributes = property_copyAttributeList(property, &attributeCount);
        protocol_addProperty(myProtocol, property_getName(property), attributes, attributeCount, YES, YES);
        free(attributes);
    }
 
    free(methods);
    free(classMethods);
    free(properties);
 
    protocol_addProtocol(myProtocol, objc_getProtocol("JSExport"));
 
    // Add the new protocol to the class
    objc_registerProtocol(myProtocol);
    class_addProtocol(class, myProtocol);
 
    assert(protocol_conformsToProtocol(myProtocol, objc_getProtocol("JSExport")));
 
    // forEachProtocolImplementingProtocol
//    debug(@"listing");
//    unsigned int outCount;
//    __unsafe_unretained Protocol **protocols = class_copyProtocolList(class, &outCount);
//    for (int i = 0; i < outCount; i++) {
//
//        Protocol *ptotocol = protocols[i];
//        const char * name = protocol_getName(ptotocol);
//        NSLog(@"ptotocol_name:%s - %d!", name, protocol_conformsToProtocol(ptotocol, objc_getProtocol("JSExport")));
//
//    }
 
//    Class superclass = class_getSuperclass(class);
//    if (superclass) {
//        FJS_exportClassJSExport(superclass);
//    }
}*/









