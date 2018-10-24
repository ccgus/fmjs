#import <XCTest/XCTest.h>
#import "FJSSimpleTests.h" // For some inline test functions.
#import "FJSFFI.h"
#import "FJSUtil.h"
#import "FJSSymbol.h"
#import <FMJS/FJS.h>
#import <dlfcn.h>

// This is in FJSRuntime, as CGRectMake(74, 78, 11, 16)
APPKIT_EXTERN const CGRect FJSRuntimeTestCGRect;


@interface FJSStructTests : XCTestCase

@end

@implementation FJSStructTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    [FJSRuntime setUseSynchronousGarbageCollectForDebugging:YES];
    
    [FJSRuntime new]; // Warm things up.
    
    NSString *FMJSBridgeSupportPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"FJSTests" ofType:@"bridgesupport"];
    FMAssert(FMJSBridgeSupportPath);
    
    [[FJSSymbolManager sharedManager] parseBridgeFileAtPath:FMJSBridgeSupportPath];
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testCGRectReference {
    
    CGRect originalRect = CGRectMake(74, 78, 11, 16);
    
    FJSSymbol *CGRectMakeSymbol = [FJSSymbol symbolForName:@"CGRectMake"];
    XCTAssert(CGRectMakeSymbol);
    FJSSymbol *CGRectMakeRetSymbol = [CGRectMakeSymbol returnValue];
    XCTAssert(CGRectMakeRetSymbol);
    
    // Let's make some meory to store the pointers to our args.
    ffi_cif cif;
    ffi_type** ffiArgs = malloc(sizeof(ffi_type *) * 4);
    void** ffiValues   = malloc(sizeof(void *) * 4);
    
    // Assign the type and pointer locations of the arguments.
    ffiArgs[0]   = &ffi_type_double;
    ffiValues[0] = &originalRect.origin.x;
    
    ffiArgs[1]   = &ffi_type_double;
    ffiValues[1] = &originalRect.origin.y;
    
    ffiArgs[2]   = &ffi_type_double;
    ffiValues[2] = &originalRect.size.width;
    
    ffiArgs[3]   = &ffi_type_double;
    ffiValues[3] = &originalRect.size.height;
    
    ffi_type *ffi_type_cgrect = [FJSFFI ffiTypeForStructure:[CGRectMakeRetSymbol runtimeType]];
    
    // Get everything ready for the call.
    ffi_status prep_status = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 4, ffi_type_cgrect, ffiArgs);
    assert(prep_status == FFI_OK);
    
    void *structReturnStorage = calloc(1, sizeof(CGRect));
    debug(@"structReturnStorage: %p", structReturnStorage);
    
    // Let's look up the address of CGPointMake
    void *callAddress = dlsym(RTLD_DEFAULT, "CGRectMake");
    assert(callAddress);
    
    // And then actually call it.
    ffi_call(&cif, callAddress, structReturnStorage, ffiValues);
    
    
    // Now we're going to cast our memory to a CGPoint for use in the asserts.
    CGRect *p = ((CGRect*)structReturnStorage);
    
    XCTAssert(CGRectEqualToRect(*p, originalRect));
    
    free(ffiArgs);
    free(ffiValues);
    
    ffiArgs   = malloc(sizeof(ffi_type *) * 1);
    ffiValues = malloc(sizeof(void *) * 1);
    
    
    ffiArgs[0]   = ffi_type_cgrect;
    ffiValues[0] = p;
    
    prep_status = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 1, &ffi_type_sint8, ffiArgs);
    assert(prep_status == FFI_OK);

    // Now let's call another method with that storage.
    callAddress = dlsym(RTLD_DEFAULT, "FJSTestCGRect");
    assert(callAddress);
    
    BOOL returnValue = NO;
    
    ffi_call(&cif, callAddress, &returnValue, ffiValues);
    
    XCTAssert(returnValue);
    
    free(ffiArgs);
    free(ffiValues);
    free(structReturnStorage);
}


