//
//  fmjsTests.m
//  fmjsTests
//
//  Created by August Mueller on 9/15/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import "FJSSimpleTests.h"
#import "FJSFFI.h"
#import "FJSSymbol.h"
#import "FJSPrivate.h"
#import <fmjs/FJS.h>
#import <dlfcn.h>

@interface FJSValue (PrivateTestThings)
+ (size_t)countOfLiveInstances;
+ (NSPointerArray*)liveInstancesPointerArray;
@end

@interface FJSRuntime (PrivateTestThings)
- (FJSValue*)evaluateAsModule:(NSString*)script;
@end

@interface FJSNonNativeType : NSObject @end

@implementation FJSNonNativeType /* Doesn't actually have to do anything. */ @end

const NSString *FJSTestConstString = @"HELLO I'M FJSTestConstString";
const int FJSTestConstInt = 74;

NSString *FJSTestExceptionReason = @"this is a test exception";

int FJSSimpleTestsInitHappend;
int FJSSimpleTestsDeallocHappend;
int FJSSimpleTestsMethodCalled;
int FJSTestCGImageRefExampleCounter;

@interface FJSTestClass : NSObject
@property (assign) int passedInt;
@property (strong) NSString *randomString;
@property (retain) NSMutableArray *testArray;
@property (strong) id randomId;
@end

@implementation FJSTestClass

- (instancetype)init {
    self = [super init];
    if (self) {
        FJSSimpleTestsInitHappend++;
    }
    
    return self;
}

+ (instancetype)sharedInstance {
    static FJSTestClass *tc;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tc = [FJSTestClass new];
    });
    return tc;
}

- (void)loadArray {
    
    _testArray = [NSMutableArray array];
    
    [_testArray addObject:@"Item One"];
    [_testArray addObject:@"Item Two"];
    [_testArray addObject:@"Item Three"];
}

- (void)loadArrayWithNonNativeTypes {
    
    _testArray = [NSMutableArray array];
    [_testArray addObject:[FJSNonNativeType new]];
    [_testArray addObject:[FJSNonNativeType new]];
    [_testArray addObject:[FJSNonNativeType new]];
}

- (NSArray*)testArrayPass {
    return _testArray;
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

+ (void)testCGImageIs400x400:(CGImageRef)ref {
    
    if (CGSizeEqualToSize(CGSizeMake(400, 400), CGSizeMake(CGImageGetWidth(ref), CGImageGetHeight(ref)))) {
        FJSTestCGImageRefExampleCounter++;
    }
}

- (void)testFunctionToBlock:(void (^)(FJSTestClass *c, int what, id other))block {
    
    block(self, 0, self);
    
}

- (void)testFunctionToBlock:(void (^)(FJSTestClass *c))block argObjDict:(NSDictionary*)d {

    //[self testFunctionToBlock:block];
}

- (CGRect)getRect {
    return CGRectMake(10, 11, 12, 13);
}

- (void)checkRect:(CGRect)r {
    assert(CGRectEqualToRect(r, CGRectMake(10, 11, 12, 13)));
}

- (void)randomSelector:(id)a withArgument:(id)b {
    FMAssert(NO);
}

- (void)callFunction:(id)whatever {
    FMAssert(NO);
}

- (BOOL)doFJSFunction:(FJSValue*)function inRuntime:(FJSRuntime*)runtime withValues:(NSArray<FJSValue*>*)values returning:(FJSValue**)returnValue {
    
    SEL methodSelector = NSSelectorFromString([[function symbol] name]);
    

    if (methodSelector == @selector(randomSelector:withArgument:)) {

        assert([values count] == 2);

        FJSSimpleTestsMethodCalled++;

        *returnValue = [FJSValue valueWithJSValueRef:JSValueMakeNumber([runtime contextRef], 2011) inRuntime:runtime];
        
        return YES;
    }
    
    if (methodSelector == @selector(callFunction:)) {
        
        assert([values count] == 1);
        assert([[values firstObject] isJSFunction]);
        
        *returnValue = [[values firstObject] callWithArguments:@[[FJSValue valueWithJSValueRef:JSValueMakeNumber([runtime contextRef], 3) inRuntime:runtime]]];
        
        return YES;
    }
    
    return NO;
    
}


- (BOOL)hasFJSValueForKeyedSubscript:(NSString *)key inRuntime:(FJSRuntime*)runtime {
    
    return [key isEqualToString:@"testKeyedSubscript"];
}

- (FJSValue*)FJSValueForKeyedSubscript:(NSString *)key inRuntime:(FJSRuntime*)runtime {
    
    if ([key isEqualToString:@"testKeyedSubscript"]) {
        FJSValue *v = [FJSValue valueWithInstance:(__bridge CFTypeRef _Nonnull)(@(642)) inRuntime:runtime];
        return v;
    }
    
    return nil;
}

- (BOOL)setFJSValue:(FJSValue*)value forKeyedSubscript:(NSString*)key inRuntime:(FJSRuntime*)runtime {
    
    if ([key isEqualToString:@"testKeyedSubscript"]) {
        return YES;
    }
    
    return NO;
}

+ (void)checkImageIsGood:(CGImageRef)r {
    if (r) {
        FJSTestCGImageRefExampleCounter++;
    }
}

+ (void)checkDictionary:(NSDictionary*)d {
    assert(d);
}

+ (NSInteger)testGetTwelve {
    return 12;
}

+ (BOOL)getInt:(int*)i {
    assert(i);
    *i = 74;
    return YES;
}

+ (BOOL)getError:(NSError **)outErr {
    
    FMAssert(!*outErr); // These better be nil coming in.
    
    debug(@"outErr: %p", *outErr);
    debug(@"outErr address: %p", outErr);
    
    *outErr = [NSError errorWithDomain:@"Foo" code:78 userInfo:nil];
    return NO;
}

+ (void)doubleRect:(NSRect*)r {
    
    debug(@"r: %p", r);
    
    r->size.width *= 2;
    r->size.height *= 2;
    r->origin.x *= 2;
    r->origin.y *= 2;
}


@end




@implementation FJSSimpleTests


- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    [FJSRuntime setUseSynchronousGarbageCollectForDebugging:YES];
    
    NSString *FMJSBridgeSupportPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"FJSTests" ofType:@"bridgesupport"];
    FMAssert(FMJSBridgeSupportPath);
    
    [[FJSSymbolManager sharedManager] parseBridgeFileAtPath:FMJSBridgeSupportPath];
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.

    [self checkForValueLeaks];
}

