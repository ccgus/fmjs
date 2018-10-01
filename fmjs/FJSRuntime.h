//
//  FJSRuntime.h
//  fmjs
//
//  Created by August Mueller on 8/20/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@import JavaScriptCore;

extern NSString *FMJavaScriptExceptionName;

@class FJSValue;

NS_ASSUME_NONNULL_BEGIN

@interface FJSRuntime : NSObject

@property (copy) void(^exceptionHandler)(FJSRuntime *runtime, NSException *exception);
@property (copy) void(^printHandler)(FJSRuntime *runtime, NSString *stringToPrint);
@property (copy) void(^finalizeHandler)(FJSRuntime *runtime, FJSValue *value);

+ (void)loadFrameworkAtPath:(NSString*)path;

- (FJSValue*)evaluateScript:(NSString*)str;
- (FJSValue*)evaluateScript:(NSString *)script withSourceURL:(nullable NSURL *)sourceURL;

- (FJSValue*)setRuntimeObject:(nullable id)object withName:(NSString *)name;

- (void)shutdown;
- (void)garbageCollect;

- (JSValueRef)newJSValueForWrapper:(FJSValue*)w;

- (JSContextRef)contextRef;

- (FJSValue *)callFunctionNamed:(NSString*)name withArguments:(NSArray*)arguments;
- (BOOL)hasFunctionNamed:(NSString*)name;

@end


NS_ASSUME_NONNULL_END
