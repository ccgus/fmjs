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

extern NSString *FMJavaScriptExceptionName;

@class FJSValue;


@interface FJSRuntime : NSObject

@property (class, assign) BOOL useSynchronousGarbageCollectForDebugging;
@property (copy) void(^exceptionHandler)(FJSRuntime *runtime, NSException *exception);
@property (copy) void(^printHandler)(FJSRuntime *runtime, NSString *stringToPrint);
@property (copy) void(^finalizeHandler)(FJSRuntime *runtime, FJSValue *value);
@property (strong) dispatch_queue_t evaluateQueue;

+ (void)loadFrameworkAtPath:(NSString*)path;

- (FJSValue*)evaluateScript:(NSString*)str;
- (FJSValue*)evaluateScript:(NSString *)script withSourceURL:(nullable NSURL *)sourceURL;

- (void)setRuntimeObject:(nullable id)object withName:(NSString *)name;
- (FJSValue*)runtimeObjectWithName:(NSString *)name;
- (void)deleteRuntimeObjectWithName:(NSString*)name;

- (void)shutdown;
- (void)garbageCollect;

- (JSValueRef)newJSValueForWrapper:(FJSValue*)w;

- (JSContextRef)contextRef;

- (FJSValue *)callFunctionNamed:(NSString*)name withArguments:(NSArray*)arguments;
- (BOOL)hasFunctionNamed:(NSString*)name;
+ (FJSRuntime*)currentRuntime;
@end


@interface NSObject (FJSRuntimePropertyAccess)

- (BOOL)hasFJSValueForKeyedSubscript:(NSString *)key inRuntime:(FJSRuntime*)runtime;
- (FJSValue*)FJSValueForKeyedSubscript:(NSString *)key inRuntime:(FJSRuntime*)runtime;
- (BOOL)setFJSValue:(FJSValue*)value forKeyedSubscript:(NSString*)key inRuntime:(FJSRuntime*)runtime;

- (id)hasFJSValueAtIndexedSubscript:(NSUInteger)index inRuntime:(FJSRuntime*)runtime;
- (id)FJSValueAtIndexedSubscript:(NSUInteger)index inRuntime:(FJSRuntime*)runtime;
- (BOOL)setFJSValue:(FJSValue*)value atIndexedSubscript:(NSUInteger)idx inRuntime:(FJSRuntime*)runtime;

@end

NS_ASSUME_NONNULL_END