- (void)checkForValueLeaks {
    XCTAssert(![FJSValue countOfLiveInstances], @"Got %ld instances still around", [FJSValue countOfLiveInstances]); // If this fails, make sure you're calling shutdown on all your runtimes.
    
    if ([FJSValue countOfLiveInstances]) {
        
        NSPointerArray *ar = [FJSValue liveInstancesPointerArray];
        
        for (NSUInteger idx = 0; idx < [ar count]; idx++) {
            
            FJSValue *v = [ar pointerAtIndex:idx];
            if (v) {
                debug(@"%@ (Finalized? %d)", v, [v debugFinalizeCalled]);
                debug(@"As object: '%@'", [v toObject]);
                debug(@"Leaked object created at: %@", [v debugStackFromInit]);
            }
        }
        
    }
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
        runtime[@"testClass"] = testClass;
        
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
    XCTAssert(![FJSValue countOfLiveInstances], @"Got %ld instances still around", [FJSValue countOfLiveInstances]); // If this fails, make sure you're calling shutdown on all your runtimes.
    
    
    
    // This is the second part mentioned in another comment.
    FJSSimpleTestsInitHappend = 0;
    FJSSimpleTestsDeallocHappend = 0;
    FJSSimpleTestsMethodCalled = 0;
    
    
    @autoreleasepool {
        
        FJSRuntime *runtime = [[FJSRuntime alloc] init];
        
        FJSTestClass *testClass = [FJSTestClass new];
        runtime[@"testClass"] = testClass;
        
        FJSValue *tc = runtime[@"testClass"];
        tc[@"randomId"] = [FJSTestClass new];
        
        weakTestClass = [tc[@"randomId"] toObject];
        XCTAssert([weakTestClass isKindOfClass:[FJSTestClass class]]);
        
        
        FJSTestClass *anotherTestClass = [FJSTestClass new];
        runtime[@"anotherTestClass"] = anotherTestClass;
        FJSValue *atc = runtime[@"anotherTestClass"];
        atc[@"randomId"] = [FJSTestClass new];
        
        XCTAssert([[atc[@"randomId"] toObject] isKindOfClass:[FJSTestClass class]]);
        
        // FIXME: Why doesn't the runtime do this automatically when we shut down? Do we have to delete our objects?
        [runtime evaluateScript:@"testClass = null;"];
        [runtime evaluateScript:@"anotherTestClass = null;"];
        
        [runtime shutdown];
    }
    
    XCTAssert(!weakTestClass);
    XCTAssert(FJSSimpleTestsInitHappend == 4);
    XCTAssert(FJSSimpleTestsDeallocHappend == 4, @"Got %d deallocs", FJSSimpleTestsDeallocHappend);
    XCTAssert(![FJSValue countOfLiveInstances], @"Got %ld instances still around", [FJSValue countOfLiveInstances]); // If this fails, make sure you're calling shutdown on all your runtimes.
    
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
    
    XCTAssert(![FJSValue countOfLiveInstances], @"Got %ld instances still around", [FJSValue countOfLiveInstances]); // If this fails, make sure you're calling shutdown on all your runtimes.
    XCTAssert(!testClass);
    XCTAssert(FJSSimpleTestsMethodCalled == count);
    XCTAssert(FJSSimpleTestsInitHappend == count);
    XCTAssert(FJSSimpleTestsDeallocHappend == count);
    
    if ([FJSValue countOfLiveInstances]) {
        
        NSPointerArray *ar = [FJSValue liveInstancesPointerArray];
        
        for (NSUInteger idx = 0; idx < [ar count]; idx++) {
            
            FJSValue *v = [ar pointerAtIndex:idx];
            if (v) {
                debug(@"v: '%@'", v);
                debug(@"[v toObject]: '%@'", [v toObject]);
                
            }
        }
        
        abort();
    }
    
    
}

- (void)testCoreImageExample {
    
    // Note- when guard malloc is turned on in 10.14, the Apple JPEG decoders trip it up. Hurray.
    
    
    NSString *code = @"\
    var url = NSURL.fileURLWithPath_('/Library/Desktop Pictures/Beach.jpg');\n\
    var img = CIImage.imageWithContentsOfURL_(url)\n\
    var f = CIFilter.filterWithName_('CIColorInvert');\n\
    f.setValue_forKey_(img, kCIInputImageKey);\n\
    var r = f.outputImage();\n\
    r = r.imageByCroppingToRect_(CGRectMake(0, 0, 500, 500));\n\
    r = r.imageByApplyingTransform_(CGAffineTransformMakeScale(.5, .5));\n\
    checkImage(r);";
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    runtime[@"checkImage"] = ^(CIImage *img) {
        XCTAssert([img extent].size.width == 250, @"Got %f", [img extent].size.width);
        XCTAssert([img extent].size.height == 250, @"Got %f", [img extent].size.height);
    };
    
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        debug(@"exception: '%@'", exception);
    }];
    
    [runtime evaluateScript:code];

    FJSValue *img = runtime[@"img"];
    XCTAssert(img);
    
    // FIXME: This sucks! Why do we have to nil out our variables to get JSC to call finalize on our objects? We don't need to do this in a cocoa app, which has runloops all set up :/"
    [runtime evaluateScript:@"url = null; img = null; f = null; r = null; tiff = null;"];
    
    [runtime shutdown];
    
    XCTAssert([img debugFinalizeCalled]);
    
    
}

- (void)testCoreImageExample2 {
    
    @autoreleasepool {
        
        // This is currently failing because of the use of unprotectContextRef. Which is a bummer. We're going to have to figure that one out.
        
        NSString *code = @"\
        \n\
        var center = CIVector.vectorWithX_Y_(100, 100);\n\
        var filterParams = { inputWidth: 5, inputSharpness: .5, inputCenter: center, }\n\
        var url = NSURL.fileURLWithPath_('/Library/Desktop Pictures/Beach.jpg');\n\
        var image = CIImage.imageWithContentsOfURL_(url)\n\
        image = image.imageByApplyingFilter_withInputParameters_('CICircularScreen', filterParams);\n\
        image = image.imageByCroppingToRect_(CGRectMake(0, 0, 200, 200));\n\
        checkImage(image);\n\
        //var tiff = image.TIFFRepresentation();\n\
        //tiff.writeToFile_atomically_('/tmp/foo2.tiff', true);\n\
        //NSWorkspace.sharedWorkspace().openFile_('/tmp/foo2.tiff');";
        
        
        FJSRuntime *runtime = [FJSRuntime new];
        
        
        runtime[@"checkImage"] = ^(CIImage *img) {
            XCTAssert([img extent].size.width == 200, @"Got %f", [img extent].size.width);
            XCTAssert([img extent].size.height == 200, @"Got %f", [img extent].size.height);
        };
        
        [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
            debug(@"exception: '%@'", exception);
            XCTAssert(NO);
        }];
        
        [runtime evaluateScript:code];
        // This is kind of Bs. What if we do a runloop?
        [runtime evaluateScript:@"center = null; filterParams.filterParams = null; filterParams = null; url = null; image = null; tiff = null;"];
        [runtime shutdown];
        
    }
    
    
}




