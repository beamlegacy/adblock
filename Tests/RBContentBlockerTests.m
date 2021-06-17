//
//  RBContentBlockerTests.m
//  RadBlockTests
//
//  Created by Mike Pulaski on 01/11/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RBFilterGroup-Private.h"
#import "RBUtils.h"
#import "RBDatabase-Private.h"
#import "RBMockExtensionContext.h"
#import "NSString+IDNA.h"
#import "RBContentBlocker.h"


@interface RBContentBlockerTests : XCTestCase

@end

typedef NSArray<NSDictionary<NSString*, NSDictionary*>*>* _RBContentBlockerRules;

@implementation RBContentBlockerTests {
    NSURL *_tempDirectoryURL;
    RBContentBlocker *_contentBlocker;
}

static _RBContentBlockerRules placeholderRules;
static _RBContentBlockerRules dummyRules;

+ (void)setUp {
    NSError *error = nil;
    NSURL *placeholderURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"blockerList" withExtension:@"json"];
    NSAssert(placeholderURL != nil, @"%@", error);
    
    NSData *placeholderData = [NSData dataWithContentsOfURL:placeholderURL options:0 error:&error];
    NSAssert(placeholderData != nil, @"%@", error);
    
    placeholderRules = [NSJSONSerialization JSONObjectWithData:placeholderData options:0 error:&error];
    NSAssert(placeholderRules != nil, @"%@", error);
    
    dummyRules = @[@{
        @"action": @{ @"type": @"block" },
        @"trigger": @{ @"url-filter": @"existing-rule" },
    }];
}

- (void)setUp {
    self.continueAfterFailure = NO;
    
    _tempDirectoryURL = RBCreateTemporaryDirectory(NULL);
    
    RBFilterGroup *mockGroup = [[RBFilterGroup alloc] _initWithFileURL:[_tempDirectoryURL URLByAppendingPathComponent:@"group.json"]];
    RBDatabase *allowList = [[RBDatabase alloc] initWithFileURL:[_tempDirectoryURL URLByAppendingPathComponent:@"allowList"]];
    _contentBlocker = [[RBContentBlocker alloc] initWithFilterGroup:mockGroup allowList:allowList];
    _contentBlocker.rulesFileURL = [_tempDirectoryURL URLByAppendingPathComponent:@"rules.json"];
}

- (void)tearDown {
    [_contentBlocker.allowList _drainPool];
    
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtURL:_tempDirectoryURL error:&error];
    
    // Force dealloc
    _contentBlocker = nil;
}

- (void)_readRulesUsingBlock:(void(^)(_RBContentBlockerRules,NSError*))block {
    [_contentBlocker writeRulesWithCompletionHandler:^(NSURL *url, NSError *error){
        if (error != nil || url == nil) {
            return block(nil, error);
        }

        NSData *data = [NSData dataWithContentsOfURL:url];
        id rules = nil;
        if (error == nil) {
            rules = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        }
        block(rules, error);
    }];
}

