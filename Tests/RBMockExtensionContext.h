//
//  RBMockExtensionContext.h
//  RadBlockTests
//
//  Created by Mike Pulaski on 01/11/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RBMockExtensionContext : NSExtensionContext

+ (instancetype)mockExtensionContextWithCompletionHandler:(void(^)(NSArray<NSExtensionItem*>*, NSError*))block;

@end

NS_ASSUME_NONNULL_END
