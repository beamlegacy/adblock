//
//  RBFilter.m
//  rAdblock Manager
//
//  Created by Mikey on 16/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBFilter.h"
#import "RBFilterBuilder.h"
#import "RBUtils.h"
#import <CloudKit/CloudKit.h>


@implementation RBFilter {
    CKRecord *_record;
}

- (instancetype)init {
    return [self initWithPropertyList:@{}];
}

- (instancetype)initWithRecord:(CKRecord *)record {
    self = [self initWithPropertyList:@{
        @"id": record.recordID.recordName ?: [NSNull null],
        @"group": record[@"group"] ?: [NSNull null],
        @"language": record[@"language"] ?: [NSNull null],
        @"md5": record[@"md5"] ?: [NSNull null],
        @"numberOfRules": record[@"numberOfRules"] ?: [NSNull null],
        @"selector": record[@"selector"] ?: [NSNull null]
    }];
    if (self == nil)
        return nil;
    
    _record = [record copy];
    
    return self;
}

- (instancetype)initWithPropertyList:(NSDictionary<NSString *,id> *)plist {
    if (plist == nil)
        return nil;
    
    NSString *uniqueIdentifier = RBKindOfClassOrNil(NSString, plist[@"id"]);
    NSString *group = RBKindOfClassOrNil(NSString, plist[@"group"]);
    
    if (uniqueIdentifier == nil || group == nil)
        return nil;

    self = [super init];
    if (self == nil)
        return nil;
    
    _uniqueIdentifier = uniqueIdentifier;
    _group = group;
    _language = RBKindOfClassOrNil(NSString, plist[@"language"]) ?: @"";
    _md5 = RBKindOfClassOrNil(NSString, plist[@"md5"]) ?: @"";
    _numberOfRules = [RBKindOfClassOrNil(NSNumber, plist[@"numberOfRules"]) ?: @(0) unsignedIntegerValue];
    _selector = RBKindOfClassOrNil(NSString, plist[@"selector"]) ?: @"";

    _propertyList = RBPlistNormalizedCopy([plist dictionaryWithValuesForKeys:@[@"id", @"group", @"language", @"md5", @"numberOfRules", @"selector"]]);
    
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ %@ %lu", _uniqueIdentifier, _group, _numberOfRules];
}

- (id)copyWithZone:(NSZone *)zone {
    RBFilter *filter = [[[self class] allocWithZone:zone] initWithPropertyList:_propertyList];
    if (filter != nil && _record != nil) {
        filter->_record = [_record copy];
    }
    return filter;
}

- (NSUInteger)hash {
    return _uniqueIdentifier.hash;
}

- (BOOL)isEqual:(id)object {
    if (object == nil || ![object isKindOfClass:[RBFilter class]]) {
        return NO;
    }
    return [self isEqualToFilter:object];
}

- (BOOL)isEqualToFilter:(RBFilter *)other {
    return [_uniqueIdentifier isEqual:other.uniqueIdentifier];
}

@end

