//
//  FJSWasmTests.m
//  FMJSTests
//
//  Created by August Mueller on 4/30/19.
//  Copyright © 2019 Flying Meat Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <fmjs/FJS.h>
#import "FJSNSDataAdditions.h"
#import "FJSSimpleTests.h"

@interface FJSWasmTests : XCTestCase

@end

// FIXME: WASM tests are failing on Sonoma because of a WebKit JIT change: https://bugs.webkit.org/show_bug.cgi?id=265151
// Hardened runtime needs to be turned off for these to work, but I don't know how to do that for tests.

@implementation FJSWasmTests

- (void)setUp {
    
    [FJSRuntime setUseSynchronousGarbageCollectForDebugging:YES];
    
    [FJSRuntime new]; // Warm things up.
    
    NSString *FMJSBridgeSupportPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"FJSTests" ofType:@"bridgesupport"];
    FMAssert(FMJSBridgeSupportPath);
    
    [[FJSSymbolManager sharedManager] parseBridgeFileAtPath:FMJSBridgeSupportPath];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)xtestWasm1 {
    
    NSString *js = @"var wasmCode = new Uint8Array([0,97,115,109,1,0,0,0,1,138,128,128,128,0,2,96,0,1,127,96,1,127,1,127,3,131,128,128,128,0,2,0,1,4,132,128,128,128,0,1,112,0,0,5,131,128,128,128,0,1,0,1,6,129,128,128,128,0,0,7,151,128,128,128,0,3,6,109,101,109,111,114,121,2,0,4,109,97,105,110,0,0,3,102,111,111,0,1,10,150,128,128,128,0,2,132,128,128,128,0,0,65,42,11,135,128,128,128,0,0,32,0,65,12,106,11]);\n\
    var wasmImports = {};\n\
    var wasmModule = new WebAssembly.Module(wasmCode);\n\
    var wasmInstance = new WebAssembly.Instance(wasmModule, wasmImports);\n\
    wasmInstance.exports.main();\n";
    
    FJSRuntime *runtime = [[FJSRuntime alloc] init];
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        debug(@"exception: '%@'", exception);
        XCTAssert(NO);
    }];
    
    FJSValue *v = [runtime evaluateScript:js];
    XCTAssert([v toInt] == 42);
    
    v = [runtime evaluateScript:@"wasmInstance.exports.foo(12)"];
    
    XCTAssert([v toInt] == 24);
    
    [runtime shutdown];
}

- (void)xtestWasm2 {
    
    char wasm[] = {0,97,115,109,1,0,0,0,1,133,128,128,128,0,1,96,0,1,127,3,130,128,128,128,0,1,0,4,132,128,128,128,0,1,112,0,0,5,131,128,128,128,0,1,0,1,6,129,128,128,128,0,0,7,145,128,128,128,0,2,6,109,101,109,111,114,121,2,0,4,109,97,105,110,0,0,10,139,128,128,128,0,1,133,128,128,128,0,0,65,202,0,11};
    
    int wasm_length = sizeof(wasm) / sizeof(*wasm);
    
    NSData *d = [NSData dataWithBytes:wasm length:wasm_length];
    
    
    FJSRuntime *runtime = [[FJSRuntime alloc] init];
    
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        debug(@"exception: '%@'", exception);
        XCTAssert(NO);
    }];
    
    runtime[@"d"] = d;
    NSString *js = @"var wasmCode = d.toUint8Array();\n\
    var wasmImports = {};\n\
    var wasmModule = new WebAssembly.Module(wasmCode);\n\
    var wasmInstance = new WebAssembly.Instance(wasmModule, wasmImports);\n\
    wasmInstance.exports.main();\n";
    
    FJSValue *v = [runtime evaluateScript:js];
    XCTAssert([v toInt] == 74);
    
    runtime[@"d"] = nil;
    [runtime shutdown];
    
}

- (void)xtestWasmArrayBuffer {
    
    char wasm[] = {0,97,115,109,1,0,0,0,1,133,128,128,128,0,1,96,0,1,127,3,130,128,128,128,0,1,0,4,132,128,128,128,0,1,112,0,0,5,131,128,128,128,0,1,0,1,6,129,128,128,128,0,0,7,145,128,128,128,0,2,6,109,101,109,111,114,121,2,0,4,109,97,105,110,0,0,10,139,128,128,128,0,1,133,128,128,128,0,0,65,202,0,11};
    
    int wasm_length = sizeof(wasm) / sizeof(*wasm);
    
    NSData *d = [NSData dataWithBytes:wasm length:wasm_length];
    
    FJSRuntime *runtime = [[FJSRuntime alloc] init];
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        debug(@"exception: '%@'", exception);
        XCTAssert(NO);
    }];
    
    runtime[@"d"] = d;
    NSString *js = @"var wasmCode = d.toArrayBuffer();\n\
    var wasmImports = {};\n\
    var wasmModule = new WebAssembly.Module(wasmCode);\n\
    var wasmInstance = new WebAssembly.Instance(wasmModule, wasmImports);\n\
    wasmInstance.exports.main();\n";
    
    FJSValue *v = [runtime evaluateScript:js];
    XCTAssert([v toInt] == 74);
    
    runtime[@"d"] = nil;
    [runtime shutdown];
    
}


