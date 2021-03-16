//
//  RBSynchronizeInterval.m
//  RadBlock
//
//  Created by Mike Pulaski on 22/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBSynchronizeInterval.h"
#import "RBUtils.h"

NSString* NSStringFromRBSynchronizeInterval(RBSynchronizeInterval v) {
    switch (v) {
        case RBSynchronizeIntervalDisabled:
            return @"disabled";
        case RBSynchronizeIntervalDaily:
            return @"daily";
        case RBSynchronizeIntervalBiWeekly:
            return @"biweekly";
        case RBSynchronizeIntervalWeekly:
            return @"weekly";
        case RBSynchronizeIntervalMonthly:
            return @"monthly";
        default:
            return @"unknown";
    }
}

RBSynchronizeInterval RBSynchronizeIntervalFromNSString(NSString *v) {
    v = v ?: @"";
    
    if ([v isEqualToString:@"daily"]) {
        return RBSynchronizeIntervalDaily;
    } else if ([v isEqualToString:@"biweekly"]) {
        return RBSynchronizeIntervalBiWeekly;
    } else if ([v isEqualToString:@"weekly"]) {
        return RBSynchronizeIntervalWeekly;
    } else if ([v isEqualToString:@"monthly"]) {
        return RBSynchronizeIntervalMonthly;
    } else {
        return RBSynchronizeIntervalDisabled;
    }
}

NSDateComponents* NSDateComponentsFromRBSynchronizeInterval(RBSynchronizeInterval v) {
    NSDateComponents *dateComponents = [NSDateComponents new];
    
    if (RBIsDateDurationFake) {
        switch (v) {
            case RBSynchronizeIntervalDaily:
                dateComponents.minute = 1;
                break;
            case RBSynchronizeIntervalBiWeekly:
                dateComponents.minute = 5;
                break;
            case RBSynchronizeIntervalWeekly:
                dateComponents.minute = 15;
                break;
            case RBSynchronizeIntervalMonthly:
                dateComponents.minute = 60;
                break;
            default:
                return nil;
        }
    } else {
        switch (v) {
            case RBSynchronizeIntervalDaily:
                dateComponents.day = 1;
                break;
            case RBSynchronizeIntervalBiWeekly:
                dateComponents.day = 3;
                dateComponents.hour = 12;
                break;
            case RBSynchronizeIntervalWeekly:
                dateComponents.day = 7;
                break;
            case RBSynchronizeIntervalMonthly:
                dateComponents.month = 1;
                break;
            default:
                return nil;
        }
    }
    
    return dateComponents;
}
