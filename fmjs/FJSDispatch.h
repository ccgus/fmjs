//
//  FJSDispatch.h
//  FMJS
//
//  Created by August Mueller on 2/27/20.
//  Copyright © 2020 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FJSDispatch : NSObject

@end

void FJSDispatchSyncOnMainThread(void (^block)(void));
void FJSDispatchAsyncOnMainThread(void (^block)(void));

NS_ASSUME_NONNULL_END
