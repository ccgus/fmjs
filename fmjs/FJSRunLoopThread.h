//
//  FJSRunLoopThread.h
//  fmjs
//
//  Created by August Mueller on 11/19/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FJSValue.h"
NS_ASSUME_NONNULL_BEGIN


@interface FJSBasicRunLoopThread : NSObject

typedef void* (*FJSThreadMainType)(void*);
+ (FJSThreadMainType)threadMain;

- (void)didFinishRunLoopInitialization;
- (void)start;
- (void)join;

@end


@interface FJSRunLoopThread : FJSBasicRunLoopThread

+ (FJSThreadMainType)threadMain;

@property dispatch_queue_t asyncQueue;

- (id)initWithRuntime:(FJSRuntime *)runtime;
- (void)loadFile:(NSString *)file;
- (void)start;
- (void)join;
- (JSValue *)didReceiveInput:(NSString *)input;
- (void)performCallback:(JSValue *)callback withError:(NSString *)errorMessage;
- (void)performCallback:(JSValue *)callback withArguments:(NSArray *)arguments;
- (void)didFinishRunLoopInitialization;

@end


NS_ASSUME_NONNULL_END
