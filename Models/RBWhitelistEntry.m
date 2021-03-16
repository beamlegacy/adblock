//
//  RBWhitelistEntry.m
//  RadBlock
//
//  Created by Mike Pulaski on 30/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBWhitelistEntry.h"
#import "RBWhitelistEntry-Private.h"
#import "RBSQLite.h"
#import "RBUtils.h"

@implementation RBWhitelistEntry

- (id)copyWithZone:(NSZone *)zone {
    RBWhitelistEntry *entry = [[RBWhitelistEntry alloc] init];
    [entry _copyValuesFrom:self];
    return entry;
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    RBMutableWhitelistEntry *entry = [[RBMutableWhitelistEntry alloc] init];
    [entry _copyValuesFrom:self];
    return entry;
}

- (void)_copyValuesFrom:(RBWhitelistEntry *)entry {
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
    RBWhitelistEntry *otherEntry = RBKindOfClassOrNil(RBWhitelistEntry, object);
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

@implementation RBMutableWhitelistEntry
@dynamic groupNames, enabled;

- (void)setGroupNames:(NSArray *)groupNames { [super _setGroupNames:groupNames]; }
- (void)setEnabled:(BOOL)enabled { [super _setEnabled:enabled]; }

@end