- (void)testFFITestStructCaching {
    
    /*
     {CGPoint=dd}16@0:8
     {_NSAffineTransformStruct=dddddd}
     {CGScreenUpdateMoveDelta="dX"i"dY"i}
     {CGRect={CGPoint=dd}{CGSize=dd}}16@0:8
     {CGSize=dd}
     {_NSRange=QQ}
     {_NSHashEnumerator="_pi"Q"_si"Q"_bs"^v}
     {_NSDecimal="_exponent"i"_length"I"_isNegative"I"_isCompact"I"_reserved"I"_mantissa"[8S]}
     {CGRect={CGPoint=dd}{CGSize=dd}}32@0:8{_NSRange=QQ}16
     {CGPSConverterCallbacks="version"I"beginDocument"^?"endDocument"^?"beginPage"^?"endPage"^?"noteProgress"^?"noteMessage"^?"releaseInfo"^?}
     {_NSHashTableCallBacks="hash"^?"isEqual"^?"retain"^?"release"^?"describe"^?}
     {NSEdgeInsets=dddd}
     {CGAffineTransform=dddddd}
     {_NSRange=QQ}24@0:8q16
     {_NSHashEnumerator=QQ^v}
     */
    
    [FJSFFI ffiTypeForStructure:@"{CGRect={CGPoint=dd}{CGSize=dd}}16@0:8"];
    
    
    NSString *cgPointStuctString = @"{CGPoint=dd}";
    ffi_type *cgPointType = [FJSFFI ffiTypeForStructure:cgPointStuctString];
    XCTAssert(cgPointType == [FJSFFI ffiTypeForStructure:cgPointStuctString]);
    
    
    NSString *cgRectStuctString = @"{CGRect={CGPoint=dd}{CGSize=dd}}";
    ffi_type *cgRectType = [FJSFFI ffiTypeForStructure:cgRectStuctString];
    XCTAssert(cgRectType == [FJSFFI ffiTypeForStructure:cgRectStuctString]);
    
    
}

- (void)testRandomCGCrap {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    {
        
        
        CIVector *v2 = [[runtime evaluateScript:@"v = CIVector.vectorWithCGRect_(CGRectMake(83, 75, 79, 13));"] toObject];
        XCTAssert([v2 isKindOfClass:[CIVector class]]);
        CGRect vr2 = [v2 CGRectValue];
        XCTAssert(CGRectEqualToRect(vr2, CGRectMake(83, 75, 79, 13)));
        
        
        CIVector *v1 = [[runtime evaluateScript:@"v = CIVector.vectorWithX_Y_Z_W_(82, 74, 78, 12);"] toObject];
        XCTAssert([v1 isKindOfClass:[CIVector class]]);
        CGRect vr1 = [v1 CGRectValue];
        XCTAssert(CGRectEqualToRect(vr1, CGRectMake(82, 74, 78, 12)));
        
        
        
        XCTAssert([FJSSymbol symbolForName:@"FJSTestCGRect"]);
        
        CGRect r = [[runtime evaluateScript:@"var r = CGRectMake(74, 78, 11, 16); r;"] toCGRect];
        XCTAssert(CGRectEqualToRect(r, FJSRuntimeTestCGRect));
        
        XCTAssert([[runtime evaluateScript:@"FJSTestCGRect(r)"] toBOOL]);
        
        XCTAssert([FJSSymbol symbolForName:@"FJSRuntimeTestCGRect"]);
        XCTAssert([[runtime evaluateScript:@"FJSTestCGRect(FJSRuntimeTestCGRect)"] toBOOL]);
        
        
        XCTAssert([FJSSymbol symbolForName:@"CGRectInset"]);
        CGRect inset = [[runtime evaluateScript:@"CGRectInset(CGRectMake(74, 78, 11, 16), 2, 3)"] toCGRect];
        
        XCTAssert(FJSEqualFloats(inset.origin.x, 76));
        XCTAssert(FJSEqualFloats(inset.origin.y, 81));
        XCTAssert(FJSEqualFloats(inset.size.width, 7));
        XCTAssert(FJSEqualFloats(inset.size.height, 10));



        CGPoint p = [[runtime evaluateScript:@"CGPointMake(74, 78);"] toCGPoint];

        XCTAssert(FJSEqualFloats(p.x, 74));
        XCTAssert(FJSEqualFloats(p.y, 78));


        r = [[runtime evaluateScript:@"CGRectMake(74, 78, 11, 16);"] toCGRect];

        XCTAssert(FJSEqualFloats(r.origin.x, 74));
        XCTAssert(FJSEqualFloats(r.origin.y, 78));
        XCTAssert(FJSEqualFloats(r.size.width, 11));
        XCTAssert(FJSEqualFloats(r.size.height, 16));
        
        [runtime shutdown];
        
    }
}

