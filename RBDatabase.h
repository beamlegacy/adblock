//
//  RBDatabase.h
//  RadBlock
//
//  Created by Mike Pulaski on 23/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RBWhitelistEntry.h"
#import "RBDateRange.h"
#import "RBStat.h"


NS_ASSUME_NONNULL_BEGIN

#if TARGET_OS_OSX
extern NSNotificationName RBDatabaseDidAddEntryNotification;
extern NSNotificationName RBDatabaseDidUpdateEntryNotification;
extern NSNotificationName RBDatabaseDidRemoveEntryNotification;
extern NSString *const RBWhitelistEntryDomainKey;
extern NSString *const RBDatabaseLocalModificationKey;
#endif

NS_SWIFT_NAME(RadBlockDatabase)

@interface RBDatabase : NSObject <NSCopying>
@property(class,readonly) RBDatabase *sharedDatabase;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFileURL:(NSURL *)fileURL NS_DESIGNATED_INITIALIZER;

@property(nonatomic,readonly) NSURL *fileURL;

#pragma mark - Whitelist

- (void)whitelistEntryForDomain:(NSString *)domain completionHandler:(void(^)(RBWhitelistEntry *__nullable, NSError *__nullable))completionHandler;
- (void)writeWhitelistEntryForDomain:(NSString *)domain usingBlock:(nullable void(^)(RBMutableWhitelistEntry*, BOOL*))block completionHandler:(void(^)(RBWhitelistEntry *__nullable, NSError *__nullable))completionHandler;

- (void)removeWhitelistEntryForDomain:(NSString *)domain completionHandler:(void(^)(NSError *__nullable))completionHandler;
- (void)removeWhitelistEntriesForDomains:(NSArray *)domains completionHandler:(void(^)(NSError *__nullable))completionHandler;

typedef NS_ENUM(short, RBWhitelistEntrySortOrder) {
    RBWhitelistEntrySortOrderDomain,
    RBWhitelistEntrySortOrderCreateDate
};
- (void)whitelistEntryEnumeratorForGroup:(nullable NSString *)group domain:(nullable NSString *)domain sortOrder:(RBWhitelistEntrySortOrder)sortOrder completionHandler:(void(^)(NSEnumerator <RBWhitelistEntry*>*__nullable, NSError*__nullable))completionHandler;

#pragma mark - Stats

 - (void)incrementStatWithName:(NSString *)name by:(NSUInteger)delta completionHandler:(nullable void(^)(NSError *__nullable))completionHandler;
 - (void)getStatsInDateRange:(RBDateRange *)dateRange completionHandler:(void(^)(NSArray<RBStat *> *__nullable, NSError *__nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END
