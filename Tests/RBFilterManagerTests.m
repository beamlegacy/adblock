//
//  RBFilterManagerTests.m
//  RadBlockTests
//
//  Created by Mikey on 18/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <CloudKit/CloudKit.h>

#import "RBFilterManager-Private.h"
#import "RBFilterManagerState-Private.h"
#import "RBMockClient.h"
#import "RBFilter+Mock.h"
#import "RBFilterGroup.h"
#import "RBUtils.h"
#import "RBDigest.h"
#import "RBDatabase-Private.h"


@interface RBFilterManagerTests : XCTestCase
@end


@interface RBFilterManager(Tests)
@property(nonatomic,readonly) NSArray<NSURL*> *filterRuleURLs;
@end


@implementation RBFilterManagerTests {
    NSURL *_tempDirectoryURL;
    RBFilterManager *_manager;
    RBMockClient *_mockClient;
}

- (void)setUp {
    [super setUp];
    
    self.continueAfterFailure = NO;
    
    _tempDirectoryURL = RBCreateTemporaryDirectory(NULL);
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:NSStringFromClass(self.class)];
    RBFilterManagerState *state = [[RBFilterManagerState alloc] _initWithDefaults:defaults filterGroupDirectoryURL:[_tempDirectoryURL URLByAppendingPathComponent:@"groups" isDirectory:YES]];
    
    _mockClient = [[RBMockClient alloc] init];
    _manager = [[RBFilterManager alloc] _initWithState:state client:_mockClient filterRulesDirectoryURL:[_tempDirectoryURL URLByAppendingPathComponent:@"rules" isDirectory:YES]];
    _manager.state.synchronizeInterval = RBSynchronizeIntervalDisabled;
}

- (void)tearDown {
    [_manager.state _waitUntilSynchronized];

    [[NSFileManager defaultManager] removeItemAtURL:_tempDirectoryURL error:NULL];
    [[NSUserDefaults new] removePersistentDomainForName:NSStringFromClass(self.class)];
    
    [_mockClient invalidate];
    _mockClient = nil;

    _manager = nil;
}

