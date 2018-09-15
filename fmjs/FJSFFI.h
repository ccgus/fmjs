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

+ (instancetype)ffiWithFunction:(FJSValue*)f caller:(nullable FJSValue*)caller arguments:(NSArray*)args cos:(FJSRuntime*)cos;

- (nullable FJSValue*)callFunction;

+ (ffi_type *)ffiTypeAddressForTypeEncoding:(char)encoding;

@end

NS_ASSUME_NONNULL_END
