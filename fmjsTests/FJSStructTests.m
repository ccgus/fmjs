#import <XCTest/XCTest.h>
#import "FJSSimpleTests.h" // For some inline test functions.
#import "FJSFFI.h"
#import <FMJS/FJS.h>
#import <dlfcn.h>

@interface FJSStructTests : XCTestCase

@end

@implementation FJSStructTests


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
        
        // Do we have to free the elements as well? Problaby.
        
        free(ffi_type_cgpoint);
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
    void *structReturnStorage = calloc(sizeof(CGPoint), 1);
    
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


@end



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
