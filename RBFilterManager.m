//
//  RBFilterManager.m
//  RadBlock
//
//  Created by Mikey on 17/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBFilterManager-Private.h"
#import "RBFilterManagerState-Private.h"

#import "RBClient.h"
#import "RBDigest.h"
#import "RBFilter.h"
#import "RBFilterBuilder.h"
#import "RBFilterGroup-Private.h"
#import "RBUtils.h"
#import "RBKVO.h"


@implementation RBFilterManager {
    RBClient *_client;
    NSURL *_directoryURL;
    
    dispatch_source_t _synchronizeTimer;
    RBKVO *_synchronizeDateBinding;
    NSProgress *_synchronizeProgress;
    BOOL _synchronizeAutomatically;
    
    dispatch_queue_t _q;
    void *_qContext;
}
@synthesize _filterRulesDirectoryURL = _filterRulesDirectoryURL;

+ (RBFilterManager *)defaultManager {
    static dispatch_once_t onceToken;
    static RBFilterManager *defaultManager;
    
    dispatch_once(&onceToken, ^{
        defaultManager = [[self alloc] _initWithState:[RBFilterManagerState sharedState]];
    });
    
    return defaultManager;
}

- (instancetype)_initWithState:(RBFilterManagerState *)state {
    return [self _initWithState:state client:[RBClient defaultClient]];
}

- (instancetype)_initWithState:(RBFilterManagerState *)state client:(RBClient *)client {
    NSURL *rulesDirectory = [RBSharedApplicationDataURL URLByAppendingPathComponent:@"rules" isDirectory:YES];
    return [self _initWithState:state client:client filterRulesDirectoryURL:rulesDirectory];
}

- (instancetype)_initWithState:(RBFilterManagerState *)state client:(RBClient *)client filterRulesDirectoryURL:(NSURL *)filterRulesDirectoryURL {
    self = [super init];
    if (self == nil)
        return nil;
    
    _state = state;
    _client = client ?: [RBClient defaultClient];
    _filterRulesDirectoryURL = filterRulesDirectoryURL;
    
    _q = dispatch_queue_create("net.youngdynasty.radblock.manager.queue-serial", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
    _qContext = &_qContext;
    dispatch_queue_set_specific(_q, _qContext, (void*)1, NULL);
    
    __weak RBFilterManager *weakSelf = self;
    _synchronizeDateBinding = [RBKVO observe:state keyPath:@"nextSynchronizeDate" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial usingBlock:^(RBFilterManagerState *state, NSDictionary *changes) {
        [weakSelf _scheduleNextSynchronize];
    }];
    
    return self;
}

- (void)dealloc {
    if (_synchronizeTimer != NULL) {
        dispatch_source_cancel(_synchronizeTimer);
        _synchronizeTimer = NULL;
    }
    
    [_synchronizeDateBinding invalidate];
}

#pragma mark - Synchronization

- (NSProgress *)synchronizeWithOptions:(RBSynchronizeOptions)options completionHandler:(void (^)(NSError *))completionHandler {
    return [self synchronizeWithOptions:options errorHandler:nil completionHandler:completionHandler];
}

- (NSProgress *)synchronizeWithOptions:(RBSynchronizeOptions)options errorHandler:(void (^)(RBFilterGroup *, NSError *, BOOL *))errorHandler completionHandler:(void (^)(NSError *))completionHandler {
    NSLog(@"In synchronizeWithOptions");
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:1];
    
    dispatch_async(_q, ^{
        if (self.state.isDisabled) {
            if (completionHandler != nil) {
                completionHandler([NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]);
            }
            
            return;
        }
        
        if (!self.isSynchronizing) {
            self.synchronizing = YES;
        }

        if (self->_synchronizeProgress != nil) {
            [self->_synchronizeProgress cancel];
        }
        
        self->_synchronizeProgress = progress;
        
        self.state.lastSynchronizeAttemptDate = [NSDate date];

        [progress addChild:[self _synchronizeWithErrorHandler:errorHandler completionHandler:^(NSError *error) {
            // Update state
            if (!progress.isCancelled) {
                if (error == nil) {
                    self.state.lastSynchronizeDate = [NSDate date];
                } else if ((options & RBSynchronizeOptionRescheduleOnError) != 0) {
                    self.state.numberOfFailuresSinceLastSynchronize++;
                }
            }
            
            if (self->_synchronizeProgress == progress) {
                self.synchronizing = NO;
                self->_synchronizeProgress = nil;
            }
            
            if (completionHandler != nil) {
                completionHandler(error);
            }
        }] withPendingUnitCount:1];
    });
        
    return progress;
}

