//
//  RBFilterGroup.m
//  RadBlock
//
//  Created by Mike Pulaski on 19/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBFilterGroup.h"
#import "RBFilterGroup-Private.h"
#import "RBUtils.h"
#import "RBFilter.h"

@implementation RBFilterGroup

- (instancetype)_initWithFileURL:(NSURL *)fileURL {
    self = [super init];
    if (self == nil)
        return nil;
    
    _fileURL = fileURL;
    
    return self;
}

- (NSString *)name {
    return [_fileURL.lastPathComponent stringByDeletingPathExtension];
}

- (void)_reloadWithPropertyList:(NSDictionary<NSString *,id>*)plist {
    self.lastBuildDate = RBKindOfClassOrNil(NSDate, plist[@"lastBuildDate"]);
    self.lastModificationDate = RBKindOfClassOrNil(NSDate, plist[@"lastModificationDate"]);
    self.numberOfRules = (RBKindOfClassOrNil(NSNumber, plist[@"numberOfRules"]) ?: @(0)).integerValue;
}

- (NSDictionary<NSString *,id>*)propertyList {
    return RBPlistNormalizedCopy(@{
        @"lastBuildDate": _lastBuildDate ?: [NSNull null],
        @"lastModificationDate": _lastModificationDate ?: [NSNull null],
        @"numberOfRules": @(_numberOfRules),
    });
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingPropertyList {
    return [NSSet setWithObjects:@"lastBuildDate", @"lastModificationDate", @"numberOfRules", nil];
}

- (NSPredicate *)_filterPredicate {
    [NSException raise:NSInternalInconsistencyException format:@"%@ must be overridden by subclasses", NSStringFromSelector(_cmd)];
    return nil;
}

- (BOOL)isEqualToGroup:(RBFilterGroup *)other {
    NSDate *placeholderDate = [NSDate date];
    
    return [other isKindOfClass:[self class]]
        && _numberOfRules == other.numberOfRules
        && [_lastModificationDate ?: placeholderDate isEqualToDate:other.lastModificationDate ?: placeholderDate]
        && [_lastBuildDate ?: placeholderDate isEqualToDate:other.lastBuildDate ?: placeholderDate]
    ;
}

- (BOOL)isEqual:(id)object {
    if (object != nil && [object isKindOfClass:[self class]]) {
        return [self isEqualToGroup:object];
    } else {
        return NO;
    }
}

- (NSArray<RBFilter*>*)reduceFilters:(NSArray<RBFilter*>*)rules {
    return [rules filteredArrayUsingPredicate:self._filterPredicate];
}

@end


@implementation RBAdsFilterGroup

- (NSPredicate *)_filterPredicate {
    return [NSPredicate predicateWithFormat:@"group = 'ads' AND language = ''"];
}

@end


@implementation RBRegionalFilterGroup

- (void)_reloadWithPropertyList:(NSDictionary<NSString *,id>*)plist {
    [super _reloadWithPropertyList:plist];
    
    NSArray *languageCodes = RBKindOfClassOrNil(NSArray, plist[@"languageCodes"]);
    if (languageCodes == nil) {
        // The defaults CLI doesn't support nested composite types; explode strings
        NSString *stringVersion = RBKindOfClassOrNil(NSString, plist[@"languageCodes"]);
        if (stringVersion != nil) {
            languageCodes = [stringVersion componentsSeparatedByString:@","];
        }
    }
    
    if (languageCodes == nil) {
        NSMutableOrderedSet *systemLanguages = [NSMutableOrderedSet orderedSet];
        
        for (NSString *language in [NSLocale preferredLanguages]) {
            [systemLanguages addObject:[[language componentsSeparatedByString:@"-"] firstObject]];
        }
        
        // Remove unsupported languages by intersecting with languages we support
        [systemLanguages intersectSet:[NSSet setWithObjects:@"fr", @"de", @"ru", nil]];
        
        languageCodes = [systemLanguages array];
    }
    
    self.languageCodes = languageCodes;
}

- (NSDictionary<NSString *,id> *)propertyList {
    NSMutableDictionary *plist = [[super propertyList] mutableCopy];
    plist[@"languageCodes"] = _languageCodes ?: @[];
    return plist;
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingPropertyList {
    return [[super keyPathsForValuesAffectingPropertyList] setByAddingObject:@"languageCodes"];
}

- (NSPredicate *)_filterPredicate {
    NSArray *languageCodes = _languageCodes ?: @[];
    
    // CloudKit predicates evaluate to true if CONTAINS is performed on an empty array (!!)
    if (languageCodes.count == 0) {
        languageCodes = @[@"--cloudkit-dragon-slayer--"];
    }
    
    return [NSPredicate predicateWithFormat:@"%@ CONTAINS language", languageCodes];
}

- (BOOL)isEqualToGroup:(RBRegionalFilterGroup *)other {
    return [super isEqualToGroup:other] && [_languageCodes ?: @[] isEqualToArray:other.languageCodes ?: @[]];
}

@end


@implementation RBPrivacyFilterGroup

- (void)_reloadWithPropertyList:(NSDictionary<NSString *,id>*)plist {
    [super _reloadWithPropertyList:plist];
    
    self.socialMediaFilterEnabled = (RBKindOfClassOrNil(NSNumber, plist[@"socialMediaFilterEnabled"]) ?: @(NO)).boolValue;
}

- (NSDictionary<NSString *,id> *)propertyList {
    NSMutableDictionary *plist = [[super propertyList] mutableCopy];
    plist[@"socialMediaFilterEnabled"] = @(_socialMediaFilterEnabled);
    
    return plist;
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingPropertyList {
    return [[super keyPathsForValuesAffectingPropertyList] setByAddingObject:@"socialMediaFilterEnabled"];
}

- (NSPredicate *)_filterPredicate {
    NSMutableSet *selectors = [NSMutableSet setWithObject:@""];

    if (_socialMediaFilterEnabled) {
        [selectors addObject:@"social"];
    }
    
    return [NSPredicate predicateWithFormat:@"group = 'privacy' AND language = '' AND selector IN %@", selectors];
}

- (BOOL)isEqualToGroup:(RBPrivacyFilterGroup *)other {
    return [super isEqualToGroup:other]
        && _socialMediaFilterEnabled == other.isSocialMediaFilterEnabled
    ;
}

@end


@implementation RBAnnoyanceFilterGroup

- (void)_reloadWithPropertyList:(NSDictionary<NSString *,id>*)plist {
    [super _reloadWithPropertyList:plist];
    
    self.cookiesFilterEnabled = (RBKindOfClassOrNil(NSNumber, plist[@"cookiesFilterEnabled"]) ?: @(NO)).boolValue;
}

- (NSDictionary<NSString *,id> *)propertyList {
    NSMutableDictionary *plist = [[super propertyList] mutableCopy];
    plist[@"cookiesFilterEnabled"] = @(_cookiesFilterEnabled);
    
    return plist;
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingPropertyList {
    return [[super keyPathsForValuesAffectingPropertyList] setByAddingObject:@"cookiesFilterEnabled"];
}

- (NSPredicate *)_filterPredicate {
    NSMutableSet *selectors = [NSMutableSet setWithObject:@""];

    if (_cookiesFilterEnabled) {
        [selectors addObject:@"cookies"];
    }
    
    return [NSPredicate predicateWithFormat:@"group = 'annoyance' AND language = '' AND selector IN %@", selectors];
}

- (BOOL)isEqualToGroup:(RBAnnoyanceFilterGroup *)other {
    return [super isEqualToGroup:other]
        && _cookiesFilterEnabled == other.isCookiesFilterEnabled
    ;
}

@end

#pragma mark -

NSUInteger RBFilterGroupRulesCount(RBFilterGroupRules *rules) {
    NSUInteger numberOfRules = 0;
    for (RBFilter *filter in rules.allKeys) {
        numberOfRules += filter.numberOfRules;
    }
    return numberOfRules;
}
