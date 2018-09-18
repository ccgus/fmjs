//
//  fmjsTests.m
//  fmjsTests
//
//  Created by August Mueller on 9/15/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FJS.h"
#import "FJSTestStuff.h"
@interface FJSSimpleTests : XCTestCase

@end

int FJSSimpleTestsInitHappend;
int FJSSimpleTestsDeallocHappend;
int FJSSimpleTestsMethodCalled;


@interface AllocInitDeallocTest : NSObject

@end

@implementation AllocInitDeallocTest

- (instancetype)init {
    self = [super init];
    if (self) {
        FJSSimpleTestsInitHappend++;
    }
    
    return self;
}

- (void)testMethod {
    FJSSimpleTestsMethodCalled++;
}

- (void)dealloc {
    FJSSimpleTestsDeallocHappend++;
    NSLog(@"Gone! (%d)", FJSSimpleTestsDeallocHappend);
}

@end




@implementation FJSSimpleTests


- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testInitAndDealoc {
    FJSSimpleTestsInitHappend = 0;
    FJSSimpleTestsDeallocHappend = 0;
    FJSSimpleTestsMethodCalled = 0;

    int count = 10;
    
    
    @autoreleasepool {
        
        FJSRuntime *runtime = [[FJSRuntime alloc] init];
        
        for (int i = 0; i < count; i++) {
            [runtime evaluateScript:@"var c = AllocInitDeallocTest.new(); c.testMethod(); c = null;"];
        }
        
        [runtime shutdown];
        
        debug(@"done? %d/%d", FJSSimpleTestsInitHappend, FJSSimpleTestsMethodCalled);
        
        XCTAssert(FJSSimpleTestsMethodCalled == count);
        XCTAssert(FJSSimpleTestsInitHappend == count);
    
        
    }
    
    // I've seen this take over 70 seconds in the past. I'm sure there's something we can do to nudge things along, I just don't know what those are.
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    while (FJSSimpleTestsDeallocHappend != count)  {
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
    }
    
    debug(@"%f seconds later…", [NSDate timeIntervalSinceReferenceDate] - startTime);
    
    XCTAssert(FJSSimpleTestsMethodCalled == count);
    XCTAssert(FJSSimpleTestsInitHappend == count);
    XCTAssert(FJSSimpleTestsDeallocHappend == count);
}


- (void)xtestExample {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassCCharM(FJSTestAddSignedChar('l'));"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassUnsignedCCharM(FJSTestAddUnsignedChar('l'));"];
    assert(FJSTestStuffTestPassed);
    
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"print(FJSMethodStringSringArgStringReturn('Hello', 'World'))"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassNegativeBOOL(FJSMethodNegateBOOL(true));"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassPositiveBOOL(FJSMethodNegateBOOL(false));"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassNSStringClass(NSString.class());"];
    assert(FJSTestStuffTestPassed);
    
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassNegativeBOOL(false);"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassPositiveBOOL(true);"];
    assert(FJSTestStuffTestPassed);
    
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassFloat123(123);"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassDouble123(123);"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassDataUsingEncodingAllowLossyConversionSelectorAndCharM('dataUsingEncoding:allowLossyConversion:', 'm');"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassDataUsingEncodingAllowLossyConversionSelector('dataUsingEncoding:allowLossyConversion:');"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassSignedLongNumber3(3);"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassUnsignedLongNumber3(3);"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassSignedLongLongNumber3(3);"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassUnsignedLongLongNumber3(3);"];
    assert(FJSTestStuffTestPassed);
    
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassSignedShortNumber3(3);"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassUnsignedShortNumber3(3);"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassCCharM('m');"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassUnsignedCCharM('m');"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassSignedIntNumber3(3);"];
    assert(FJSTestStuffTestPassed);
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassUnsignedIntNumber3(3);"];
    assert(FJSTestStuffTestPassed);
    
    [runtime evaluateScript:@"var c = FJSTestStuff.new(); FJSAssertObject(c); FJSAssert(c != null);"];
    
    [runtime evaluateScript:@"print('Hello?');"];
    [runtime evaluateScript:@"print(FJSMethodReturnNSDictionary());"];
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodCheckNSDictionary(FJSMethodReturnNSDictionary());"];
    assert(FJSTestStuffTestPassed);
    
    
    FJSTestStuffTestPassed = NO;
    [runtime evaluateScript:@"FJSMethodPleasePassNSNumber3(3);"];
    assert(FJSTestStuffTestPassed);
    
    
    
    
    //[cos evaluateScript:@"print(NSHomeDirectoryForUser('kirstin'));"];
    
    //[cos evaluateScript:@"s = NSUUID.allocWithZone(null).init(); print(s);"];
    
    //[cos evaluateScript:@"print(NSUserName())"];
    //[cos evaluateScript:@"print(NSFullUserName())"];
    //[cos evaluateScript:@"var s = COScriptLite.testClassMethod();"];
    //[cos evaluateScript:@"s = null;"];
    
    [runtime garbageCollect];
    
    printf("All done\n");
    
}

- (void)xtestPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
