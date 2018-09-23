//
//  fmjsTests.m
//  fmjsTests
//
//  Created by August Mueller on 9/15/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import "FJSSimpleTests.h"
#import "TDConglomerate.h"
#import <FMJS/FJS.h>
#import <dlfcn.h>

FOUNDATION_STATIC_INLINE BOOL FJSEqualFloats(CGFloat a, CGFloat b) {
#if __LP64__
    return fabs(a - b)  <= FLT_EPSILON;
#else
    return fabsf(a - b) <= FLT_EPSILON;
#endif
}

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
    NSWorkspace.sharedWorkspace().openFile_('/tmp/foo.tiff');";
    
    FJSRuntime *runtime = [FJSRuntime new];
    [runtime evaluateScript:code];
}

- (void)testStructs { // OH MY.
    
    
    TDTokenizer *tokenizer  = [TDTokenizer tokenizerWithString:@"{CGPoint=dd}"];
    TDToken *tok                    = nil;
    BOOL lastWasAtSym               = NO;
    
    while ((tok = [tokenizer nextToken]) != [TDToken EOFToken]) {
        NSString *sv = [tok stringValue];
        debug(@"[tok isSymbol]: '%d'", [tok isSymbol]);
        debug(@"sv: '%@'", sv);
    
    }
    //{CGPoint=dd}
    //{CGRect={CGPoint=dd}{CGSize=dd}}
    
    
    void *cmem = calloc(sizeof(CGPoint), 1);
    
    
    void *callAddress = dlsym(RTLD_DEFAULT, "CGPointMake");
    assert(callAddress);
    
    CGFloat a = 74, b = 78;
    
    uint effectiveArgumentCount = 2;
    
    // Prepare ffi
    ffi_cif cif;
    ffi_type** ffiArgs = malloc(sizeof(ffi_type *) * effectiveArgumentCount);
    void** ffiValues   = malloc(sizeof(void *) * effectiveArgumentCount);
    
    ffiArgs[0]   = &ffi_type_double;
    ffiValues[0] = &a;
    
    ffiArgs[1]   = &ffi_type_double;
    ffiValues[1] = &b;
    
    // We have to build our own type yay.
    ffi_type structureType;
    ffi_type *structureTypeElements[3];
    
    
    // Build FFI type
    structureType.size      = 0;
    structureType.alignment = 0;
    structureType.type      = FFI_TYPE_STRUCT;
    structureType.elements  = structureTypeElements; //calloc(sizeof(ffi_type *), effectiveArgumentCount + 1);
    
    structureTypeElements[0] = &ffi_type_double;
    structureTypeElements[1] = &ffi_type_double;
    structureTypeElements[2] = nil;
    
    
//    structureType.elements[0] = &ffi_type_double;
//    structureType.elements[1] = &ffi_type_double;
//    assert(!structureType.elements[2]);
//    structureType.elements[2] = nil;
    
    
    /*
     Here is how the struct is defined:
     
     struct tm {
     int tm_sec;
     int tm_min;
     int tm_hour;
     int tm_mday;
     int tm_mon;
     int tm_year;
     int tm_wday;
     int tm_yday;
     int tm_isdst;
     
    long int __tm_gmtoff__;
    __const char *__tm_zone__;
};
Here is the corresponding code to describe this struct to libffi:

{
    ffi_type tm_type;
    ffi_type *tm_type_elements[12];
    int i;
    
    tm_type.size = tm_type.alignment = 0;
    tm_type.type = FFI_TYPE_STRUCT;
    tm_type.elements = &tm_type_elements;
    
    for (i = 0; i < 9; i++)
        tm_type_elements[i] = &ffi_type_sint;
    
    tm_type_elements[9] = &ffi_type_slong;
    tm_type_elements[10] = &ffi_type_pointer;
    tm_type_elements[11] = NULL;
    
    / * tm_type can now be used to represent tm argument types and
     return types for ffi_prep_cif() * /
}*/
    
    
    
    
    
    
    
    
//    NSUInteger i = 0;
//    for (NSString *type in types) {
//        char charEncoding = *(char*)[type UTF8String];
//        _structureType.elements[i++] = [MOFunctionArgument ffiTypeForTypeEncoding:charEncoding];
//    }
//    _structureType.elements[elementCount] = NULL;
    
    ;
    ffi_status prep_status = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, effectiveArgumentCount, &structureType, ffiArgs);
    
    assert(prep_status == FFI_OK);
    
    ffi_call(&cif, callAddress, cmem, ffiValues);
    
    
    CGPoint apoint;
    memcpy(&apoint, cmem, sizeof(CGPoint));
    
    debug(@"apoint: %@", NSStringFromPoint(apoint));
    
    
    
//    FJSValue *val = [runtime evaluateScript:@"CGPointMake(74, 78);"];
//
//    CGPoint point;
//    memcpy(&point, [val pointer], sizeof(CGPoint));
//
//    XCTAssert(FJSEqualFloats(point.x, 74));
//    XCTAssert(FJSEqualFloats(point.y, 78));
    
}

- (void)testExample {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassCCharM(FJSTestAddSignedChar('l'));"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSMethodPleasePassUnsignedCCharM(FJSTestAddUnsignedChar('l'));"] toBOOL]);
    
    [runtime evaluateScript:@"print(FJSMethodStringStringArgStringReturn('Hello', 'World'))"];
    
    XCTAssert([[[runtime evaluateScript:@"FJSMethodStringStringArgStringReturn('Hello', 'World');"] toObject] isEqualToString:@"Hello.World"]);;
    
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



