- (void)testCoreImageExample3 {
    
    
    NSString *code = @"\
    var url = NSURL.fileURLWithPath_('/Library/Desktop Pictures/Beach.jpg');\n\
    var img = CIImage.imageWithContentsOfURL_(url)\n\
    var f = CIFilter.filterWithName('CIComicEffect');\n\
    f['inputImage'] = img; // Test auto kvc lookup. \n\
    var r = f.outputImage();\n\
    checkImage(r);\n\
    checkImage(f['inputImage'])\n\
    ";
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    runtime[@"checkImage"] = ^(CIImage *img) {
        XCTAssert(img != nil);
    };
    
    [runtime evaluateScript:code];
    
    FJSValue *img = runtime[@"img"];
    XCTAssert(img);
    
    // FIXME: This sucks! Why do we have to nil out our variables to get JSC to call finalize on our objects? We don't need to do this in a cocoa app, which has runloops all set up :/"
    [runtime evaluateScript:@"url = null; img = null; f = null; r = null;"];
    
    [runtime shutdown];
    
    XCTAssert([img debugFinalizeCalled]);
    
    
}





- (void)testDumbImportThings {
    // Both these work.
    //NSString *code = @"var _ = function(){ var a = {name: 'Gus'};  return a; }(); _;";
    NSString *code = @"(function(){ var a = {name: 'Gus'};  return a; }())";
    
    FJSRuntime *runtime = [FJSRuntime new];
    FJSValue *v = [runtime evaluateScript:code];
    
    runtime[@"what"] = v;
    
    runtime[@"funk"] = ^(NSString*s) {
        
        XCTAssert([s isEqualToString:@"Gus"]);
        
    };
    
    [runtime evaluateScript:@"funk(what.name);"];
    
}

- (void)testSimpleModuleRequire {
    
    NSString *modulePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"FJSTestModule" ofType:@"js"];
    FMAssert(modulePath);

    modulePath = [modulePath stringByDeletingPathExtension];
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        debug(@"exception: '%@'", exception);
    }];
    
    __block BOOL functionCalled = NO;
    runtime[@"testFunction"] = ^{
        functionCalled = YES;
    };
    
    FJSValue *functionBlock = runtime[@"testFunction"];
    
    XCTAssert(functionBlock);
    
    [runtime evaluateScript:[NSString stringWithFormat:@"var r = require('%@');", modulePath]];
    
    [runtime evaluateScript:@"r.callTestFunc();"];
    
    FJSValue *v = [runtime evaluateScript:@"r.callInc()"];
    XCTAssert([v toInt] == 1);
    
    v = [runtime evaluateScript:@"r.callInc()"];
    XCTAssert([v toInt] == 2);
    
    [runtime evaluateScript:[NSString stringWithFormat:@"r = require('%@');", modulePath]];
    
    v = [runtime evaluateScript:@"r.callInc()"];
    XCTAssert([v toInt] == 3, @"Got %d", [v toInt]);
    
    
    FJSValue *rModule = runtime[@"r"];
    XCTAssert(rModule);
    
    FJSValue *callIncFunction = rModule[@"callInc"];
    XCTAssert(callIncFunction);
    
    v = [rModule invokeMethodNamed:@"callInc" withArguments:nil];
    XCTAssert([v toInt] == 4, @"Got %d", [v toInt]);
    
    
    FJSValue *subModule = rModule[@"subMod"];
    XCTAssert(![subModule isUndefined]);
    v = [subModule invokeMethodNamed:@"returnTwelve" withArguments:nil];
    XCTAssert([v toInt] == 12, @"Got %d", [v toInt]);
    
    [runtime shutdown];
    
    XCTAssert(functionCalled);
    
}



- (void)xtestCoreImageExampleInAutoreleasePool {
    
    // Note- when guard malloc is turned on in 10.14, the Apple JPEG decoders trip it up. Hurray.
    
    NSString *code = @"\
    function doCI(idx) {\n\
        print('…………');\n\
        var url = NSURL.fileURLWithPath_('/System/Library/Desktop Pictures/Yosemite.jpg');\n\
        var img = CIImage.imageWithContentsOfURL_(url)\n\
        var f = CIFilter.filterWithName_('CIColorInvert');\n\
        f.setValue_forKey_(img, kCIInputImageKey);\n\
        var r = f.outputImage();\n\
        r = r.imageByCroppingToRect_(CGRectMake(0, 0, 500, 500));\n\
        r = r.imageByApplyingTransform_(CGAffineTransformMakeScale(.5, .5));\n\
        var tiff = r.TIFFRepresentation();\n\
        var file = '/tmp/foo' + idx + '.tiff';\n\
        print(file);\n\
        tiff.writeToFile_atomically_(file, true)\n\
        NSWorkspace.sharedWorkspace().openFile_(file);\n\
    }";
    
    FJSRuntime *runtime = [FJSRuntime new];
    [runtime evaluateScript:code];
    
    for  (int i = 0; i < 10; i++) @autoreleasepool {
        [runtime callFunctionNamed:@"doCI" withArguments:@[@(i)]];
    }
    
}

