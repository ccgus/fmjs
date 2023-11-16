//
//  FJSDispatch.m
//  FMJS
//
//  Created by August Mueller on 2/27/20.
//  Copyright © 2020 Flying Meat Inc. All rights reserved.
//

#import "FJSDispatch.h"
#import "FJS.h"
#import "FJSPrivate.h"

@implementation FJSDispatch


+ (void)syncOnMain:(FJSValue *)function inFJSRuntime:(FJSRuntime*)runtime {
    
    
    FMAssert(function);
    
    if ([function isJSFunction]) {
        
        if ([NSThread isMainThread]) {
            [function callWithArguments:@[]];
        }
        else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [function callWithArguments:@[]];
            });
        }
    }
    else {
        NSLog(@"syncOnMain passed a non function object: %@", function);
    }
}

+ (void)asyncOnMain:(FJSValue *)function inFJSRuntime:(FJSRuntime*)runtime {
    
    
    FMAssert(function);
    
    if ([function isJSFunction]) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [function callWithArguments:@[]];
        });
        
    }
    else {
        NSLog(@"asyncOnMain passed a non function object: %@", function);
    }
}

+ (void)syncOnBackground:(FJSValue *)function inFJSRuntime:(FJSRuntime*)runtime {
    
    
    FMAssert(function);
    
    if ([function isJSFunction]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [function callWithArguments:@[]];
        });
        
    }
    else {
        NSLog(@"asyncOnMain passed a non function object: %@", function);
    }
}

+ (void)asyncOnBackground:(FJSValue *)function inFJSRuntime:(FJSRuntime*)runtime {
    
    
    FMAssert(function);
    
    if ([function isJSFunction]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [function callWithArguments:@[]];
        });
        
    }
    else {
        NSLog(@"asyncOnMain passed a non function object: %@", function);
    }
}



@end

void FJSDispatchSyncOnMainThread(void (^block)(void)) {
    
    if ([NSThread isMainThread]) {
        block();
    }
    else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

void FJSDispatchAsyncOnMainThread(void (^block)(void)) {
    
    if ([NSThread isMainThread]) {
        block();
    }
    else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}


