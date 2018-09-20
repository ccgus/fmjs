//
//  fmjsTests.m
//  fmjsTests
//
//  Created by August Mueller on 9/15/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <FMJS/FJS.h>
@interface FJSSimpleTests : XCTestCase

@end

FOUNDATION_STATIC_INLINE BOOL FJSEqualFloats(CGFloat a, CGFloat b) {
#if __LP64__
    return fabs(a - b)  <= FLT_EPSILON;
#else
    return fabsf(a - b) <= FLT_EPSILON;
#endif
}

int FJSSimpleTestsInitHappend;
int FJSSimpleTestsDeallocHappend;
int FJSSimpleTestsMethodCalled;
int FJSRandomTestMethodCalled;
BOOL FJSTestStuffTestPassed;

@interface FJSTestClass : NSObject
@property (assign) int passedInt;
@end

@implementation FJSTestClass

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

- (void)passArgument:(int)i {
    if (i == 42) {
        FJSRandomTestMethodCalled++;
        _passedInt = i;
    }
}

- (void)passMyself:(FJSTestClass*)inception {
    if (inception == self) {
        FJSRandomTestMethodCalled++;
    }
}


- (void)passAndPrintString:(NSString*)foo {
    printf("%s\n", [[foo description] UTF8String]);
}

- (void)passLong:(long)l {
    if (l == 42) {
        FJSRandomTestMethodCalled++;
    }
}


- (double)addDouble:(double)d float:(float)f {
    return d + f;
}

- (void)dealloc {
    FJSSimpleTestsDeallocHappend++;
    NSLog(@"Gone! (%d)", FJSSimpleTestsDeallocHappend);
}

@end




@implementation FJSSimpleTests


- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    NSString *FMJSBridgeSupportPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"FJSTests" ofType:@"bridgesupport"];
    FMAssert(FMJSBridgeSupportPath);
    
    [[FJSSymbolManager sharedManager] parseBridgeFileAtPath:FMJSBridgeSupportPath];
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testObjcMethods {
    FJSRandomTestMethodCalled = 0;
    
    FJSRuntime *runtime = [[FJSRuntime alloc] init];
    
    [runtime evaluateScript:@"var c = FJSTestClass.new(); c.passArgument_(42);"];
    
    XCTAssert(FJSRandomTestMethodCalled == 1);
    FJSRandomTestMethodCalled = 0;
    
    [runtime evaluateScript:@"c.passMyself_(c);"];
    
    XCTAssert(FJSRandomTestMethodCalled == 1);
    
    FJSRandomTestMethodCalled = 0;
    [runtime evaluateScript:@"c.passLong_(42);"];
    XCTAssert(FJSRandomTestMethodCalled == 1);
    
    FJSValue *df = [runtime evaluateScript:@"c.addDouble_float_(120, 4.5);"];
    
    XCTAssert(df);
    XCTAssert(FJSEqualFloats([df toDouble], 124.5));
    
    FJSValue *value = [runtime evaluateScript:@"c;"];
    
    FJSTestClass *testClass = [value toObject];
    XCTAssert(testClass);
    XCTAssert([testClass isKindOfClass:[FJSTestClass class]]);
    XCTAssert([testClass passedInt] == 42);
    
    // ES6 Support!
    [runtime evaluateScript:@"var n = 'Gus'; c.passAndPrintString_(`Hello ${n}!`);"];
    
    // This however, will not work. We get two arguments that are trying to be passed to passAndPrintString: The first is a js object, the second is the value of n
    // [runtime evaluateScript:@"c.passAndPrintString_`Hello again, ${n}!`;"];
    
    [runtime shutdown];
    
}

