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

+ (id)objectPointerInFJSRuntime:(FJSRuntime*)rt {
    
    FJSPointer *p = [FJSPointer new];
    
    p->ptr = &(p->cValue.value);
    
    return [FJSValue valueWithInstance:(__bridge CFTypeRef _Nonnull)(p) inRuntime:rt];
}

+ (id)valuePointerInFJSRuntime:(FJSRuntime*)rt {
    
    FJSPointer *p = [FJSPointer new];
    
    p->ptr = &(p->cValue.value);
    
    return [FJSValue valueWithInstance:(__bridge CFTypeRef _Nonnull)(p) inRuntime:rt];
}


+ (id)pointerWithValue:(FJSValue*)v inFJSRuntime:(FJSRuntime*)rt {
    
    FJSPointer *p = [FJSPointer new];
    
    p->ptr = [v objectStorage];
    
    [p setPtrValue:v];
    
    return [FJSValue valueWithInstance:(__bridge CFTypeRef _Nonnull)(p) inRuntime:rt];
}



@end

