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

- (FJSValue*)toTypedArray:(JSTypedArrayType)type inFJSRuntime:(FJSRuntime*)runtime;
- (FJSValue*)toTypedArrayNoCopy:(JSTypedArrayType)type inFJSRuntime:(FJSRuntime*)runtime;

+ (FJSValue*)dataFromTypedArray:(FJSValue*)array inFJSRuntime:(FJSRuntime*)runtime;
+ (JSTypedArrayType)JSTypedArrayTypeFromTypedArrayName:(NSString*)name;

@end
