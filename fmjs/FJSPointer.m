//
//  FJSPointer.m
//  FMJS
//
//  Created by August Mueller on 5/16/19.
//  Copyright © 2019 Flying Meat Inc. All rights reserved.
//

#import "FJSPointer.h"
#import "FJS.h"
#import "FJSPrivate.h"

@implementation FJSPointer

+ (id)pointerWithValue:(FJSValue*)v inFJSRuntime:(FJSRuntime*)rt {
    
    FJSPointer *p = [FJSPointer new];
    
    p->ptr = [v pointer];
    
    [p setPtrValue:v];
    
    //CGRect *rect = (CGRect*)p->value;
    //debug(@"r: %@", NSStringFromRect(*((CGRect*)p->value)));
    
    return [FJSValue valueWithInstance:(__bridge CFTypeRef _Nonnull)(p) inRuntime:rt];
}

@end

