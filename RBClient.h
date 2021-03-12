//
//  RBClient.h
//  rAdblock Manager
//
//  Created by Mikey on 16/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RBFilter.h"
#import "RBFilterGroup.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Client)
@interface RBClient : NSObject

@property(class,readonly) RBClient* defaultClient;

@property(nonatomic,readonly,getter=isCloudKitEnabled) BOOL cloudKitEnabled;

@property(nonatomic,readonly) NSURL *url;

- (NSProgress *)fetchFilterRulesForGroup:(RBFilterGroup *)group outputDirectory:(NSURL *)outputDirectoryURL completionHandler:(void(^)(RBFilterGroupRules* __nullable, NSError* __nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END
