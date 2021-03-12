//
//  RBDatabase-Private.h
//  RadBlock
//
//  Created by Mike Pulaski on 23/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#include <sqlite3.h>
#import "RBDatabase.h"

NS_ASSUME_NONNULL_BEGIN

@interface RBDatabase()
@property(nonatomic,setter=_setStatDate:,nullable) NSDate *_statDate;

- (void)_accessConnectionUsingBlock:(void(^)(sqlite3*))block;
- (void)_drainPool;

@end

NS_ASSUME_NONNULL_END