- (void)testPropertyAccesInBitmapImageRep {
    
    NSBitmapImageRep *r = [[NSBitmapImageRep alloc] initWithData:[NSData dataWithContentsOfFile:@"/Library/Desktop Pictures/Beach.jpg"]];
    
    XCTAssert(r, @"Can't find /System/Library/Desktop Pictures/Yosemite.jpg");
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    runtime[@"br"] = r;
    
    size_t w = [[runtime evaluateScript:@"br.pixelsWide()"] toLong];
    
    XCTAssert(w == 5120);
    
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

- (void)testFunctionToBlock {
    
    // FIXME: how are we going to do JS functions to blocks?
    
    // FJSTraceFunctionCalls = YES;
    
    FJSTestClass *testClass = [FJSTestClass new];
    FJSSymbol *symbol = [FJSSymbol symbolForName:@"testFunctionToBlock" inObject:testClass];
    XCTAssert(symbol);
    
    XCTAssert([[[[symbol arguments] firstObject] runtimeType] isEqualToString:@"@?"]);
    
    
    FJSSymbol *otherSym = [FJSSymbol symbolForName:@"testFunctionToBlock_argObjDict" inObject:testClass];
    XCTAssert(otherSym);
    
//    FJSRuntime *runtime = [FJSRuntime new];
//
//
//    runtime[@"testClass"] = testClass;
//    [runtime evaluateScript:@"testClass.testFunctionToBlock(function(tc) { tc.passedInt = 17; })"];
//
//     XCTAssert(testClass.passedInt == 17);
//
//    [runtime shutdown];
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
    
    [runtime setPrintHandler:^(FJSRuntime * _Nonnull rt, NSString * _Nonnull stringToPrint) {
        // pass.
    }];
    
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
    
    XCTAssert([[runtime evaluateScript:@"NSNull.null() != null;"] toBOOL]); // NSNull is still an object.
    
    XCTAssert([[runtime evaluateScript:@"FJSTestReturnNil() == undefined;"] toBOOL]);
    
    XCTAssert([[runtime evaluateScript:@"FJSTestPassNil(null);"] toBOOL]);
    XCTAssert([[runtime evaluateScript:@"FJSTestPassNil(undefined);"] toBOOL]);
    
    [runtime evaluateScript:@"var c = FJSSimpleTests.new(); FJSAssertObject(c); FJSAssert(c != null); c = null;"];
    
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
    
}

- (void)testFunctionLookup {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    NSString *funk = @"function foof() { print('Hello, world')}";
    
    [runtime evaluateScript:funk];
    
    XCTAssert([runtime hasFunctionNamed:@"foof"]);
    
    FJSValue *f = runtime[@"foof"];
    
    XCTAssert(f);
    XCTAssert([[f toObject] isEqualToString:funk]);
    
    [runtime shutdown];
}

- (void)testMakeFunction {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    [runtime setPrintHandler:^(FJSRuntime * _Nonnull rt, NSString * _Nonnull stringToPrint) {
        // pass
    }];
    
    JSStringRef functionName = JSStringCreateWithCFString((__bridge CFStringRef)@"__runtimeFunction");
    JSStringRef functionBody = JSStringCreateWithCFString((__bridge CFStringRef)@"{print('Hello from func'); FJSMethodPleasePassSignedShortNumber3(3); return 12;}");
    JSValueRef exception = nil;
    JSObjectRef jsFunction = JSObjectMakeFunction([runtime contextRef], nil, 0, nil, functionBody, nil, 0, &exception);
    [runtime reportPossibleJSException:exception];
    
    JSStringRelease(functionName);
    JSStringRelease(functionBody);
    
    FMAssert(jsFunction);
    
    JSValueRef jsFunctionReturnValue = JSObjectCallAsFunction([runtime contextRef], jsFunction, NULL, 0, nil, &exception);
    XCTAssert(JSValueIsNumber([runtime contextRef], jsFunctionReturnValue));
    
    XCTAssert(FJSEqualFloats(JSValueToNumber([runtime contextRef], jsFunctionReturnValue, NULL), 12));
    
    [runtime reportPossibleJSException:exception];
    
    // FIXME: report the exception.
    
    
    
}

- (void)testPrintBlockHangingAround {
    /*
     This test was because of an autorelease problem with setRuntimeObject:withName:
     It was fixed, but hey let's keep this around anyway.
     */
    
    @autoreleasepool {
        
        FJSRuntime *runtime = [FJSRuntime new];
        
        [runtime shutdown];
    }
    
    XCTAssert(![FJSValue countOfLiveInstances], @"Still have %ld live instances.", [FJSValue countOfLiveInstances]);
    
    if ([FJSValue countOfLiveInstances]) {
        
        NSPointerArray *ar = [FJSValue liveInstancesPointerArray];
        
        for (NSUInteger idx = 0; idx < [ar count]; idx++) {
            
            FJSValue *v = [ar pointerAtIndex:idx];
            if (v) {
                debug(@"v: '%@'", v);
            }
        }
        
        
    }
}

- (void)testBlock {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    [runtime setPrintHandler:^(FJSRuntime * _Nonnull rt, NSString * _Nonnull stringToPrint) {
        // pass.
    }];
    
    __block int foo = 0;
    __block BOOL calledFunk = NO;
    
    runtime[@"funk"] = ^{
        foo++;
        calledFunk = YES;
    };
    [runtime evaluateScript:@"funk();"];
    
    
    XCTAssert(calledFunk);
    XCTAssert(foo == 1);
    
    runtime[@"funkItUp"] = ^(NSString *what) {
        foo++;
        calledFunk = [what isEqualToString:@"funky"];
    };
    
    [runtime evaluateScript:@"funkItUp('funky');"];
    
    
    XCTAssert(calledFunk);
    XCTAssert(foo == 2);
    
    
    runtime[@"whatWhat"] = ^(NSUInteger un, NSInteger sn, double dub) {
        foo++;
        XCTAssert(un == 3);
        XCTAssert(sn == -1);
        XCTAssert(FJSEqualFloats(dub, 123.45));
    };
    
    [runtime evaluateScript:@"whatWhat(3, -1, 123.45);"];
    
    XCTAssert(foo == 3);
    
    [runtime evaluateScript:@"var y = {name:'me'}; function foof() { print('Hello, world')}; y.f = foof; print(y)"];
    
    [runtime shutdown];
}

- (void)testRandomCrasher1 {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    [runtime setPrintHandler:^(FJSRuntime * _Nonnull rt, NSString * _Nonnull stringToPrint) {
        // pass
    }];
    
    [runtime evaluateScript:@"var x = {name:'a'}; print(x); var y = {name:'me'}; function foof() { print('Hello, world')}; y.f = foof; print(y);"];
    
    [runtime shutdown];
}

- (void)testDictionaryAccess {
    
    NSDictionary *d = @{@"a": @(123.0), @"b": @"FMJSYo"};
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    runtime[@"d"] = d;
    
    FJSValue *v = [runtime evaluateScript:@"d.a + 1"];
    
    XCTAssert([v toLong] == 124, "Got %ld", [v toLong]);
    
    v = [runtime evaluateScript:@"d.objectForKey_('b');"];
    XCTAssert([[v toObject] isEqualToString:@"FMJSYo"], "Got %@", [v toObject]);
    
    [runtime shutdown];
}

- (void)testPropertyAccess {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    FJSValue *d = [runtime evaluateScript:@"d = {a: 123, bart: 'bart'}"];
    
    FJSValue *a = d[@"a"];
    XCTAssert([a toLong] == 123, "Got %ld", [a toLong]);
    
    XCTAssert([d[@"noProp"] isUndefined]);
    
    
    NSUUID *uuid = [NSUUID UUID];
    d[@"uuid"] = uuid;
    
    FJSValue *jsuuid = d[@"uuid"];
    NSUUID *ruuid = [jsuuid toObject];
    
    XCTAssert(ruuid == uuid, @"Got %@", ruuid);
    
    //[jsuuid unprotect];
    
    d[@"uuid"] = nil;
    
    XCTAssert([d[@"uuid"] isUndefined]);
    
    [runtime shutdown];
    
    
    
    // Just checking to see what JSContext does, so we can match it.
    JSContext *ctx = [JSContext new];
    JSValue *jsv = [ctx evaluateScript:@"d = {a: 1234, bart: 'bart'}"];
    JSValue *jsa = jsv[@"a"];
    XCTAssert([jsa toInt32] == 1234, "Got %d", [jsa toInt32]);
    XCTAssert([jsv[@"noProp"] isUndefined]);
    
    FJSTestClass *c = [FJSTestClass new];
    ctx[@"d"][@"testClass"] = c;
    
    JSValue *jsc = [ctx evaluateScript:@"c = d.testClass; c;"];
    
    XCTAssert([jsc toObject] == c);
    
    debug(@"%@", [ctx evaluateScript:@"c.foo"]);
}


- (void)testArrayAccess {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    runtime[@"a"] = @[@(7), @(65), @(72), @(84), @"Hello"];
    
    FJSValue *v = [runtime evaluateScript:@"a[0];"];
    XCTAssert([v toLong] == 7, "Got %ld", [v toLong]);
    
    v = [runtime evaluateScript:@"a[1];"];
    XCTAssert([v toLong] == 65, "Got %ld", [v toLong]);
    
    v = [runtime evaluateScript:@"a[2];"];
    XCTAssert([v toLong] == 72, "Got %ld", [v toLong]);
    
    v = [runtime evaluateScript:@"a[3] + 1;"];
    XCTAssert([v toLong] == 85, "Got %ld", [v toLong]);
    
    v = [runtime evaluateScript:@"a[4];"];
    XCTAssert([[v toObject] isEqualToString:@"Hello"], "Got %@", [v toObject]);
    
    v = [runtime evaluateScript:@"a.objectAtIndex_(1);"];
    XCTAssert([v toLong] == 65, "Got %ld", [v toLong]);
    
    [runtime shutdown];
}

- (void)testStringToNumber {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    FJSValue *v = [runtime evaluateScript:@"'Hello'"];
    
    XCTAssert([[v toObject] isEqualToString:@"Hello"], @"Got %@", [v toObject]);
    
    // FIXME: What should we do in this case? Right now we get a nan.
    // XCTAssert([v toLong] == 0, "Got %ld", [v toLong]);
    
    [runtime shutdown];
}

- (void)testSetProperty {
    
    @autoreleasepool {
        
        FJSRuntime *runtime = [[FJSRuntime alloc] init];
        
        XCTAssert([runtime evaluateScript:@"var c = FJSTestClass.new(); c.randomString = 'FM';"]);
        
        FJSValue *f = runtime[@"c"];
        XCTAssert(f);
        
        FJSTestClass *c = [f toObject];
        XCTAssert([c isKindOfClass:[FJSTestClass class]]);
        
        XCTAssert([[c randomString] isEqualToString:@"FM"]);
        
        [runtime evaluateScript:@"c = null"]; // So checkForValueLeaks passes.
        
        [runtime shutdown];
    }
    
    [self checkForValueLeaks];
    
}

- (void)testArraySubscript {
    
    
    FJSRuntime *runtime = [[FJSRuntime alloc] init];
    
    NSMutableArray *ar = [NSMutableArray array];
    
    runtime[@"ar"] = ar;
    
    XCTAssert([runtime evaluateScript:@"ar[0] = 'Hi!';"]);
    
    XCTAssert([ar count] == 1);
    XCTAssert([[ar objectAtIndex:0] isEqualToString:@"Hi!"]);
    
    XCTAssert([runtime evaluateScript:@"ar[0] = 'Hello?';"]);
    XCTAssert([[ar objectAtIndex:0] isEqualToString:@"Hello?"]);
    
    FJSTestClass *c = [FJSTestClass new];
    [c loadArray];
    
    
    runtime[@"testClass"] = c;
    FJSValue *first = [runtime evaluateScript:@"testClass.testArray()[0];"];
    XCTAssert([[first toObject] isEqualToString:@"Item One"], @"Expected 'Item One' got %@ instead", [first toObject]);
    
    [c loadArrayWithNonNativeTypes];
    first = [runtime evaluateScript:@"testClass.testArray()[0];"];
    XCTAssert([[first toObject] isKindOfClass:[FJSNonNativeType class]]);
    
    
    [runtime shutdown];
    
    
}

- (void)testMissingUnderscoreMethod {
    
    FJSRuntime *runtime = [[FJSRuntime alloc] init];
    
    XCTAssert([runtime evaluateScript:@"var c = NSString.stringWithString('FJS Missing Underscore');"]);
    
    FJSValue *f = runtime[@"c"];
    XCTAssert(f);
    
    NSString *c = [f toObject];
    XCTAssert([c isEqualToString:@"FJS Missing Underscore"]);
    
    #pragma message "FIXME: Why do we need to do this now?"
    [runtime evaluateScript:@"c = null;"];
    
    FJSValue *u = [runtime evaluateScript:@"NSURL.URLWithString('https://flyingmeat.com').URLByAppendingPathComponent('acorn');"];
    XCTAssert(u);
    
    NSURL *url = [u toObject];
    XCTAssert([url isKindOfClass:[NSURL class]]);
    
    XCTAssert([[url absoluteString] isEqualToString:@"https://flyingmeat.com/acorn"]);
    
    [runtime shutdown];
}

- (void)testRectCheckTestThing {
    
    NSString *code = @"var c = FJSTestClass.new()\n"
    "var r = c.getRect()\n"
    "c.checkRect(r);\n"
    "r = null; c = null;\n";
    
    FJSRuntime *runtime = [FJSRuntime new];
    [runtime evaluateScript:code];
    
    
    [runtime shutdown];
}

- (void)testStringConversion {
    
    NSString *s = [NSString stringWithFormat:@"%@yum", self];
    
    __block NSString *printedString;
    FJSRuntime *runtime = [FJSRuntime new];
    [runtime setPrintHandler:^(FJSRuntime * _Nonnull rt, NSString * _Nonnull stringToPrint) {
        printedString = stringToPrint;
        debug(@"printedString: '%@'", printedString);
    }];
    
    runtime[@"foo"] = self;
    
    [runtime evaluateScript:@"print(foo + 'yum');"];
    
    XCTAssert(printedString);
    XCTAssert([printedString isEqualToString:s], @"Got: %@", printedString);
    
    #pragma message "FIXME: What do we do with rects where instances are expected?"
//    [runtime evaluateScript:@"printjsv(CGRectMake(1, 2, 3, 4));"];
//    XCTAssert(printedString);
//    XCTAssert([printedString isEqualToString:@"1"], @"Got: %@", printedString);
    
    [runtime shutdown];
}

- (void)testProtect {
    
    
    size_t startInits = FJSSimpleTestsInitHappend;
    size_t startDeallocs = FJSSimpleTestsDeallocHappend;
    
    
    @autoreleasepool {
        
        FJSRuntime *runtime = [FJSRuntime new];
        
        [runtime evaluateScript:@"var c = FJSTestClass.new();"];
        
        __attribute__((objc_precise_lifetime))
        FJSValue *v = runtime[@"c"];
        
        XCTAssert(v);
        
        XCTAssert(FJSSimpleTestsInitHappend == (startInits + 1));
        
        [v protect];
        [v protect];
        [v unprotect];
        [v protect];
        
        [runtime evaluateScript:@"c = null;"];
        
        
        XCTAssert(FJSSimpleTestsDeallocHappend == startDeallocs);
        
        XCTAssert([[v valueForKey:@"protectCount"] integerValue] == 2);
        
        [v unprotect];
        
        XCTAssert([[v valueForKey:@"protectCount"] integerValue] == 1);
        
        [v unprotect];
        
        [runtime shutdown];
        
        v = nil;
        
    }
    
    XCTAssert(FJSSimpleTestsDeallocHappend == startDeallocs + 1);
}

- (void)testImageIOLookup { // Currently failing.
    
    [FJSRuntime loadFrameworkAtPath:@"/System/Library/Frameworks/ImageIO.framework"];
    
    __block NSString *printedString;
    FJSRuntime *runtime = [FJSRuntime new];
    [runtime setPrintHandler:^(FJSRuntime * _Nonnull rt, NSString * _Nonnull stringToPrint) {
        printedString = stringToPrint;
    }];
    
    
    void *addr = dlsym(RTLD_DEFAULT, "kCGImagePropertyExifDateTimeOriginal");
    XCTAssert(addr == &kCGImagePropertyExifDateTimeOriginal);
    
    id foo = (__bridge id)(*(void**) addr);
    
    XCTAssert([foo isEqualToString:(id)kCGImagePropertyExifDateTimeOriginal]);
    
    [runtime evaluateScript:@"print(kCGImagePropertyExifDateTimeOriginal + '');"]; // DateTimeOriginal
    
    XCTAssert([printedString isEqualToString:(id)kCGImagePropertyExifDateTimeOriginal], @"Got: '%@'", printedString);
    
    [runtime evaluateScript:@"print(kCGImagePropertyExifDateTimeOriginal);"]; // DateTimeOriginal
    XCTAssert([printedString isEqualToString:(id)kCGImagePropertyExifDateTimeOriginal], @"Got: '%@'", printedString);
    
    
    [runtime shutdown];
    
}

- (void)testStringPassing { // Currently failing, look for 5C54337E-CBF3-4323-9EDB-268DF924CF15 for a fix.
    
    __block NSString *printedString;
    FJSRuntime *runtime = [FJSRuntime new];
    [runtime setPrintHandler:^(FJSRuntime * _Nonnull rt, NSString * _Nonnull stringToPrint) {
        printedString = stringToPrint;
    }];
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        NSLog(@"exception: %@", exception);
        XCTAssert(NO);
    }];
    
    [runtime evaluateScript:@"var s = NSString.stringWithString('/foo/bar.png').lastPathComponent().stringByDeletingPathExtension(); print(s);"];
    
    XCTAssert([printedString isEqualToString:@"bar"]);
    
    [runtime evaluateScript:@"print('foo' + s); s = null;"];
    
    XCTAssert([printedString isEqualToString:@"foobar"], @"Got '%@'", printedString);
    
    
    [runtime shutdown];
    
}

