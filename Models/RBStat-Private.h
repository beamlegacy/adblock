//
//  RBStat-Private.h
//  RadBlock
//
//  Created by Mike Pulaski on 20/11/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBStat.h"

NS_ASSUME_NONNULL_BEGIN

@interface RBStat()
@property(nonatomic,setter=_setName:) NSString *name;
@property(nonatomic,setter=_setValue:) NSUInteger value;
@end

NS_ASSUME_NONNULL_END
