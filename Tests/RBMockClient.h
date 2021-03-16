//
//  RBMockClient.h
//  RadBlockTests
//
//  Created by Mikey on 16/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RBClient.h"
#import "RBFilter+Mock.h"

NS_ASSUME_NONNULL_BEGIN

@interface RBMockClient : RBClient
+ (NSData *)jsonData:(id)obj;

@property(nonatomic,getter=isCloudKitEnabled) BOOL cloudKitEnabled;

- (void)mockFilters:(NSArray<RBFilter*>*)filters;
- (void)mockError:(NSError *)error forFilter:(RBFilter *)filter;
- (void)invalidate;

typedef void(^RBMockClientHandler)(int *__nonnull status, NSDictionary *__nonnull*_Nonnull headers, NSData *__nonnull*_Nonnull data);

- (void)handlePath:(NSString *)path usingBlock:(RBMockClientHandler)handler;
- (RBMockClientHandler)handlerForPath:(NSString *)path;

@end

NS_ASSUME_NONNULL_END
