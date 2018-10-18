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

@interface FJSValue (Private)
+ (size_t)countOfLiveInstances;
@end

const NSString *FJSTestConstString = @"HELLO I'M FJSTestConstString";
const int FJSTestConstInt = 74;

NSString *FJSTestExceptionReason = @"this is a test exception";

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
}

+ (void)methodThatTakesAnArgument:(id)whatever {
    // pass.
}

+ (void)throwException {
    @throw [NSException exceptionWithName:NSGenericException reason:FJSTestExceptionReason userInfo:nil];
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
    
    [runtime evaluateScript:@"c = null;"];
    
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

- (void)testRuntimeObjectDealoc {
    
    
    FJSSimpleTestsInitHappend = 0;
    FJSSimpleTestsDeallocHappend = 0;
    FJSSimpleTestsMethodCalled = 0;
    
    
    __weak __attribute__((objc_precise_lifetime)) FJSTestClass *weakTestClass;
    
    @autoreleasepool {
        
        FJSRuntime *runtime = [[FJSRuntime alloc] init];
        
        FJSTestClass *testClass = [FJSTestClass new];
        weakTestClass = testClass;
        [runtime setRuntimeObject:testClass withName:@"testClass"];
        
        [runtime setPrintHandler:^(FJSRuntime * _Nonnull rt, NSString * _Nonnull stringToPrint) {
            XCTAssert(stringToPrint);
        }];
        
        [runtime evaluateScript:@"print(testClass);"];
        [runtime evaluateScript:@"testClass.testMethod();"];
        
        // FIXME: Why doesn't the runtime do this automatically when we shut down? Do we have to delete our objects?
        [runtime evaluateScript:@"testClass = null;"];
        
        [runtime shutdown];
        
    }
    
    XCTAssert(!weakTestClass);
    XCTAssert(FJSSimpleTestsMethodCalled == 1);
    XCTAssert(FJSSimpleTestsInitHappend == 1);
    
    XCTAssert(FJSSimpleTestsDeallocHappend == 1, @"Got %d deallocs", FJSSimpleTestsDeallocHappend);
    XCTAssert(![FJSValue countOfLiveInstances]); // If this fails, make sure you're calling shutdown on all your runtimes.
    
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
        
//#define USE_PRIVATE_API_FOR_SYNC_GC
#ifdef USE_PRIVATE_API_FOR_SYNC_GC
        // If we wanted to use private APIS, we could do this:
        JSContextRef jsRef = CFRetain([runtime contextRef]);
        JSGlobalContextRef global = JSGlobalContextRetain(JSContextGetGlobalContext(jsRef));
        
        [runtime shutdown];
        
        // We could also define `JS_EXPORT void JSSynchronousGarbageCollectForDebugging(JSContextRef);` instead of using runtime lookups. But this feels a little safer in case JSSynchronousGarbageCollectForDebugging goes away some day.
        void *callAddress = dlsym(RTLD_DEFAULT, "JSSynchronousGarbageCollectForDebugging");
        if (callAddress) {
            void (*jc)(JSContextRef) = (void (*)(JSContextRef))callAddress;
            jc(jsRef);
        }
        
        // Also this for the private APIs:
        CFRelease(jsRef);
        JSGlobalContextRelease(global);
#else
        [runtime shutdown];
#endif
        
        XCTAssert(FJSSimpleTestsMethodCalled == count);
        XCTAssert(FJSSimpleTestsInitHappend == count);
    }
    
    
#ifndef USE_PRIVATE_API_FOR_SYNC_GC
    // I've seen this take over 70 seconds in the past. I'm sure there's something we can do to nudge things along, I just don't know what those are.
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    while (FJSSimpleTestsDeallocHappend != count) {
        debug(@"%f seconds later… %d of %d dealloced.", [NSDate timeIntervalSinceReferenceDate] - startTime, FJSSimpleTestsDeallocHappend, count);
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        
        if (FJSSimpleTestsDeallocHappend == (count - 1) && testClass) {
            // The __weak ivar release isn't happening. Try compiling with -O
            XCTAssert(NO, @"The release of __weak testClass didn't happen- try compiling with -O");
            testClass = nil;
        }
        
        /*
         
         https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/runtime/JSRunLoopTimer.cpp
         
         And FWIW, this is the stack trace
         #0    0x0000000104a1f5c4 in FJS_finalize at /Volumes/srv/Users/gus/Projects/fmjs/fmjs/FJSRuntime.m:627
         #1    0x00007fff549685be in JSC::JSCallbackObject<JSC::JSDestructibleObject>::destroy(JSC::JSCell*) ()
         #2    0x00007fff55349761 in void JSC::MarkedBlock::Handle::specializedSweep<true, (JSC::MarkedBlock::Handle::EmptyMode)0, (JSC::MarkedBlock::Handle::SweepMode)0, (JSC::MarkedBlock::Handle::SweepDestructionMode)1, (JSC::MarkedBlock::Handle::ScribbleMode)0, (JSC::MarkedBlock::Handle::NewlyAllocatedMode)1, (JSC::MarkedBlock::Handle::MarksMode)0, JSC::JSDestructibleObjectDestroyFunc>(JSC::FreeList*, JSC::MarkedBlock::Handle::EmptyMode, JSC::MarkedBlock::Handle::SweepMode, JSC::MarkedBlock::Handle::SweepDestructionMode, JSC::MarkedBlock::Handle::ScribbleMode, JSC::MarkedBlock::Handle::NewlyAllocatedMode, JSC::MarkedBlock::Handle::MarksMode, JSC::JSDestructibleObjectDestroyFunc const&) ()
         #3    0x00007fff55348c3d in void JSC::MarkedBlock::Handle::finishSweepKnowingHeapCellType<JSC::JSDestructibleObjectDestroyFunc>(JSC::FreeList*, JSC::JSDestructibleObjectDestroyFunc const&)::'lambda'()::operator()() const ()
         #4    0x00007fff55330e48 in void JSC::MarkedBlock::Handle::finishSweepKnowingHeapCellType<JSC::JSDestructibleObjectDestroyFunc>(JSC::FreeList*, JSC::JSDestructibleObjectDestroyFunc const&) ()
         #5    0x00007fff55330d0a in JSC::JSDestructibleObjectHeapCellType::finishSweep(JSC::MarkedBlock::Handle&, JSC::FreeList*) ()
         #6    0x00007fff5507da69 in JSC::MarkedBlock::Handle::sweep(JSC::FreeList*) ()
         #7    0x00007fff55072c3c in JSC::IncrementalSweeper::sweepNextBlock() ()
         #8    0x00007fff5485cde8 in JSC::IncrementalSweeper::doWork() ()
         #9    0x00007fff5537e704 in JSC::JSRunLoopTimer::timerDidFireCallback(__CFRunLoopTimer*, void*) ()
         #10    0x00007fff5144fe6d in __CFRUNLOOP_IS_CALLING_OUT_TO_A_TIMER_CALLBACK_FUNCTION__ ()
         #11    0x00007fff5144fa20 in __CFRunLoopDoTimer ()
         #12    0x00007fff5144f560 in __CFRunLoopDoTimers ()
         #13    0x00007fff514307b7 in __CFRunLoopRun ()
         #14    0x00007fff5142fce4 in CFRunLoopRunSpecific ()
         #15    0x00007fff537905da in -[NSRunLoop(NSRunLoop) runMode:beforeDate:] ()
         #16    0x00000001049c8f9a in -[FJSSimpleTests testInitAndDealoc] at /Volumes/srv/Users/gus/Projects/fmjs/fmjsTests/FJSSimpleTests.m:189
         */
    }
#endif
    
    // xctest(30812,0x1000c05c0) malloc: circular parent reference in __decrement_table_slot_refcount
    // Why is the above printing out?
    // https://opensource.apple.com/source/libmalloc/libmalloc-116.30.3/src/stack_logging_disk.c.auto.html
    
    debug(@"[FJSValue countOfLiveInstances]: %ld", [FJSValue countOfLiveInstances]);
    
    XCTAssert(![FJSValue countOfLiveInstances]); // If this fails, make sure you're calling shutdown on all your runtimes.
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

- (void)testReentrantCrash {
    
    // If you want to test crashes on reentrantcy (is that a word?) uncomment these:
    //    FJSRuntime *runtime = [FJSRuntime new];
    //    [runtime setRuntimeObject:runtime withName:@"rt"];
    //    [runtime evaluateScript:@"print(rt);"];
    //    [runtime evaluateScript:@"rt.evaluateScript_('please crash');"];
    
}

- (void)testExceptionHandler {
    
    __block NSException *lastException;
    FJSRuntime *runtime = [FJSRuntime new];
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        lastException = exception;
        XCTAssert(rt == runtime);
    }];
    
    [runtime evaluateScript:@"var i = 0;"];
    XCTAssert(!lastException);
    
    [runtime evaluateScript:@"blh blahfd _ ++ fsjdl; !!"];
    XCTAssert(lastException);
    
    lastException = nil;
    [runtime evaluateScript:@"FJSTestClass.throwException();"];
    XCTAssert(lastException);
    XCTAssert([[lastException reason] isEqualToString:FJSTestExceptionReason]);
    
    lastException = nil;
    [runtime evaluateScript:@"FJSThrowException();"];
    XCTAssert(lastException);
    XCTAssert([[lastException reason] isEqualToString:FJSTestExceptionReason]);
    
    
    lastException = nil;
    [runtime evaluateScript:@"FJSTestClass.methodThatTakesAnArgument_();"];
    XCTAssert(lastException);
    
    lastException = nil;
    [runtime evaluateScript:@"FJSTestReturnPassedObject();"];
    XCTAssert(lastException);
    
    
    [runtime shutdown];
}

