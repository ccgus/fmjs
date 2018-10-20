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

#ifndef debug
#define debug NSLog
#endif

#ifndef FMAssert
#define FMAssert assert
#endif

#import <FMJS/FJSRuntime.h>
#import <FMJS/FJSValue.h>
// TODO, figure out why FJSSymbolManager, and only FJSSymbolManager needs to have a lowercase fmjs there.
//#import <FMJS/FJSSymbolManager.h>
#import <fmjs/FJSSymbolManager.h>
