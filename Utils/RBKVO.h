//
//  RBKVO.h
//  RadBlock
//
//  Created by Mike Pulaski on 22/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RBKVO : NSObject
+ (instancetype)observe:(id)object keyPath:(NSString *)keyPath usingBlock:(void(^)(id))block;
+ (instancetype)observe:(id)object keyPaths:(NSArray<NSString*>*)keyPath usingBlock:(void(^)(id))block;
+ (instancetype)observe:(id)object keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options usingBlock:(void(^)(id, NSDictionary<NSKeyValueChangeKey,id>*))block;
+ (instancetype)observe:(id)object keyPaths:(NSArray<NSString*>*)keyPaths options:(NSKeyValueObservingOptions)options usingBlock:(void(^)(id, NSDictionary<NSKeyValueChangeKey,id>*))block;

- (void)invalidate;
@end

NS_ASSUME_NONNULL_END
