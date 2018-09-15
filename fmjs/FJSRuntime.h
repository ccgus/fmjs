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

@property (strong) JSContext *jscContext;

- (id)evaluateScript:(NSString*)str;
- (id)evaluateScript:(NSString *)script withSourceURL:(NSURL *)sourceURL;

- (JSValueRef)setRuntimeObject:(id)object withName:(NSString *)name;

- (void)garbageCollect;

- (JSValueRef)newJSValueForWrapper:(FJSValue*)w;

- (JSContextRef)contextRef;

@end


NS_ASSUME_NONNULL_END
