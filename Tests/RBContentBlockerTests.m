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
    RBDatabase *whitelist = [[RBDatabase alloc] initWithFileURL:[_tempDirectoryURL URLByAppendingPathComponent:@"whitelist"]];
    _contentBlocker = [[RBContentBlocker alloc] initWithFilterGroup:mockGroup whitelist:whitelist];
    _contentBlocker.rulesFileURL = [_tempDirectoryURL URLByAppendingPathComponent:@"rules.json"];
}

- (void)tearDown {
    [_contentBlocker.whitelist _drainPool];
    
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
    
    // Whitelist should have no effect (whitelist is inclusive to rules)
    XCTestExpectation *whitelist = [self expectationWithDescription:@"whitelist"];
    [_contentBlocker.whitelist writeWhitelistEntryForDomain:@"yolo.com" usingBlock:^(RBMutableWhitelistEntry *entry, BOOL *stop) {
        XCTAssertFalse(entry.existsInStore);
        entry.groupNames = @[self->_contentBlocker.filterGroup.name];
    } completionHandler:^(RBWhitelistEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"%@", error);
        [whitelist fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];

    load = [self expectationWithDescription:@"load with whitelist"];
    
    [self _readRulesUsingBlock:^(_RBContentBlockerRules rules, NSError *error) {
        XCTAssertEqualObjects(rules, placeholderRules, @"%@", error);
        [load fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testWithoutWhitelist {
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
    NSArray *whitelistDomains = @[@"aaa.com", @"bbb.com", @"ccc.com"];
    XCTestExpectation *whitelist = [self expectationWithDescription:@"whitelist"];
    whitelist.expectedFulfillmentCount = whitelistDomains.count;
    
    NSUInteger idx = 0;
    for (NSString *domain in whitelistDomains) {
        BOOL enabled = idx++ % 2 == 0;
        
        [_contentBlocker.whitelist writeWhitelistEntryForDomain:domain usingBlock:^(RBMutableWhitelistEntry *entry, BOOL *stop) {
            XCTAssertFalse(entry.existsInStore);
            entry.enabled = enabled;
        } completionHandler:^(RBWhitelistEntry *entry, NSError *error) {
            XCTAssertNotNil(entry, @"%@", error);
            [whitelist fulfill];
        }];
    }
    
    [self waitForExpectationsWithTimeout:1 handler:nil];

    _contentBlocker.maxNumberOfRules = dummyRules.count + whitelistDomains.count - 1;
    _contentBlocker.whitelistGroupSize = 1;
    
    NSError *error = nil;
    NSData *existingRuleData = [NSJSONSerialization dataWithJSONObject:dummyRules options:0 error:&error];
    XCTAssertNotNil(existingRuleData, @"%@", error);
    XCTAssertTrue([existingRuleData writeToURL:_contentBlocker.filterGroup.fileURL options:0 error:&error], @"%@", error);
    
    XCTestExpectation *read = [self expectationWithDescription:@"read"];
    [self _readRulesUsingBlock:^(_RBContentBlockerRules rules, NSError *error) {
        XCTAssertNotNil(rules, @"%@", error);
        XCTAssertLessThan(rules.count, dummyRules.count + whitelistDomains.count);
        XCTAssertEqual(rules.count, self->_contentBlocker.maxNumberOfRules);

        [read fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testWhitelistUniformEntries {
    NSArray *domains = @[@"cAsE.cOm", @"🔥"];
    
    XCTestExpectation *whitelist = [self expectationWithDescription:@"whitelist"];
    whitelist.expectedFulfillmentCount = domains.count;
    
    // Insert domains synchronously to preserve ordering
    __block void(^insertDomain)(NSEnumerator *enumerator) = nil;
    insertDomain = ^(NSEnumerator *enumerator) {
        NSString *domain = enumerator.nextObject;
        if (domain == nil) {
            insertDomain = nil;
            return;
        }
        
        [self->_contentBlocker.whitelist writeWhitelistEntryForDomain:domain usingBlock:^(RBMutableWhitelistEntry *entry, BOOL *stop) {
            XCTAssertFalse(entry.existsInStore);
            entry.groupNames = @[self->_contentBlocker.filterGroup.name];
        } completionHandler:^(RBWhitelistEntry *entry, NSError *error) {
            XCTAssertNotNil(entry, @"%@", error);
            insertDomain(enumerator);
            [whitelist fulfill];
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
    [_contentBlocker.whitelist writeWhitelistEntryForDomain:domains.lastObject usingBlock:^(RBMutableWhitelistEntry *entry, BOOL *stop) {
        XCTAssertTrue(entry.existsInStore);
        entry.enabled = NO;
    } completionHandler:^(RBWhitelistEntry *entry, NSError *error) {
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

- (void)testWhitelistDisjointedEntries {
    NSArray *domains = @[@"aaa.com", @"alt-1.domain.com", @"alt-2.domain.com", @"alt-3.domain.com", @"alt-4.domain.com"];
    XCTestExpectation *whitelist = [self expectationWithDescription:@"whitelist"];
    whitelist.expectedFulfillmentCount = domains.count;
    
    NSUInteger idx = 0;
    for (NSString *domain in domains) {
        BOOL enabled = idx++ % 2 == 0;
        
        [_contentBlocker.whitelist writeWhitelistEntryForDomain:domain usingBlock:^(RBMutableWhitelistEntry *entry, BOOL *stop) {
            XCTAssertFalse(entry.existsInStore);
            entry.enabled = enabled;
        } completionHandler:^(RBWhitelistEntry *entry, NSError *error) {
            XCTAssertNotNil(entry, @"%@", error);
            [whitelist fulfill];
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
    
    [_contentBlocker.whitelist writeWhitelistEntryForDomain:@"domain.com" usingBlock:nil completionHandler:^(RBWhitelistEntry *entry, NSError *error) {
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
