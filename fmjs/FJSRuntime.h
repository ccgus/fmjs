//
//  FJSRuntime.h
//  yd
//
//  Created by August Mueller on 8/20/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@import JavaScriptCore;

@class FJSValue;

NS_ASSUME_NONNULL_BEGIN

@protocol COScriptLiteJavaScriptMethods <JSExport>

+ (void)testClassMethod;

@end

@interface FJSRuntime : NSObject <COScriptLiteJavaScriptMethods>

- (FJSValue*)evaluateScript:(NSString*)str;
- (FJSValue*)evaluateScript:(NSString *)script withSourceURL:(nullable NSURL *)sourceURL;

- (JSValueRef)setRuntimeObject:(nullable id)object withName:(NSString *)name;

- (void)shutdown;
- (void)garbageCollect;

- (JSValueRef)newJSValueForWrapper:(FJSValue*)w;

- (JSContextRef)contextRef;

@end


NS_ASSUME_NONNULL_END
