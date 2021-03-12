//
//  EBFilterManager-Testing.h
//  rAdblock Manager
//
//  Created by Mike Pulaski on 18/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBFilterManager.h"

NS_ASSUME_NONNULL_BEGIN

@class RBClient;

@interface RBFilterManager()

- (instancetype)_initWithState:(RBFilterManagerState *)state;
- (instancetype)_initWithState:(RBFilterManagerState *)state client:(RBClient *)client;
- (instancetype)_initWithState:(RBFilterManagerState *)state client:(RBClient *)client filterRulesDirectoryURL:(NSURL *)filterRulesDirectoryURL NS_DESIGNATED_INITIALIZER;

@property(nonatomic,readonly) NSURL *_filterRulesDirectoryURL;
@property(nonatomic,getter=isSynchronizing,setter=_setSynchronizing:) BOOL synchronizing;

@end

NS_ASSUME_NONNULL_END
