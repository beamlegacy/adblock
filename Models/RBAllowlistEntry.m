//
//  RBAllowlistEntry.m
//  RadBlock
//
//  Created by Mike Pulaski on 30/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBAllowlistEntry.h"
#import "RBAllowlistEntry-Private.h"
#import "RBSQLite.h"
#import "RBUtils.h"

@implementation RBAllowlistEntry

- (id)copyWithZone:(NSZone *)zone {
    RBAllowlistEntry *entry = [[RBAllowlistEntry alloc] init];
    [entry _copyValuesFrom:self];
    return entry;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    RBMutableAllowlistEntry *entry = [[RBMutableAllowlistEntry alloc] init];
    [entry _copyValuesFrom:self];
    return entry;
}

- (void)_copyValuesFrom:(RBAllowlistEntry *)entry {
    self.domain = entry.domain;
    self.groupNames = entry.groupNames;
    self.dateCreated = entry.dateCreated;
    self.dateModified = entry.dateModified;
    self.enabled = entry.isEnabled;
    self.existsInStore = entry.existsInStore;
}

- (NSUInteger)hash {
    return _domain.hash;
}

- (BOOL)isEqual:(id)object {
    RBAllowlistEntry *otherEntry = RBKindOfClassOrNil(RBAllowlistEntry, object);
    if (otherEntry != nil) {
        return [_domain isEqualToString:otherEntry.domain];
    }
    
    NSString *domain = RBKindOfClassOrNil(NSString, object);
    if (domain != nil) {
        return [_domain isEqualToString:domain];
    }
    
    return NO;
}

@end

@implementation RBMutableAllowlistEntry
@dynamic groupNames, enabled;

- (void)setGroupNames:(NSArray *)groupNames { [super _setGroupNames:groupNames]; }
- (void)setEnabled:(BOOL)enabled { [super _setEnabled:enabled]; }

@end
