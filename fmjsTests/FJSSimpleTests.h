//
//  fmjsTests.m
//  fmjsTests
//
//  Created by August Mueller on 9/15/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface FJSSimpleTests : XCTestCase

@end

APPKIT_EXTERN const NSString *FJSTestConstString;
APPKIT_EXTERN const int FJSTestConstInt;


FOUNDATION_STATIC_INLINE BOOL FJSEqualFloats(CGFloat a, CGFloat b) {
#if __LP64__
    return fabs(a - b)  <= FLT_EPSILON;
#else
    return fabsf(a - b) <= FLT_EPSILON;
#endif
}

