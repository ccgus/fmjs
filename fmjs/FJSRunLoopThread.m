//
//  FJSRunLoopThread.m
//  fmjs
//
//  Created by August Mueller on 11/19/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//
/*
 * Copyright (C) 2014 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "FJSRunLoopThread.h"
#import "FJSScriptInputSource.h"

#import <pthread.h>

@implementation FJSBasicRunLoopThread {
    pthread_t m_thread;
    pthread_mutex_t m_lock;
    pthread_cond_t m_condition;
    bool m_loopInitialized;
}

+ (FJSThreadMainType)threadMain
{
    return 0;
}

- (id)init
{
    self = [super init];
    if (!self)
        return nil;
    
    m_loopInitialized = false;
    
    pthread_mutex_init(&m_lock, NULL);
    pthread_cond_init(&m_condition, NULL);
    
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&m_lock);
    pthread_cond_destroy(&m_condition);
}

- (void)didFinishRunLoopInitialization
{
    pthread_mutex_lock(&m_lock);
    m_loopInitialized = true;
    pthread_cond_signal(&m_condition);
    pthread_mutex_unlock(&m_lock);
}

- (void)start
{
    pthread_create(&m_thread, NULL, [[self class] threadMain], (__bridge void *)(self));
    
    pthread_mutex_lock(&m_lock);
    while (!m_loopInitialized)
        pthread_cond_wait(&m_condition, &m_lock);
    pthread_mutex_unlock(&m_lock);
}

- (void)join
{
    void* result;
    pthread_join(m_thread, &result);
}

@end


@implementation FJSRunLoopThread {
    NSString *m_fileToRun;
    CFRunLoopRef m_runLoop;
    FJSScriptInputSource *m_scriptSource;
    FJSRuntime *m_runtime;
    dispatch_queue_t m_asyncQueue;
}

static void* jsThreadMain(void* context)
{
    FJSRunLoopThread *thread = (__bridge FJSRunLoopThread *)(context);
    [thread startRunLoop];
    return 0;
}

+ (FJSThreadMainType)threadMain
{
    return jsThreadMain;
}

- (id)initWithRuntime:(FJSRuntime *)runtime {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    m_runtime = runtime;
    m_scriptSource = [[FJSScriptInputSource alloc] initWithRuntime:runtime];
    m_asyncQueue = dispatch_queue_create("node.fmjs async queue", DISPATCH_QUEUE_CONCURRENT);
    
    return self;
}

- (void)loadFile:(NSString *)file
{
    m_fileToRun = file;
}

- (void)startRunLoop
{
    m_runLoop = CFRunLoopGetCurrent();
    [m_scriptSource addToCurrentRunLoop];
    
    [self didFinishRunLoopInitialization];
    
    CFRunLoopRun();
}

- (void)start
{
    [super start];
    
    if (m_fileToRun) {
        NSString *script = [NSString stringWithContentsOfFile:m_fileToRun encoding:NSUTF8StringEncoding error:nil];
        [m_scriptSource runScriptRemotely:script];
    }
}

- (void)join
{
    [m_scriptSource removeFromRemoteRunLoop];
    CFRunLoopStop(m_runLoop);
    
    [super join];
}

- (FJSValue *)didReceiveInput:(NSString *)input
{
    return [m_scriptSource runScriptRemotely:input];
}

- (void)performCallback:(FJSValue *)callback withError:(NSString *)errorMessage
{
}

- (void)performCallback:(FJSValue *)callback withArguments:(NSArray *)arguments
{
}

- (void)didFinishRunLoopInitialization
{
    NSMutableDictionary *threadStorage = [[NSThread currentThread] threadDictionary];
    [threadStorage setObject:self forKey:@"currentJSThread"];
    [super didFinishRunLoopInitialization];
}

@end