- (void)testPrintHandler {
    
    
    FJSRuntime *runtime = [FJSRuntime new];
    __block NSString *lastString = nil;
    [runtime setPrintHandler:^(FJSRuntime * _Nonnull rt, NSString * _Nonnull stringToPrint) {
        lastString = stringToPrint;
    }];
    
    [runtime evaluateScript:@"print('Hello, FMJS');"];
    
    XCTAssert([lastString isEqualToString:@"Hello, FMJS"]);
    
    // TODO: How can we make the print happen outside this thread?
    [runtime evaluateScript:@"print('Hello again!');"];
    
    XCTAssert([lastString isEqualToString:@"Hello again!"]);
    
    [runtime shutdown];
}

- (void)testCallFunctionNamed {
    
    FJSRuntime *runtime = [FJSRuntime new];
    __block NSString *lastString = nil;
    [runtime setPrintHandler:^(FJSRuntime * _Nonnull rt, NSString * _Nonnull stringToPrint) {
        lastString = stringToPrint;
    }];
    
    [runtime evaluateScript:@"function printSomething(s) { print(s); };"];
    
    XCTAssert([runtime hasFunctionNamed:@"printSomething"]);
    
    // TODO: How can we make the print happen outside this thread?
    [runtime callFunctionNamed:@"printSomething" withArguments:@[@"Hello function!"]];
    
    XCTAssert([lastString isEqualToString:@"Hello function!"]);
    
    [runtime shutdown];
    
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

- (void)testFunctionLookup {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    NSString *funk = @"function foof() { print('Hello, world')}";
    
    [runtime evaluateScript:funk];
    
    XCTAssert([runtime hasFunctionNamed:@"foof"]);
    
    FJSValue *f = [runtime runtimeObjectWithName:@"foof"];
    
    XCTAssert(f);
    XCTAssert([[f toObject] isEqualToString:funk]);
    
    [runtime shutdown];
}

- (void)testBlock {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    __block int foo = 0;
    __block BOOL calledFunk = NO;
    debug(@"calledFunk: %p", &calledFunk);
    id block = ^{
        debug(@"HELLO THERE");
        //debug(@"calledFunkx: %p", &calledFunk);
        foo++;
        calledFunk = YES;
    };
    
    [runtime setRuntimeObject:block withName:@"funk"];
    
    [runtime evaluateScript:@"funk();"];
    
    
    XCTAssert(calledFunk);
    
    [runtime shutdown];
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

void FJSThrowException() {
    @throw [NSException exceptionWithName:NSGenericException reason:FJSTestExceptionReason userInfo:nil];
}
















