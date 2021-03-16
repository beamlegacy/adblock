//
//  RBStat.h
//  RadBlock
//
//  Created by Mike Pulaski on 20/11/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RBStat : NSObject
@property(nonatomic,readonly) NSString *name;
@property(nonatomic,readonly) NSUInteger value;
@end

NS_ASSUME_NONNULL_END
