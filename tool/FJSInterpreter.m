//
//  MOCInterpreter.m
//  mocha
//
//  Created by Logan Collins on 5/12/12.
//  Copyright (c) 2012 Sunflower Softworks. All rights reserved.
//

#import "FJSInterpreter.h"
#import "FJSPrivate.h"
#import <JavaScriptCore/JavaScriptCore.h>

#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <readline/readline.h>
#import <readline/history.h>
#import <sys/select.h>


static const char interactivePrompt[] = "> ";

static char ** runtimeCompletion(const char * text, int start, int end);

@implementation FJSInterpreter

- (void)installBuiltinsInRuntime:(FJSRuntime*)runtime {
    
//    MOMethod *gc = [MOMethod methodWithTarget:runtime selector:@selector(garbageCollect)];
//    [runtime setValue:gc forKey:@"gc"];
//
//    MOMethod *checkSyntax = [MOMethod methodWithTarget:runtime selector:@selector(isSyntaxValidForString:)];
//    [runtime setValue:checkSyntax forKey:@"checkSyntax"];
//
//    MOMethod *exit = [MOMethod methodWithTarget:self selector:@selector(exit)];
//    [runtime setValue:exit forKey:@"exit"];
    
    [runtime setObject:self forKeyedSubscript:@"console"];
    
    
    
}

- (void)log:(NSString*)s {
    printf("%s\n", [[s description] UTF8String]);
}

- (void)run {
    FJSRuntime *runtime = [FJSRuntime new];
    
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        
        NSString *sourceURL = [[exception userInfo] objectForKey:@"sourceURL"];
        NSString *line      = [[exception userInfo] objectForKey:@"line"];
        NSString *column    = [[exception userInfo] objectForKey:@"column"];
        
        printf("Exception:");
        
        if (line && column) {
            printf(" line %s:%s", [line UTF8String], [column UTF8String]);
        }
        if (sourceURL) {
            printf(" of %s", [sourceURL UTF8String]);
        }
        
        printf("\n%s\n", [[exception description] UTF8String]);
        
    }];
    
    [self installBuiltinsInRuntime:runtime];
    
    rl_attempted_completion_function = runtimeCompletion;
    rl_bind_key('\t', rl_complete);
    
    char *line = NULL;
    
    while ((line = readline(interactivePrompt))) {
        if (line[0]) {
            add_history(line);
        }
        
        NSString *string = [NSString stringWithCString:(const char *)line encoding:NSUTF8StringEncoding];
        
        if ([string length]) {
            
            FJSValue *value = [runtime evaluateScript:string];
            id obj = [value toObject];
            if (obj) {
                printf("%s\n", [[[value toObject] description] UTF8String]);
            }
        }
        
        free(line);
    }
}

- (void)exit {
    exit(0);
}

@end


static char ** runtimeCompletion(const char * text, int start, int end) {
    char ** matches = NULL;
    NSString *query = [NSString stringWithUTF8String:text];
    NSArray *symbols = [[[FJSSymbolManager sharedManager] symbolNames] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self beginswith %@", query]];
    NSUInteger count = [symbols count];
    if (count > 0) {
        matches = (char **)malloc(sizeof(char *) * ([symbols count] + 1));
        
        for (NSUInteger i=0; i<count; i++) {
            NSString *string = [symbols objectAtIndex:i];
            char * aString = (char *)[string UTF8String];
            char * name = (char *)malloc(strlen(aString) + 1);
            strcpy(name, aString);
            matches[i] = name;
        }
        matches[count] = NULL;
    }
    
    return matches;
}

// For some reason, #import <sys/select.h> isn't good enough…
int select(int, fd_set * __restrict, fd_set * __restrict, fd_set * __restrict, struct timeval * __restrict);

@implementation NSFileHandle (FJSAdditions)

- (BOOL)fjs_isReadable {
    int fd = [self fileDescriptor];
    fd_set fdset;
    struct timeval tmout = { 0, 0 }; // return immediately
    FD_ZERO(&fdset);
    FD_SET(fd, &fdset);
    if (select(fd + 1, &fdset, NULL, NULL, &tmout) <= 0) {
        return NO;
    }
    return FD_ISSET(fd, &fdset);
}

- (BOOL)fjs_isTerminal {
    int fd = [self fileDescriptor];
    return (isatty(fd) == 1 ? YES : NO);
}

@end






