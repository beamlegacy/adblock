//
//  RBFilterManagerStateTests.m
//  RadBlockTests
//
//  Created by Mike Pulaski on 23/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RBFilterManagerState-Private.h"
#import "RBFilter+Mock.h"
#import "RBFilterGroup.h"
#import "RBUtils.h"
#import "RBDatabase-Private.h"


@interface RBFilterManagerStateTests : XCTestCase

@end


@implementation RBFilterManagerStateTests {
    RBFilterManagerState *_state;
}

- (void)setUp {
    self.continueAfterFailure = NO;
    
    NSString *suiteName = self.className;
    NSURL *tempDirectoryURL = RBCreateTemporaryDirectory(NULL);
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
    
    _state = [[RBFilterManagerState alloc] _initWithDefaults:defaults filterGroupDirectoryURL:[tempDirectoryURL URLByAppendingPathComponent:@"groups" isDirectory:YES]];

    [self addTeardownBlock:^{
        [[NSFileManager defaultManager] removeItemAtURL:tempDirectoryURL error:NULL];
        [[[NSUserDefaults alloc] init] removePersistentDomainForName:suiteName];
//        self->_state = nil;
    }];
}

- (void)testSynchronizeIntervals {
    XCTAssertEqual(_state.synchronizeInterval, RBSynchronizeIntervalWeekly);
    
    RBSynchronizeInterval intervals[] = {
        RBSynchronizeIntervalDisabled,
        RBSynchronizeIntervalDaily,
        RBSynchronizeIntervalBiWeekly,
        RBSynchronizeIntervalWeekly,
        RBSynchronizeIntervalMonthly,
        -1
    };
    
    for (int i = 0; intervals[i] != -1; i++) {
        RBSynchronizeInterval interval = intervals[i];
        _state.synchronizeInterval = interval;
        XCTAssertEqual(interval, _state.synchronizeInterval);
    }
}

- (void)testNextSynchronizeDateIntervals {
    XCTAssertNotNil(_state.nextSynchronizeDate);
    XCTAssertLessThanOrEqual([_state.nextSynchronizeDate timeIntervalSinceNow], 0);
    
    _state.lastSynchronizeAttemptDate = [NSDate date];
    _state.lastSynchronizeDate = [NSDate date];

    NSDictionary *intervalDict = @{
        @(RBSynchronizeIntervalDisabled): @(-1),
        @(RBSynchronizeIntervalDaily): @(60*60*24),
        @(RBSynchronizeIntervalBiWeekly): @(60*60*24*3.5),
        @(RBSynchronizeIntervalWeekly): @(60*60*24*7),
        @(RBSynchronizeIntervalMonthly): @(60*60*24*28),
    };
    
    for (NSNumber *intervalNum in intervalDict) {
        _state.synchronizeInterval = [intervalNum intValue];

        NSTimeInterval timeInterval = [intervalDict[intervalNum] doubleValue];
        
        if (timeInterval == -1) {
            XCTAssertNil(_state.nextSynchronizeDate);
        } else {
            NSTimeInterval actualTimeInterval = [_state.nextSynchronizeDate timeIntervalSinceDate:_state.lastSynchronizeDate];
            
            if (_state.synchronizeInterval == RBSynchronizeIntervalMonthly) {
                NSTimeInterval actualDays = actualTimeInterval / (60*60*24);
                XCTAssertTrue(actualDays >= 28 && actualDays < 32, @"%f", actualDays);
            } else {
                XCTAssertGreaterThanOrEqual(actualTimeInterval, 0.99 * timeInterval, @"%@ %@", NSStringFromRBSynchronizeInterval([intervalNum intValue]), _state.nextSynchronizeDate);
                XCTAssertLessThanOrEqual(actualTimeInterval, 1.01 * timeInterval, @"%@ %@", NSStringFromRBSynchronizeInterval([intervalNum intValue]), _state.nextSynchronizeDate);
            }
        }
    }
}

- (void)testNextSynchronizeDateCooldown {
    _state._cooldownInterval = 500;
    _state.lastSynchronizeAttemptDate = [NSDate date];
    
    for (int i = 1; i < 5; i++) {
        _state.numberOfFailuresSinceLastSynchronize = i;
        XCTAssertEqual([_state.nextSynchronizeDate timeIntervalSinceDate:_state.lastSynchronizeAttemptDate], i * _state._cooldownInterval);
    }
    
    _state.synchronizeInterval = RBSynchronizeIntervalDisabled;
    XCTAssertNil(_state.nextSynchronizeDate);
}

- (void)testFilterGroupPersistence {
    _state.filters = [RBFilter mockFilters:5];
    _state.synchronizeInterval = RBSynchronizeIntervalMonthly;
    _state.privacyFilterGroup.socialMediaFilterEnabled = YES;
    _state.annoyanceFilterGroup.cookiesFilterEnabled = YES;

    [_state _waitUntilSynchronized];
    
    RBFilterManagerState *otherState = [_state copy];
    XCTAssertTrue([otherState.filters isEqualToArray:_state.filters]);
    XCTAssertEqual(otherState.synchronizeInterval, _state.synchronizeInterval);
    XCTAssertEqual(otherState.privacyFilterGroup.isSocialMediaFilterEnabled, _state.privacyFilterGroup.isSocialMediaFilterEnabled);
    XCTAssertEqual(otherState.annoyanceFilterGroup.isCookiesFilterEnabled, _state.annoyanceFilterGroup.isCookiesFilterEnabled);
}

static NSArray *_defaultsValueArgs(id value) {
    if (value == nil) {
        return @[];
    }
    
    if ([value isKindOfClass:[NSString class]]) {
        return @[value];
    } else if ([value isKindOfClass:[NSNumber class]]) {
        return @[@"-int", [(NSNumber*)value stringValue]];
    } else if ([value isKindOfClass:[NSDate class]]) {
        NSDateFormatter *fmt = [NSDateFormatter new];
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        fmt.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        fmt.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        return @[@"-date", [fmt stringFromDate:value]];
    } else if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableArray *res = [NSMutableArray arrayWithObject:@"-dict"];
        [(NSDictionary*)value enumerateKeysAndObjectsUsingBlock:^(id dictKey, id dictValue, BOOL *stop) {
            [res addObject:dictKey];
            [res addObjectsFromArray:_defaultsValueArgs(dictValue)];
        }];
        return [res copy];
    } else if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *res = [NSMutableArray arrayWithObject:@"-array"];
        for (id curValue in (NSArray *)value) {
            [res addObjectsFromArray:_defaultsValueArgs(curValue)];
        }
        return [res copy];
    }
    
    return @[];
}

@end
