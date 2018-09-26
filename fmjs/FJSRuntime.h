//
//  FJSRuntime.h
//  fmjs
//
//  Created by August Mueller on 8/20/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@import JavaScriptCore;

@class FJSValue;

APPKIT_EXTERN const CGRect CGRectOneTwoThree;

NS_ASSUME_NONNULL_BEGIN

@interface FJSRuntime : NSObject

- (FJSValue*)evaluateScript:(NSString*)str;
- (FJSValue*)evaluateScript:(NSString *)script withSourceURL:(nullable NSURL *)sourceURL;

- (JSValueRef)setRuntimeObject:(nullable id)object withName:(NSString *)name;

- (void)shutdown;
- (void)garbageCollect;

- (JSValueRef)newJSValueForWrapper:(FJSValue*)w;

- (JSContextRef)contextRef;

@end


NS_ASSUME_NONNULL_END
