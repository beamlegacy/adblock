//
//  ContentBlockerRequestHandler.h
//  ContentBlocker
//
//  Created by Mike Pulaski on 29/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RBFilterGroup;
@class RBDatabase;

NS_ASSUME_NONNULL_BEGIN

@interface RBContentBlocker : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFilterGroup:(RBFilterGroup *)filterGroup allowList:(RBDatabase *)allowList NS_DESIGNATED_INITIALIZER;

@property(nonatomic,readonly) RBFilterGroup *filterGroup;
@property(nonatomic,readonly) RBDatabase *allowList;

@property(nonatomic,nonnull) NSURL *rulesFileURL;

@property(nonatomic) NSUInteger allowListGroupSize;
@property(nonatomic) NSUInteger maxNumberOfRules;

- (void)writeRulesWithCompletionHandler:(void (^)(NSURL *_Nullable, NSError *_Nullable))handler;
@end

NS_ASSUME_NONNULL_END