- (void)testNSNullNull {
    
    
    FJSRuntime *runtime = [FJSRuntime new];
    XCTAssert([[runtime evaluateScript:@"NSNull.null() != null;"] toBOOL]); // This guy is still an object that can be passed around.
    [runtime shutdown];
    
}

- (void)testFalseIsFalseAndTrueIsTrue {
    
    
    FJSRuntime *runtime = [FJSRuntime new];
    XCTAssert(![[runtime evaluateScript:@"false;"] toBOOL]);
    XCTAssert([[runtime evaluateScript:@"true;"] toBOOL]);
    XCTAssert(![[runtime evaluateScript:@"var x = true; x = false; x;"] toBOOL]);
    [runtime shutdown];
    
}

- (void)testBoolFunctionReturnValue {
    
    FJSRuntime *runtime = [FJSRuntime new];
    [runtime evaluateScript:@"ft = function() { var f = false; return f }"];
    
    FJSValue *v = [runtime callFunctionNamed:@"ft" withArguments:@[]];
    
    XCTAssert(![v toBOOL]);
    
    [runtime shutdown];
    
}

- (void)testModuleFunctionExists {
    
    NSString *moduleScript = @"module.exports = { aFunc: function(a) { return a + 1; }, };";
    FJSRuntime *runtime = [FJSRuntime new];
    FJSValue *module = [runtime evaluateAsModule:moduleScript];
    
    XCTAssert(module);
    
    XCTAssert(module[@"aFunc"]);
    
    FJSValue *v = [module invokeMethodNamed:@"aFunc" withArguments:@[@"1"]];
    XCTAssert([v toInt] == 2);
    
    XCTAssert([module[@"aFuncNotThere"] isUndefined]);
    
    [runtime evaluateScript:@"d = {}"];
    XCTAssert([runtime[@"d"][@"foo"] isUndefined]);
    
    
    // What does JSC do? It should also return undefined.
    JSContext *ctx = [[JSContext alloc] init];
    [ctx evaluateScript:@"d = {}"];
    JSValue *jsv = ctx[@"d"];
    XCTAssert(jsv);
    XCTAssert([jsv[@"blah"] isUndefined]);
    
}

