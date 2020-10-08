//
//  main.m
//  fmjs
//
//  Created by August Mueller on 9/30/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//
//  Portions created by Logan Collins on 5/12/12.
//  Copyright (c) 2012 Sunflower Softworks. All rights reserved.


#import <Foundation/Foundation.h>
#import <getopt.h>
#import "FJS.h"
#import "FJSInterpreter.h"
#import "FJSPrivate.h"

static const char * program_name = "fmjs";
static const char * program_version = "0.1a";


static const char * short_options = "hv";
static struct option long_options[] = {
    { "help", optional_argument, NULL, 'h' },
    { "version", optional_argument, NULL, 'v' },
    { NULL, 0, NULL, 0 }
};


static void printUsage(FILE *stream) {
    fprintf(stream, "%s %s\n", program_name, program_version);
    fprintf(stream, "Usage: %s [-hv] [file]\n", program_name);
    fprintf(stream,
            "  -h, --help                Show this help information.\n"
            "  -v, --version             Show the program's version number.\n"
            );
}


static void printVersion(void) {
    printf("%s %s\n", program_name, program_version);
}


void FJSToolExecuteScriptWithArguments(NSString *script, NSString *path, NSArray *args);


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSMutableArray *arguments = [NSMutableArray array];
        
        // Check and see if the first argument is a file. If yes, then don't bother with the fmjs commands.
        
        int idx = 1;
        if (idx < argc) {
            while (idx < argc) {
                const char * arg = argv[idx++];
                NSString *string = [NSString stringWithUTF8String:arg];
                [arguments addObject:string];
            }
        }
        
        
        NSString  *firstArgReadAsPath = nil;
        if ([arguments count]) {
            NSError *fileReadError;
            firstArgReadAsPath = [NSString stringWithContentsOfFile:[arguments firstObject] encoding:NSUTF8StringEncoding error:&fileReadError];
        }
        
        if (!firstArgReadAsPath) {
            int next_option;
            do {
                next_option = getopt_long(argc, (char * const *)argv, short_options, long_options, NULL);
                
                switch (next_option) {
                    case -1: {
                        break;
                    }
                    case 'v': {
                        printVersion();
                        exit(0);
                        break;
                    }
                    case 'h': {
                        printUsage(stdout);
                        exit(0);
                        break;
                    }
                    case '?': {
                        printUsage(stderr);
                        exit(1);
                        break;
                    }
                }
            }
            while (next_option != -1);
        }
        
        
        NSFileHandle *stdinHandle = [NSFileHandle fileHandleWithStandardInput];
        
        
        if (firstArgReadAsPath) {
            FJSToolExecuteScriptWithArguments(firstArgReadAsPath, [arguments firstObject], arguments);
        }
        else if ([stdinHandle fjs_isReadable]) {
            // Execute contents of stdin
            NSData *stdinData = [stdinHandle readDataToEndOfFile];
            NSString *string = [[NSString alloc] initWithData:stdinData encoding:NSUTF8StringEncoding];
            FJSToolExecuteScriptWithArguments(string, nil, arguments);
        }
        else {
            // Interactive mode
            FJSInterpreter *interpreter = [FJSInterpreter new];
            [interpreter run];
        }
    }
    return 0;
}


void FJSToolExecuteScriptWithArguments(NSString *script, NSString *path, NSArray *args) {
    FJSRuntime *rt = [FJSRuntime new];
    
    [rt setExceptionHandler:^(FJSRuntime * _Nonnull runtime, NSException * _Nonnull exception) {
        
        NSString *sourceURL = [[exception userInfo] objectForKey:@"sourceURL"];
        NSString *line      = [[exception userInfo] objectForKey:@"line"];
        NSString *column    = [[exception userInfo] objectForKey:@"column"];
        
        printf("Exception:");
        
        if (line && column) {
            printf(" line %s:%s", [line UTF8String], [column UTF8String]);
        }
        else if (line) {
            printf(" line %s", [line UTF8String]);
        }
        
        if (sourceURL) {
            printf(" of %s", [sourceURL UTF8String]);
        }
        
        printf("\n%s\n", [[exception description] UTF8String]);
        
    }];
    
    if ([script length] >= 2 && [[script substringWithRange:NSMakeRange(0, 2)] isEqualToString:@"#!"]) {
        // Ignore bash shebangs
        NSRange lineRange = [script lineRangeForRange:NSMakeRange(0, 2)];
        script = [script substringFromIndex:NSMaxRange(lineRange)];
    }
    
    // We're going to fake Node's process package.
    NSDictionary *process = @{@"argv": (args ? args : @[]), @"exit": ^(int code) { exit(code); }};
    rt[@"process"] = process;
    
    @try {
        [FJSValue setCaptureJSValueInstancesForDebugging:YES];
        [rt evaluateScript:script withSourceURL:[NSURL fileURLWithPath:path]];
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


