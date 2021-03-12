//
//  RBClient-Private.h
//  rAdblock Manager
//
//  Created by Mikey on 16/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <CloudKit/CloudKit.h>

#import "RBClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface RBClient()

@property(nonatomic,nullable,readonly,copy) NSURLSessionConfiguration *_sessionConfiguration;

- (NSProgress *)_performQuery:(CKQuery *)query completionHandler:(void (^)(NSArray<CKRecord *> * _Nullable, NSError * _Nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END
