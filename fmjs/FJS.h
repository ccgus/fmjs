//
//  FMJS.h
//  FMJS
//
//  Created by August Mueller on 9/15/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//! Project version number for FMJS.
FOUNDATION_EXPORT double FMJSVersionNumber;

//! Project version string for FMJS.
FOUNDATION_EXPORT const unsigned char FMJSVersionString[];

#ifdef DEBUG
#ifndef debug
    #define debug(...) NSLog(__VA_ARGS__)
    #define FMAssert assert

    // Just comment out the above if we want to use this guy:
    #ifndef FMAssert
        #define FMAssert(condition) \
        { \
            if (!(condition)) {\
                NSLog(@"FMAssert fail on %s:%d", __FUNCTION__, __LINE__);\
                NSLog(@"Invalid parameter not satisfying: %s", #condition); \
                NSLog(@"%@",[NSThread callStackSymbols]);\
            }\
        }
    #endif
#endif
#else
    #define debug(...)
    #define FMAssert(...)
#endif

#import "FJSRuntime.h"
#import "FJSValue.h"
#import "FJSSymbolManager.h"
