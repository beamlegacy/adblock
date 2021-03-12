//
//  RBFilterManagerState.m
//  RadBlock
//
//  Created by Mike Pulaski on 22/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBFilterManagerState-Private.h"
#import "RBFilterGroup-Private.h"
#import "RBFilter.h"
#import "RBKVO.h"
#import "RBUtils.h"
#import "RBDatabase.h"

static void* txQueueProcessKey = &txQueueProcessKey;

@implementation RBFilterManagerState {
    NSUserDefaults *_defaults;
    NSURL *_filterGroupDirectoryURL;
    NSSet<RBKVO*> *_observers;
    dispatch_queue_t _txQueue;
    dispatch_group_t _syncGroup;
    dispatch_source_t _debugSource;
}

@synthesize _cooldownInterval = _cooldownInterval;
@synthesize _maxCooldownInterval = _maxCooldownInterval;

+ (instancetype)sharedState {
    static dispatch_once_t onceToken;
    static RBFilterManagerState *sharedState = nil;
    dispatch_once(&onceToken, ^{
        sharedState = [[self alloc] _initWithDefaults:RBSharedUserDefaults];
    });
    return sharedState;
}

- (instancetype)_initWithDefaults:(NSUserDefaults *)defaults {
    NSURL *groupDirectory = [RBSharedApplicationDataURL URLByAppendingPathComponent:@"groups" isDirectory:YES];
    return [self _initWithDefaults:defaults filterGroupDirectoryURL:groupDirectory];
}

- (instancetype)_initWithDefaults:(NSUserDefaults *)defaults filterGroupDirectoryURL:(NSURL *)filterGroupDirectoryURL {
    self = [super init];
    if (self == nil)
        return nil;
    
    _defaults = defaults;
    _filterGroupDirectoryURL = filterGroupDirectoryURL;
    
    _txQueue = dispatch_queue_create("net.youngdynasty.net.radblock.manager-state.tx", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
    dispatch_queue_set_specific(_txQueue, txQueueProcessKey, (void*)1, NULL);
    _syncGroup = dispatch_group_create();

    _adsFilterGroup = [[RBAdsFilterGroup alloc] _initWithFileURL:[filterGroupDirectoryURL URLByAppendingPathComponent:@"ads.json"]];
    _regionalFilterGroup = [[RBRegionalFilterGroup alloc] _initWithFileURL:[filterGroupDirectoryURL URLByAppendingPathComponent:@"regional.json"]];
    _privacyFilterGroup = [[RBPrivacyFilterGroup alloc] _initWithFileURL:[filterGroupDirectoryURL URLByAppendingPathComponent:@"privacy.json"]];
    _annoyanceFilterGroup = [[RBAnnoyanceFilterGroup alloc] _initWithFileURL:[filterGroupDirectoryURL URLByAppendingPathComponent:@"annoyance.json"]];
    _filterGroups = @[_adsFilterGroup, _regionalFilterGroup, _privacyFilterGroup, _annoyanceFilterGroup];
    
    NSMutableSet<RBKVO*> *observers = [NSMutableSet set];
    
    for (RBFilterGroup *group in _filterGroups) {
        __block NSDictionary *plist = RBKindOfClassInDefaults(NSDictionary, defaults, _filterGroupKey(group)) ?: @{};
        [group _reloadWithPropertyList:plist];
        
        [observers addObject:[RBKVO observe:self keyPath:[NSString stringWithFormat:@"%@.propertyList", _filterGroupKey(group)] usingBlock:^(RBFilterManagerState *self) {
            if ([plist isEqualToDictionary:group.propertyList]) {
                return;
            }

            // Persist changes using background queue, otherwise the main thread may lock
            dispatch_group_async(self->_syncGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                [self _noteFilterGroupDidChange:group];
            });

            plist = group.propertyList;
        }]];
    }
    
    _observers = [observers copy];
    
    for (int i = 0, m = sizeof(ipcBindings) / sizeof(NSString*); i < m; i++) {
        [_defaults addObserver:self forKeyPath:ipcBindings[i] options:NSKeyValueObservingOptionNew context:ipcContext];
    }
    
    // Set default values (and implicitly set nextSynchronizeDate to now)
    if ([self _isSynchronizeIntervalEmpty]) {
        self.synchronizeInterval = RBSynchronizeIntervalWeekly;
    }
    
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] _initWithDefaults:_defaults filterGroupDirectoryURL:_filterGroupDirectoryURL];
}

- (void)dealloc {
    for (int i = 0, m = sizeof(ipcBindings) / sizeof(NSString*); i < m; i++) {
        [_defaults removeObserver:self forKeyPath:ipcBindings[i]];
    }
    
    for (RBKVO *observer in _observers) {
        [observer invalidate];
    }
    
    if (_debugSource != nil) {
        dispatch_source_cancel(_debugSource);
    }
}

#pragma mark -

- (BOOL)_isSynchronizeIntervalEmpty {
    return RBKindOfClassInDefaults(NSString, _defaults, @"synchronizeInterval") == nil;
}

