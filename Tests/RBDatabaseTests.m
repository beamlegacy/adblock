#pragma clang diagnostic ignored "-Warc-retain-cycles"

//
//  RBDatabaseTests.m
//  RadBlockTests
//
//  Created by Mike Pulaski on 27/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RBFilterGroup.h"
#import "RBFilterGroup-Private.h"
#import "RBSQLite.h"
#import "RBUtils.h"
#import "RBDatabase-Private.h"


@interface RBDatabaseTests : XCTestCase
@end


@implementation RBDatabaseTests {
    RBFilterGroup *_adGroup;
    RBFilterGroup *_privacyGroup;
    RBFilterGroup *_emptyGroup;

    RBDatabase *_database;
    NSURL *_tempDirectoryURL;
}

- (void)setUp {
    self.continueAfterFailure = NO;
    
    _tempDirectoryURL = RBCreateTemporaryDirectory(NULL);
    _adGroup = [[RBAdsFilterGroup alloc] _initWithFileURL:[_tempDirectoryURL URLByAppendingPathComponent:@"ads"]];
    _privacyGroup = [[RBPrivacyFilterGroup alloc] _initWithFileURL:[_tempDirectoryURL URLByAppendingPathComponent:@"privacy"]];
    _emptyGroup = [[RBPrivacyFilterGroup alloc] _initWithFileURL:[_tempDirectoryURL URLByAppendingPathComponent:@"empty"]];
    _database = [[RBDatabase alloc] initWithFileURL:[_tempDirectoryURL URLByAppendingPathComponent:@"database"]];
}

- (void)tearDown {
    [_database _drainPool];
    [[NSFileManager defaultManager] removeItemAtURL:_tempDirectoryURL error:NULL];
    
    // Force dealloc
    _database = nil;
}