- (void)testDataArrays {
    
    FJSRuntime *runtime = [[FJSRuntime alloc] init];
    
    {
        uint8 ui8[] = {5, 6, 7};
        NSData *ui8d = [NSData dataWithBytes:&ui8 length:sizeof(ui8)];
        runtime[@"ui8d"] = ui8d;
        [runtime evaluateScript:@"var ui8da = ui8d.toUint8Array();"];
        XCTAssert([[runtime evaluateScript:@"ui8da[0]"] toInt] == 5);
        XCTAssert([[runtime evaluateScript:@"ui8da[1]"] toInt] == 6);
        XCTAssert([[runtime evaluateScript:@"ui8da[2]"] toInt] == 7);
    }
    
    
    {
        uint8 ui8[] = {255, 4, 48, 128};
        
        NSData *ui8dx = [NSData dataWithBytesNoCopy:&ui8 length:sizeof(uint8) * 4 freeWhenDone:NO];
        runtime[@"ui8dx"] = ui8dx;
        [runtime evaluateScript:@"var ui8dxa = ui8dx.toTypedArrayNoCopyOfType(Uint8Array);"];
        XCTAssert([[runtime evaluateScript:@"ui8dxa[0]"] toInt] == 255);
        XCTAssert([[runtime evaluateScript:@"ui8dxa[1]"] toInt] == 4);
        XCTAssert([[runtime evaluateScript:@"ui8dxa[2]"] toInt] == 48);
        XCTAssert([[runtime evaluateScript:@"ui8dxa[3]"] toInt] == 128);
        
        [runtime evaluateScript:@"ui8dxa[1] = ui8dxa[1] + 8;"];
        XCTAssert([[runtime evaluateScript:@"ui8dxa[1]"] toInt] == 12);
        XCTAssert([[runtime evaluateScript:@"ui8dxa[2]"] toInt] == 48);
        debug(@"ui8[1]: %hhu", ui8[1]);
        XCTAssert(ui8[1] == 12);
        
    }
    
    
    {
        sint8 si8[] = {15, 16, 17};
        NSData *si8d = [NSData dataWithBytes:&si8 length:sizeof(si8)];
        runtime[@"si8d"] = si8d;
        [runtime evaluateScript:@"var si8da = si8d.toInt8Array();"];
        XCTAssert([[runtime evaluateScript:@"si8da[0]"] toInt] == 15);
        XCTAssert([[runtime evaluateScript:@"si8da[1]"] toInt] == 16);
        XCTAssert([[runtime evaluateScript:@"si8da[2]"] toInt] == 17);
    }
    
    {
        uint16 ui16[] = {115, 116, 117};
        NSData *ui16d = [NSData dataWithBytes:&ui16 length:sizeof(ui16)];
        runtime[@"ui16d"] = ui16d;
        [runtime evaluateScript:@"var ui16da = ui16d.toUint16Array();"];
        XCTAssert([[runtime evaluateScript:@"ui16da[0]"] toInt] == 115);
        XCTAssert([[runtime evaluateScript:@"ui16da[1]"] toInt] == 116);
        XCTAssert([[runtime evaluateScript:@"ui16da[2]"] toInt] == 117);
    }
    
    {
        sint16 si16[] = {1115, 1116, 1117};
        NSData *si16d = [NSData dataWithBytes:&si16 length:sizeof(si16)];
        runtime[@"si16d"] = si16d;
        [runtime evaluateScript:@"var si16da = si16d.toInt16Array();"];
        XCTAssert([[runtime evaluateScript:@"si16da[0]"] toLong] == 1115);
        XCTAssert([[runtime evaluateScript:@"si16da[1]"] toLong] == 1116);
        XCTAssert([[runtime evaluateScript:@"si16da[2]"] toLong] == 1117);
    }
    
    {
        uint32 ui32[] = {11115, 11116, 11117};
        NSData *ui32d = [NSData dataWithBytes:&ui32 length:sizeof(ui32)];
        runtime[@"ui32d"] = ui32d;
        [runtime evaluateScript:@"var ui32da = ui32d.toUint32Array();"];
        XCTAssert([[runtime evaluateScript:@"ui32da[0]"] toLong] == 11115);
        XCTAssert([[runtime evaluateScript:@"ui32da[1]"] toLong] == 11116);
        XCTAssert([[runtime evaluateScript:@"ui32da[2]"] toLong] == 11117);
    }
    
    {
        sint32 si32[] = {111115, 111116, 111117};
        NSData *si32d = [NSData dataWithBytes:&si32 length:sizeof(si32)];
        runtime[@"si32d"] = si32d;
        [runtime evaluateScript:@"var si32da = si32d.toInt32Array();"];
        XCTAssert([[runtime evaluateScript:@"si32da[0]"] toLong] == 111115);
        XCTAssert([[runtime evaluateScript:@"si32da[1]"] toLong] == 111116);
        XCTAssert([[runtime evaluateScript:@"si32da[2]"] toLong] == 111117);
    }
    
    {
        float f32[] = {1111115.0, 1111116.0, 1111117.0};
        NSData *f32d = [NSData dataWithBytes:&f32 length:sizeof(f32)];
        runtime[@"f32d"] = f32d;
        [runtime evaluateScript:@"var f32da = f32d.toFloat32Array();"];
        XCTAssert(FJSEqualFloats([[runtime evaluateScript:@"f32da[0]"] toFloat], 1111115.0));
        XCTAssert(FJSEqualFloats([[runtime evaluateScript:@"f32da[1]"] toFloat], 1111116.0));
        XCTAssert(FJSEqualFloats([[runtime evaluateScript:@"f32da[2]"] toFloat], 1111117.0));
    }
    
    {
        double f64[] = {1.23, 2.34, .01};
        NSData *f64d = [NSData dataWithBytes:&f64 length:sizeof(f64)];
        runtime[@"f64d"] = f64d;
        [runtime evaluateScript:@"var f64da = f64d.toFloat64Array();"];
        XCTAssert(FJSEqualFloats([[runtime evaluateScript:@"f64da[0]"] toDouble], 1.23));
        XCTAssert(FJSEqualFloats([[runtime evaluateScript:@"f64da[1]"] toDouble], 2.34));
        XCTAssert(FJSEqualFloats([[runtime evaluateScript:@"f64da[2]"] toDouble], .01));
    }
    
    
    {
        FJSValue *v = [runtime evaluateScript:@"var int8a = new Int8Array([-12, 34, -56]); NSData.dataFromInt8Array(int8a);"];
        NSData *d = [v toObject];
        XCTAssert([d isKindOfClass:[NSData class]]);
        XCTAssert([d length] == 3);
        sint8 *values = (sint8 *)[d bytes];
        XCTAssert(values[0] == -12);
        XCTAssert(values[1] ==  34);
        XCTAssert(values[2] == -56);
    }
    
    
    {
        FJSValue *v = [runtime evaluateScript:@"var uint8a = new Uint8Array([-12, 34, -56]); NSData.dataFromUint8Array(uint8a);"];
        NSData *d = [v toObject];
        XCTAssert([d isKindOfClass:[NSData class]]);
        XCTAssert([d length] == 3);
        uint8 *values = (uint8 *)[d bytes];
        XCTAssert(values[0] == 256-12);
        XCTAssert(values[1] ==  34);
        XCTAssert(values[2] == 256-56);
    }
    
    {
        FJSValue *v = [runtime evaluateScript:@"var int16a = new Int16Array([-122, 343, -567]); NSData.dataFromInt16Array(int16a);"];
        NSData *d = [v toObject];
        XCTAssert([d isKindOfClass:[NSData class]]);
        XCTAssert([d length] == 6);
        sint16 *values = (sint16 *)[d bytes];
        XCTAssert(values[0] == -122);
        XCTAssert(values[1] ==  343);
        XCTAssert(values[2] == -567);
    }
    
    
    {
        FJSValue *v = [runtime evaluateScript:@"var uint16a = new Uint16Array([-121, 3444, -561]); NSData.dataFromUint16Array(uint16a);"];
        NSData *d = [v toObject];
        XCTAssert([d isKindOfClass:[NSData class]]);
        XCTAssert([d length] == 6);
        uint16 *values = (uint16 *)[d bytes];
        XCTAssert(values[0] == 65536-121);
        XCTAssert(values[1] ==  3444);
        XCTAssert(values[2] == 65536-561);
    }
    
    {
        FJSValue *v = [runtime evaluateScript:@"var int32a = new Int32Array([-1322, 3443, -5617]); NSData.dataFromInt32Array(int32a);"];
        NSData *d = [v toObject];
        XCTAssert([d isKindOfClass:[NSData class]]);
        XCTAssert([d length] == 12);
        sint32 *values = (sint32 *)[d bytes];
        XCTAssert(values[0] == -1322);
        XCTAssert(values[1] ==  3443);
        XCTAssert(values[2] == -5617);
    }
    
    {
        FJSValue *v = [runtime evaluateScript:@"var uint32a = new Uint32Array([-1221, 34444, -5615]); NSData.dataFromUint32Array(uint32a);"];
        NSData *d = [v toObject];
        XCTAssert([d isKindOfClass:[NSData class]]);
        XCTAssert([d length] == 12);
        uint32 *values = (uint32 *)[d bytes];
        XCTAssert(values[0] == 4294967296-1221);
        XCTAssert(values[1] ==  34444);
        XCTAssert(values[2] == 4294967296-5615);
    }
    
    {
        FJSValue *v = [runtime evaluateScript:@"var f32a = new Float32Array([-74.35, 12.6, 49.2]); NSData.dataFromFloat32Array(f32a);"];
        NSData *d = [v toObject];
        XCTAssert([d isKindOfClass:[NSData class]]);
        XCTAssert([d length] == 12);
        float *values = (float *)[d bytes];
        XCTAssert(FJSEqualFloatsSlop(values[0], -74.35));
        XCTAssert(FJSEqualFloatsSlop(values[1],  12.6));
        XCTAssert(FJSEqualFloatsSlop(values[2],  49.2));
    }
    
    {
        FJSValue *v = [runtime evaluateScript:@"var f64a = new Float64Array([-742.35, 123.6, 491.2]); NSData.dataFromFloat64Array(f64a);"];
        NSData *d = [v toObject];
        XCTAssert([d isKindOfClass:[NSData class]]);
        XCTAssert([d length] == 24);
        double *values = (double *)[d bytes];
        XCTAssert(FJSEqualFloats(values[0], -742.35));
        XCTAssert(FJSEqualFloats(values[1],  123.6));
        XCTAssert(FJSEqualFloats(values[2],  491.2));
    }
    
    [runtime shutdown];
}


