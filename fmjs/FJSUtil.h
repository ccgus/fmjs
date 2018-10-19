//
//  FJSUtil.h
//  yd
//
//  Created by August Mueller on 9/13/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@import JavaScriptCore;

BOOL FJSCharEquals(const char *__s1, const char *__s2);
BOOL FJSStringIsNumber(NSString *s);

NSString *FJSStructNameFromRuntimeType(NSString *runtimeType);

id FJSNativeObjectFromJSValue(JSValueRef jsValue, NSString *typeEncoding, JSContextRef context);
JSValueRef FJSNativeObjectToJSValue(id o, JSContextRef context);

void *FJSCallAddressForBlock(id block);
const char *FJSTypeEncodingForBlock(id theBlock);

BOOL FJSGetSizeOfTypeEncoding(size_t *sizePtr, char encoding);

