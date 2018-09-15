//
//  main.m
//  yd
//
//  Created by August Mueller on 8/20/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FJSRuntime.h"
#import "FJSBridgeParser.h"
#import "FJSTestStuff.h"
#import <objc/runtime.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        [[FJSBridgeParser sharedParser] parseBridgeFileAtPath:@"/Users/gus/Projects/yellowduck/bridgesupport/yd.bridgesupport"];
        
        FJSRuntime *runtime = [FJSRuntime new];
        
        //[cos evaluateScript:@"x = 10; log(x); print('Hello, World');"];
        
        
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
        
        //NSLog(@"%@", NSHomeDirectoryForUser(@"kirstin"));
        
    }
    return 0;
}
