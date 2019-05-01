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

- (void)testWasm1 {
    
    NSString *js = @"var wasmCode = new Uint8Array([0,97,115,109,1,0,0,0,1,138,128,128,128,0,2,96,0,1,127,96,1,127,1,127,3,131,128,128,128,0,2,0,1,4,132,128,128,128,0,1,112,0,0,5,131,128,128,128,0,1,0,1,6,129,128,128,128,0,0,7,151,128,128,128,0,3,6,109,101,109,111,114,121,2,0,4,109,97,105,110,0,0,3,102,111,111,0,1,10,150,128,128,128,0,2,132,128,128,128,0,0,65,42,11,135,128,128,128,0,0,32,0,65,12,106,11]);\n\
    var wasmImports = {};\n\
    var wasmModule = new WebAssembly.Module(wasmCode);\n\
    var wasmInstance = new WebAssembly.Instance(wasmModule, wasmImports);\n\
    wasmInstance.exports.main();\n";
    
    FJSRuntime *runtime = [[FJSRuntime alloc] init];
    
    FJSValue *v = [runtime evaluateScript:js];
    XCTAssert([v toInt] == 42);
    
    v = [runtime evaluateScript:@"wasmInstance.exports.foo(12)"];
    
    XCTAssert([v toInt] == 24);
    
    [runtime shutdown];
}

- (void)testWasm2 {
    
    char wasm[] = {0,97,115,109,1,0,0,0,1,133,128,128,128,0,1,96,0,1,127,3,130,128,128,128,0,1,0,4,132,128,128,128,0,1,112,0,0,5,131,128,128,128,0,1,0,1,6,129,128,128,128,0,0,7,145,128,128,128,0,2,6,109,101,109,111,114,121,2,0,4,109,97,105,110,0,0,10,139,128,128,128,0,1,133,128,128,128,0,0,65,202,0,11};
    
    int wasm_length = sizeof(wasm) / sizeof(*wasm);
    
    NSData *d = [NSData dataWithBytes:wasm length:wasm_length];
    
    
    FJSRuntime *runtime = [[FJSRuntime alloc] init];
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

- (void)testWasmArrayBuffer {
    
    char wasm[] = {0,97,115,109,1,0,0,0,1,133,128,128,128,0,1,96,0,1,127,3,130,128,128,128,0,1,0,4,132,128,128,128,0,1,112,0,0,5,131,128,128,128,0,1,0,1,6,129,128,128,128,0,0,7,145,128,128,128,0,2,6,109,101,109,111,114,121,2,0,4,109,97,105,110,0,0,10,139,128,128,128,0,1,133,128,128,128,0,0,65,202,0,11};
    
    int wasm_length = sizeof(wasm) / sizeof(*wasm);
    
    NSData *d = [NSData dataWithBytes:wasm length:wasm_length];
    
    FJSRuntime *runtime = [[FJSRuntime alloc] init];
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
    
    [runtime shutdown];
}


@end
