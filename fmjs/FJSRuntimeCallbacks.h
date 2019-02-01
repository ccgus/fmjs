//
//  FJSRuntime.h
//  fmjs
//
//  Created by August Mueller on 8/20/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FJSRuntime.h"

@interface FJSRuntime (JSCallbacks)

- (void)setupJSCallbacks;

- (JSValueRef)convertObject:(FJSValue*)valueObject toType:(JSType)type exception:(JSValueRef*)outException;
- (JSValueRef)invokeFunction:(FJSValue*)function onObject:(FJSValue*)object withArguments:(NSArray*)args exception:(JSValueRef *)outException;

- (BOOL)setValue:(FJSValue*)arg forProperty:(NSString*)propertyName inObject:(FJSValue*)object exception:(JSValueRef*)outException;
- (JSValueRef)getProperty:(NSString*)propertyName inObject:(FJSValue*)object exception:(JSValueRef *)outException;
- (BOOL)object:(FJSValue*)object hasProperty:(NSString *)propertyName;

@end