- (RBSynchronizeInterval)synchronizeInterval {
    return RBSynchronizeIntervalFromNSString(RBKindOfClassInDefaults(NSString, _defaults, @"synchronizeInterval"));
}

- (void)setSynchronizeInterval:(RBSynchronizeInterval)synchronizeInterval {
    [self _invokeBlockWithinInterProcessLock:^{
        [self->_defaults setObject:NSStringFromRBSynchronizeInterval(synchronizeInterval) forKey:@"synchronizeInterval"];
        [self _updateNextSynchronizeDate];
    }];
}

- (BOOL)isDisabled {
    return [_defaults boolForKey:@"disabled"];
}

- (void)setDisabled:(BOOL)disabled {
    [self _invokeBlockWithinInterProcessLock:^{
        [self->_defaults setBool:disabled forKey:@"disabled"];
        [self _updateNextSynchronizeDate];
    }];
}

- (NSDate *)lastSynchronizeDate {
    NSDate *date = RBKindOfClassInDefaults(NSDate, _defaults, @"lastSynchronizeDate");
    if (date != nil) {
        return date;
    }
    
    // Tests use integers (the defaults CLI doesn't write dates properly)
    NSNumber *timestamp = RBKindOfClassInDefaults(NSNumber, _defaults, @"lastSynchronizeDate");
    if (timestamp != nil) {
        return [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue]];
    }
    
    return nil;
}

- (void)_setLastSynchronizeDate:(NSDate *)newValue {
    [self _invokeBlockWithinInterProcessLock:^{
        if (newValue != nil) {
            [self->_defaults setObject:newValue forKey:@"lastSynchronizeDate"];
        } else {
            [self->_defaults removeObjectForKey:@"lastSynchronizeDate"];
        }
        
        [self _setNumberOfFailuresSinceLastSynchronize:0];
        [self _updateNextSynchronizeDate];
    }];
}

- (NSDate *)lastSynchronizeAttemptDate {
    NSDate *date = RBKindOfClassInDefaults(NSDate, _defaults, @"lastSynchronizeAttemptDate");
    if (date != nil) {
        return date;
    }
    
    // Tests use integers (the defaults CLI doesn't write dates properly)
    NSNumber *timestamp = RBKindOfClassInDefaults(NSNumber, _defaults, @"lastSynchronizeAttemptDate");
    if (timestamp != nil) {
        return [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue]];
    }
    
    return nil;
}

- (void)_setLastSynchronizeAttemptDate:(NSDate *)newValue {
    [self _invokeBlockWithinInterProcessLock:^{
        if (newValue != nil) {
            [self->_defaults setObject:newValue forKey:@"lastSynchronizeAttemptDate"];
        } else {
            [self->_defaults removeObjectForKey:@"lastSynchronizeAttemptDate"];
        }
    }];
}

- (NSDate *)nextSynchronizeDate {
    NSDate *date = RBKindOfClassInDefaults(NSDate, _defaults, @"nextSynchronizeDate");
    if (date != nil) {
        return date;
    }

    // Tests use integers (the defaults CLI doesn't write dates properly)
    NSNumber *timestamp = RBKindOfClassInDefaults(NSNumber, _defaults, @"nextSynchronizeDate");
    if (timestamp != nil) {
        return [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue]];
    }
    
    return nil;
}

- (void)_setNextSynchronizeDate:(NSDate *)newValue {
    [self _invokeBlockWithinInterProcessLock:^{
        if (newValue != nil) {
            [self->_defaults setObject:newValue forKey:@"nextSynchronizeDate"];
        } else {
            [self->_defaults removeObjectForKey:@"nextSynchronizeDate"];
        }
    }];
}

- (void)_updateNextSynchronizeDate {
    if (self.isDisabled) {
        self.nextSynchronizeDate = nil;
        return;
    }
    
    RBSynchronizeInterval interval = self.synchronizeInterval;
    NSDateComponents *dateComponents = NSDateComponentsFromRBSynchronizeInterval(interval);
    if (interval == RBSynchronizeIntervalDisabled || dateComponents == nil) {
        self.nextSynchronizeDate = nil;
        return;
    }
    
    NSTimeInterval cooldown = self._currentCooldown;
    NSDate *lastSynchronizeDate = self.lastSynchronizeDate;
    NSDate *lastSynchronizeAttemptDate = self.lastSynchronizeAttemptDate;
    
    if (cooldown > 0) {
        self.nextSynchronizeDate = [lastSynchronizeAttemptDate ?: [NSDate date] dateByAddingTimeInterval:cooldown];
    } else if (lastSynchronizeAttemptDate == nil) {
        self.nextSynchronizeDate = [NSDate date];
    } else {
        self.nextSynchronizeDate = [[NSCalendar currentCalendar] dateByAddingComponents:dateComponents toDate:lastSynchronizeDate ?: [NSDate date] options:0];
    }
}

