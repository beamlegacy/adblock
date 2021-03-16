//
//  RBFilter+Mock.h
//  RadBlock
//
//  Created by Mikey on 18/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RBFilter.h"

NS_ASSUME_NONNULL_BEGIN

@interface RBFilter(Mock)

+ (instancetype)mockFilter;
+ (instancetype)mockFilterWithGroup:(NSString *)group rules:(nullable NSArray<NSDictionary*>*)rules;

+ (NSArray<RBFilter*>*)mockFilters:(NSUInteger)size;
+ (NSArray<RBFilter*>*)standardMockFilters:(NSUInteger)size;
+ (NSArray<RBFilter*>*)mockFilters:(NSUInteger)size plistBlock:(nullable NSDictionary*(^)(NSUInteger))plistBlock rulesBlock:(nullable NSArray<NSDictionary*>*(^)(NSUInteger))rulesBlock;

- (nullable NSArray<NSDictionary*>*)rulesObject;

- (instancetype)copyByMergingPropertyList:(NSDictionary *)plist;
- (instancetype)copyOutOfSync;

@end

NS_ASSUME_NONNULL_END
