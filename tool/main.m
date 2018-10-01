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


void executeScript(NSString *script, NSString *path);


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSMutableArray *filePaths = [NSMutableArray array];
        
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
        
        if (optind < argc) {
            while (optind < argc) {
                const char * arg = argv[optind++];
                NSString *string = [NSString stringWithUTF8String:arg];
                [filePaths addObject:string];
            }
        }
        
        NSFileHandle *stdinHandle = [NSFileHandle fileHandleWithStandardInput];
        
        if ([filePaths count] > 0) {
            // Execute files
            for (NSString *path in filePaths) {
                NSError *err;
                NSString *s = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
                
                if (!s) {
                    NSLog(@"Could not read the file at %@", path);
                    NSLog(@"%@", err);
                    exit(1);
                }
                
                executeScript(s, path);
            }
        }
        else if ([stdinHandle fjs_isReadable]) {
            // Execute contents of stdin
            NSData *stdinData = [stdinHandle readDataToEndOfFile];
            NSString *string = [[NSString alloc] initWithData:stdinData encoding:NSUTF8StringEncoding];
            executeScript(string, nil);
        }
        else {
            // Interactive mode
            FJSInterpreter *interpreter = [FJSInterpreter new];
            [interpreter run];
        }
    }
    return 0;
}


void executeScript(NSString *script, NSString *path) {
    FJSRuntime *rt = [FJSRuntime new];
    
    if ([script length] >= 2 && [[script substringWithRange:NSMakeRange(0, 2)] isEqualToString:@"#!"]) {
        // Ignore bash shebangs
        NSRange lineRange = [script lineRangeForRange:NSMakeRange(0, 2)];
        script = [script substringFromIndex:NSMaxRange(lineRange)];
    }
    
    @try {
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


