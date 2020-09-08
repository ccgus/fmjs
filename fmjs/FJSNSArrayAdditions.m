//
//  FJSNSArrayAdditions.m
//  fmjs
//

#import "FJSNSDataAdditions.h"
#import "FJS.h"
#import "FJSSymbol.h"

@implementation NSArray (FJSNSArrayAdditions)


- (void)forEach:(FJSValue*)callbackFunction inFJSRuntime:(FJSRuntime*)runtime {
    
    [self enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [callbackFunction callWithArguments:@[obj, @(idx), self]];
    }];
}

// This should never be called, as it's handled in the runtime's - (JSValueRef)getProperty:inObject:exception:
// But, we still want to define it, so that the runtime lookup will know it's there.
- (NSUInteger)length {
    FMAssert(NO);
    return [self count];
}

@end
