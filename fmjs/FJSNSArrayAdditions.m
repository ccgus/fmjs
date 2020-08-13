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

- (NSUInteger)length {
    return [self count];
}

@end
