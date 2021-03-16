//
//  RBFilter.h
//  rAdblock Manager
//
//  Created by Mikey on 16/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CKRecord;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Filter)

@interface RBFilter : NSObject <NSCopying>
- (nullable instancetype)initWithRecord:(CKRecord *)record;
@property(nonatomic,nullable,copy,readonly) CKRecord *record;

- (nullable instancetype)initWithPropertyList:(NSDictionary<NSString*,id>*)propertyList NS_DESIGNATED_INITIALIZER;
@property(nonatomic,readonly) NSDictionary<NSString*, id>* propertyList;

@property(nonatomic,readonly) NSString *uniqueIdentifier;
@property(nonatomic,readonly) NSString *group;
@property(nonatomic,readonly) NSString *md5;

@property(nonatomic,readonly) NSString *language;
@property(nonatomic,readonly) NSString *selector;
@property(nonatomic,readonly) NSUInteger numberOfRules;

- (BOOL)isEqualToFilter:(RBFilter *)filter;

@end

NS_ASSUME_NONNULL_END
