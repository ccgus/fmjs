//
//  fmjsTests.m
//  fmjsTests
//
//  Created by August Mueller on 9/15/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import "FJSSimpleTests.h"
#import "FJSFFI.h"
#import <FMJS/FJS.h>
#import <dlfcn.h>

const NSString *FJSTestConstString = @"HELLO I'M FJSTestConstString";
const int FJSTestConstInt = 74;


int FJSSimpleTestsInitHappend;
int FJSSimpleTestsDeallocHappend;
int FJSSimpleTestsMethodCalled;

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

- (BOOL)passArgument:(int)i {
    _passedInt = i;
    return (i == 42);
}

- (BOOL)passMyself:(FJSTestClass*)inception {
    return (inception == self);
}


- (void)passAndPrintString:(NSString*)foo {
    printf("%s\n", [[foo description] UTF8String]);
}

- (long)passAndReturnLongPlusOne:(long)l {
    return l + 1;
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
    
    [FJSRuntime new]; // Warm things up.
    
    NSString *FMJSBridgeSupportPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"FJSTests" ofType:@"bridgesupport"];
    FMAssert(FMJSBridgeSupportPath);
    
    [[FJSSymbolManager sharedManager] parseBridgeFileAtPath:FMJSBridgeSupportPath];
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testObjcMethods {
    
    FJSRuntime *runtime = [[FJSRuntime alloc] init];
    
    XCTAssert([[runtime evaluateScript:@"var c = FJSTestClass.new(); c.passArgument_(42);"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"c.passMyself_(c);"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"c.passAndReturnLongPlusOne_(42);"] toLongLong] == 43);
    
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
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    while (FJSSimpleTestsDeallocHappend != count) {
        debug(@"%f seconds later… %d of %d dealloced.", [NSDate timeIntervalSinceReferenceDate] - startTime, FJSSimpleTestsDeallocHappend, count);
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        
        if (FJSSimpleTestsDeallocHappend == (count - 1) && testClass) {
            // The __weak ivar release isn't happening. Try compiling with -O
            XCTAssert(NO, @"The release of __weak testClass didn't happen- try compiling with -O");
            testClass = nil;
        }
    }
    
    
    XCTAssert(!testClass);
    XCTAssert(FJSSimpleTestsMethodCalled == count);
    XCTAssert(FJSSimpleTestsInitHappend == count);
    XCTAssert(FJSSimpleTestsDeallocHappend == count);
}

- (void)testCoreImageExample {
    
    // Note- when guard malloc is turned on in 10.14, the Apple JPEG decoders trip it up. Hurray.
    
    NSString *code = @"\
    var url = NSURL.fileURLWithPath_('/Library/Desktop Pictures/Yosemite.jpg');\n\
    var img = CIImage.imageWithContentsOfURL_(url)\n\
    var f = CIFilter.filterWithName_('CIColorInvert');\n\
    f.setValue_forKey_(img, kCIInputImageKey);\n\
    var r = f.outputImage();\n\
    r = r.imageByCroppingToRect_(CGRectMake(0, 0, 500, 500));\n\
    r = r.imageByApplyingTransform_(CGAffineTransformMakeScale(.5, .5));\n\
    var tiff = r.TIFFRepresentation();\n\
    tiff.writeToFile_atomically_('/tmp/foo.tiff', true);\n\
    NSWorkspace.sharedWorkspace().openFile_('/tmp/foo.tiff');";
    
    FJSRuntime *runtime = [FJSRuntime new];
    [runtime evaluateScript:code];
}