- (void)testDictionaryTying {
    FJSRuntime *runtime = [FJSRuntime new];
    
    [runtime evaluateScript:@"FJSTestClass.checkDictionary({a:1, b:2, c:3})"];
    [runtime evaluateScript:@"FJSTestClass.checkDictionary({c:1, b:2, a:3})"];
    
    [runtime shutdown];
    
}

- (void)testStringThing {
    
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    FJSValue *v = [runtime evaluateScript:@"NSString.stringWithString('abc')"];
    
    XCTAssert([[v toObject] hasPrefix:@"a"]);
    
    v = [runtime evaluateScript:@"NSString.stringWithString('abc').startsWith('a')"];
    
    
    XCTAssert([[v toObject] isKindOfClass:[NSNumber class]]);
    
    [runtime shutdown];
}

- (void)testArrayLength {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    FJSValue *v = [runtime evaluateScript:@"NSArray.arrayWithObject(1)"];
    
    XCTAssert([[v toObject] isKindOfClass:[NSArray class]]);
    
    v = [runtime evaluateScript:@"NSArray.arrayWithObject(1).length"];
    XCTAssert(v);
    XCTAssert([v toInt] == 1);
    
    runtime[@"someArray"] = @[@(1), @(2)];
    
    v = [runtime evaluateScript:@"someArray.length"];
    
    XCTAssert([v toInt] == 2);
    
    [runtime shutdown];
}


