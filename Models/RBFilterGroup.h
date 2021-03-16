//
//  RBFilterGroup.h
//  RadBlock
//
//  Created by Mike Pulaski on 19/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RBFilter;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Filter.Group)
@interface RBFilterGroup : NSObject
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic,readonly) NSURL *fileURL;
@property(nonatomic,readonly) NSString *name;

@property(nonatomic,readonly) NSDictionary<NSString *,id> *propertyList;

@property(nonatomic,nullable,readonly) NSDate *lastBuildDate;
@property(nonatomic,nullable,readonly) NSDate *lastModificationDate;

@property(nonatomic,readonly) NSUInteger numberOfRules;

- (BOOL)isEqualToGroup:(RBFilterGroup *)group;
- (NSArray<RBFilter*>*)reduceFilters:(NSArray<RBFilter*>*)rules;
@end

typedef NSDictionary<RBFilter *,NSURL *> RBFilterGroupRules;
extern NSUInteger RBFilterGroupRulesCount(RBFilterGroupRules *rules);

typedef NSMapTable<RBFilterGroup*, NSDictionary<RBFilter *,NSURL *>*> RBFilterGroupRulesMap;
static inline RBFilterGroupRulesMap* RBFilterGroupRulesMapCreate() { return [NSMapTable strongToStrongObjectsMapTable]; }

@interface RBAdsFilterGroup : RBFilterGroup
@end

@interface RBRegionalFilterGroup : RBFilterGroup
@property(nonatomic,copy) NSArray *languageCodes;
@end

@interface RBPrivacyFilterGroup : RBFilterGroup
@property(nonatomic,getter=isSocialMediaFilterEnabled) BOOL socialMediaFilterEnabled;
@end

@interface RBAnnoyanceFilterGroup : RBFilterGroup
@property(nonatomic,getter=isCookiesFilterEnabled) BOOL cookiesFilterEnabled;
@end


NS_ASSUME_NONNULL_END
