//
//  RBFilterGroup.h
//  RadBlock
//
//  Created by Mike Pulaski on 19/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBFilterGroup.h"

NS_ASSUME_NONNULL_BEGIN

@interface RBFilterGroup()
- (instancetype)_initWithFileURL:(NSURL *)fileURL NS_DESIGNATED_INITIALIZER;

- (void)_reloadWithPropertyList:(NSDictionary<NSString *,id> *)plist;
@property(nonatomic,readonly) NSPredicate *_filterPredicate;

@property(nonatomic,nullable,setter=_setLastBuildDate:) NSDate *lastBuildDate;
@property(nonatomic,nullable,setter=_setLastModificationDate:) NSDate *lastModificationDate;
@property(nonatomic,setter=_setNumberOfRules:) NSUInteger numberOfRules;
@end

NS_ASSUME_NONNULL_END