- (void)testExample {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassCCharM(FJSTestAddSignedChar('l'));"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassUnsignedCCharM(FJSTestAddUnsignedChar('l'));"] toBOOL]);
    
    [runtime evaluateScript:@"print(FJSMethodStringStringArgStringReturn('Hello', 'World'))"];
    
    XCTAssert([[[runtime evaluateScript:@"FJSMethodStringStringArgStringReturn('Hello', 'World');"] toObject] isEqualToString:@"Hello.World"]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassNegativeBOOL(FJSMethodNegateBOOL(true));"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassPositiveBOOL(FJSMethodNegateBOOL(false));"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassNSStringClass(NSString.class());"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassNegativeBOOL(false);"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassPositiveBOOL(true);"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassFloat123(123);"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassDouble123(123);"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassDataUsingEncodingAllowLossyConversionSelectorAndCharM('dataUsingEncoding:allowLossyConversion:', 'm');"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassDataUsingEncodingAllowLossyConversionSelector('dataUsingEncoding:allowLossyConversion:');"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassSignedLongNumber3(3);"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassUnsignedLongNumber3(3);"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassSignedLongLongNumber3(3);"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassUnsignedLongLongNumber3(3);"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassSignedShortNumber3(3);"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassUnsignedShortNumber3(3);"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassCCharM('m');"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassUnsignedCCharM('m');"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassSignedIntNumber3(3);"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassUnsignedIntNumber3(3);"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"NSNull.null() == null;"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSTestReturnNil() == undefined;"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSTestPassNil(null);"] toBOOL]);
    XCTAssert([[runtime evaluateScript:@"FJSTestPassNil(undefined);"] toBOOL]);
    
    [runtime evaluateScript:@"var c = FJSSimpleTests.new(); FJSAssertObject(c); FJSAssert(c != null);"];
    
    [runtime evaluateScript:@"print('Hello?');"];
    [runtime evaluateScript:@"print(FJSMethodReturnNSDictionary());"];
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodCheckNSDictionary(FJSMethodReturnNSDictionary());"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassNSNumber3(3);"] toBOOL]);
    
    XCTAssert([[[runtime evaluateScript:@"kCIInputImageKey;"] toObject] isEqualToString:@"inputImage"]);
    
    // Enum
    XCTAssert([[runtime evaluateScript:@"NSASCIIStringEncoding;"] toLong] == NSASCIIStringEncoding);
    
    // Const double.
    XCTAssert(FJSEqualFloats([[runtime evaluateScript:@"NSAppKitVersionNumber;"] toDouble], NSAppKitVersionNumber));
    
    XCTAssert([[runtime evaluateScript:@"FJSTestConstString;"] pointer] == (__bridge void *)(FJSTestConstString));
    
    XCTAssert([[runtime evaluateScript:@"FJSTestConstInt;"] toLong] == FJSTestConstInt);
    
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


NSString * FJSMethodStringArgStringReturn(NSString *s) {
    return [NSString stringWithFormat:@"!!%@!!", s];
}

NSString * FJSMethodStringStringArgStringReturn(NSString *a, NSString *b) {
    return [NSString stringWithFormat:@"%@.%@", a, b];
}

BOOL FJSMethodPleasePassNSNumber3(NSNumber *n) {
    return [n isKindOfClass:[NSNumber class]] && [n integerValue] == 3;
}


BOOL FJSMethodPleasePassSignedShortNumber3(short n) {
    return n == 3;
}

BOOL FJSMethodPleasePassUnsignedShortNumber3(unsigned short n) {
    return n == 3;
}

BOOL FJSMethodPleasePassSignedIntNumber3(int n) {
    return n == 3;
}

BOOL FJSMethodPleasePassUnsignedIntNumber3(uint n) {
    return n == 3;
}

BOOL FJSMethodPleasePassSignedLongNumber3(long n) {
    return n == 3;
}

BOOL FJSMethodPleasePassUnsignedLongNumber3(unsigned long n) {
    return n == 3;
}

BOOL FJSMethodPleasePassSignedLongLongNumber3(long long n) {
    return n == 3;
}

BOOL FJSMethodPleasePassUnsignedLongLongNumber3(unsigned long long n) {
    return n == 3;
}

BOOL FJSMethodPleasePassCCharM(char c) {
    return c == 'm';
}

BOOL FJSMethodPleasePassFloat123(float f) {
    return FJSEqualFloats(f, 123.0f);
}

BOOL FJSMethodPleasePassDouble123(double d) {
    return FJSEqualFloats(d, 123.0);
}

BOOL FJSMethodPleasePassDataUsingEncodingAllowLossyConversionSelector(SEL selector) {
    return @selector(dataUsingEncoding:allowLossyConversion:) == selector;
}

BOOL FJSMethodPleasePassUnsignedCCharM(unsigned char c) {
    return c == 'm';
}

BOOL FJSMethodPleasePassPositiveBOOL(BOOL b) {
    return b;
}

BOOL FJSMethodPleasePassNegativeBOOL(BOOL b) {
    return !b;
}


BOOL FJSMethodNegateBOOL(BOOL b) {
    return !b;
}


BOOL FJSMethodPleasePassNSStringClass(Class c) {
    return c == [NSString class];
}

BOOL FJSMethodPleasePassDataUsingEncodingAllowLossyConversionSelectorAndCharM(SEL selector, char c) {
    return @selector(dataUsingEncoding:allowLossyConversion:) == selector && c == 'm';
}

NSDictionary * FJSMethodReturnNSDictionary(void) {
    return @{@"theKey": @(42)};
}

BOOL FJSMethodCheckNSDictionary(NSDictionary *d) {
    NSNumber *n = [d objectForKey:@"theKey"];
    return [n isKindOfClass:[NSNumber class]] && [n integerValue] == 42;
}

char FJSTestAddSignedChar(char c) {
    return c + 1;
}


unsigned char FJSTestAddUnsignedChar(char c) {
    return c + 1;
}

id FJSTestReturnNil() {
    return nil;
}

id FJSTestReturnPassedObject(id o) {
    return o;
}

BOOL FJSTestPassNil(id o) {
    return o == nil;
}



