- (void)testSymbolLookup {
    
    // Make sure bridge stuff is loaded first.
    [FJSRuntime new];
    
    XCTAssert([FJSSymbol symbolForName:@"CIColorInvert" inObject:nil] != nil); // CIColorInvert isn't public, but it's a subclass of CIFilter that we get handed sometimes.
    XCTAssert([FJSSymbol symbolForName:@"NSString" inObject:nil] != nil);
    XCTAssert([FJSSymbol symbolForName:@"NSMutableString" inObject:nil] != nil);
    
    XCTAssert([FJSSymbol symbolForName:@"filterWithName:" inObject:NSClassFromString(@"CIColorInvert")] != nil); // This isn't! (at least in Foundation.bridgesupport)
    
    // stringWithCString:length: is defined in NSString.
    XCTAssert([FJSSymbol symbolForName:@"stringWithCString:length:" inObject:[NSString class]] != nil); // This is in bridge support on 10.14
    XCTAssert([FJSSymbol symbolForName:@"stringWithCString:length:" inObject:[NSMutableString class]] != nil); // This is in bridge support on 10.14
    XCTAssert([FJSSymbol symbolForName:@"string" inObject:[NSMutableString class]] != nil); // This isn't! (at least in Foundation.bridgesupport)

    
}

- (void)testInitAndDealoc {
    FJSSimpleTestsInitHappend = 0;
    FJSSimpleTestsDeallocHappend = 0;
    FJSSimpleTestsMethodCalled = 0;

    int count = 10;
    
    __weak __attribute__((objc_precise_lifetime)) FJSTestClass *testClass;
    
    @autoreleasepool {
        
        FJSRuntime *runtime = [[FJSRuntime alloc] init];
        
        for (int i = 0; i < count; i++) {
            [runtime evaluateScript:@"var c = FJSTestClass.new(); c.testMethod();"];
        }
        
        testClass = [[runtime evaluateScript:@"c;"] toObject];
        XCTAssert(testClass);
        
        [runtime evaluateScript:@"c = null;"];
        XCTAssert(![[runtime evaluateScript:@"c;"] toObject]);
        
        [runtime shutdown];
        
        XCTAssert(FJSSimpleTestsMethodCalled == count);
        XCTAssert(FJSSimpleTestsInitHappend == count);
    }
    
    // I've seen this take over 70 seconds in the past. I'm sure there's something we can do to nudge things along, I just don't know what those are.
    // Also, if you get stuck here, make sure you're compiling with -O
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    while (FJSSimpleTestsDeallocHappend != count)  {
        debug(@"%f seconds later… %d of %d dealloced.", [NSDate timeIntervalSinceReferenceDate] - startTime, FJSSimpleTestsDeallocHappend, count);
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
    
    XCTAssert(!testClass);
    XCTAssert(FJSSimpleTestsMethodCalled == count);
    XCTAssert(FJSSimpleTestsInitHappend == count);
    XCTAssert(FJSSimpleTestsDeallocHappend == count);
}

- (void)testCIExample {
    
    // Note- when guard malloc is turned on in 10.14, the Apple JPEG decoders trip it up. Hurray.
    
    #pragma message "FIXME: Throw in a imageByApplyingTransform for the CIImage stuff."
    
    NSString *code = @"\
    var url = NSURL.fileURLWithPath_('/Library/Desktop Pictures/Yosemite.jpg');\n\
    var img = CIImage.imageWithContentsOfURL_(url)\n\
    var f = CIFilter.filterWithName_('CIColorInvert');\n\
    f.setValue_forKey_(img, kCIInputImageKey);\n\
    var r = f.outputImage();\n\
    var tiff = r.TIFFRepresentation();\n\
    tiff.writeToFile_atomically_('/tmp/foo.tiff', true);\n\
    NSWorkspace.sharedWorkspace().openFile_('/tmp/foo.tiff')";
    
    FJSRuntime *runtime = [FJSRuntime new];
    [runtime evaluateScript:code];
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
    
    [runtime shutdown];
    
    printf("All done\n");
    
}

- (void)xtestPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end




void FJSMethodNoArgsNoReturn(void) {
    debug(@"%s:%d", __FUNCTION__, __LINE__);
}


void FJSSingleArgument(id obj) {
    debug(@"%s:%d", __FUNCTION__, __LINE__);
    FJSTestStuffTestPassed = YES;
}

id FJSMethodNoArgsIDReturn(void) {
    debug(@"%s:%d", __FUNCTION__, __LINE__);
    FJSTestStuffTestPassed = YES;
    return @"FJSMethodNoArgsIDReturn Method Return Value";
}


NSString * FJSMethodStringArgStringReturn(NSString *s) {
    FJSTestStuffTestPassed = YES;
    return [NSString stringWithFormat:@"!!%@!!", s];
}

NSString * FJSMethodStringSringArgStringReturn(NSString *a, NSString *b) {
    FJSTestStuffTestPassed = YES;
    return [NSString stringWithFormat:@"++!!%@.%@!!", a, b];
}

void FJSMethodPleasePassNSNumber3(NSNumber *n) {
    FJSTestStuffTestPassed = [n isKindOfClass:[NSNumber class]] && [n integerValue] == 3;
}


void FJSMethodPleasePassSignedShortNumber3(short n) {
    FJSTestStuffTestPassed = n == 3;
}

void FJSMethodPleasePassUnsignedShortNumber3(unsigned short n) {
    FJSTestStuffTestPassed = n == 3;
}

void FJSMethodPleasePassSignedIntNumber3(int n) {
    FJSTestStuffTestPassed = n == 3;
}

void FJSMethodPleasePassUnsignedIntNumber3(uint n) {
    FJSTestStuffTestPassed = n == 3;
}

void FJSMethodPleasePassSignedLongNumber3(long n) {
    FJSTestStuffTestPassed = n == 3;
}

void FJSMethodPleasePassUnsignedLongNumber3(unsigned long n) {
    FJSTestStuffTestPassed = n == 3;
}

void FJSMethodPleasePassSignedLongLongNumber3(long long n) {
    FJSTestStuffTestPassed = n == 3;
}

void FJSMethodPleasePassUnsignedLongLongNumber3(unsigned long long n) {
    FJSTestStuffTestPassed = n == 3;
}

void FJSMethodPleasePassCCharM(char c) {
    FJSTestStuffTestPassed = c == 'm';
}

void FJSMethodPleasePassFloat123(float f) {
    FJSTestStuffTestPassed = fabsf(f - 123.0f) <= 0.000001;
}

void FJSMethodPleasePassDouble123(double d) {
    FJSTestStuffTestPassed = fabs(d - 123.0)  <= 0.000001;
}

void FJSMethodPleasePassDataUsingEncodingAllowLossyConversionSelector(SEL selector) {
    FJSTestStuffTestPassed = @selector(dataUsingEncoding:allowLossyConversion:) == selector;
}

void FJSMethodPleasePassUnsignedCCharM(unsigned char c) {
    FJSTestStuffTestPassed = c == 'm';
}

void FJSMethodPleasePassPositiveBOOL(BOOL b) {
    FJSTestStuffTestPassed = b;
}

void FJSMethodPleasePassNegativeBOOL(BOOL b) {
    FJSTestStuffTestPassed = !b;
}


BOOL FJSMethodNegateBOOL(BOOL b) {
    return !b;
}


void FJSMethodPleasePassNSStringClass(Class c) {
    FJSTestStuffTestPassed = c == [NSString class];
}

void FJSMethodPleasePassDataUsingEncodingAllowLossyConversionSelectorAndCharM(SEL selector, char c) {
    FJSTestStuffTestPassed = @selector(dataUsingEncoding:allowLossyConversion:) == selector && c == 'm';
}

NSDictionary * FJSMethodReturnNSDictionary(void) {
    return @{@"theKey": @(42)};
}

void FJSMethodCheckNSDictionary(NSDictionary *d) {
    NSNumber *n = [d objectForKey:@"theKey"];
    FJSTestStuffTestPassed = [n isKindOfClass:[NSNumber class]] && [n integerValue] == 42;
}

char FJSTestAddSignedChar(char c) {
    return c + 1;
}


unsigned char FJSTestAddUnsignedChar(char c) {
    return c + 1;
}



