- (NSProgress *)_synchronizeWithErrorHandler:(void (^)(RBFilterGroup *, NSError *, BOOL *))errorHandler completionHandler:(void (^)(NSError *))completionHandler {
    dispatch_assert_queue(_q);
    
    NSArray *filterGroups = _state.filterGroups;
    NSArray *cachedFilters = _state.filters;
    
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:filterGroups.count + 1];
    dispatch_group_t dispatchGroup = dispatch_group_create();
    
    RBFilterGroupRulesMap *map = RBFilterGroupRulesMapCreate();
    NSMutableArray<RBFilter*> *synchronizedFilters = [NSMutableArray array];
    __block NSError *error = nil;
    
    for (RBFilterGroup *filterGroup in filterGroups) {
        dispatch_group_enter(dispatchGroup);
        
        [progress addChild:[self _synchronizeFilterGroup:filterGroup withCompletionHandler:^(RBFilterGroupRules *rules, NSError *syncError) {
            if (rules != nil) {
                [synchronizedFilters addObjectsFromArray:rules.allKeys];
                [map setObject:rules forKey:filterGroup];
            } else {
                // Add cached filters to our array so that allow partial errors don't mutate the existing state for the group
                [synchronizedFilters addObjectsFromArray:[filterGroup reduceFilters:cachedFilters]];
                
                if (errorHandler != nil) {
                    BOOL stop = NO;
                    errorHandler(filterGroup, syncError, &stop);
                    
                    if (stop) {
                        [progress cancel];
                    }
                }
                
                error = error ?: syncError;
            }
            
            dispatch_group_leave(dispatchGroup);
            
        }] withPendingUnitCount:1];
    }
    
    dispatch_group_notify(dispatchGroup, _q, ^{
        // Remove old filters and update state
        NSMutableSet *removedFilters = [NSMutableSet setWithArray:cachedFilters];
        [removedFilters minusSet:[NSSet setWithArray:synchronizedFilters]];
        NSLog(@"%d synchronizedFilters before removal", synchronizedFilters.count);

        for (RBFilter *removedFilter in removedFilters) {
            NSURL *removedFilterURL = [self._filterRulesDirectoryURL URLByAppendingPathComponent:removedFilter.uniqueIdentifier];
            [[NSFileManager defaultManager] removeItemAtURL:removedFilterURL error:NULL];
        }
        
        // Sort synchronized filters for consistent output
        [synchronizedFilters sortUsingComparator:^NSComparisonResult(RBFilter* f1, RBFilter* f2) {
            return [f1.uniqueIdentifier compare:f2.uniqueIdentifier];
        }];

        self.state.filters = synchronizedFilters;
        
        progress.completedUnitCount++;
        completionHandler(error);
    });
    
    return progress;
}

- (void)setSynchronizeAutomatically:(BOOL)synchronizeAutomatically {
    if (dispatch_get_specific(_qContext) == NULL) {
        return dispatch_sync(_q, ^{
            [self setSynchronizeAutomatically:synchronizeAutomatically];
        });
    }
    dispatch_assert_queue(_q);

    _synchronizeAutomatically = synchronizeAutomatically;
    [self _scheduleNextSynchronize];
}

- (BOOL)synchronizeAutomatically {
    __block BOOL v = NO;
    
    if (dispatch_get_specific(_qContext) == NULL) {
        dispatch_sync(_q, ^{
            v = self->_synchronizeAutomatically;
        });
    } else {
        v = _synchronizeAutomatically;
    }
    
    return v;
}