- (void)testArrayForEach {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    __block int blockCountCalled = 0;
    void (^blockA)(void) = ^void() { blockCountCalled += 1; };
    void (^blockB)(void) = ^void() { blockCountCalled += 2; };
    void (^blockC)(void) = ^void() { blockCountCalled += 3; };
    
    NSArray *a = @[blockA, blockB, blockC];
    
    runtime[@"testArray"] = a;
    
    [runtime evaluateScript:@"testArray.forEach(function(b) { b(); });"];
    
    XCTAssert(blockCountCalled == 6, @"blockCountCalled was wrong, got %d", blockCountCalled);
    
    [runtime shutdown];
}



- (void)testCommandSelector {
    
    FJSSimpleTestsMethodCalled = 0;
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    FJSValue *v = [runtime evaluateScript:@"var f = FJSTestClass.new(); f.randomSelector_withArgument(1, 2);"];
    
    XCTAssert([v toInt] == 2011);
    
    [runtime evaluateScript:@"f = null;"];
    
    [runtime shutdown];
    
    XCTAssert(FJSSimpleTestsMethodCalled == 1);
    
}

- (void)testCommandSelector2 {

    FJSSimpleTestsMethodCalled = 0;
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    FJSValue *v = [runtime evaluateScript:@"var f = FJSTestClass.new(); f.callFunction(function(foo) { if (foo == 3) { f.randomSelector_withArgument(1, 2); }; return 1978;});"];
    
    XCTAssert([v toInt] == 1978, @"Got: %d", [v toInt]);
    
    [runtime evaluateScript:@"f = null;"];
    
    [runtime shutdown];
    
    XCTAssert(FJSSimpleTestsMethodCalled == 1);

}

- (void)testDictionaryNumber {
    
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    [runtime evaluateScript:@"function f (d) { return d['key'] }"];
    
    FJSValue *k = [runtime callFunctionNamed:@"f" withArguments:@[@{@"key": @(YES)}]];
    
    XCTAssert([k toObject]);
    XCTAssert([[k toObject] isKindOfClass:[NSNumber class]]);
    XCTAssert([[k toObject] boolValue]);
    
    [runtime shutdown];
    
    
    
}

- (void)testUndefinedVoidReturn {
    
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    FJSValue *u = [runtime evaluateScript:@"var s = NSMutableSet.set(); s.removeAllObjects();"];
    
    XCTAssert([u isUndefined]);
    
    XCTAssert([[runtime evaluateScript:@"FJSReturnVoid()"] isUndefined]);
    
    [runtime evaluateScript:@"s=null"];
    
    [runtime shutdown];
    
}

- (void)testBlockPass {
    
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    
    [runtime evaluateScript:@"function funk (d) { d() }"];
    
    __block BOOL blockCalled = NO;
    
    [runtime callFunctionNamed:@"funk" withArguments:@[^{
        blockCalled = YES;
    }]];
    
    XCTAssert(blockCalled);
    
    [runtime shutdown];
    
    
}

- (void)testQueueThing {
    
    
    __block BOOL blockCalled = NO;
    FJSRuntime *runtime = [FJSRuntime new];
    
    [runtime dispatchOnQueue:^{
        
        [runtime dispatchOnQueue:^{
            
            [runtime dispatchOnQueue:^{
                
                blockCalled = YES;
                
            }];
            
            
        }];
        
    }];
    
    XCTAssert(blockCalled);
    
    [runtime shutdown];
}

- (void)testDefaultHTTPApp {
    
    [FJSRuntime loadFrameworkAtPath:@"/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework"];
    
    NSURL *u = CFBridgingRelease(LSCopyDefaultApplicationURLForURL((__bridge CFURLRef)[NSURL URLWithString:@"http://apple.com/"], kLSRolesViewer, nil));
    XCTAssert(u);
    
    // Note: this is currently failing, and I'm not sure it's something I want to support yet.
    FJSRuntime *runtime = [FJSRuntime new];
    
    FJSValue *vu = [runtime evaluateScript:@"LSCopyDefaultApplicationURLForURL(NSURL.URLWithString('http://apple.com/'), kLSRolesViewer, null)"];
    
    XCTAssert([[vu toObject] isEqualTo:u]);
    
    [runtime shutdown];
    
    
}

- (void)testHandle {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    FJSValue *vu = [runtime evaluateScript:
                    @"var ptr = FJSPointer.valuePointer();\n"
                    @"FJSTestClass.getInt(ptr);\n"
                    @"ptr\n"];
    
    XCTAssert([vu toInt] == 74, @"Got %d", [vu toInt]);
    
    [runtime evaluateScript:@"FJSXAssert(ptr.toInt() == 74)"];
    
    [runtime evaluateScript:@"ptr=null;"];
    
    vu = nil;
    
    [runtime shutdown];
}

- (void)testHandle2 {
    
    NSScanner *s = [[NSScanner alloc] initWithString:@"123 3.14159"];
    int i;
    [s scanInt:&i];
    assert(i == 123);
    double d;
    [s scanDouble:&d];
    XCTAssert(FJSEqualFloats(d, 3.14159), @"Got %f", d);
    
    FJSRuntime *runtime = [FJSRuntime new];

    FJSValue *vu = [runtime evaluateScript:@"var scanner = NSScanner.alloc().initWithString_('123 3.14159');\n"
                                           @"var ptr = FJSPointer.valuePointer();\n"
                                           @"scanner.scanInteger(ptr);\n"
                    @"ptr;\n"];
    
    XCTAssert([vu toInt] == 123, @"Got %ld", [vu toLong]);
    [runtime evaluateScript:@"FJSXAssert(ptr.toInt() == 123)"];
    
    vu = [runtime evaluateScript:@"scanner.scanDouble(ptr); ptr;"];
    
    XCTAssert(FJSEqualFloats([vu toFloat], 3.14159), @"Got %f", [vu toFloat]);
    
    [runtime evaluateScript:@"FJSXAssert(ptr.toFloat() == 3.14159)"];
    
    [runtime evaluateScript:@"ptr=null; scanner=null;"];
    [runtime shutdown];
}

- (void)testErrHandle {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    FJSValue *vu = [runtime evaluateScript:
                    @"var ptr = FJSPointer.objectPointer();\n"
                    @"FJSTestClass.getError(ptr);\n"
                    @"ptr\n"];
    
    NSError *err = [vu toObject];
    
    debug(@"err: %p", err);
    debug(@"err address: %p", &err);
    
    XCTAssert(err);
    XCTAssert([[err domain] isEqualToString:@"Foo"]);
    XCTAssert([err code] == 78);
    
    [runtime evaluateScript:@"ptr=null;"];
    
    [runtime shutdown];
    
}


