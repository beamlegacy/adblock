//
//  RBSQLiteTests.m
//  RadBlockTests
//
//  Created by Mike Pulaski on 27/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RBSQLite.h"
#import "RBUtils.h"


@interface RBSQLiteTests : XCTestCase

@end

@implementation RBSQLiteTests {
    dispatch_queue_t _concurrentQueue;
}

- (void)setUp {
    _concurrentQueue = _concurrentQueue ?: dispatch_queue_create("net.youngdynasty.radblock-tests.sqlite-queue", DISPATCH_QUEUE_CONCURRENT_WITH_AUTORELEASE_POOL);
    self.continueAfterFailure = NO;
}

- (void)testPool {
    XCTestExpectation *open = [self expectationWithDescription:@"open"];
    open.expectedFulfillmentCount = 2;
    
    RBSQLitePoolRef pool = RBSQLitePoolCreate(2, ^sqlite3 *{
        sqlite3 *db = NULL;
        XCTAssertEqual(sqlite3_open(":memory:", &db), SQLITE_OK);
        
        [open fulfill];
        
        return db;
    });
    
    [self addTeardownBlock:^{
        RBSQLitePoolDrain(pool);
        RBSQLitePoolFree(pool);
    }];
    
    XCTestExpectation *getPut = [self expectationWithDescription:@"get/put"];
    getPut.expectedFulfillmentCount = 5;

    for (int i = 0; i < 5; i++) {
        dispatch_async(_concurrentQueue, ^{
            RBSQLitePoolPut(pool, RBSQLitePoolGet(pool));
            [getPut fulfill];
        });
    }
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testExecutePrepareAndScan {
    sqlite3 *db = NULL;
    [self addTeardownBlock:^{ sqlite3_close(db); }];
    
    XCTAssertEqual(sqlite3_open(":memory:", &db), SQLITE_OK);
    
    int status = RBSQLiteExecute(db, @"CREATE TABLE a (id int, text string, created date)");
    XCTAssertEqual(status, SQLITE_DONE, @"%s", sqlite3_errstr(status));
    
    for (int i = 0; i < 5; i++) {
        status = RBSQLiteExecute(db, @"INSERT INTO a (id, text, created) VALUES ($1, $2, $3)", @(i), @"...", [NSDate date]);
        XCTAssertEqual(status, SQLITE_DONE, @"%s", sqlite3_errstr(status));
    }
    
    sqlite3_stmt *stmt = NULL;
    [self addTeardownBlock:^{
        sqlite3_finalize(stmt);
    }];
    
    status = RBSQLitePrepare(db, &stmt, @"SELECT id, text, created FROM a");
    XCTAssertEqual(status, SQLITE_OK, @"%s", sqlite3_errstr(status));
    
    int row = 0;
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        XCTAssertEqualObjects(RBSQLiteScanNumber(stmt, 0), @(row++));
        XCTAssertEqualObjects(RBSQLiteScanString(stmt, 1), @"...");
        XCTAssertNotNil(RBSQLiteScanDate(stmt, 2));
    }
    XCTAssertEqual(row, 5);
}

- (void)testTransaction {
    sqlite3 *db = NULL;
    sqlite3_stmt *stmt = NULL;
    [self addTeardownBlock:^{
        sqlite3_finalize(stmt);
        sqlite3_close(db);
    }];
    
    XCTAssertEqual(sqlite3_open(":memory:", &db), SQLITE_OK);
    
    int status = RBSQLiteExecute(db, @"CREATE TABLE a (id int)");
    XCTAssertEqual(status, SQLITE_DONE, @"%s", sqlite3_errstr(status));

    status = RBSQLitePrepare(db, &stmt, @"SELECT COUNT(*) FROM a");
    XCTAssertEqual(status, SQLITE_OK, @"%s", sqlite3_errstr(status));

    status = RBSQLiteTransaction(db, ^int{
        int status = RBSQLiteExecute(db, @"INSERT INTO a (id) VALUES (?)", @(0));
        XCTAssertEqual(status, SQLITE_DONE, @"%s", sqlite3_errstr(status));
        return SQLITE_ABORT;
    });
    
    XCTAssertEqual(status, SQLITE_ABORT, @"%s", sqlite3_errstr(status));

    XCTAssertEqual(sqlite3_reset(stmt), SQLITE_OK);
    XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW);
    XCTAssertEqual(sqlite3_column_int(stmt, 0), 0);

    status = RBSQLiteTransaction(db, ^int{
        return RBSQLiteExecute(db, @"INSERT INTO a (id) VALUES (?)", @(1));
    });
    XCTAssertEqual(status, SQLITE_DONE, @"%s", sqlite3_errstr(status));
    
    XCTAssertEqual(sqlite3_reset(stmt), SQLITE_OK);
    XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW);
    XCTAssertEqual(sqlite3_column_int(stmt, 0), 1);
}

@end
