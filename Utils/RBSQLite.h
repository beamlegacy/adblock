//
//  RBSQLite.h
//  RadBlock
//
//  Created by Mike Pulaski on 26/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <sqlite3.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern int RBSQLitePrepare(sqlite3 *db, sqlite3_stmt *_Nonnull*_Nullable stmt, NSString *query, ...);
extern int RBSQLiteExecute(sqlite3 *db, NSString *query, ...);
extern int RBSQLiteBind(sqlite3_stmt *stmt, ...);

/// Run a transaction using the given block.
/// The transaction will be committed if the block returns \c SQLITE_OK or \c SQLITE_DONE and will be reverted otherwise.
/// The status code returned by the block will be propogated when reverted, otherwise it will be the result of the commit.
extern int RBSQLiteTransaction(sqlite3 *db, int(^block)(void));

extern NSErrorDomain RBSQLiteErrorDomain;
extern NSError*__nullable NSErrorFromSQLiteStatus(int status);

extern NSDate*__nullable RBSQLiteScanDate(sqlite3_stmt *stmt, int column);
extern NSData*__nullable RBSQLiteScanData(sqlite3_stmt *stmt, int column);
extern NSNumber*__nullable RBSQLiteScanNumber(sqlite3_stmt *stmt, int column);
extern NSString*__nullable RBSQLiteScanString(sqlite3_stmt *stmt, int column);

#pragma mark - Resource sharing

typedef struct _RBSQLitePool RBSQLitePool;
typedef RBSQLitePool*__nullable RBSQLitePoolRef;

extern RBSQLitePoolRef RBSQLitePoolCreate(int capacity, sqlite3*(^constructorBlock)(void));
extern sqlite3* RBSQLitePoolGet(RBSQLitePoolRef pool);
extern void RBSQLitePoolPut(RBSQLitePoolRef pool, sqlite3 *db);
extern void RBSQLitePoolDrain(RBSQLitePoolRef pool);
extern void RBSQLitePoolFree(RBSQLitePoolRef pool);

NS_ASSUME_NONNULL_END
