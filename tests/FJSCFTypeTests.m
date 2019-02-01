//
//  FJSCFTypeTests.m
//  FMJSTests
//
//  Created by August Mueller on 1/31/19.
//  Copyright © 2019 Flying Meat Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FJSFFI.h"
#import "FJSSymbol.h"
#import "FJSPrivate.h"
#import <fmjs/FJS.h>
#import <dlfcn.h>

@import CoreImage.CIContext;

extern int FJSTestCGImageRefExampleCounter;

@interface FJSValue (PrivateTestThings)
+ (size_t)countOfLiveInstances;
+ (NSPointerArray*)liveInstancesPointerArray;
@end

@interface FJSCFTypeTests : XCTestCase

@end

@implementation FJSCFTypeTests


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

// <cftype gettypeid_func='CFStringGetTypeID' name='CFStringRef' tollfree='__NSCFString' type='^{__CFString=}'/>

- (void)testCFString1Symbol {
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    FJSSymbol *stringRefSymbol = [FJSSymbol symbolForName:@"CFStringRef"];
    
    XCTAssert(stringRefSymbol);
    XCTAssert([stringRefSymbol isCFType]);
    
    
    FJSSymbol *imageRefSymbol = [FJSSymbol symbolForName:@"CGImageRef"];
    
    XCTAssert(imageRefSymbol);
    XCTAssert([imageRefSymbol isCFType]);
    
    XCTAssert(imageRefSymbol == [FJSSymbol symbolForCFType:@"^{CGImage=}"]);
    XCTAssert(stringRefSymbol == [FJSSymbol symbolForCFType:@"^{CFString=}"]);

    
    XCTAssert(imageRefSymbol == [FJSSymbol symbolForCFType:@"^{__CGImage=}"]);
    XCTAssert(stringRefSymbol == [FJSSymbol symbolForCFType:@"^{__CFString=}"]);

    
    // '^{CFStringTokenizer=}'
    
    
    [runtime shutdown];
    
}

- (void)testCGImageRefExample {
    
    int countStart = FJSTestCGImageRefExampleCounter;
    
    NSString *code = @"\
    var url = NSURL.fileURLWithPath_('/Library/Desktop Pictures/Yosemite.jpg');\n\
    var img = CIImage.imageWithContentsOfURL_(url)\n\
    var ctx = CIContext.new();\n\
    var cgimg = ctx.createCGImage_fromRect_(img, CGRectMake(0, 0, 400, 400));\n\
    FJSTestClass.testCGImageIs400x400_(cgimg);\n\
    url = null; img = null; ctx = null; cgimg = null;";
    
    FJSRuntime *runtime = [FJSRuntime new];
    [runtime evaluateScript:code];
    
    XCTAssert(FJSTestCGImageRefExampleCounter = countStart + 1);
    
    
    [runtime shutdown];
    
}



- (void)testCGImageSourceThumb {
    
    int countStart = FJSTestCGImageRefExampleCounter;
    
    NSString *code = @"\
    var url = NSURL.fileURLWithPath_('/Library/Desktop Pictures/Yosemite.jpg');\n\
    var imgSrc = CGImageSourceCreateWithURL(url, null)\n\
    var thumb = CGImageSourceCreateThumbnailAtIndex(imgSrc, 0, {kCGImageSourceCreateThumbnailFromImageIfAbsent: false});\n\
    FJSTestClass.checkImageIsGood(thumb);\n\
    print('Got thumb: ' + thumb);\n\
    \n\
    // This one doesn't have a thumb.\n\
    var url = NSURL.fileURLWithPath_('/Library/Desktop Pictures/Reflection 1.jpg');\n\
    imgSrc = CGImageSourceCreateWithURL(url, null)\n\
    thumb = CGImageSourceCreateThumbnailAtIndex(imgSrc, 0, {kCGImageSourceCreateThumbnailFromImageIfAbsent: false});\n\
    FJSTestClass.checkImageIsGood(thumb);\n\
    print('Got thumb: ' + thumb);";
    
    [FJSRuntime loadFrameworkAtPath:@"/System/Library/Frameworks/ImageIO.framework"];
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        NSLog(@"exception: %@", exception);
        XCTAssert(NO);
    }];
    
    __block NSString *lastPrintedString;
    [runtime setPrintHandler:^(FJSRuntime * _Nonnull rt, NSString * _Nonnull stringToPrint) {
        debug(@"printedString: '%@'", stringToPrint);
        lastPrintedString = stringToPrint;
    }];
    
    [runtime evaluateScript:code];
    
    XCTAssert(FJSTestCGImageRefExampleCounter = countStart + 1);
    
    XCTAssert([lastPrintedString isEqualToString:@"Got thumb: null"]);
    
    XCTAssert([[runtime evaluateScript:@"thumb == null;"] toBOOL]);
    
    [runtime evaluateScript:@"url = null; imgSrc = null; thumb = null;"];
    
    
    [runtime shutdown];
    
}

- (void)testNullCGImage {
    
    NSString *code = @"\
    var img = CGImageCreateCopy(null);\n\
    print('img ' + img);";
    
    [FJSRuntime loadFrameworkAtPath:@"/System/Library/Frameworks/ImageIO.framework"];
    
    FJSRuntime *runtime = [FJSRuntime new];
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        NSLog(@"exception: %@", exception);
        XCTAssert(NO);
    }];
    
    __block NSString *passedString;
    
    [runtime setPrintHandler:^(FJSRuntime * _Nonnull rt, NSString * _Nonnull stringToPrint) {
        debug(@"printedString: '%@'", stringToPrint);
        passedString = stringToPrint;
    }];
    
    [runtime evaluateScript:code];
    
    XCTAssert([[runtime evaluateScript:@"img == null;"] toBOOL]);
    
    XCTAssert([passedString isEqualToString:@"img null"]);
    
    [runtime evaluateScript:@"img = null;"];
    [runtime shutdown];
}

- (void)testNullCGImageCI {
    
    //- (nullable CGImageRef)createCGImage:(CIImage *)image fromRect:(CGRect)fromRect

    
    FJSRuntime *runtime = [FJSRuntime new];
    
    [runtime setExceptionHandler:^(FJSRuntime * _Nonnull rt, NSException * _Nonnull exception) {
        NSLog(@"exception: %@", exception);
        XCTAssert(NO);
    }];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    CGImageRef r = [[CIContext new] createCGImage:nil fromRect:CGRectMake(0, 0, 1, 1)];
    assert(!r);
#pragma clang diagnostic pop
    
    [runtime evaluateScript:@"var context = CIContext.alloc().init();\n"];
    XCTAssert([[runtime evaluateScript:@"context != null;"] toBOOL]);

    [runtime evaluateScript:@"var img = context.createCGImage_fromRect(null, CGRectMake(0, 0, 1, 1));\n"];
    
    XCTAssert([[runtime evaluateScript:@"img == null;"] toBOOL]);
    
    [runtime evaluateScript:@"context = null; img = null;"];
    [runtime shutdown];
    
}

@end
