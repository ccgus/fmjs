//
//  FJSFFI.h
//  yd
//
//  Created by August Mueller on 8/22/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ffi/ffi.h>

@class FJSValue;
@class FJSRuntime;

NS_ASSUME_NONNULL_BEGIN

@interface FJSFFI : NSObject

+ (instancetype)ffiWithFunction:(FJSValue*)f caller:(nullable FJSValue*)caller arguments:(NSArray*)args runtime:(FJSRuntime*)runtime;

- (nullable FJSValue*)callFunction;

+ (nullable ffi_type *)ffiTypeAddressForTypeEncoding:(char)encoding;
+ (nullable ffi_type *)ffiTypeForStructure:(NSString*)structEncoding;
+ (void)describeFFIType:(ffi_type*)type;
+ (size_t)countOfElementsInType:(ffi_type*)type;

@end

/*
@interface FJSFFIStruct : NSObject {
    NSMutableArray *_elements;
}

- (int)countOfElements;
- (NSArray*)elements;
- (void)addElement:(id)element; // either a string for a simple type, or a FJSFFIStruct for a complex one.

@end
*/




NS_ASSUME_NONNULL_END