- (void)testAllowlistAddEntry {
    NSString *domain = [NSStringFromSelector(_cmd) stringByAppendingString:@".app"];
    XCTestExpectation *add = [self expectationWithDescription:@"add"];
    
    [_database writeAllowlistEntryForDomain:domain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        entry.groupNames = @[@"ads", @"privacy"];
    } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"%@", error);
        XCTAssertEqualObjects(entry.domain, domain);
        XCTAssertNotNil(entry.dateCreated);
        XCTAssertNotNil(entry.dateModified);
        XCTAssertTrue(([entry.groupNames isEqualToArray:@[@"ads", @"privacy"]]), "%@", entry.groupNames);

        [add fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTestExpectation *groupEntries = [self expectationWithDescription:@"entries"];
    groupEntries.expectedFulfillmentCount = 3;
    
    [_database allowlistEntryEnumeratorForGroup:_adGroup.name domain:nil sortOrder:0 completionHandler:^(NSEnumerator<RBAllowlistEntry *> *entries, NSError *error) {
        XCTAssertNotNil(entries, @"%@", error);
        XCTAssertEqualObjects([entries.nextObject domain], domain);
        [groupEntries fulfill];
    }];
    
    [_database allowlistEntryEnumeratorForGroup:_privacyGroup.name domain:nil sortOrder:0 completionHandler:^(NSEnumerator<RBAllowlistEntry *> *entries, NSError *error) {
        XCTAssertNotNil(entries, @"%@", error);
        XCTAssertEqualObjects([entries.nextObject domain], domain);
        [groupEntries fulfill];
    }];
    
    [_database allowlistEntryEnumeratorForGroup:_emptyGroup.name domain:nil sortOrder:0 completionHandler:^(NSEnumerator<RBAllowlistEntry *> *entries, NSError *error) {
        XCTAssertNotNil(entries, @"%@", error);
        XCTAssertNil(entries.nextObject);
        [groupEntries fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllowlistAddDuplicateEntry {
    NSString *domain = [NSStringFromSelector(_cmd) stringByAppendingString:@".app"];
    XCTestExpectation *add = [self expectationWithDescription:@"add"];
    
    [_database writeAllowlistEntryForDomain:domain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        entry.groupNames = @[@"ads", @"privacy"];
    } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"%@", error);
        XCTAssertEqualObjects(entry.domain, domain);
        XCTAssertNotNil(entry.dateCreated);
        XCTAssertNotNil(entry.dateModified);
        XCTAssertTrue(([entry.groupNames isEqualToArray:@[@"ads", @"privacy"]]), "%@", entry.groupNames);

        [add fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTestExpectation *dupe = [self expectationWithDescription:@"add"];
    
    [_database writeAllowlistEntryForDomain:domain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        XCTAssertTrue(entry.existsInStore);
    } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(entry.domain, domain);
        XCTAssertTrue(([entry.groupNames isEqualToArray:@[@"ads", @"privacy"]]), "%@", entry.groupNames);

        [dupe fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllowlistEntryLookup {
    NSString *domain = [NSStringFromSelector(_cmd) stringByAppendingString:@".app"];
    XCTestExpectation *lookup = [self expectationWithDescription:@"lookup"];

    [_database writeAllowlistEntryForDomain:domain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        entry.groupNames = @[@"ads", @"privacy"];
    } completionHandler:^(RBAllowlistEntry *insertedEntry, NSError *error) {
        [self->_database allowlistEntryForDomain:domain completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
            XCTAssertNotNil(entry, @"%@", error);
            XCTAssertEqualObjects(entry.domain, domain);
            XCTAssertNotNil(entry.dateCreated);
            XCTAssertNotNil(entry.dateModified);
            XCTAssertTrue(([entry.groupNames isEqualToArray:@[@"ads", @"privacy"]]), "%@", entry.groupNames);
            
            [lookup fulfill];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllowlistEntryLookupSubdomain {
    NSString *domain = [NSStringFromSelector(_cmd) stringByAppendingString:@".app"];
    NSString *subdomain = [@"wow." stringByAppendingString:domain];
    
    XCTestExpectation *write = [self expectationWithDescription:@"write"];

    [_database writeAllowlistEntryForDomain:domain usingBlock:nil completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"%@", error);
        [write fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTestExpectation *lookup = [self expectationWithDescription:@"lookup"];
    lookup.expectedFulfillmentCount = 2;
    
    [_database allowlistEntryForDomain:domain completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"%@", error);
        XCTAssertEqualObjects(entry.domain, domain);
        [lookup fulfill];
    }];

    [_database allowlistEntryForDomain:subdomain completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNil(entry);
        XCTAssertNil(error);
        [lookup fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllowlistEntryEnumeratorSubdomains {
    NSString *rootDomain = [NSStringFromSelector(_cmd) stringByAppendingString:@".app"];
    NSString *otherDomain = [NSStringFromSelector(_cmd) stringByAppendingString:@"Alt.app"];
    NSArray<NSString*> *subdomains = @[[@"wow1." stringByAppendingString:rootDomain], [@"wow2." stringByAppendingString:rootDomain], [@"wow3." stringByAppendingString:rootDomain]];
    
    XCTestExpectation *writes = [self expectationWithDescription:@"writes"];
    writes.expectedFulfillmentCount = subdomains.count + 2;
    
    for (NSString *domain in [@[rootDomain, otherDomain] arrayByAddingObjectsFromArray:subdomains]) {
        [_database writeAllowlistEntryForDomain:domain usingBlock:nil completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
            XCTAssertNotNil(entry, @"%@", error);
            [writes fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTestExpectation *lookupOther = [self expectationWithDescription:@"lookup other"];
    
    [_database allowlistEntryEnumeratorForGroup:nil domain:otherDomain sortOrder:RBAllowlistEntrySortOrderCreateDate completionHandler:^(NSEnumerator<RBAllowlistEntry *> *entries, NSError *error) {
        XCTAssertNotNil(entries, @"%@", error);
        XCTAssertEqualObjects([[entries allObjects] valueForKey:@"domain"], @[otherDomain]);
        [lookupOther fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTestExpectation *lookup = [self expectationWithDescription:@"lookup"];
    
    [_database allowlistEntryEnumeratorForGroup:nil domain:rootDomain sortOrder:RBAllowlistEntrySortOrderDomain completionHandler:^(NSEnumerator<RBAllowlistEntry *> *entries, NSError *error) {
        XCTAssertNotNil(entries, @"%@", error);
        XCTAssertEqualObjects([[entries allObjects] valueForKey:@"domain"], [@[rootDomain] arrayByAddingObjectsFromArray:subdomains]);
        [lookup fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTestExpectation *groups = [self expectationWithDescription:@"read/write group"];
    [_database writeAllowlistEntryForDomain:rootDomain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *cancel) {
        entry.groupNames = @[@"ok"];
    } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"%@", error);
        
        [self->_database allowlistEntryEnumeratorForGroup:nil domain:rootDomain sortOrder:RBAllowlistEntrySortOrderDomain completionHandler:^(NSEnumerator<RBAllowlistEntry *> *entryEnumerator, NSError *error) {
            XCTAssertNotNil(entryEnumerator, @"%@", error);
            
            NSArray<RBAllowlistEntry*> *entries = [entryEnumerator allObjects];
            XCTAssertGreaterThan(entries.count, 2);
            XCTAssertTrue([[entries.firstObject groupNames] isEqualToArray:@[@"ok"]]);
            XCTAssertNil([entries.lastObject groupNames]);
        }];
        
        [groups fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllowlistEntryEnumeratorSorting {
    XCTestExpectation *insert = [self expectationWithDescription:@"insert"];
    insert.expectedFulfillmentCount = 9;
    
    NSMutableArray *insertedDomains = [NSMutableArray arrayWithCapacity:10];
    
    // Insert serially so that the create dates are ordered (and reverse order by name)
    __block void(^doInsert)(int);
    doInsert = ^(int idx) {
        NSString *domain = nil;
        
        switch (idx) {
            case 1:
                domain = @"bbb.com";
                break;
            case 2:
                domain = @"ccc.com";
                break;
            case 3: case 4: case 5:
                domain = [NSString stringWithFormat:@"%d.ccc.com", idx];
                break;
            default:
                domain = [NSString stringWithFormat:@"d%d.com", idx];
                break;
        }
        
        [self->_database writeAllowlistEntryForDomain:domain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
            entry.groupNames = @[@"ads"];
        } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
            XCTAssertNotNil(entry, @"%@", error);
            
            [insertedDomains addObject:entry.domain];
            
            if (idx > 1) {
                doInsert(idx - 1);
            } else {
                doInsert = nil;
            }
            
            [insert fulfill];
        }];
    };
    doInsert((int)insert.expectedFulfillmentCount);
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqual(insertedDomains.count, insert.expectedFulfillmentCount);
    
    XCTestExpectation *lookup = [self expectationWithDescription:@"lookup"];
    lookup.expectedFulfillmentCount = 2;
    
    [_database allowlistEntryEnumeratorForGroup:nil domain:nil sortOrder:RBAllowlistEntrySortOrderCreateDate completionHandler:^(NSEnumerator<RBAllowlistEntry *> *entries, NSError *error) {
        XCTAssertNotNil(entries, @"%@", error);
        XCTAssertEqualObjects([[entries allObjects] valueForKey:@"domain"], insertedDomains);
        [lookup fulfill];
    }];
    
    [_database allowlistEntryEnumeratorForGroup:nil domain:nil sortOrder:RBAllowlistEntrySortOrderDomain completionHandler:^(NSEnumerator<RBAllowlistEntry *> *entries, NSError *error) {
        XCTAssertNotNil(entries, @"%@", error);
        XCTAssertEqualObjects([[entries allObjects] valueForKey:@"domain"], [[insertedDomains reverseObjectEnumerator] allObjects]);
        
        [lookup fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllowlistWildcardGroup {
    XCTestExpectation *add = [self expectationWithDescription:@"add"];
    NSString *domain = [NSStringFromSelector(_cmd) stringByAppendingString:@".app"];

    [_database writeAllowlistEntryForDomain:domain usingBlock:nil completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"%@", error);
        XCTAssertEqualObjects(entry.domain, domain);
        XCTAssertNotNil(entry.dateCreated);
        XCTAssertNotNil(entry.dateModified);
        XCTAssertEqual(entry.groupNames, nil);

        [add fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTestExpectation *enumerate = [self expectationWithDescription:@"enumerate"];
    
    [_database allowlistEntryEnumeratorForGroup:_adGroup.name domain:nil sortOrder:0 completionHandler:^(NSEnumerator<RBAllowlistEntry *> *entries, NSError *error) {
        XCTAssertNotNil(entries, @"%@", error);
        
        RBAllowlistEntry *entry = entries.nextObject;
        
        XCTAssertEqualObjects(entry.domain, domain);
        XCTAssertEqual(entry.groupNames, nil);
        
        [enumerate fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllowlistAddBadEntries {
    XCTestExpectation *add = [self expectationWithDescription:@"add"];
    add.expectedFulfillmentCount = 2;
    
    [_database writeAllowlistEntryForDomain:@"" usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        entry.groupNames = @[@"ads", @"privacy"];
    } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNil(entry);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, RBSQLiteErrorDomain);
        XCTAssertEqual(error.code, SQLITE_CONSTRAINT);
        
        [add fulfill];
    }];
    
    [_database writeAllowlistEntryForDomain:@"youngdynasty.net" usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        entry.groupNames = @[];
    } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNil(entry);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, RBSQLiteErrorDomain);
        XCTAssertEqual(error.code, SQLITE_CONSTRAINT);
        
        [add fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllowlistRemoveEntry {
    XCTestExpectation *add = [self expectationWithDescription:@"add"];
    NSString *domain = [NSStringFromSelector(_cmd) stringByAppendingString:@".app"];
    
    [_database writeAllowlistEntryForDomain:domain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        entry.groupNames = @[@"ads", @"privacy"];
    } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"%@", error);
        [add fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTestExpectation *remove = [self expectationWithDescription:@"add"];
    
    [_database removeAllowlistEntryForDomain:domain completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"%@", error);

        [remove fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTestExpectation *groupEntries = [self expectationWithDescription:@"entries"];
    groupEntries.expectedFulfillmentCount = 3;
    
    for (RBFilterGroup *group in @[_adGroup, _privacyGroup, _emptyGroup]) {
        [_database allowlistEntryEnumeratorForGroup:group.name domain:nil sortOrder:0 completionHandler:^(NSEnumerator<RBAllowlistEntry *> *entries, NSError *error) {
            XCTAssertNotNil(entries, @"%@", error);
            XCTAssertNil(entries.nextObject);
            [groupEntries fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTestExpectation *cascade = [self expectationWithDescription:@"cascade"];
    
    [_database _accessConnectionUsingBlock:^(sqlite3 *conn) {
        sqlite3_stmt *stmt = NULL;
        int status = RBSQLitePrepare(conn, &stmt, @"SELECT COUNT(*) FROM exception_group WHERE exception_domain = $1", domain);
        
        XCTAssertEqual(status, SQLITE_OK, @"%@", NSErrorFromSQLiteStatus(status));
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW, @"%@", NSErrorFromSQLiteStatus(status));
        XCTAssertEqualObjects(RBSQLiteScanNumber(stmt, 0), @(0), @"%@", NSErrorFromSQLiteStatus(status));
        
        sqlite3_finalize(stmt);
        [cascade fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllowlistUpdateEntry {
    XCTestExpectation *add = [self expectationWithDescription:@"add"];
    NSString *domain = [NSStringFromSelector(_cmd) stringByAppendingString:@".app"];
    
    __block NSDate *originalCreationDate = nil;
    __block NSDate *originalModificationDate = nil;
    
    [_database writeAllowlistEntryForDomain:domain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        XCTAssertFalse(entry.existsInStore);
        entry.groupNames = @[@"ads", @"privacy"];
    } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"%@", error);
        originalCreationDate = entry.dateCreated;
        originalModificationDate = entry.dateModified;

        [add fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTestExpectation *update = [self expectationWithDescription:@"update"];
    
    [_database writeAllowlistEntryForDomain:domain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        XCTAssertTrue(entry.existsInStore);
        entry.groupNames = @[@"privacy"];
    } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"%@", error);
        XCTAssertEqualObjects(originalCreationDate, entry.dateCreated);
        XCTAssertEqual([originalModificationDate compare:entry.dateModified], NSOrderedAscending);
        XCTAssertTrue(entry.isEnabled);
        
        XCTAssertTrue(([entry.groupNames isEqualToArray:@[@"privacy"]]), "%@", entry.groupNames);
        
        [update fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTestExpectation *lookup = [self expectationWithDescription:@"lookup"];
    
    [_database allowlistEntryForDomain:domain completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertEqual(entry, entry);
        XCTAssertTrue(([entry.groupNames isEqualToArray:@[@"privacy"]]), "%@", entry.groupNames);

        [lookup fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTestExpectation *disable = [self expectationWithDescription:@"disable"];

    [_database writeAllowlistEntryForDomain:domain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        entry.enabled = NO;
    } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertFalse(entry.isEnabled);
        [disable fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllowlistUpdateBadEntries {
    XCTestExpectation *add = [self expectationWithDescription:@"add"];
    NSString *domain = [NSStringFromSelector(_cmd) stringByAppendingString:@".app"];

    [_database writeAllowlistEntryForDomain:domain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        entry.groupNames = @[@"ads", @"privacy"];
    } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"%@", error);
        [add fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTestExpectation *update = [self expectationWithDescription:@"update"];
    
    [_database writeAllowlistEntryForDomain:domain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        entry.groupNames = @[];
    } completionHandler:^(RBAllowlistEntry *newEntry, NSError *error) {
        XCTAssertNil(newEntry);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, RBSQLiteErrorDomain);
        XCTAssertEqual(error.code, SQLITE_CONSTRAINT);
        
        [update fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllowlistWriteCancel {
    XCTestExpectation *update = [self expectationWithDescription:@"update"];
    
    [_database writeAllowlistEntryForDomain:[[NSUUID UUID] UUIDString] usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        XCTAssertFalse(entry.existsInStore);
        (*stop) = YES;
    } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNil(entry);
        XCTAssertNil(error);

        [update fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllowlistNotifications {
    RBDatabase *otherAllowlist = [[RBDatabase alloc] initWithFileURL:_database.fileURL];
    NSString *domain = [NSStringFromSelector(_cmd) stringByAppendingString:@".app"];
    
    [self expectationForNotification:RBDatabaseDidAddEntryNotification object:_database handler:^BOOL(NSNotification *notification) {
        XCTAssertEqualObjects(notification.userInfo[RBAllowlistEntryDomainKey], domain);
        XCTAssertEqualObjects(notification.userInfo[RBDatabaseLocalModificationKey], @(YES));
        return YES;
    }];
    
    [self expectationForNotification:RBDatabaseDidAddEntryNotification object:otherAllowlist handler:^BOOL(NSNotification *notification) {
        XCTAssertEqualObjects(notification.userInfo[RBAllowlistEntryDomainKey], domain);
        XCTAssertEqualObjects(notification.userInfo[RBDatabaseLocalModificationKey], @(NO));
        return YES;
    }];
    
    [_database writeAllowlistEntryForDomain:domain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        entry.groupNames = @[@"ads", @"privacy"];
    } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"%@", error);
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];

    [self expectationForNotification:RBDatabaseDidUpdateEntryNotification object:_database handler:^BOOL(NSNotification *notification) {
        return [notification.userInfo[RBDatabaseLocalModificationKey] boolValue] && [notification.userInfo[RBAllowlistEntryDomainKey] isEqualToString:domain];
    }];
    
    [self expectationForNotification:RBDatabaseDidUpdateEntryNotification object:otherAllowlist handler:^BOOL(NSNotification *notification) {
        XCTAssertEqualObjects(notification.userInfo[RBAllowlistEntryDomainKey], domain);
        XCTAssertEqualObjects(notification.userInfo[RBDatabaseLocalModificationKey], @(NO));
        return YES;
    }];
    
    [_database writeAllowlistEntryForDomain:domain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        entry.groupNames = @[@"ads"];
    } completionHandler:^(RBAllowlistEntry *newEntry, NSError *error) {
        XCTAssertNil(error);
        XCTAssertTrue(([newEntry.groupNames isEqualToArray:@[@"ads"]]), "%@", newEntry.groupNames);
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];

    [self expectationForNotification:RBDatabaseDidRemoveEntryNotification object:_database handler:^BOOL(NSNotification *notification) {
        return [notification.userInfo[RBDatabaseLocalModificationKey] boolValue] && [notification.userInfo[RBAllowlistEntryDomainKey] isEqualToString:domain];
    }];

    [self expectationForNotification:RBDatabaseDidRemoveEntryNotification object:otherAllowlist handler:^BOOL(NSNotification *notification) {
        return ![notification.userInfo[RBDatabaseLocalModificationKey] boolValue] && [notification.userInfo[RBAllowlistEntryDomainKey] isEqualToString:domain];
    }];

    [_database removeAllowlistEntryForDomain:domain completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"%@", error);
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllowlistConcurrency {
    const int numInstances = 3;
    const int numReads = 10;
    const int numWrites = 10;
    
    XCTestExpectation *op = [self expectationWithDescription:@"operation"];
    op.expectedFulfillmentCount = numInstances * (numReads + numWrites);
    
    for (int i = 0; i < numInstances; i++) {
        RBDatabase *database = nil;
        
        if (i == 0) {
            database = _database;
        } else {
            database = [_database copy];
            [self addTeardownBlock:^{
                [database _drainPool];
            }];
        }
        NSMutableArray *domains = [NSMutableArray array];
        
        for (int j = 0; j < numWrites; j++) {
            [domains addObject:[[[NSUUID UUID] UUIDString] stringByAppendingString:@".com"]];
            
            [database writeAllowlistEntryForDomain:[domains lastObject] usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
                entry.groupNames = @[@"ads"];
            } completionHandler:^(RBAllowlistEntry *_, NSError *error) {
                XCTAssertNil(error, @"%d %d %@", i, j, [domains sortedArrayUsingSelector:@selector(compare:)]);
                [op fulfill];
            }];
        }

        for (int j = 0; j < numReads; j++) {
            [database allowlistEntryEnumeratorForGroup:_adGroup.name domain:nil sortOrder:0 completionHandler:^(NSEnumerator*_, NSError *error) {
                XCTAssertNil(error);
                [op fulfill];
            }];
        }
    }
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
    
    XCTestExpectation *count = [self expectationWithDescription:@"count"];
    
    [_database allowlistEntryEnumeratorForGroup:_adGroup.name domain:nil sortOrder:0 completionHandler:^(NSEnumerator<RBAllowlistEntry *>*entries, NSError *error) {
        XCTAssertNil(error, @"%@", error);
        XCTAssertEqual(entries.allObjects.count, numInstances*numWrites);
        
        [count fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark -

- (void)testIncrementStat {
    NSString *name = self.testRun.test.name;
    
    XCTestExpectation *incr = [self expectationWithDescription:@"increment"];
    incr.expectedFulfillmentCount = 2;
    
    for (int i = 0; i < incr.expectedFulfillmentCount; i++) {
        [_database incrementStatWithName:name by:1 completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"%@", error);
            [incr fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTestExpectation *lookup = [self expectationWithDescription:@"lookup"];

    [_database getStatsInDateRange:[RBDateRange today] completionHandler:^(NSArray<RBStat *>* stats, NSError *error) {
        XCTAssertEqual(stats.count, 1, @"%@", error);
        XCTAssertEqualObjects(stats.lastObject.name, name, @"%@", error);
        XCTAssertEqual(stats.lastObject.value, 2, @"%@", error);
        [lookup fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testStatRange {
    [self addTeardownBlock:^{ self->_database._statDate = nil; }];
    
    NSString *name = self.testRun.test.name;
    
    XCTestExpectation *incr = [self expectationWithDescription:@"increment"];
    incr.expectedFulfillmentCount = 4;
    
    [_database incrementStatWithName:name by:1 completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"%@", error);
        [incr fulfill];
    }];
    
    _database._statDate = [NSDate dateWithTimeIntervalSinceNow:6*-24*60*60];
    [_database incrementStatWithName:name by:1 completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"%@", error);
        [incr fulfill];
    }];

    _database._statDate = [NSDate dateWithTimeIntervalSinceNow:14*-24*60*60];
    [_database incrementStatWithName:name by:1 completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"%@", error);
        [incr fulfill];
    }];

    _database._statDate = [NSDate dateWithTimeIntervalSinceNow:31*-24*60*60];
    [_database incrementStatWithName:name by:1 completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"%@", error);
        [incr fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTestExpectation *lookup = [self expectationWithDescription:@"lookup"];
    lookup.expectedFulfillmentCount = 4;
    
    [_database getStatsInDateRange:[RBDateRange today] completionHandler:^(NSArray<RBStat *>* stats, NSError *error) {
        XCTAssertEqual(stats.count, 1, @"%@", error);
        XCTAssertEqual(stats.lastObject.value, 1, @"%@", error);
        [lookup fulfill];
    }];

    [_database getStatsInDateRange:[RBDateRange lastWeek] completionHandler:^(NSArray<RBStat *>* stats, NSError *error) {
        XCTAssertEqual(stats.count, 1, @"%@", error);
        XCTAssertEqual(stats.lastObject.value, 2, @"%@", error);
        [lookup fulfill];
    }];

    [_database getStatsInDateRange:[RBDateRange lastMonth] completionHandler:^(NSArray<RBStat *>* stats, NSError *error) {
        XCTAssertEqual(stats.count, 1, @"%@", error);
        XCTAssertEqual(stats.lastObject.value, 3, @"%@", error);
        [lookup fulfill];
    }];

    [_database getStatsInDateRange:[RBDateRange lastYear] completionHandler:^(NSArray<RBStat *>* stats, NSError *error) {
        XCTAssertEqual(stats.count, 1, @"%@", error);
        XCTAssertEqual(stats.lastObject.value, 4, @"%@", error);
        [lookup fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testStatConcurrency {
    const int numInstances = 3;
    const int numReads = 10;
    const int numWrites = 10;
    
    XCTestExpectation *op = [self expectationWithDescription:@"operation"];
    op.expectedFulfillmentCount = numInstances * (numReads + numWrites);

    NSMutableArray *names = [NSMutableArray arrayWithCapacity:numWrites];
    for (int i = 0; i < numWrites; i++) {
        [names addObject:[[NSUUID UUID] UUIDString]];
    }
    
    for (int i = 0; i < numInstances; i++) {
        RBDatabase *database = nil;
        
        if (i == 0) {
            database = _database;
        } else {
            database = [_database copy];
            [self addTeardownBlock:^{
                [database _drainPool];
            }];
        }

        for (int j = 0; j < numWrites; j++) {
            [database incrementStatWithName:names[j] by:1 completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"%d %d %@", i, j, [names sortedArrayUsingSelector:@selector(compare:)]);
                [op fulfill];
            }];
        }

        for (int j = 0; j < numReads; j++) {
            [database getStatsInDateRange:[RBDateRange lastMonth] completionHandler:^(NSArray<RBStat *> *stats, NSError *error) {
                XCTAssertNotNil(stats, @"%@", error);
                [op fulfill];
            }];
        }
    }
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
    
    XCTestExpectation *count = [self expectationWithDescription:@"count"];
    
    [_database getStatsInDateRange:[RBDateRange lastMonth] completionHandler:^(NSArray<RBStat *> *stats, NSError *error) {
        XCTAssertEqual(stats.count, numWrites, @"%@", error);
        
        for (RBStat *stat in stats) {
            XCTAssertEqual(stat.value, numInstances);
        }
        
        [count fulfill];
    }];
        
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
