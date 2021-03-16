//
//  RBSynchronizeInterval.h
//  RadBlock
//
//  Created by Mike Pulaski on 22/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(FilterManager.SynchronizeInterval)
typedef NS_ENUM(int, RBSynchronizeInterval) {
    RBSynchronizeIntervalDisabled,
    RBSynchronizeIntervalDaily,
    RBSynchronizeIntervalBiWeekly,
    RBSynchronizeIntervalWeekly,
    RBSynchronizeIntervalMonthly
};

extern NSString* NSStringFromRBSynchronizeInterval(RBSynchronizeInterval v);
extern RBSynchronizeInterval RBSynchronizeIntervalFromNSString(NSString *__nullable v);

extern NSDateComponents*__nullable NSDateComponentsFromRBSynchronizeInterval(RBSynchronizeInterval v);

NS_ASSUME_NONNULL_END
