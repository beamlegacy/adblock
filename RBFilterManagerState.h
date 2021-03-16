//
//  RBFilterManagerState.h
//  RadBlock
//
//  Created by Mike Pulaski on 22/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RBSynchronizeInterval.h"

NS_ASSUME_NONNULL_BEGIN

@class RBFilter;
@class RBFilterGroup;
@class RBAdsFilterGroup;
@class RBRegionalFilterGroup;
@class RBPrivacyFilterGroup;
@class RBAnnoyanceFilterGroup;


NS_SWIFT_NAME(FilterManager.State)

@interface RBFilterManagerState : NSObject
@property(class,readonly) RBFilterManagerState* sharedState;

- (instancetype)init NS_UNAVAILABLE;

// State
@property(nonatomic) RBSynchronizeInterval synchronizeInterval;
@property(nonatomic,readonly) NSUInteger numberOfFailuresSinceLastSynchronize;
@property(nonatomic,readonly,nullable) NSDate *nextSynchronizeDate;
@property(nonatomic,readonly,nullable) NSDate *lastSynchronizeDate;
@property(nonatomic,readonly,nullable) NSDate *lastSynchronizeAttemptDate;
@property(nonatomic,getter=isDisabled) BOOL disabled;

// Filters / groups
@property(nonatomic,readonly) NSArray<RBFilter*> *filters;
@property(nonatomic,readonly) NSArray<RBFilterGroup *> *filterGroups;

@property(nonatomic,readonly) RBAdsFilterGroup *adsFilterGroup;
@property(nonatomic,readonly) RBRegionalFilterGroup *regionalFilterGroup;
@property(nonatomic,readonly) RBPrivacyFilterGroup *privacyFilterGroup;
@property(nonatomic,readonly) RBAnnoyanceFilterGroup *annoyanceFilterGroup;

@end

NS_ASSUME_NONNULL_END