- (void)_scheduleNextSynchronize {
    if (dispatch_get_specific(_qContext) == NULL) {
        return dispatch_async(_q, ^{
            [self _scheduleNextSynchronize];
        });
    }
    dispatch_assert_queue(_q);
    
    if (_synchronizeTimer != NULL) {
        dispatch_source_cancel(_synchronizeTimer);
        _synchronizeTimer = NULL;
    }
    
    NSDate *nextSynchronizeDate = _state.nextSynchronizeDate;
    if (nextSynchronizeDate == nil || !_synchronizeAutomatically) {
        return;
    }
    
    dispatch_time_t startTime = dispatch_walltime(NULL, [_state.nextSynchronizeDate timeIntervalSinceNow] * NSEC_PER_SEC);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _q);
    dispatch_source_set_timer(timer, startTime, DISPATCH_TIME_FOREVER, 30 * NSEC_PER_SEC);
    
    __weak RBFilterManager *weakSelf = self;
    __block NSProgress *progress = nil;
    
    dispatch_source_set_event_handler(timer, ^{
        progress = [weakSelf synchronizeWithOptions:RBSynchronizeOptionRescheduleOnError completionHandler:^(NSError *error) {
            if (error != nil) {
                NSLog(@"WARNING: Synchronize failed: %@", error);
                NSLog(@"Next synchronize: %@", weakSelf.state.nextSynchronizeDate);
            }
            
            progress = nil;
        }];
    });
    
    dispatch_source_set_cancel_handler(timer, ^{
        if (progress != nil) {
            [progress cancel];
            progress = nil;
        }
    });
    
    dispatch_resume(timer);
    
    _synchronizeTimer = timer;
}

- (NSProgress *)_synchronizeFilterGroup:(RBFilterGroup *)filterGroup withCompletionHandler:(void(^)(RBFilterGroupRules*, NSError *))completionHandler {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:3];
    
    dispatch_group_t dispatchGroup = dispatch_group_create();
    
    __block RBFilterGroupRules *rules = nil;
    __block NSError *error = nil;

    // Fetch rules
    dispatch_group_enter(dispatchGroup);
    
    [progress addChild:[_client fetchFilterRulesForGroup:filterGroup
                                         outputDirectory:_filterRulesDirectoryURL
                                       completionHandler:^(RBFilterGroupRules *filterRules, NSError *fetchError) {
        dispatch_group_async(dispatchGroup, self->_q, ^{
            if (filterRules == nil) {
                error = fetchError;
                return;
            }
            
            rules = filterRules;
            NSUInteger numberOfRules = RBFilterGroupRulesCount(filterRules);
            
            // Update group's attributes if needed
            NSArray *newFilters = filterRules.allKeys;
            NSArray *oldFilters = [filterGroup reduceFilters:self.state.filters];
            
            NSMutableSet *modifiedHashes = [NSMutableSet setWithArray:[newFilters valueForKeyPath:@"md5"]];
            [modifiedHashes minusSet:[NSSet setWithArray:[oldFilters valueForKeyPath:@"md5"]]];
            
            if (modifiedHashes.count > 0) {
                filterGroup.lastModificationDate = [NSDate date];
            }
            
            // Rebuild group if the number of rules have changed or if the group has been modified since the last build date
            NSDate *lastModificationDate = filterGroup.lastModificationDate ?: [NSDate date];
            NSDate *lastBuildDate = filterGroup.lastBuildDate ?: [NSDate distantPast];
            
            if (numberOfRules == filterGroup.numberOfRules
                && [lastModificationDate compare:lastBuildDate] != NSOrderedDescending
                && [[NSFileManager defaultManager] fileExistsAtPath:filterGroup.fileURL.absoluteString]) {
                progress.completedUnitCount++;
                return;
            }
            
            dispatch_group_enter(dispatchGroup);
            
            [progress addChild:[self _buildFilterGroup:filterGroup withRulesMap:filterRules completionHandler:^(NSError *buildError) {
                if (buildError == nil) {
                    filterGroup.lastBuildDate = [NSDate date];
                    filterGroup.numberOfRules = numberOfRules;
                } else {
                    error = buildError;
                }
                
                dispatch_group_leave(dispatchGroup);
            }] withPendingUnitCount:1];
        });
        
        dispatch_group_leave(dispatchGroup);
    }] withPendingUnitCount:2];
    
    dispatch_group_notify(dispatchGroup, _q, ^{
        completionHandler(rules, error);
    });
    
    return progress;
}

- (NSProgress *)_buildFilterGroup:(RBFilterGroup *)filterGroup withRulesMap:(RBFilterGroupRules *)rulesMap completionHandler:(void(^)(NSError *))completionHandler {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:10];
    
    [progress addChild:[RBFilterBuilder temporaryBuilderForFileURLs:rulesMap.allValues completionHandler:^(RBFilterBuilder *builder, NSError *error) {
        // Move result to its final destination
        if (error == nil && RBMoveFileURL(builder.outputURL, filterGroup.fileURL, &error)) {
            progress.completedUnitCount++;
        }
        
        completionHandler(error);
    }] withPendingUnitCount:9];
    
    return progress;
}

@end
