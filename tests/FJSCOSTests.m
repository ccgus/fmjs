//
//  FJSCOSTests.m
//  FMJSTests
//
//  Created by August Mueller on 4/29/20.
//  Copyright © 2020 Flying Meat Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FJSCocoaScriptPreProcessor.h"

@interface FJSCOSTests : XCTestCase

@end

@implementation FJSCOSTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testProc1 {
    
    NSString *r = [FJSCocoaScriptPreProcessor preprocessCode:@"[jstalk include:'acornsetup.jstalk'];"];
    
    XCTAssert([r isEqualToString:@"jstalk.include_( 'acornsetup.jstalk');"]);
}

@end