- (void)testCGRectBridgeStructFFIBuild {
    
    FJSSymbol *CGRectSym = [FJSSymbol symbolForName:@"CGRect"];
    XCTAssert(CGRectSym);
    
    FJSSymbol *CGRectMakeSymbol = [FJSSymbol symbolForName:@"CGRectMake"];
    XCTAssert(CGRectMakeSymbol);
    
    FJSSymbol *CGRectMakeRetSymbol = [CGRectMakeSymbol returnValue];
    XCTAssert(CGRectMakeRetSymbol);
    
    XCTAssert([[CGRectMakeRetSymbol runtimeType] isEqualToString:@"{CGRect={CGPoint=dd}{CGSize=dd}}"]);
    
    ffi_type *ffi_type_rect = [FJSFFI ffiTypeForStructure:[CGRectMakeRetSymbol runtimeType]];
    XCTAssert(ffi_type_rect);
    
    if (ffi_type_rect) {
        
        // We're going to do this here, and then reuse it later on for testing in another method.
        XCTAssert(ffi_type_rect->type == FFI_TYPE_STRUCT);
        XCTAssert(ffi_type_rect->elements[0]->type == FFI_TYPE_STRUCT);
        XCTAssert(ffi_type_rect->elements[1]->type == FFI_TYPE_STRUCT);
        XCTAssert(ffi_type_rect->elements[2] == nil);
        
        
        // CGPoint
        XCTAssert(ffi_type_rect->elements[0]->elements[0] == &ffi_type_double);
        XCTAssert(ffi_type_rect->elements[0]->elements[1] == &ffi_type_double);
        XCTAssert(ffi_type_rect->elements[0]->elements[2] == nil);
        
        // CGSize
        XCTAssert(ffi_type_rect->elements[1]->elements[0] == &ffi_type_double);
        XCTAssert(ffi_type_rect->elements[1]->elements[1] == &ffi_type_double);
        XCTAssert(ffi_type_rect->elements[1]->elements[2] == nil);
        
        
        XCTAssert([FJSFFI countOfElementsInType:ffi_type_rect] == 2);
        XCTAssert([FJSFFI countOfElementsInType:ffi_type_rect->elements[0]] == 2);
        XCTAssert([FJSFFI countOfElementsInType:ffi_type_rect->elements[1]] == 2);
        
        [FJSFFI describeFFIType:ffi_type_rect];
    }
}

- (void)testCGSizeBridgeStructFFIBuild {
    
    FJSSymbol *CGSizeSym = [FJSSymbol symbolForName:@"CGSize"];
    XCTAssert(CGSizeSym);
    
    FJSSymbol *CGSizeMakeSymbol = [FJSSymbol symbolForName:@"CGSizeMake"];
    XCTAssert(CGSizeMakeSymbol);
    
    FJSSymbol *CGSizeMakeRetSymbol = [CGSizeMakeSymbol returnValue];
    XCTAssert(CGSizeMakeRetSymbol);
    
    XCTAssert([[CGSizeMakeRetSymbol runtimeType] isEqualToString:@"{CGSize=dd}"]);
    
    ffi_type *ffi_type_cgsize = [FJSFFI ffiTypeForStructure:[CGSizeMakeRetSymbol runtimeType]];
    XCTAssert(ffi_type_cgsize);
    
    if (ffi_type_cgsize) {
        
        // We're going to do this here, and then reuse it later on for testing in another method.
        XCTAssert(ffi_type_cgsize->type == FFI_TYPE_STRUCT);
        XCTAssert(ffi_type_cgsize->elements[0] == &ffi_type_double);
        XCTAssert(ffi_type_cgsize->elements[1] == &ffi_type_double);
        XCTAssert(ffi_type_cgsize->elements[2] == nil);
        
        XCTAssert([FJSFFI countOfElementsInType:ffi_type_cgsize] == 2);
        
    }
}


