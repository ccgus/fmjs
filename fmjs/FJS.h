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

// In this header, you should import all the public headers of your framework using statements like #import <fmjs/PublicHeader.h>

#define debug NSLog
#define FMAssert assert

#import <FMJS/FJSRuntime.h>