- (void)testRectHandle {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    FJSValue *vu = [runtime evaluateScript:
                    @"var r = NSMakeRect(1,2,3,4);"
                    @"FJSTestClass.doubleRect(FJSPointer.pointerWithValue(r));\n"
                    @"r;\n"];
    
    NSRect r = [vu toCGRect];
    
    XCTAssert(CGRectEqualToRect(r, NSMakeRect(2, 4, 6, 8)), @"Got %@", NSStringFromRect(r));
    
    [runtime evaluateScript:@"r=null;"];
    
    [runtime shutdown];
    
}


- (void)testObjectForKeyedSubscriptStuff {
    
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        XCTAssert(NO);
    }];
    
    FJSValue *vu = [runtime evaluateScript:
                    @"var r = FJSTestClass.new();"
                    @"r.randomString = 'hi!';\n"
                    @"r;"];
    
    debug(@"vu[@randomString]: '%@'", vu[@"randomString"]);
    
    XCTAssert([[vu[@"randomString"] toObject] isEqualToString:@"hi!"]);
    
    [runtime evaluateScript:@"r = null;"];
    
    [runtime shutdown];
}

- (void)testJSObjectForKeyedSubscriptStuff {
    
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        debug(@"exception: '%@'", exception);
        XCTAssert(NO);
    }];
    
    __block BOOL passedAssertion = NO;
    runtime[@"XCTAssert"] = ^(BOOL condition) {
        XCTAssert(condition);
        passedAssertion = condition;
    };
    
    FJSValue *f = [FJSValue valueWithNewObjectInRuntime:runtime];
    runtime[@"f"] = f;
    
    f[@"foo"] = @(123);
    
    [runtime evaluateScript:@"XCTAssert(f.foo == 123);"];
    
    XCTAssert(passedAssertion);
    
    [runtime shutdown];
}


- (void)testJSFunctionOnMainThreadSync {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        debug(@"exception: '%@'", exception);
        XCTAssert(NO);
    }];
    
    __block BOOL waiting = YES;
    __block BOOL passedAssertion = NO;
    runtime[@"XCTAssert"] = ^(BOOL condition) {
        passedAssertion = condition;
        waiting = NO;
    };
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [runtime evaluateScript:@"DispatchQueue.syncOnMain(function () { XCTAssert(NSThread.isMainThread()); });"];
    });
    
    while (waiting) {
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
        [NSThread sleepForTimeInterval:.01];
    }
    
    XCTAssert(passedAssertion);
    
    [runtime shutdown];
}

- (void)testJSFunctionOnMainThreadAsync {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        debug(@"exception: '%@'", exception);
        XCTAssert(NO);
    }];
    
    __block BOOL waiting = YES;
    __block BOOL passedAssertion = NO;
    runtime[@"XCTAssert"] = ^(BOOL condition) {
        passedAssertion = condition;
        waiting = NO;
    };
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [runtime evaluateScript:@"DispatchQueue.asyncOnMain(function () { XCTAssert(NSThread.isMainThread()); });"];
    });
    
    while (waiting) {
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
        [NSThread sleepForTimeInterval:.01];
    }
    
    XCTAssert(passedAssertion);
    
    [runtime shutdown];
}

- (void)testJSFunctionOnBackgroundThreadAsync {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        debug(@"exception: '%@'", exception);
        XCTAssert(NO);
    }];
    
    __block BOOL waiting = YES;
    __block BOOL passedAssertion = NO;
    runtime[@"XCTAssert"] = ^(BOOL condition) {
        passedAssertion = condition;
        waiting = NO;
    };
    
    [runtime evaluateScript:@"DispatchQueue.asyncOnBackground(function () { XCTAssert(!NSThread.isMainThread()); });"];
    
    
    while (waiting) {
        [NSThread sleepForTimeInterval:.01];
    }
    
    XCTAssert(passedAssertion);
    
    [runtime shutdown];
}

- (void)testJSFunctionOnBackgroundThreadSync {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        debug(@"exception: '%@'", exception);
        XCTAssert(NO);
    }];
    
    __block BOOL waiting = YES;
    __block BOOL passedAssertion = NO;
    runtime[@"XCTAssert"] = ^(BOOL condition) {
        passedAssertion = condition;
        waiting = NO;
    };
    
    [runtime evaluateScript:@"DispatchQueue.syncOnBackground(function () { XCTAssert(!NSThread.isMainThread()); });"];
    
    while (waiting) {
        [NSThread sleepForTimeInterval:.01];
    }
    
    XCTAssert(passedAssertion);
    
    [runtime shutdown];
}


// I can get a similar test to fail in Acorn, but I can't here. It's a little nutty whyyy.
- (void)testSharedInstanceEquality {
    
    //[FJSValue setCaptureJSValueInstancesForDebugging:YES];
    
    FJSRuntime *runtime = [FJSRuntime new];
    [FJSRuntime setUseSynchronousGarbageCollectForDebugging:YES];
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        debug(@"exception: '%@'", exception);
        XCTAssert(NO);
    }];
    
    __block BOOL passedAssertion = NO;
    runtime[@"XCTAssert"] = ^(BOOL condition) {
        passedAssertion = condition;
    };
    
    [runtime evaluateScript:@"var a = FJSTestClass.sharedInstance(); var b = FJSTestClass.sharedInstance(); XCTAssert(a == b);"];
    
    XCTAssert(passedAssertion);
    
    [runtime garbageCollect];
    
    // Do it again because singletons are a bit odd.
    
    [runtime evaluateScript:@"var a = FJSTestClass.sharedInstance(); var b = FJSTestClass.sharedInstance(); XCTAssert(a == b);"];
    
    XCTAssert(passedAssertion);
    
    [runtime evaluateScript:@"a = null;"];
    
    [runtime garbageCollect];
    
    [runtime evaluateScript:@"XCTAssert(b != null);"];
    
    
    [runtime evaluateScript:@"b = null;"];
    
    [runtime shutdown];
    
    
    
    
    
    
}


- (void)xtestClassExtension {
    
    // Note: this is currently failing, and I'm not sure it's something I want to support yet.
    FJSRuntime *runtime = [FJSRuntime new];
    
    FJSValue *u = [runtime evaluateScript:@"class FakeDate extends FJSTestClass { }; var f = new FakeDate(); f.testGetTwelve();"];
    
    XCTAssert([u toInt] == 12);
    
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

id FJSTestReturnNil(void) {
    return nil;
}

id FJSTestReturnPassedObject(id o) {
    return o;
}

BOOL FJSTestPassNil(id o) {
    return o == nil;
}

void FJSThrowException(void) {
    @throw [NSException exceptionWithName:NSGenericException reason:FJSTestExceptionReason userInfo:nil];
}

void FJSReturnVoid(void) {
    ;
}

void FJSXAssert(BOOL b) {
    id self = @"LOL";
    XCTAssert(b);
    XCTAssert(self); // shhh clang sa.
}
