- (void)testCGContextDataAccess {
    
    FJSRuntime *runtime = [[FJSRuntime alloc] init];
    
    size_t width  = 100;
    size_t height = 100;
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
    
    CGContextRef bgraContext = CGBitmapContextCreate(nil, width, height, 8, 100, cs, (CGBitmapInfo)kCGImageAlphaNone);
    
    CGFloat locations[] = {0.0, 1.0};
    CGFloat colors[] = {0.0, 1.0,
                        1.0, 1.0};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(cs, colors, locations, 2);
    CGContextDrawLinearGradient(bgraContext, gradient, CGPointMake(0, 0), CGPointMake(width, 0), 0);
    
    CGColorSpaceRelease(cs);
    
    size_t bytesPerRow = CGBitmapContextGetBytesPerRow(bgraContext);
    
    NSData *dataWrapper = [NSData dataWithBytesNoCopy:CGBitmapContextGetData(bgraContext) length:bytesPerRow * height freeWhenDone:NO];
    
    FJSValue *typedArray = [dataWrapper toTypedArrayNoCopy:kJSTypedArrayTypeUint8Array runtime:runtime];
    
    runtime[@"ta"] = typedArray;
    
    NSString *ditherFunction =
@"function floydSteinberg(sb, w, h)   // source buffer, width, height\n\
{\n\
   for(var i=0; i<h; i++)\n\
      for(var j=0; j<w; j++)\n\
      {\n\
         var ci = i*w+j;               // current buffer index\n\
         var cc = sb[ci];              // current color\n\
         var rc = (cc<128?0:255);      // real (rounded) color\n\
         var err = cc-rc;              // error amount\n\
         sb[ci] = rc;                  // saving real color\n\
         if(j+1<w) sb[ci  +1] += (err*7)>>4;  // if right neighbour exists\n\
         if(i+1==h) continue;   // if we are in the last line\n\
         if(j  >0) sb[ci+w-1] += (err*3)>>4;  // bottom left neighbour\n\
                   sb[ci+w  ] += (err*5)>>4;  // bottom neighbour\n\
         if(j+1<w) sb[ci+w+1] += (err*1)>>4;  // bottom right neighbour\n\
      }\n\
}\n\
floydSteinberg(ta, 100, 100);";
    
    [runtime evaluateScript:ditherFunction];
    
    [runtime shutdown];
    
    CGImageRef img = CGBitmapContextCreateImage(bgraContext);
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:@"/tmp/foo.tiff"], kUTTypeTIFF, 1, NULL);
    CGImageDestinationAddImage(imageDestination, img, (__bridge CFDictionaryRef)[NSDictionary dictionary]);
    BOOL worked = CGImageDestinationFinalize(imageDestination);
    
    if (!worked) {
        NSLog(@"%s:%d", __FUNCTION__, __LINE__);
        debug(@"CGImageDestinationFinalize failed");
    }
    
    CFRelease(imageDestination);
    CGImageRelease(img);
    
    system("open /tmp/foo.tiff");
    
}


@end
