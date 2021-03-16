//
//  RBDateRange.m
//  RadBlock
//
//  Created by Mike Pulaski on 20/11/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBDateRange.h"

@implementation RBDateRange

+ (instancetype)today {
    static dispatch_once_t onceToken;
    static RBDateRange *v = nil;
    
    dispatch_once(&onceToken, ^{
        NSDateComponents *c = [NSDateComponents new];
        c.day = -1;
        v = [[self alloc] initWithStartDateComponents:c endDateComponents:[NSDateComponents new]];
    });
    
    return v;
}

+ (instancetype)lastWeek {
    static dispatch_once_t onceToken;
    static RBDateRange *v = nil;
    
    dispatch_once(&onceToken, ^{
        NSDateComponents *c = [NSDateComponents new];
        c.day = -7;
        v = [[self alloc] initWithStartDateComponents:c endDateComponents:[NSDateComponents new]];
    });
    
    return v;
}

+ (instancetype)lastMonth {
    static dispatch_once_t onceToken;
    static RBDateRange *v = nil;
    
    dispatch_once(&onceToken, ^{
        NSDateComponents *c = [NSDateComponents new];
        c.month = -1;
        v = [[self alloc] initWithStartDateComponents:c endDateComponents:[NSDateComponents new]];
    });
    
    return v;
}

+ (instancetype)lastYear {
    static dispatch_once_t onceToken;
    static RBDateRange *v = nil;
    
    dispatch_once(&onceToken, ^{
        NSDateComponents *c = [NSDateComponents new];
        c.year = -1;
        v = [[self alloc] initWithStartDateComponents:c endDateComponents:[NSDateComponents new]];
    });
    
    return v;
}

- (instancetype)initWithStartDateComponents:(NSDateComponents *)startDateComponents endDateComponents:(NSDateComponents *)endDateComponents {
    self = [super init];
    if (self == nil)
        return nil;
    
    _startDateComponents = startDateComponents;
    _endDateComponents = endDateComponents;
    
    return self;
}

- (void)startDate:(NSDate **)outStartDate endDate:(NSDate **)outEndDate {
    if (outStartDate != NULL) {
        (*outStartDate) = [[NSCalendar currentCalendar] dateByAddingComponents:_startDateComponents toDate:[NSDate date] options:0];
    }
    
    if (outEndDate != NULL) {
        (*outEndDate) = [[NSCalendar currentCalendar] dateByAddingComponents:_endDateComponents toDate:[NSDate date] options:0];
    }
}

@end
