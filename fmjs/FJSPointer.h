//
//  FJSPointer.h
//  FMJS
//
//  Created by August Mueller on 5/16/19.
//  Copyright © 2019 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FJSValue;

@interface FJSPointer : NSObject {
    @public
    void *ptr;
}

@property (weak) FJSValue *ptrValue;

@end