- (void)testRulesPlaceholder {
    XCTestExpectation *load = [self expectationWithDescription:@"load"];
    
    [self _readRulesUsingBlock:^(_RBContentBlockerRules rules, NSError *error) {
        XCTAssertEqualObjects(rules, placeholderRules, @"%@", error);
        [load fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    // allowList should have no effect (allowList is inclusive to rules)
    XCTestExpectation *allowList = [self expectationWithDescription:@"allowList"];
    [_contentBlocker.allowList writeAllowlistEntryForDomain:@"yolo.com" usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        XCTAssertFalse(entry.existsInStore);
        entry.groupNames = @[self->_contentBlocker.filterGroup.name];
    } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"%@", error);
        [allowList fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];

    load = [self expectationWithDescription:@"load with allowList"];
    
    [self _readRulesUsingBlock:^(_RBContentBlockerRules rules, NSError *error) {
        XCTAssertEqualObjects(rules, placeholderRules, @"%@", error);
        [load fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testWithoutAllowlist {
    NSError *error = nil;
    NSData *existingRuleData = [NSJSONSerialization dataWithJSONObject:dummyRules options:0 error:&error];
    XCTAssertNotNil(existingRuleData, @"%@", error);
    XCTAssertTrue([existingRuleData writeToURL:_contentBlocker.filterGroup.fileURL options:0 error:&error], @"%@", error);
    
    XCTestExpectation *read = [self expectationWithDescription:@"read"];
    [self _readRulesUsingBlock:^(_RBContentBlockerRules rules, NSError *error) {
        XCTAssertNotNil(rules, @"%@", error);
        XCTAssertEqualObjects(rules, dummyRules);
        
        [read fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testMaxRules {
    NSArray *allowlistDomains = @[@"aaa.com", @"bbb.com", @"ccc.com"];
    XCTestExpectation *allowList = [self expectationWithDescription:@"allowList"];
    allowList.expectedFulfillmentCount = allowlistDomains.count;
    
    NSUInteger idx = 0;
    for (NSString *domain in allowlistDomains) {
        BOOL enabled = idx++ % 2 == 0;
        
        [_contentBlocker.allowList writeAllowlistEntryForDomain:domain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
            XCTAssertFalse(entry.existsInStore);
            entry.enabled = enabled;
        } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
            XCTAssertNotNil(entry, @"%@", error);
            [allowList fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:1 handler:nil];

    _contentBlocker.maxNumberOfRules = dummyRules.count + allowlistDomains.count - 1;
    _contentBlocker.allowListGroupSize = 1;
    
    NSError *error = nil;
    NSData *existingRuleData = [NSJSONSerialization dataWithJSONObject:dummyRules options:0 error:&error];
    XCTAssertNotNil(existingRuleData, @"%@", error);
    XCTAssertTrue([existingRuleData writeToURL:_contentBlocker.filterGroup.fileURL options:0 error:&error], @"%@", error);
    
    XCTestExpectation *read = [self expectationWithDescription:@"read"];
    [self _readRulesUsingBlock:^(_RBContentBlockerRules rules, NSError *error) {
        XCTAssertNotNil(rules, @"%@", error);
        XCTAssertLessThan(rules.count, dummyRules.count + allowlistDomains.count);
        XCTAssertEqual(rules.count, self->_contentBlocker.maxNumberOfRules);

        [read fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllowlistUniformEntries {
    NSArray *domains = @[@"cAsE.cOm", @"🔥"];
    
    XCTestExpectation *allowList = [self expectationWithDescription:@"allowList"];
    allowList.expectedFulfillmentCount = domains.count;
    
    // Insert domains synchronously to preserve ordering
    __block void(^insertDomain)(NSEnumerator *enumerator) = nil;
    insertDomain = ^(NSEnumerator *enumerator) {
        NSString *domain = enumerator.nextObject;
        if (domain == nil) {
            insertDomain = nil;
            return;
        }
        
        [self->_contentBlocker.allowList writeAllowlistEntryForDomain:domain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
            XCTAssertFalse(entry.existsInStore);
            entry.groupNames = @[self->_contentBlocker.filterGroup.name];
        } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
            XCTAssertNotNil(entry, @"%@", error);
            insertDomain(enumerator);
            [allowList fulfill];
        }];
    };
    insertDomain(domains.objectEnumerator);
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    NSError *error = nil;
    XCTAssertTrue([@"[1]" writeToURL:_contentBlocker.filterGroup.fileURL atomically:YES encoding:NSUTF8StringEncoding error:&error], @"%@", error);
    
    XCTestExpectation *read = [self expectationWithDescription:@"read"];

    [self _readRulesUsingBlock:^(_RBContentBlockerRules rules, NSError *error) {
        XCTAssertNotNil(rules, @"%@", error);
        XCTAssertEqual(rules.count, 2, @"Group rules should be preserved");
        
        XCTAssertEqualObjects(rules.lastObject[@"trigger"][@"url-filter"], @".*");
        
        NSMutableArray *expectedDomains = [NSMutableArray arrayWithCapacity:domains.count];
        
        for (NSString *domain in domains) {
            [expectedDomains addObject:[@"*" stringByAppendingString:[domain idnaEncodedString]]];
        }
        
        XCTAssertEqualObjects(rules.lastObject[@"trigger"][@"if-domain"], expectedDomains);

        [read fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    // Disable last entry
    XCTestExpectation *disable = [self expectationWithDescription:@"disable"];
    [_contentBlocker.allowList writeAllowlistEntryForDomain:domains.lastObject usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
        XCTAssertTrue(entry.existsInStore);
        entry.enabled = NO;
    } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"%@", error);
        [disable fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTestExpectation *readWithDisable = [self expectationWithDescription:@"read with disable"];

    [self _readRulesUsingBlock:^(_RBContentBlockerRules rules, NSError *error) {
        XCTAssertNotNil(rules, @"%@", error);
        XCTAssertEqual(rules.count, 2, @"Group rules should be preserved");
        
        XCTAssertEqualObjects(rules.lastObject[@"trigger"][@"url-filter"], @".*");
        XCTAssertEqualObjects(rules.lastObject[@"trigger"][@"if-domain"], @[[@"*" stringByAppendingString:[domains[0] idnaEncodedString]]]);

        [readWithDisable fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAllowlistDisjointedEntries {
    NSArray *domains = @[@"aaa.com", @"alt-1.domain.com", @"alt-2.domain.com", @"alt-3.domain.com", @"alt-4.domain.com"];
    XCTestExpectation *allowList = [self expectationWithDescription:@"allowList"];
    allowList.expectedFulfillmentCount = domains.count;
    
    NSUInteger idx = 0;
    for (NSString *domain in domains) {
        BOOL enabled = idx++ % 2 == 0;
        
        [_contentBlocker.allowList writeAllowlistEntryForDomain:domain usingBlock:^(RBMutableAllowlistEntry *entry, BOOL *stop) {
            XCTAssertFalse(entry.existsInStore);
            entry.enabled = enabled;
        } completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
            XCTAssertNotNil(entry, @"%@", error);
            [allowList fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    NSError *error = nil;
    XCTAssertTrue([@"[1]" writeToURL:_contentBlocker.filterGroup.fileURL atomically:YES encoding:NSUTF8StringEncoding error:&error], @"%@", error);
    
    XCTestExpectation *rootDisabled = [self expectationWithDescription:@"root domain disabled"];

    [self _readRulesUsingBlock:^(_RBContentBlockerRules rules, NSError *error) {
        XCTAssertNotNil(rules, @"%@", error);
        XCTAssertEqual(rules.count, 2, @"Group rules should be preserved: %@", rules);
        
        XCTAssertEqualObjects(rules[1][@"trigger"][@"if-domain"], (@[@"*aaa.com", @"*alt-2.domain.com", @"*alt-4.domain.com"]));
        XCTAssertEqualObjects(rules[1][@"trigger"][@"url-filter"], @".*");
        
        [rootDisabled fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTestExpectation *enableRoot = [self expectationWithDescription:@"enable root"];
    
    [_contentBlocker.allowList writeAllowlistEntryForDomain:@"domain.com" usingBlock:nil completionHandler:^(RBAllowlistEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"%@", error);
        [enableRoot fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTestExpectation *rootEnabled = [self expectationWithDescription:@"root domain enabled"];

    [self _readRulesUsingBlock:^(_RBContentBlockerRules rules, NSError *error) {
        XCTAssertNotNil(rules, @"%@", error);
        XCTAssertEqual(rules.count, 3, @"Group rules should be preserved: %@", rules);
        
        NSRegularExpression *domainFilter = [NSRegularExpression regularExpressionWithPattern:rules[1][@"trigger"][@"url-filter"] options:0 error:&error];
        XCTAssertNotNil(domainFilter, @"%@", error);
        XCTAssertTrue([[domainFilter matchesInString:@"https://domain.com" options:0 range:NSMakeRange(0, @"https://domain.com".length)] count] > 0);
        XCTAssertTrue([[domainFilter matchesInString:@"https://x-domain.com" options:0 range:NSMakeRange(0, @"https://x-domain.com".length)] count] == 0);
        
        XCTAssertEqualObjects(rules[1][@"trigger"][@"unless-domain"], (@[@"alt-1.domain.com", @"alt-3.domain.com"]));

        XCTAssertEqualObjects(rules[2][@"trigger"][@"url-filter"], @".*");
        XCTAssertEqualObjects(rules[2][@"trigger"][@"if-domain"], (@[@"*aaa.com"]));

        [rootEnabled fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testBadRuleData {
    NSError *error = nil;
    XCTAssertTrue([@"asdf" writeToURL:_contentBlocker.filterGroup.fileURL atomically:YES encoding:NSUTF8StringEncoding error:&error], @"%@", error);

    XCTestExpectation *read = [self expectationWithDescription:@"read"];
    [self _readRulesUsingBlock:^(_RBContentBlockerRules rules, NSError *error) {
        XCTAssertNotNil(rules, @"%@", error);
        XCTAssertEqualObjects(rules, placeholderRules);
        
        [read fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testErrorRecovery {
    NSError *error = nil;
    NSData *existingRuleData = [NSJSONSerialization dataWithJSONObject:dummyRules options:0 error:&error];
    XCTAssertNotNil(existingRuleData, @"%@", error);
    XCTAssertTrue([existingRuleData writeToURL:_contentBlocker.filterGroup.fileURL options:0 error:&error], @"%@", error);
    
    XCTestExpectation *read = [self expectationWithDescription:@"read"];
    [self _readRulesUsingBlock:^(_RBContentBlockerRules rules, NSError *error) {
        XCTAssertNotNil(rules, @"%@", error);
        XCTAssertEqualObjects(rules, dummyRules);
        
        [read fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    // Make sure we don't overwrite valid rules with bad rule data (or the placeholder)
    XCTAssertTrue([@"asdf" writeToURL:_contentBlocker.filterGroup.fileURL atomically:YES encoding:NSUTF8StringEncoding error:&error], @"%@", error);

    XCTestExpectation *readWithBadRules = [self expectationWithDescription:@"read with bad rules"];
    [self _readRulesUsingBlock:^(_RBContentBlockerRules rules, NSError *error) {
        XCTAssertNotNil(rules, @"%@", error);
        XCTAssertEqualObjects(rules, dummyRules);
        
        [readWithBadRules fulfill];
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
