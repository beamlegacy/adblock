//
//  RBFilterManager.h
//  RadBlock
//
//  Created by Mikey on 17/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class RBFilterGroup;
@class RBFilterManagerState;

NS_SWIFT_NAME(FilterManager)

@interface RBFilterManager : NSObject
@property(class,readonly) RBFilterManager* defaultManager;

- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic,readonly) RBFilterManagerState *state;

@property(nonatomic) BOOL synchronizeAutomatically;
@property(nonatomic,readonly,getter=isSynchronizing) BOOL synchronizing;

typedef NS_ENUM(NSUInteger, RBSynchronizeOptions) {
    RBSynchronizeOptionRescheduleOnError = 0x01
};

- (NSProgress *)synchronizeWithOptions:(RBSynchronizeOptions)options completionHandler:(nullable void(^)(NSError *__nullable))completionHandler;
- (NSProgress *)synchronizeWithOptions:(RBSynchronizeOptions)options errorHandler:(nullable void(^)(RBFilterGroup*__nullable, NSError*__nullable, BOOL*))errorHandler completionHandler:(nullable void(^)(NSError *))completionHandler;

@end

NS_ASSUME_NONNULL_END
