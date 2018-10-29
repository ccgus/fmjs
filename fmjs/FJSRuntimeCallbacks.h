//
//  FJSRuntime.h
//  fmjs
//
//  Created by August Mueller on 8/20/18.
//  Copyright © 2018 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FJSRuntime.h"


NS_ASSUME_NONNULL_BEGIN

@interface FJSRuntime (JSCallbacks)

- (void)setupJSCallbacks;

- (JSValueRef)convertObject:(FJSValue*)valueObject toType:(JSType)type exception:(JSValueRef*)exception;
- (JSValueRef)callAsFunction:(FJSValue*)functionToCall onObject:(FJSValue*)objectToCall withArguments:(NSArray*)args exception:(JSValueRef *)exception;
- (BOOL)setValue:(FJSValue*)arg forProperty:(NSString*)propertyName inObject:(FJSValue*)object exception:(JSValueRef*)exception;
- (JSValueRef)getPropertyNamed:(NSString*)propertyName inObject:(FJSValue*)valueFromJSObject exception:(JSValueRef *)exception;
- (BOOL)objectRef:(FJSValue*)objectValue hasProperty:(NSString *)propertyName;



@end

NS_ASSUME_NONNULL_END
