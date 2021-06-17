//
//  RBAllowlistEntry-Private.h
//  RadBlock
//
//  Created by Mike Pulaski on 30/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBAllowlistEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface RBAllowlistEntry() <NSCopying, NSMutableCopying>
@property(nonatomic,setter=_setDomain:) NSString *domain;
@property(nonatomic,setter=_setGroupNames:,nullable) NSArray *groupNames;
@property(nonatomic,setter=_setDateCreated:) NSDate *dateCreated;
@property(nonatomic,setter=_setDateModified:) NSDate *dateModified;
@property(nonatomic,getter=isEnabled,setter=_setEnabled:) BOOL enabled;
@property(nonatomic,setter=_setExistsInStore:) BOOL existsInStore;

- (void)_copyValuesFrom:(RBAllowlistEntry *)entry;
@end

NS_ASSUME_NONNULL_END
