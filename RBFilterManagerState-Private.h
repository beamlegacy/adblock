//
//  RBFilterManagerState-Private.h
//  RadBlock
//
//  Created by Mike Pulaski on 22/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBFilterManagerState.h"

@class RBFilter;
@class RBFilterGroup;

NS_ASSUME_NONNULL_BEGIN

@interface RBFilterManagerState() <NSCopying>

- (instancetype)_initWithDefaults:(NSUserDefaults *)defaults;
- (instancetype)_initWithDefaults:(NSUserDefaults *)defaults filterGroupDirectoryURL:(NSURL *)filterGroupDirectoryURL NS_DESIGNATED_INITIALIZER;

@property(nonatomic,nullable,setter=_setNextSynchronizeDate:) NSDate *nextSynchronizeDate;
@property(nonatomic,nullable,setter=_setLastSynchronizeDate:) NSDate *lastSynchronizeDate;
@property(nonatomic,nullable,setter=_setLastSynchronizeAttemptDate:) NSDate *lastSynchronizeAttemptDate;

@property(nonatomic,setter=_setNumberOfFailuresSinceLastSynchronize:) NSUInteger numberOfFailuresSinceLastSynchronize;

@property(nonatomic,setter=_setFilters:) NSArray<RBFilter*> *filters;

// Non-persistent (exposed for testing)
@property(nonatomic,setter=_setCooldownInterval:) NSTimeInterval _cooldownInterval;
@property(nonatomic,setter=_setMaxCooldownInterval:) NSTimeInterval _maxCooldownInterval;

- (void)_waitUntilSynchronized;

@end

NS_ASSUME_NONNULL_END