- (void)testCGPointBridgeStructFFIBuild {
    
    
    FJSSymbol *CGPointSym = [FJSSymbol symbolForName:@"CGPoint"];
    XCTAssert(CGPointSym);
    
    FJSSymbol *CGPointMakeSymbol = [FJSSymbol symbolForName:@"CGPointMake"];
    XCTAssert(CGPointMakeSymbol);
    
    FJSSymbol *CGPointMakeRetSymbol = [CGPointMakeSymbol returnValue];
    XCTAssert(CGPointMakeRetSymbol);
    
    XCTAssert([[CGPointMakeRetSymbol runtimeType] isEqualToString:@"{CGPoint=dd}"]);
    
    ffi_type *ffi_type_cgpoint = [FJSFFI ffiTypeForStructure:[CGPointMakeRetSymbol runtimeType]];
    XCTAssert(ffi_type_cgpoint);
    
    if (ffi_type_cgpoint) {
    
        // We're going to do this here, and then reuse it later on for testing in another method.
        XCTAssert(ffi_type_cgpoint->type == FFI_TYPE_STRUCT);
        XCTAssert(ffi_type_cgpoint->elements[0] == &ffi_type_double);
        XCTAssert(ffi_type_cgpoint->elements[1] == &ffi_type_double);
        XCTAssert(ffi_type_cgpoint->elements[2] == nil);
        
        XCTAssert([FJSFFI countOfElementsInType:ffi_type_cgpoint] == 2);
        
    }
    
    
    //names:
    // <struct name='NSPoint' type='{_NSPoint=&quot;x&quot;f&quot;y&quot;f}' type64='{CGPoint=&quot;x&quot;d&quot;y&quot;d}'/>
    // <struct name='NSMapTableValueCallBacks' type='{_NSMapTableValueCallBacks=&quot;retain&quot;^?&quot;release&quot;^?&quot;describe&quot;^?}'/>

    
    // return and arg types
    // {CGRect={CGPoint=dd}{CGSize=dd}}
    // {CGAffineTransform=dddddd}
    // ^{CGAffineTransform=dddddd}
    // ^{CGPath=}
    // ^{CGShading=}
    // {CGScreenUpdateMoveDelta=ii}
}

- (void)testCGPointStructFFICall {
    // this is around for reference, as a way to showcase to myself how to call CGPointMake with a couple of doubles.
    // http://www.chiark.greenend.org.uk/doc/libffi-dev/html/Type-Example.html
    
    
    
    // This is where ffi will eventually write our struct.
    void *structReturnStorage = calloc(1, sizeof(CGPoint));
    
    // Let's look up the address of CGPointMake
    void *callAddress = dlsym(RTLD_DEFAULT, "CGPointMake");
    assert(callAddress);
    
    // There are the values, and then the argument count to CGPointMake.
    CGFloat a = 74, b = 78;
    uint effectiveArgumentCount = 2;
    
    // Let's make some meory to store the pointers to our args.
    ffi_cif cif;
    ffi_type** ffiArgs = malloc(sizeof(ffi_type *) * effectiveArgumentCount);
    void** ffiValues   = malloc(sizeof(void *) * effectiveArgumentCount);
    
    // Assign the type and pointer locations of the arguments.
    ffiArgs[0]   = &ffi_type_double;
    ffiValues[0] = &a;
    
    ffiArgs[1]   = &ffi_type_double;
    ffiValues[1] = &b;
    
    // Since CGPoint isn't built into lib_ffi, we have to build our own ffi_type. (Things like ffi_type_double are already built in).
    ffi_type ffi_type_cgpoint;
    
    // Build FFI type
    ffi_type_cgpoint.size      = 0;
    ffi_type_cgpoint.alignment = 0;
    ffi_type_cgpoint.type      = FFI_TYPE_STRUCT;
    ffi_type_cgpoint.elements  = calloc(sizeof(ffi_type *), effectiveArgumentCount + 1);
    
    ffi_type_cgpoint.elements[0] = &ffi_type_double;
    ffi_type_cgpoint.elements[1] = &ffi_type_double;
    ffi_type_cgpoint.elements[2] = nil;
    
    // Get everything ready for the call.
    ffi_status prep_status = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, effectiveArgumentCount, &ffi_type_cgpoint, ffiArgs);
    assert(prep_status == FFI_OK);
    
    // And then actually call it.
    ffi_call(&cif, callAddress, structReturnStorage, ffiValues);
    
    // Now we're going to cast our memory to a CGPoint for use in the asserts.
    CGPoint p = *((CGPoint*)structReturnStorage);
    
    XCTAssert(FJSEqualFloats(p.x, 74));
    XCTAssert(FJSEqualFloats(p.y, 78));
    
    free(structReturnStorage);
    
    // We're going to do this here, and then reuse it later on for testing in another method.
    XCTAssert(ffi_type_cgpoint.type == FFI_TYPE_STRUCT);
    XCTAssert(ffi_type_cgpoint.elements[0] == &ffi_type_double);
    XCTAssert(ffi_type_cgpoint.elements[1] == &ffi_type_double);
    XCTAssert(ffi_type_cgpoint.elements[2] == nil);
    
    free(ffi_type_cgpoint.elements);
    
}


