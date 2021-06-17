//
//  RBDatabase.h
//  RadBlock
//
//  Created by Mike Pulaski on 23/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RBAllowlistEntry.h"
#import "RBDateRange.h"
#import "RBStat.h"


NS_ASSUME_NONNULL_BEGIN

#if TARGET_OS_OSX
extern NSNotificationName RBDatabaseDidAddEntryNotification;
extern NSNotificationName RBDatabaseDidUpdateEntryNotification;
extern NSNotificationName RBDatabaseDidRemoveEntryNotification;
extern NSString *const RBAllowlistEntryDomainKey;
extern NSString *const RBDatabaseLocalModificationKey;
#endif

NS_SWIFT_NAME(RadBlockDatabase)

@interface RBDatabase : NSObject <NSCopying>
@property(class,readonly) RBDatabase *sharedDatabase;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFileURL:(NSURL *)fileURL NS_DESIGNATED_INITIALIZER;

@property(nonatomic,readonly) NSURL *fileURL;

#pragma mark - allowList

- (void)allowlistEntryForDomain:(NSString *)domain completionHandler:(void(^)(RBAllowlistEntry *__nullable, NSError *__nullable))completionHandler;
- (void)writeAllowlistEntryForDomain:(NSString *)domain usingBlock:(nullable void(^)(RBMutableAllowlistEntry*, BOOL*))block completionHandler:(void(^)(RBAllowlistEntry *__nullable, NSError *__nullable))completionHandler;

- (void)removeAllowlistEntryForDomain:(NSString *)domain completionHandler:(void(^)(NSError *__nullable))completionHandler;
- (void)removeAllowlistEntriesForDomains:(NSArray *)domains completionHandler:(void(^)(NSError *__nullable))completionHandler;

typedef NS_ENUM(short, RBAllowlistEntrySortOrder) {
    RBAllowlistEntrySortOrderDomain,
    RBAllowlistEntrySortOrderCreateDate
};
- (void)allowlistEntryEnumeratorForGroup:(nullable NSString *)group domain:(nullable NSString *)domain sortOrder:(RBAllowlistEntrySortOrder)sortOrder completionHandler:(void(^)(NSEnumerator <RBAllowlistEntry*>*__nullable, NSError*__nullable))completionHandler;

#pragma mark - Stats

 - (void)incrementStatWithName:(NSString *)name by:(NSUInteger)delta completionHandler:(nullable void(^)(NSError *__nullable))completionHandler;
 - (void)getStatsInDateRange:(RBDateRange *)dateRange completionHandler:(void(^)(NSArray<RBStat *> *__nullable, NSError *__nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END
