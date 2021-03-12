//
//  RBDateRange.h
//  RadBlock
//
//  Created by Mike Pulaski on 20/11/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RBDateRange : NSObject

+ (instancetype)today;
+ (instancetype)lastWeek;
+ (instancetype)lastMonth;
+ (instancetype)lastYear;

- (instancetype)initWithStartDateComponents:(NSDateComponents *)startDateComponents endDateComponents:(NSDateComponents *)endDateComponents;

@property(nonatomic,readonly) NSDateComponents *startDateComponents;
@property(nonatomic,readonly) NSDateComponents *endDateComponents;

- (void)startDate:(NSDate *__nullable * __nonnull)startDate endDate:(NSDate *__nullable * __nonnull)endDate;

@end

NS_ASSUME_NONNULL_END