- (void)testCGPointAccess {
    
    
    XCTAssert(!FJSStructNameFromRuntimeType(@"{=}"), @"Got '%@'", FJSStructNameFromRuntimeType(@"{=}"));
    
    
    NSString *name = FJSStructNameFromRuntimeType(@"{CGPoint=dd}");
    XCTAssert([name isEqualToString:@"CGPoint"], @"Got '%@'", name);
    
    FJSSymbol *structSym = [FJSSymbol symbolForName:name];
    
    XCTAssert([structSym structFieldNamed:@"x"]);
    XCTAssert([structSym structFieldNamed:@"y"]);
    XCTAssert(![structSym structFieldNamed:@"n"]);
    
    XCTAssert([[structSym structFieldNamed:@"x"] size] == 8);
    XCTAssert([[structSym structFieldNamed:@"y"] size] == 8);
    
    XCTAssert([[structSym structFields] count] == 2);
    
    FJSRuntime *rt = [FJSRuntime new];
    
    FJSSymbol *CGPointMakeSym = [FJSSymbol symbolForName:@"CGPointMake"];
    XCTAssert(CGPointMakeSym);

    [rt evaluateScript:@"var p = CGPointMake(3, 4);"];

    FJSValue *v = [rt evaluateScript:@"p.y"];
    
    XCTAssert([v toInt] == 4, @"Got %d", [v toInt]);

    v = [rt evaluateScript:@"p.x"];
    
    XCTAssert([v toInt] == 3, @"Got %d", [v toInt]);
    
    
    [rt evaluateScript:@"p.y = 14; p.x = 7;"];
    
    v = [rt objectForKeyedSubscript:@"p"];
    
    CGPoint p = [v toCGPoint];
    
    XCTAssert(FJSEqualFloats(p.y, 14), @"Got %f", p.y);
    XCTAssert(FJSEqualFloats(p.x, 7), @"Got %f", p.x);
    
    [rt shutdown];
    
}

- (void)testCGRectAccess {
    
    
    FJSSymbol *CGRectMakeSym = [FJSSymbol symbolForName:@"CGRectMake"];
    XCTAssert(CGRectMakeSym);
    
    NSString *name = FJSStructNameFromRuntimeType(@"{CGRect={CGPoint=dd}{CGSize=dd}}");
    XCTAssert([name isEqualToString:@"CGRect"], @"Got '%@'", name);
    
    FJSSymbol *structSym = [FJSSymbol symbolForName:name];
    
    XCTAssert([structSym structFieldNamed:@"size"]);
    XCTAssert([structSym structFieldNamed:@"origin"]);
    XCTAssert(![structSym structFieldNamed:@"x"]);
    
    XCTAssert([[structSym structFieldNamed:@"size"] size] == 16);
    XCTAssert([[structSym structFieldNamed:@"origin"] size] == 16);
    
    XCTAssert([[structSym structFields] count] == 2);
    
    FJSRuntime *rt = [FJSRuntime new];
    [rt evaluateScript:@"var r = CGRectMake(1, 2, 3, 4);"];

    FJSValue *v = [rt evaluateScript:@"r.size.width;"];
    XCTAssert([v toInt] == 3, @"Got %d", [v toInt]);
    
    v = [rt evaluateScript:@"r.size.height;"];
    XCTAssert([v toInt] == 4, @"Got %d", [v toInt]);
    
    v = [rt evaluateScript:@"r.origin.x;"];
    XCTAssert([v toInt] == 1, @"Got %d", [v toInt]);
    
    v = [rt evaluateScript:@"r.origin.y;"];
    XCTAssert([v toInt] == 2, @"Got %d", [v toInt]);
    
    CGRect *rectPointer = [[rt objectForKeyedSubscript:@"r"] structLocation];
    
    XCTAssert(FJSEqualFloats(rectPointer->origin.x + rectPointer->origin.y + rectPointer->size.width + rectPointer->size.height, 10));
    
    [rt evaluateScript:@"r.origin.x = 37;"];
    XCTAssert(FJSEqualFloats(rectPointer->origin.x, 37), @"Got %f", rectPointer->origin.x);
    
    [rt evaluateScript:@"r.origin.x = r.size.width + 15;"];
    XCTAssert(FJSEqualFloats(rectPointer->origin.x, 18), @"Got %f", rectPointer->origin.x);
    
    [rt evaluateScript:@"r.origin.y = r.size.height;"];
    XCTAssert([[rt evaluateScript:@"r.origin.y;"] toInt] == 4);
    
    
    
    [rt evaluateScript:@"r.origin = CGPointMake(43, 52);"];
    XCTAssert([[rt evaluateScript:@"r.origin.y;"] toInt] == 52, @"Got %d", [[rt evaluateScript:@"r.origin.y;"] toInt]);
    XCTAssert([[rt evaluateScript:@"r.origin.x;"] toInt] == 43, @"Got %d", [[rt evaluateScript:@"r.origin.x;"] toInt]);
    
    [rt shutdown];
    
}


