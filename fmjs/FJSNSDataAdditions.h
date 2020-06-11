//
//  FJSNSDataAdditions.h
//  fmjs
//
//  Created by August Mueller on 4/30/19.
//  Copyright © 2019 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FJSRuntime.h"

@interface NSData (FJSNSDataAdditions)

// These are to be used from outside the runtime.
- (FJSValue*)toTypedArray:(JSTypedArrayType)type runtime:(FJSRuntime*)runtime;
- (FJSValue*)toTypedArrayNoCopy:(JSTypedArrayType)type runtime:(FJSRuntime*)runtime;


+ (FJSValue*)dataFromTypedArray:(FJSValue*)array inFJSRuntime:(FJSRuntime*)runtime;
+ (JSTypedArrayType)JSTypedArrayTypeFromTypedArrayName:(NSString*)name;
+ (NSString*)FJSTypedArrayNameNameFromJSTypedArray:(JSTypedArrayType)type;

@end