- (void)testSynchronizeMissingRules {
    NSArray<RBFilter*> *filters = [RBFilter standardMockFilters:3];
    _manager.state.filters = filters;
    
    _manager.state.filters = filters;
    [_mockClient mockFilters:[@[[filters.firstObject copyOutOfSync]] arrayByAddingObjectsFromArray:[filters subarrayWithRange:NSMakeRange(1, 2)]]];
    
    XCTestExpectation *sync = [self expectationWithDescription:@"sync"];
    [_manager synchronizeWithOptions:0 completionHandler:^(NSError *err) {
        XCTAssertNil(err);
        [sync fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
    
    XCTAssertEqual(_manager.filterRuleURLs.count, filters.count);
}

// TODO disabled for first iteration
//- (void)testSynchronizeFilters {
//    NSArray *filters = [RBFilter standardMockFilters:15];
//    [_mockClient mockFilters:filters];
//
//    XCTestExpectation *sync = [self expectationWithDescription:@"sync"];
//    [_manager synchronizeWithOptions:0 completionHandler:^(NSError *err) {
//        XCTAssertNil(err, @"%@", err);
//        [sync fulfill];
//    }];
//    [self waitForExpectationsWithTimeout:1 handler:nil];
//
//    XCTAssertTrue([[NSSet setWithArray:_manager.state.filters] isEqualToSet:[NSSet setWithArray:filters]]);
//
//    for (RBFilter *filter in filters) {
//        NSURL *filterURL = [_manager._filterRulesDirectoryURL URLByAppendingPathComponent:filter.uniqueIdentifier];
//        XCTAssertEqualObjects([RBDigest MD5HashOfFileURL:filterURL error:nil], filter.md5);
//    }
//}

- (void)testSynchronizeRuleChange {
    NSArray *filters = [RBFilter standardMockFilters:15];
    [_mockClient mockFilters:filters];
    
    RBRegionalFilterGroup *regionalGroup = _manager.state.regionalFilterGroup;
    _manager.state.regionalFilterGroup.languageCodes = @[@"fr"];
    
    XCTestExpectation *sync = [self expectationWithDescription:@"sync"];
    [_manager synchronizeWithOptions:0 completionHandler:^(NSError *err) {
        XCTAssertNil(err, @"%@", err);
        
        NSUInteger regionalCount = regionalGroup.numberOfRules;
        XCTAssertGreaterThan(regionalCount, 0);
        
        regionalGroup.languageCodes = @[];
        
        [self->_manager synchronizeWithOptions:0 completionHandler:^(NSError *err) {
            XCTAssertNil(err, @"%@", err);
            XCTAssertLessThan(regionalGroup.numberOfRules, regionalCount);
            
            [sync fulfill];
        }];
        
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

// TODO disabled for first iteration
//- (void)testSynchronizeGroupAttributes {
//    NSArray *filters = [RBFilter standardMockFilters:20];
//    [_mockClient mockFilters:filters];
//
//    XCTestExpectation *initialSync = [self expectationWithDescription:@"sync"];
//    [_manager synchronizeWithOptions:0 completionHandler:^(NSError *err) {
//        XCTAssertNil(err, @"%@", err);
//        [initialSync fulfill];
//    }];
//    [self waitForExpectationsWithTimeout:1 handler:nil];
//
//    XCTAssertTrue([[NSSet setWithArray:_manager.state.filters] isEqualToSet:[NSSet setWithArray:filters]]);
//
//    NSMutableDictionary *initialModificationDates = [NSMutableDictionary dictionary];
//
//    for (RBFilterGroup *group in _manager.state.filterGroups) {
//        XCTAssertNotNil(group.lastModificationDate);
//        XCTAssertNotNil(group.lastBuildDate);
//        XCTAssertNotEqual([group.lastBuildDate compare:group.lastModificationDate], NSOrderedAscending);
//        XCTAssertGreaterThanOrEqual(group.numberOfRules, 5);
//
//        initialModificationDates[group.name] = group.lastModificationDate;
//    }
//
//    // Mock an update
//    RBFilter *outOfSyncRemoteFilter = [filters.firstObject copyOutOfSync];
//    [_mockClient mockFilters:[@[outOfSyncRemoteFilter] arrayByAddingObjectsFromArray:[filters subarrayWithRange:NSMakeRange(1, 19)]]];
//
//    XCTestExpectation *sync = [self expectationWithDescription:@"sync"];
//    [_manager synchronizeWithOptions:0 completionHandler:^(NSError *err) {
//        XCTAssertNil(err, @"%@", err);
//        [sync fulfill];
//    }];
//    [self waitForExpectationsWithTimeout:1 handler:nil];
//
//    for (RBFilterGroup *group in _manager.state.filterGroups) {
//        XCTAssertNotNil(group.lastModificationDate);
//        XCTAssertNotNil(group.lastBuildDate);
//        XCTAssertNotEqual([group.lastBuildDate compare:group.lastModificationDate], NSOrderedAscending);
//        XCTAssertGreaterThanOrEqual(group.numberOfRules, 5);
//
//        NSDate *initialModificationDate = initialModificationDates[group.name];
//        if ([group.name isEqualToString:outOfSyncRemoteFilter.group]) {
//            XCTAssertEqual([group.lastModificationDate compare:initialModificationDate], NSOrderedDescending);
//        } else {
//            XCTAssertEqualObjects(group.lastModificationDate, initialModificationDate);
//        }
//    }
//}

- (void)testSynchronizeBadHashError {
    [_mockClient mockFilters:@[[[RBFilter mockFilter] copyByMergingPropertyList:@{@"md5":@"badhash"}]]];
    
    XCTestExpectation *sync = [self expectationWithDescription:@"sync"];
    [_manager synchronizeWithOptions:0 completionHandler:^(NSError *err) {
        XCTAssertNotNil(err);
        [sync fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNil(_manager.state.lastSynchronizeDate);
    XCTAssertEqual(_manager.filterRuleURLs.count, 0);
}

- (void)testSynchronizeOldFilterRemoval {
    NSArray *filters = [RBFilter standardMockFilters:2];
    [_mockClient mockFilters:filters];
    
    XCTestExpectation *sync = [self expectationWithDescription:@"sync"];
    [_manager synchronizeWithOptions:0 completionHandler:^(NSError *err) {
        XCTAssertNil(err, @"%@", err);
        [sync fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqual(_manager.filterRuleURLs.count, filters.count);
    
    [_mockClient mockFilters:[filters subarrayWithRange:NSMakeRange(0, 1)]];
    
    XCTestExpectation *resync = [self expectationWithDescription:@"resync"];
    [_manager synchronizeWithOptions:0 completionHandler:^(NSError *err) {
        XCTAssertNil(err, @"%@", err);
        [resync fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertEqual(_manager.filterRuleURLs.count, 1);
}

// TODO disabled for first iteration
//- (void)testSynchronizePartial {
//    NSArray *filters = [RBFilter standardMockFilters:20];
//    [_mockClient mockFilters:filters];
//
//    // Initial sync
//    XCTestExpectation *sync = [self expectationWithDescription:@"sync"];
//    [_manager synchronizeWithOptions:0 completionHandler:^(NSError *err) {
//        XCTAssertNil(err, @"%@", err);
//        [sync fulfill];
//    }];
//    [self waitForExpectationsWithTimeout:1 handler:nil];
//
//    NSDate *lastSynchronizeDate = _manager.state.lastSynchronizeDate;
//    XCTAssertNotNil(lastSynchronizeDate);
//
//    NSMutableDictionary *initialModificationDates = [NSMutableDictionary dictionary];
//
//    for (RBFilterGroup *group in _manager.state.filterGroups) {
//        XCTAssertNotNil(group.lastModificationDate);
//        XCTAssertNotNil(group.lastBuildDate);
//        XCTAssertNotEqual([group.lastBuildDate compare:group.lastModificationDate], NSOrderedAscending);
//        XCTAssertGreaterThanOrEqual(group.numberOfRules, 5);
//
//        initialModificationDates[group.name] = group.lastModificationDate;
//    }
//
//    // Force synchronize to fail partially
//    RBFilter *badFilter = filters.firstObject;
//    NSError *mockError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSCoderInvalidValueError userInfo:nil];
//
//    [_mockClient mockFilters:[@[badFilter] arrayByAddingObjectsFromArray:[filters subarrayWithRange:NSMakeRange(1, filters.count-1)]]];
//    [_mockClient mockError:mockError forFilter:badFilter];
//
//    XCTestExpectation *secondSync = [self expectationWithDescription:@"second sync"];
//    XCTestExpectation *errorExp = [self expectationWithDescription:@"error"];
//
//    [_manager synchronizeWithOptions:0 errorHandler:^(RBFilterGroup *filterGroup, NSError *error, BOOL *stop) {
//        XCTAssertEqualObjects(error, mockError);
//        XCTAssertEqualObjects(badFilter.group, filterGroup.name);
//
//        [errorExp fulfill];
//    } completionHandler:^(NSError *error) {
//        XCTAssertEqualObjects(error, mockError);
//        [secondSync fulfill];
//    }];
//    [self waitForExpectationsWithTimeout:1 handler:nil];
//
//    // Make sure existing data is preserved
//    XCTAssertTrue([[NSSet setWithArray:_manager.state.filters] isEqualToSet:[NSSet setWithArray:filters]]);
//
//    for (RBFilterGroup *group in _manager.state.filterGroups) {
//        XCTAssertNotNil(group.lastModificationDate);
//        XCTAssertNotNil(group.lastBuildDate);
//        XCTAssertNotEqual([group.lastBuildDate compare:group.lastModificationDate], NSOrderedAscending);
//        XCTAssertGreaterThanOrEqual(group.numberOfRules, 5);
//        XCTAssertEqualObjects(group.lastModificationDate, initialModificationDates[group.name]);
//    }
//
//    // Last synchronize date should be the same since there were errors
//    XCTAssertEqualObjects(lastSynchronizeDate, _manager.state.lastSynchronizeDate);
//}

- (void)testSynchronizeProgress {
    NSArray *remoteFilters = [RBFilter mockFilters:1];
    [_mockClient mockFilters:remoteFilters];

    XCTestExpectation *sync = [self expectationWithDescription:@"sync"];
    NSProgress *syncProgress = [_manager synchronizeWithOptions:0 completionHandler:^(NSError *err) {
        XCTAssertNil(err, @"%@", err);
        [sync fulfill];
    }];

    [self keyValueObservingExpectationForObject:syncProgress keyPath:@"fractionCompleted" handler:^BOOL(NSProgress *progress, NSDictionary *change) {
        return progress.fractionCompleted < 1.0;
    }].assertForOverFulfill = NO;
    [self keyValueObservingExpectationForObject:syncProgress keyPath:@"fractionCompleted" expectedValue:@(1.0)];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSynchronizeCancel {
    XCTestExpectation *sync = [self expectationWithDescription:@"sync"];
    [[_manager synchronizeWithOptions:0 completionHandler:^(NSError *err) {
        XCTAssertNotNil(err);
        XCTAssertEqualObjects(err.domain, CKErrorDomain);
        XCTAssertEqual(err.code, CKErrorOperationCancelled);
        [sync fulfill];
    }] cancel];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

// TODO disabled for first iteration
//- (void)testSynchronizeConcurrency {
//    NSArray *filters = [RBFilter standardMockFilters:4];
//    [_mockClient mockFilters:filters];
//
//    XCTestExpectation *sync = [self expectationWithDescription:@"sync"];
//    sync.expectedFulfillmentCount = 4;
//    
//    [self keyValueObservingExpectationForObject:_manager keyPath:@"synchronizing" expectedValue:@(YES)].assertForOverFulfill = YES;
//    [self keyValueObservingExpectationForObject:_manager keyPath:@"synchronizing" expectedValue:@(NO)].assertForOverFulfill = YES;
//    
//    NSMutableArray *synchronizeErrors = [NSMutableArray array];
//    for (int i = 0; i < sync.expectedFulfillmentCount; i++) {
//        [_manager synchronizeWithOptions:0 completionHandler:^(NSError *error) {
//            [synchronizeErrors addObject: error ?: [NSNull null]];
//            [sync fulfill];
//        }];
//    }
//    
//    [self waitForExpectationsWithTimeout:1 handler:nil];
//    
//    NSArray *cancelErrors = [synchronizeErrors filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary<NSString *,id>*bindings) {
//        NSError *error = RBKindOfClassOrNil(NSError, obj);
//        return error != nil && [error.domain isEqualToString:CKErrorDomain] && error.code == CKErrorOperationCancelled;
//    }]];
//    
//    XCTAssertEqual(cancelErrors.count, 3, @"%@", cancelErrors);
//    XCTAssertEqual(_manager.filterRuleURLs.count, filters.count);
//    
//    for (RBFilterGroup *group in _manager.state.filterGroups) {
//        XCTAssertNotNil(group.lastModificationDate, "%@", group);
//        XCTAssertNotNil(group.lastBuildDate);
//        XCTAssertNotEqual([group.lastBuildDate compare:group.lastModificationDate], NSOrderedAscending);
//        XCTAssertGreaterThanOrEqual(group.numberOfRules, 1);
//    }
//}

- (void)testSynchronizeScheduler {
    XCTAssertNil(_manager.state.lastSynchronizeDate);
    XCTAssertNil(_manager.state.lastSynchronizeAttemptDate);
    XCTAssertNil(_manager.state.nextSynchronizeDate);

    NSArray *remoteFilters = [RBFilter standardMockFilters:5];
    [_mockClient mockFilters:remoteFilters];
    
    // Perform synchronization
    XCTestExpectation *sync = [self expectationWithDescription:@"sync"];
    [_manager synchronizeWithOptions:0 completionHandler:^(NSError *err) {
        XCTAssertNil(err, @"%@", err);
        [sync fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertNotNil(_manager.state.lastSynchronizeDate);
    XCTAssertNotNil(_manager.state.lastSynchronizeAttemptDate);
    XCTAssertNil(_manager.state.nextSynchronizeDate);
    
    _manager.state.synchronizeInterval = RBSynchronizeIntervalWeekly;
    NSDate *nextSynchronize = _manager.state.nextSynchronizeDate;
    XCTAssertNotNil(nextSynchronize);
    
    // Synchronize again
    XCTestExpectation *nextSync = [self expectationWithDescription:@"nextSync"];
    [_manager synchronizeWithOptions:0 completionHandler:^(NSError *err) {
        XCTAssertNil(err, @"%@", err);
        [nextSync fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    // Next date should be bumped up
    XCTAssertEqual([nextSynchronize compare:_manager.state.nextSynchronizeDate], NSOrderedAscending, "%@ < %@", nextSynchronize, _manager.state.nextSynchronizeDate);
}

- (void)testSynchronizeErrorCooldown {
    RBFilter *filter = [RBFilter mockFilter];
    [_mockClient mockFilters:@[filter]];
    
    NSError *unknownError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:nil];
    [_mockClient mockError:unknownError forFilter:filter];
    
    _manager.state.synchronizeInterval = RBSynchronizeIntervalDaily;
    
    // Invocations with default options should not trigger a cooldown
    NSDate *initialScheduledDate = _manager.state.nextSynchronizeDate;
    XCTAssertNotNil(initialScheduledDate);
    
    XCTestExpectation *sync = [self expectationWithDescription:@"sync"];
    [_manager synchronizeWithOptions:0 completionHandler:^(NSError *err) {
        XCTAssertNotNil(err);
        [sync fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqualObjects(initialScheduledDate, _manager.state.nextSynchronizeDate);
    XCTAssertEqual(_manager.state.numberOfFailuresSinceLastSynchronize, 0);
    
    // Trigger invocations from the scheduler and derive the cooldown values based on the next synchronization date
    NSUInteger numTries = 5;
    __block NSUInteger currentTry = 0;
    __block NSTimeInterval lastCooldown = 0;
    
    [self keyValueObservingExpectationForObject:_manager keyPath:@"synchronizing" expectedValue:@(YES)].expectedFulfillmentCount = numTries;
    [self keyValueObservingExpectationForObject:_manager keyPath:@"synchronizing" expectedValue:@(NO)].expectedFulfillmentCount = numTries;
    [self keyValueObservingExpectationForObject:_manager.state keyPath:@"numberOfFailuresSinceLastSynchronize" handler:^BOOL(RBFilterManagerState *state, NSDictionary *change) {
        NSTimeInterval currentCooldown = [state.nextSynchronizeDate timeIntervalSinceDate:state.lastSynchronizeAttemptDate];
        XCTAssertLessThanOrEqual(currentCooldown, (state._cooldownInterval * numTries));
        
        if (++currentTry >= numTries) {
            XCTAssertEqualWithAccuracy(currentCooldown, lastCooldown, 0.003);
        } else if (currentTry > 1) {
            XCTAssertGreaterThanOrEqual(currentCooldown, lastCooldown, @"try %ld", currentTry);
        }

        lastCooldown = currentCooldown;
        
        return YES;
    }].expectedFulfillmentCount = numTries;

    _manager.state._cooldownInterval = 0.001;
    _manager.state._maxCooldownInterval = _manager.state._cooldownInterval * (numTries-2);
    _manager.state.nextSynchronizeDate = [NSDate date];
    _manager.synchronizeAutomatically = YES;

    [self waitForExpectationsWithTimeout:2 handler:nil];
    
    _manager.synchronizeAutomatically = NO;
}

@end


@implementation RBFilterManager(Tests)

- (NSArray<NSURL *> *)filterRuleURLs {
    return [[[NSFileManager defaultManager] enumeratorAtURL:self._filterRulesDirectoryURL includingPropertiesForKeys:nil options:0 errorHandler:^BOOL(NSURL * _Nonnull url, NSError * _Nonnull error) {
        return NO;
    }] allObjects];
}

@end