- (void)testNSRangeAccess {
    
    FJSRuntime *rt = [FJSRuntime new];
    
    FJSSymbol *CGRectMakeSym = [FJSSymbol symbolForName:@"NSMakeRange"];
    XCTAssert(CGRectMakeSym);
    
    [rt evaluateScript:@"var r = NSMakeRange(13, 14);"];
    
    FJSValue *v = [rt evaluateScript:@"r.location;"];
    
    XCTAssert([v toInt] == 13, @"Got %d", [v toInt]);
    v = [rt evaluateScript:@"r.length;"];
    
    XCTAssert([v toInt] == 14, @"Got %d", [v toInt]);
    
    [rt evaluateScript:@"r.location = 7; r.length = 12;"];
    
    v = [rt objectForKeyedSubscript:@"r"];
    
    NSRange *r = [v structLocation];
    
    XCTAssert(FJSEqualFloats(r->length, 12), @"Got %ld", r->length);
    XCTAssert(FJSEqualFloats(r->location, 7), @"Got %ld", r->location);
    
    [rt evaluateScript:@"r.location = r.length;"];
    
    XCTAssert(FJSEqualFloats(r->location, 12), @"Got %ld", r->location);
    
    [rt shutdown];
    
}

@end

BOOL FJSTestCGRect(CGRect r) {
    debug(@"r: %@", NSStringFromRect(r));
    CGRect t = CGRectMake(74, 78, 11, 16);
    return CGRectEqualToRect(r, t);
}


