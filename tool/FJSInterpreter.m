//
//  MOCInterpreter.m
//  mocha
//
//  Created by Logan Collins on 5/12/12.
//  Copyright (c) 2012 Sunflower Softworks. All rights reserved.
//

#import "FJSInterpreter.h"

#import <JavaScriptCore/JavaScriptCore.h>

#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <readline/readline.h>
#import <readline/history.h>


static const char interactivePrompt[] = "> ";

//static char ** runtimeCompletion(const char * text, int start, int end);


@interface FJSInterpreter ()

- (void)installBuiltins;

@end


@implementation FJSInterpreter

- (void)installBuiltins {
//    FJSRuntime *runtime = [FJSRuntime new];
//
//    MOMethod *gc = [MOMethod methodWithTarget:runtime selector:@selector(garbageCollect)];
//    [runtime setValue:gc forKey:@"gc"];
//
//    MOMethod *checkSyntax = [MOMethod methodWithTarget:runtime selector:@selector(isSyntaxValidForString:)];
//    [runtime setValue:checkSyntax forKey:@"checkSyntax"];
//
//    MOMethod *exit = [MOMethod methodWithTarget:self selector:@selector(exit)];
//    [runtime setValue:exit forKey:@"exit"];
}

- (void)run {
    FJSRuntime *runtime = [FJSRuntime new];
    //[runtime setDelegate:self];
    
    [self installBuiltins];
    
    //rl_attempted_completion_function = runtimeCompletion;
    //rl_bind_key('\t', rl_complete);
    
    char *line = NULL;
    
    while ((line = readline(interactivePrompt))) {
        if (line[0]) {
            add_history(line);
        }
        
        NSString *string = [NSString stringWithCString:(const char *)line encoding:NSUTF8StringEncoding];
        
        if ([string length] > 0) {
            @try {
                [runtime evaluateScript:string];
//
//                JSValueRef value =
//                if (value != NULL) {
//                    JSStringRef string = JSValueToStringCopy([runtime context], value, NULL);
//                    NSString *description = (NSString *)CFBridgingRelease(JSStringCopyCFString(NULL, string));
//                    JSStringRelease(string);
//                    printf("%s\n", [description UTF8String]);
//                }
//
//                // Set the last result as the special variable "_"
//                id object = [runtime objectForJSValue:value];
//                if (object != nil) {
//                    [runtime setValue:object forKey:@"_"];
//                }
//                else {
//                    [runtime setNilValueForKey:@"_"];
//                }
            }
            @catch (NSException *e) {
                if ([e userInfo] != nil) {
                    printf("%s: %s\n%s\n", [[e name] UTF8String], [[e reason] UTF8String], [[[e userInfo] description] UTF8String]);
                }
                else {
                    printf("%s: %s\n", [[e name] UTF8String], [[e reason] UTF8String]);
                }
            }
        }
        
        free(line);
    }
}

- (void)exit {
    exit(0);
}

@end

//
//static char ** runtimeCompletion(const char * text, int start, int end) {
//    char ** matches = NULL;
//    
//    Mocha *runtime = [Mocha sharedRuntime];
//    NSString *query = [NSString stringWithUTF8String:text];
//    NSArray *symbols = [[runtime globalSymbolNames] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self beginswith %@", query]];
//    NSUInteger count = [symbols count];
//    
//    if (count > 0) {
//        matches = (char **)malloc(sizeof(char *) * ([symbols count] + 1));
//        
//        for (NSUInteger i=0; i<count; i++) {
//            NSString *string = [symbols objectAtIndex:i];
//            char * aString = (char *)[string UTF8String];
//            char * name = (char *)malloc(strlen(aString) + 1);
//            strcpy(name, aString);
//            matches[i] = name;
//        }
//        matches[count] = NULL;
//    }
//    
//    return matches;
//}