- (NSUInteger)numberOfFailuresSinceLastSynchronize {
    NSNumber *v = RBKindOfClassInDefaults(NSNumber, _defaults, @"numberOfFailuresSinceLastSynchronize");
    return v != nil ? [v unsignedIntegerValue] : 0;
}

- (void)_setNumberOfFailuresSinceLastSynchronize:(NSUInteger)newValue {
    [self _invokeBlockWithinInterProcessLock:^{
        if (newValue == 0) {
            [self->_defaults removeObjectForKey:@"numberOfFailuresSinceLastSynchronize"];
        } else {
            [self->_defaults setObject:@(newValue) forKey:@"numberOfFailuresSinceLastSynchronize"];
        }
        
        [self _updateNextSynchronizeDate];
    }];
}

- (NSTimeInterval)_currentCooldown {
    NSUInteger numAttempts = self.numberOfFailuresSinceLastSynchronize;
    if (numAttempts == 0) {
        return -1;
    }
    
    NSTimeInterval cooldownInterval = _cooldownInterval;
    if (cooldownInterval == 0) {
        cooldownInterval = 60*60;
    }
    
    NSTimeInterval maxCooldownInterval = _maxCooldownInterval;
    if (maxCooldownInterval == 0) {
        maxCooldownInterval = 24*cooldownInterval;
    }
    
    return MIN(cooldownInterval*numAttempts, maxCooldownInterval);
}

- (NSArray *)filters {
    NSArray *filterPlists = RBKindOfClassInDefaults(NSArray, _defaults, @"filters");
    if (filterPlists == nil) {
        return @[];
    }
    
    NSMutableArray *filters = [NSMutableArray array];
    
    for (id plist in filterPlists) {
        if (![plist isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        
        RBFilter *filter = [[RBFilter alloc] initWithPropertyList:plist];
        if (filter != nil) {
            [filters addObject:filter];
        }
    }
    
    return [filters copy];
}

- (void)_setFilters:(NSArray<RBFilter*> *)newValue {
    [self _invokeBlockWithinInterProcessLock:^{
        if (newValue.count != 0) {
            [self->_defaults setObject:[newValue valueForKeyPath:@"propertyList"] forKey:@"filters"];
        } else {
            [self->_defaults removeObjectForKey:@"filters"];
        }
    }];
}

static inline NSString *_filterGroupKey(RBFilterGroup *filterGroup) {
    return [filterGroup.name stringByAppendingString:@"FilterGroup"];
}

- (void)_noteFilterGroupDidChange:(RBFilterGroup *)filterGroup {
    [self _invokeBlockWithinInterProcessLock:^{
        [self->_defaults setObject:filterGroup.propertyList forKey:_filterGroupKey(filterGroup)];
    }];
}

- (void)_waitUntilSynchronized {
    dispatch_group_wait(_syncGroup, DISPATCH_TIME_FOREVER);
}

#pragma mark - IPC

static NSString *ipcBindings[] = {
    @"synchronizeInterval",
    @"numberOfFailuresSinceLastSynchronize",
    @"nextSynchronizeDate",
    @"lastSynchronizeDate",
    @"lastSynchronizeAttemptDate",
    @"filters",
    @"adsFilterGroup",
    @"regionalFilterGroup",
    @"privacyFilterGroup",
    @"annoyanceFilterGroup",
};
static void* ipcContext = &ipcContext;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context != ipcContext) {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    
    // Ignore mutations from within our process (assume we have one shared state instance per process)
    if (dispatch_get_specific(txQueueProcessKey) != NULL) {
        return;
    }
    
    // Defer group changes (and KVO compliance) to their respective values
    if ([keyPath hasSuffix:@"FilterGroup"]) {
        RBFilterGroup *filterGroup = RBKindOfClassOrNil(RBFilterGroup, [self valueForKeyPath:keyPath]);
        if (filterGroup != nil) {
            id newValue = change ? change[NSKeyValueChangeNewKey] : [_defaults objectForKey:keyPath];
            
            return dispatch_async(dispatch_get_main_queue(), ^{
                NSDictionary *plist = RBKindOfClassOrNil(NSDictionary, newValue) ?: @{};
                [filterGroup _reloadWithPropertyList:plist];
            });
        }
    }
    
    // Generate KVO messages for other values
    dispatch_async(dispatch_get_main_queue(), ^{
        [self willChangeValueForKey:keyPath];
        [self didChangeValueForKey:keyPath];
    });
}

- (void)_invokeBlockWithinInterProcessLock:(void(^)(void))block {
    // Invoke immediately if our process already owns a lock
    if (dispatch_get_specific(txQueueProcessKey) != NULL) {
        return block();
    }
    
    dispatch_sync(_txQueue, ^{
        int lock = RBInterProcessLock(@"manager-state");
        {
            NSAssert(lock != -1, @"Could not open lock: %d", errno);
            block();
        }
        RBInterProcessUnlock(lock);
    });
}

@end
