//
//  RBFilter+Mock.m
//  RadBlock
//
//  Created by Mikey on 18/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBFilter+Mock.h"
#import "RBDigest.h"
#import "RBMockClient.h"
#import "RBUtils.h"


@implementation RBFilter(Mock)

+ (instancetype)mockFilter {
    return [self mockFilterWithGroup:@"ads" rules:nil];
}

+ (instancetype)mockFilterWithGroup:(NSString *)group rules:(NSArray<NSDictionary*>*)rules {
    return [[self mockFilters:1 plistBlock:^NSDictionary*(NSUInteger idx) {
        return @{@"group": group};
    } rulesBlock:^NSArray<NSDictionary*>*(NSUInteger idx) {
        return rules ?: @[@{}];
    }] firstObject];
}

+ (NSArray<RBFilter *> *)mockFilters:(NSUInteger)size {
    return [self mockFilters:size plistBlock:nil rulesBlock:^id(NSUInteger idx) {
        return @[@{@"action": @{@"type": @"block"}, @"selector": @{@"if-domain": @[@(idx)]}}];
    }];
}

+ (NSArray<RBFilter *> *)standardMockFilters:(NSUInteger)size {
    return [self mockFilters:size plistBlock:^NSDictionary*(NSUInteger idx) {
        switch (idx % 4) {
            case 0:
                return @{@"group": @"ads", @"language": [NSNull null], @"selector": [NSNull null]};
            case 1:
                return @{@"group": @"privacy", @"language": [NSNull null], @"selector": [NSNull null]};
            case 2:
                return @{@"group": @"annoyance", @"language": [NSNull null], @"selector": [NSNull null]};
            default:
                return @{@"group": @"ads", @"language": @"fr", @"selector": [NSNull null]};
        }
    } rulesBlock:nil];
}

+ (NSArray<RBFilter*>*)mockFilters:(NSUInteger)size plistBlock:(nullable NSDictionary*(^)(NSUInteger))plistBlock rulesBlock:(nullable NSArray<NSDictionary*>*(^)(NSUInteger))rulesBlock {
    NSMutableArray<RBFilter*> *filters = [NSMutableArray arrayWithCapacity:size];

    for (NSUInteger i = 0; i < size; i++) {
        NSArray<NSDictionary*>* rules = rulesBlock != nil ? rulesBlock(i) : @[@{}];
        NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithDictionary:i == 0 ? [self _randomPrimaryPayloadWithRules:rules] : [self _randomSecondaryPayloadWithRules:rules]];
        
        if (plistBlock != nil) {
            [plist addEntriesFromDictionary:plistBlock(i)];
        }
        
        filters[i] = [[[self class] alloc] initWithPropertyList:plist];
        self._rulesDictionary[filters[i].uniqueIdentifier] = rules;
    }
    
    return [filters copy];
}

+ (NSDictionary *)_randomPrimaryPayloadWithRules:(NSArray<NSDictionary*>*)rules {
    NSData *data = [RBMockClient jsonData:rules];
    NSString *hash = [RBDigest MD5HashOfData:data];

    return @{
        @"id": [[NSUUID UUID] UUIDString],
        @"group": @"ads",
        @"md5": hash ?: [RBDigest MD5HashOfUTF8String:[[NSUUID UUID] UUIDString]],
        @"numberOfRules": @(rules.count),
    };
}

+ (NSDictionary *)_randomSecondaryPayloadWithRules:(NSArray<NSDictionary*>*)rules {
    NSData *data = [RBMockClient jsonData:rules];
    NSString *hash = [RBDigest MD5HashOfData:data];

    NSString *groupName = nil;
    NSString *selector = nil;
    NSString *language = nil;

    switch (arc4random() % 4) {
        case 2:
            groupName = @"privacy";
            
            switch (arc4random() % 3) {
                case 0:
                    selector = @"cookies";
                    break;
                case 1:
                    selector = @"social";
                    break;
                default:
                    break;
            }
            break;
        default:
            groupName = @"ads";
            
            switch (arc4random() % 4) {
                case 0:
                    language = @"fr";
                    break;
                case 1:
                    language = @"es";
                    break;
                case 2:
                    language = @"de";
                    break;
                case 3:
                    language = @"zh";
                    break;
            }
            
            break;
    }
    
    return @{
        @"id": [[NSUUID UUID] UUIDString],
        @"group": groupName,
        @"selector": selector ?: [NSNull null],
        @"language": language ?: [NSNull null],
        @"md5": hash ?: [RBDigest MD5HashOfUTF8String:[[NSUUID UUID] UUIDString]],
        @"numberOfRules": @(rules.count),
    };
}

+ (NSMutableDictionary *)_rulesDictionary {
    static dispatch_once_t onceToken;
    static NSMutableDictionary *rulesDictionary = nil;
    dispatch_once(&onceToken, ^{
        rulesDictionary = [NSMutableDictionary dictionary];
    });
    return rulesDictionary;
}

- (id)rulesObject {
    return [[[self class] _rulesDictionary] objectForKey:self.uniqueIdentifier];
}

- (instancetype)copyByMergingPropertyList:(NSDictionary *)otherPlist {
    NSMutableDictionary *plist = [[self propertyList] mutableCopy];
    [plist setValuesForKeysWithDictionary:otherPlist];
    return [[[self class] alloc] initWithPropertyList:plist];
}

- (instancetype)copyOutOfSync {
    NSArray<NSDictionary*>* rules = @[@{ @"action": @{@"type": @"block"}, @"selector": @{@"unless-domain": @[@"out-of-sync.com"]}}];
    NSMutableDictionary *plistCopy = [self.propertyList mutableCopy];
    plistCopy[@"md5"] = [RBDigest MD5HashOfData:[RBMockClient jsonData:rules]];
    
    RBFilter *filter = [[[self class] alloc] initWithPropertyList:plistCopy];
    [[self class] _rulesDictionary][filter.uniqueIdentifier] = rules;

    return filter;
}

@end
