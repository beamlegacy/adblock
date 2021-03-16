//
//  RBUtils.h
//  RadBlock
//
//  Created by Mikey on 17/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const RBAppGroupIdentifier;
extern NSURL *RBApplicationDataURL;
extern NSURL *RBSharedApplicationDataURL;

extern NSUserDefaults* RBSharedUserDefaults;

extern BOOL RBMoveFileURL(NSURL *sourceURL, NSURL *destURL, NSError **outError);
extern NSURL *__nullable RBCreateTemporaryDirectory(NSError **outError);

extern BOOL RBIsDateDurationFake;

extern BOOL RBSafariServicesIsVersion13OrHigher(void);
extern NSString* RBRootDomain(NSString *domain);

typedef int RBInterprocessLock;
extern int RBInterProcessLock(NSString *name);
extern void RBInterProcessUnlock(int fd);

#define RBKindOfClassOrNil(className, object) \
    ((className *)__RBKindOfClassOrNil([className class], object))

#define RBKindOfClassInDefaults(className, defaults, key) \
    ((className *)__RBKindOfClassOrNil([className class], [defaults objectForKey:key]))

NS_INLINE id __nullable __RBKindOfClassOrNil(Class expectedClass, id object) {
    return object != nil && [object isKindOfClass:expectedClass] ? object : nil;
}

NS_INLINE NSURL *__nullable RBPlistURLValue(NSDictionary *plist, id key) {
    NSString *value = RBKindOfClassOrNil(NSString, plist[key]);
    return value == nil ? nil : [NSURL URLWithString:value];
}

NS_INLINE NSDictionary *RBPlistNormalizedCopy(NSDictionary *plist) {
    NSMutableDictionary *normalized = [plist mutableCopy];
    [normalized removeObjectsForKeys:[plist allKeysForObject:[NSNull null]]];
    return [normalized copy];
}

NS_ASSUME_NONNULL_END
