//
//  FJSRuntime.h
//  fmjs
//
//  Created by August Mueller on 8/20/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@import JavaScriptCore;

NS_ASSUME_NONNULL_BEGIN

extern BOOL FJSTraceFunctionCalls;
extern NSString *FMJavaScriptExceptionName;

//#define FJSTrace(...) NSLog(__VA_ARGS__)
#define FJSTrace(...)


// FJSMapValuesForEquality is used for cases where we have a singleton object (such as NSFileManger.defaultManager()) and we want to return the same FJSValue for that (each runtime will have it's own). We could use associated objects for this, but I'm hitting a bug where something is getting over-released and I'm unable to figure out where (see FJSAssociateValuesForEquality). JavaScriptCore runtime hacks making looking at stack traces impossible.
// #define FJSMapValuesForEquality 1

// This currently kills long-running JS processes. While I would prefer to use associated objects instead of a maptable, using a weak maptable seems to be the safer bet for now.
// #define FJSAssociateValuesForEquality 1

@class FJSValue;


@interface FJSRuntime : NSObject

@property (class, assign) BOOL useSynchronousGarbageCollectForDebugging;
@property (copy) void(^exceptionHandler)(FJSRuntime *runtime, NSException *exception);
@property (copy) void(^printHandler)(FJSRuntime *runtime, NSString *stringToPrint);
@property (copy) void(^finalizeHandler)(FJSRuntime *runtime, FJSValue *value);
@property (copy) NSURL*(^resolveModuleHandler)(FJSRuntime *runtime, NSString *moduleName);
@property (copy) void(^moduleWasLoadedHandler)(FJSRuntime *runtime, FJSValue *module, NSURL *moduleURl);
@property (nullable, strong) dispatch_queue_t evaluateQueue;
@property (strong) NSDictionary* coreModuleMap;
@property (assign, nonatomic) NSString *evaluatingScript;

+ (void)loadFrameworkAtPath:(NSString*)path;

- (FJSValue*)evaluateScript:(NSString*)str;
- (FJSValue*)evaluateScript:(NSString *)script withSourceURL:(nullable NSURL *)sourceURL;

- (FJSValue*)require:(NSString*)modulePath;
- (NSArray<FJSValue *>*)modules;
- (nullable FJSValue*)evaluateModuleAtURL:(NSURL*)scriptURL;

- (void)dispatchOnQueue:(DISPATCH_NOESCAPE dispatch_block_t)block;

// This gets us context["foo"] = @"Hi"; support
// Object can either be a FJSValue object, objc block, or an objc instance (which will be wrapped in a FJSValue)
- (void)setObject:(nullable id)object forKeyedSubscript:(nullable NSString *)key;
- (FJSValue*)objectForKeyedSubscript:(id)key;

- (void)removeRuntimeValueWithName:(NSString*)name;

- (void)addURLToModuleSearchPath:(NSURL*)url;

- (void)shutdown;
- (void)garbageCollect;

- (void)installRunloop;
+ (void)setUseSynchronousGarbageCollectForDebugging:(BOOL)flag;

- (JSValueRef)newJSValueForWrapper:(FJSValue*)w;

- (JSContextRef)contextRef;

#ifdef FJSMapValuesForEquality
- (NSMapTable*)instanceMapTable;
#endif

- (FJSValue *)callFunctionNamed:(NSString*)name withArguments:(NSArray*)arguments;
- (BOOL)hasFunctionNamed:(NSString*)name;
+ (FJSRuntime*)currentRuntime;

@end


@interface NSObject (FJSRuntimePropertyAccess)

- (BOOL)hasFJSValueForKeyedSubscript:(NSString *)key inRuntime:(FJSRuntime*)runtime;
- (nullable FJSValue*)FJSValueForKeyedSubscript:(NSString *)key inRuntime:(FJSRuntime*)runtime;
- (BOOL)setFJSValue:(FJSValue*)value forKeyedSubscript:(NSString*)key inRuntime:(FJSRuntime*)runtime;

- (id)hasFJSValueAtIndexedSubscript:(NSUInteger)index inRuntime:(FJSRuntime*)runtime;
- (id)FJSValueAtIndexedSubscript:(NSUInteger)index inRuntime:(FJSRuntime*)runtime;
- (BOOL)setFJSValue:(FJSValue*)value atIndexedSubscript:(NSUInteger)idx inRuntime:(FJSRuntime*)runtime;

- (BOOL)doFJSFunction:(FJSValue*)function inRuntime:(FJSRuntime*)runtime withValues:(NSArray<FJSValue*>*)values returning:(FJSValue*_Nullable __autoreleasing*_Nullable)returnValue;

@end

NS_ASSUME_NONNULL_END
