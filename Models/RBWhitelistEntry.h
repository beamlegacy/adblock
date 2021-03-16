//
//  RBWhitelistEntry.h
//  RadBlock
//
//  Created by Mike Pulaski on 30/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Database.Entry)
@interface RBWhitelistEntry : NSObject
@property(nonatomic,readonly,getter=isEnabled) BOOL enabled;
@property(nonatomic,readonly) NSString *domain;
@property(nonatomic,readonly,nullable) NSArray *groupNames;
@property(nonatomic,readonly) NSDate *dateCreated;
@property(nonatomic,readonly) NSDate *dateModified;
@property(nonatomic,readonly) BOOL existsInStore;
@end

NS_SWIFT_NAME(Database.MutableEntry)
@interface RBMutableWhitelistEntry : RBWhitelistEntry
@property(nonatomic,getter=isEnabled) BOOL enabled;
@property(nonatomic,nullable) NSArray *groupNames;
@end

NS_ASSUME_NONNULL_END