/*

Here's a list of structs that are showing up in bridge files:

{CGPoint=dd}16@0:8
{_NSAffineTransformStruct=dddddd}
{CGScreenUpdateMoveDelta="dX"i"dY"i}
{CGRect={CGPoint=dd}{CGSize=dd}}16@0:8
{CGSize=dd}
{_NSRange=QQ}
{_NSHashEnumerator="_pi"Q"_si"Q"_bs"^v}
{_NSDecimal="_exponent"i"_length"I"_isNegative"I"_isCompact"I"_reserved"I"_mantissa"[8S]}
{CGRect={CGPoint=dd}{CGSize=dd}}32@0:8{_NSRange=QQ}16
{CGPSConverterCallbacks="version"I"beginDocument"^?"endDocument"^?"beginPage"^?"endPage"^?"noteProgress"^?"noteMessage"^?"releaseInfo"^?}
{_NSHashTableCallBacks="hash"^?"isEqual"^?"retain"^?"release"^?"describe"^?}
{NSEdgeInsets=dddd}
{CGAffineTransform=dddddd}
{_NSRange=QQ}24@0:8q16
{_NSHashEnumerator=QQ^v}
{CGAffineTransform="a"d"b"d"c"d"d"d"tx"d"ty"d}
{_NSMapTableKeyCallBacks="hash"^?"isEqual"^?"retain"^?"release"^?"describe"^?"notAKeyMarker"^v}
{_NSMapTableValueCallBacks="retain"^?"release"^?"describe"^?}
{CGSize=dd}40@0:8@16{CGSize=dd}24
{_NSRange=QQ}32@0:8{CGPoint=dd}16
{CGSize=dd}56@0:8@16{CGSize=dd}24{CGSize=dd}40
{_NSHashTableCallBacks=^?^?^?^?^?}
{CGDataConsumerCallbacks="putBytes"^?"releaseConsumer"^?}
{CGSize=dd}40@0:8@16@24@32
{CGPoint=dd}32@0:8{CGPoint=dd}16
{CGRect={CGPoint=dd}{CGSize=dd}}96@0:8@16{CGRect={CGPoint=dd}{CGSize=dd}}24{CGRect={CGPoint=dd}{CGSize=dd}}56q88
{_NSRange="location"Q"length"Q}
{CGRect={CGPoint=dd}{CGSize=dd}}32@0:8@16q24
{CGPathElement="type"i"points"^{CGPoint}}
{_NSAffineTransformStruct="m11"d"m12"d"m21"d"m22"d"tX"d"tY"d}
{CGSize=dd}16@0:8
{_NSOperatingSystemVersion=qqq}
{CGVector=dd}
{CGPoint=dd}
{_NSMapEnumerator=QQ^v}
{_NSMapEnumerator="_pi"Q"_si"Q"_bs"^v}
{CGRect={CGPoint=dd}{CGSize=dd}}
{_NSSwappedDouble="v"Q}
{CGRect={CGPoint=dd}{CGSize=dd}}96@0:8@16Q24@32{CGRect={CGPoint=dd}{CGSize=dd}}40{CGPoint=dd}72Q88
{CGRect={CGPoint=dd}{CGSize=dd}}56@0:8@16{CGRect={CGPoint=dd}{CGSize=dd}}24
{CGRect={CGPoint=dd}{CGSize=dd}}64@0:8@16@24{CGRect={CGPoint=dd}{CGSize=dd}}32
{CGScreenUpdateMoveDelta=ii}
{CGVector="dx"d"dy"d}
{NSEdgeInsets=dddd}40@0:8@16@24q32
{_NSMapTableKeyCallBacks=^?^?^?^?^?^v}
{__CGEventTapInformation="eventTapID"I"tapPoint"I"options"I"eventsOfInterest"Q"tappingProcess"i"processBeingTapped"i"enabled"B"minUsecLatency"f"avgUsecLatency"f"maxUsecLatency"f}
{CGSize=dd}32@0:8{CGSize=dd}16
{CGSize="width"d"height"d}
{CGRect={CGPoint=dd}{CGSize=dd}}80@0:8@16{CGRect={CGPoint=dd}{CGSize=dd}}24{CGPoint=dd}56Q72
{_NSSwappedDouble=Q}
{CGDeviceColor="red"f"green"f"blue"f}
{_NSRange=QQ}48@0:8@16@24@32^@40
{CGDataProviderSequentialCallbacks="version"I"getBytes"^?"skipForward"^?"rewind"^?"releaseInfo"^?}
{_NSRange=QQ}24@0:8@16
{_NSRange=QQ}16@0:8
{CGRect={CGPoint=dd}{CGSize=dd}}40@0:8{_NSRange=QQ}16^{_NSRange=QQ}32
{CGPatternCallbacks="version"I"drawPattern"^?"releaseInfo"^?}
{CGRect={CGPoint=dd}{CGSize=dd}}32@0:8@16@24
{_NSRange=QQ}52@0:8@16@24@32^q40B48
{_NSSwappedFloat="v"I}
{_NSFastEnumerationState="state"Q"itemsPtr"^@"mutationsPtr"^Q"extra"[5Q]}
{CGFunctionCallbacks="version"I"evaluate"^?"releaseInfo"^?}
{_NSMapTableValueCallBacks=^?^?^?}
{CGPoint="x"d"y"d}
{CGDataProviderDirectCallbacks="version"I"getBytePointer"^?"releaseBytePointer"^?"getBytesAtPosition"^?"releaseInfo"^?}
{_NSSwappedFloat=I}
{CGSize=dd}40@0:8@16@24q32
{CGRect="origin"{CGPoint}"size"{CGSize}}
{NSEdgeInsets="top"d"left"d"bottom"d"right"d}
{_NSDecimal=b8b4b1b1b18[8S]}
{_NSRange=QQ}56@0:8@16{_NSRange=QQ}24{_NSRange=QQ}40
{_NSOperatingSystemVersion="majorVersion"q"minorVersion"q"patchVersion"q}
{CGSize=dd}24@0:8@16


*/
