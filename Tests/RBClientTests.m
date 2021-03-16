//
//  RBClientTests.m
//  RadBlockTests
//
//  Created by Mike Pulaski on 09/11/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <CloudKit/CloudKit.h>

#import "RBMockClient.h"
#import "RBDigest.h"
#import "RBFilter+Mock.h"
#import "RBFilterGroup-Private.h"
#import "RBUtils.h"

@interface RBClientTests : XCTestCase
@end

@implementation RBClientTests {
    NSURL *_tempDirectoryURL;
    RBMockClient *_mockClient;
    RBFilterGroup *_adGroup;
}

- (void)setUp {
    self.continueAfterFailure = NO;
    
    _tempDirectoryURL = RBCreateTemporaryDirectory(NULL);
    _adGroup = [[RBAdsFilterGroup alloc] _initWithFileURL:[_tempDirectoryURL URLByAppendingPathComponent:@"ads"]];
    _mockClient = [RBMockClient new];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtURL:_tempDirectoryURL error:NULL];
    
    [_mockClient invalidate];
    _mockClient = nil;
    _adGroup = nil;
}

#pragma mark - CloudKit

- (void)testCloudKitFetchRules {
    NSMutableArray *localFilters = [NSMutableArray array];
    [localFilters addObject:[RBFilter mockFilterWithGroup:@"ads" rules:@[@{}, @{}, @{}]]];
    [localFilters addObject:[RBFilter mockFilterWithGroup:@"privacy" rules:@[@{}]]];
    [localFilters addObject:[[RBFilter mockFilterWithGroup:@"ads" rules:@[@{}]] copyByMergingPropertyList:@{@"language": @"fr"}]];
    
    [_mockClient mockFilters:localFilters];
    
    XCTestExpectation *fetch = [self expectationWithDescription:@"fetch"];
    [_mockClient fetchFilterRulesForGroup:_adGroup outputDirectory:_tempDirectoryURL completionHandler:^(RBFilterGroupRules *filterRules, NSError *error) {
        XCTAssertNotNil(filterRules, @"%@", error);
        XCTAssertEqual(filterRules.count, 1);
        
        NSURL *rulesURL = filterRules.allValues.firstObject;
        RBFilter *filter = filterRules.allKeys.firstObject;
        
        XCTAssertEqualObjects(filter.record[@"compression"], @"deflate");
        XCTAssertEqualObjects([RBDigest MD5HashOfFileURL:rulesURL error:NULL], filter.md5);
        XCTAssertEqual([[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:rulesURL] options:0 error:NULL] count], 3);
        
        [fetch fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testCloudKitFetchError {
    XCTestExpectation *fetch = [self expectationWithDescription:@"fetch"];

    NSError *expectedError = [NSError errorWithDomain:CKErrorDomain code:CKErrorServiceUnavailable userInfo:nil];

    RBFilter *filter = [RBFilter mockFilterWithGroup:@"ads" rules:nil];
    [_mockClient mockError:expectedError forFilter:filter];

    [_mockClient fetchFilterRulesForGroup:_adGroup outputDirectory:_tempDirectoryURL completionHandler:^(RBFilterGroupRules *filterRules, NSError *error) {
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, expectedError.domain, @"%@", error);
        XCTAssertEqual(error.code, expectedError.code, @"%@", error);

        [fetch fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

#pragma mark - HTTPS

- (void)testServerFetchRules {
    _mockClient.cloudKitEnabled = NO;

    NSMutableArray<RBFilter*> *localFilters = [NSMutableArray array];
    [localFilters addObject:[RBFilter mockFilterWithGroup:@"ads" rules:@[@{}, @{}, @{}]]];
    [localFilters addObject:[RBFilter mockFilterWithGroup:@"privacy" rules:@[@{}]]];
    [localFilters addObject:[[RBFilter mockFilterWithGroup:@"ads" rules:@[@{}]] copyByMergingPropertyList:@{@"language": @"fr"}]];

    [_mockClient mockFilters:localFilters];

    XCTestExpectation *fetch = [self expectationWithDescription:@"fetch"];
    [_mockClient fetchFilterRulesForGroup:_adGroup outputDirectory:_tempDirectoryURL completionHandler:^(RBFilterGroupRules *filterRules, NSError *error) {
        XCTAssertNotNil(filterRules, @"%@", error);
        XCTAssertEqual(filterRules.count, 1);

        NSURL *rulesURL = filterRules.allValues.firstObject;
        RBFilter *filter = filterRules.allKeys.firstObject;

        XCTAssertEqualObjects([RBDigest MD5HashOfFileURL:rulesURL error:NULL], filter.md5);
        XCTAssertEqual([[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:rulesURL] options:0 error:NULL] count], 3);

        [fetch fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testServerFetchCache {
    _mockClient.cloudKitEnabled = NO;

    RBFilter *filter = [RBFilter mockFilterWithGroup:@"ads" rules:@[@{}, @{}, @{}]];
    [_mockClient mockFilters:@[filter]];

    NSString *filterDownloadPath = [@"/filter/" stringByAppendingString:filter.uniqueIdentifier];
    RBMockClientHandler downloadHandler = [_mockClient handlerForPath:filterDownloadPath];
    XCTAssertNotNil(downloadHandler, @"Expected download handler");

    __block NSUInteger numDownloads = 0;

    [_mockClient handlePath:filterDownloadPath usingBlock:^(int * _Nonnull status, NSDictionary * _Nonnull __autoreleasing * _Nonnull headers, NSData * _Nonnull __autoreleasing * _Nonnull data) {
        numDownloads++;
        downloadHandler(status, headers, data);
    }];

    XCTestExpectation *fetch = [self expectationWithDescription:@"fetch"];
    [_mockClient fetchFilterRulesForGroup:_adGroup outputDirectory:_tempDirectoryURL completionHandler:^(RBFilterGroupRules *filterRules, NSError *error) {
        XCTAssertNotNil(filterRules, @"%@", error);
        XCTAssertEqual(filterRules.count, 1);

        NSURL *rulesURL = filterRules.allValues.firstObject;

        XCTAssertEqualObjects([RBDigest MD5HashOfFileURL:rulesURL error:NULL], filter.md5);
        XCTAssertEqual([[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:rulesURL] options:0 error:NULL] count], 3);

        [fetch fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertEqual(numDownloads, 1);

    XCTestExpectation *cachedFetch = [self expectationWithDescription:@"fetch"];

    [_mockClient fetchFilterRulesForGroup:_adGroup outputDirectory:_tempDirectoryURL completionHandler:^(RBFilterGroupRules *filterRules, NSError *error) {
        XCTAssertNotNil(filterRules, @"%@", error);
        XCTAssertEqual(filterRules.count, 1);

        NSURL *rulesURL = filterRules.allValues.firstObject;

        XCTAssertEqualObjects([RBDigest MD5HashOfFileURL:rulesURL error:NULL], filter.md5);
        XCTAssertEqual([[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:rulesURL] options:0 error:NULL] count], 3);

        [cachedFetch fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];

    XCTAssertEqual(numDownloads, 1);

    filter = [filter copyOutOfSync];
    [_mockClient mockFilters:@[filter]];

    downloadHandler = [_mockClient handlerForPath:filterDownloadPath];
    XCTAssertNotNil(downloadHandler, @"Expected download handler");

    [_mockClient handlePath:filterDownloadPath usingBlock:^(int * _Nonnull status, NSDictionary * _Nonnull __autoreleasing * _Nonnull headers, NSData * _Nonnull __autoreleasing * _Nonnull data) {
        numDownloads++;
        downloadHandler(status, headers, data);
    }];

    XCTestExpectation *cachedNewFetch = [self expectationWithDescription:@"fetch"];

    [_mockClient fetchFilterRulesForGroup:_adGroup outputDirectory:_tempDirectoryURL completionHandler:^(RBFilterGroupRules *filterRules, NSError *error) {
        XCTAssertNotNil(filterRules, @"%@", error);
        XCTAssertEqual(filterRules.count, 1);

        NSURL *rulesURL = filterRules.allValues.firstObject;

        XCTAssertEqualObjects([RBDigest MD5HashOfFileURL:rulesURL error:NULL], filter.md5);
        XCTAssertEqualObjects([NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:rulesURL] options:0 error:NULL], filter.rulesObject);

        [cachedNewFetch fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
    XCTAssertEqual(numDownloads, 2);
}

- (void)testServerFetchBadContent {
    _mockClient.cloudKitEnabled = NO;

    XCTestExpectation *fetch = [self expectationWithDescription:@"fetch"];

    [_mockClient handlePath:@"/filters" usingBlock:^(int* status, NSDictionary** headers, NSData** body) {
        *headers = @{@"Content-Type": @"text/html"};
    }];

    [_mockClient fetchFilterRulesForGroup:_adGroup outputDirectory:_tempDirectoryURL completionHandler:^(RBFilterGroupRules *filterRules, NSError *error) {
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, NSURLErrorDomain);
        XCTAssertEqual(error.code, NSURLErrorBadServerResponse);
        XCTAssertTrue([error.localizedDescription containsString:@"text/html"], @"%@", error.localizedDescription);

        [fetch fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testServerFetchBadCode {
    _mockClient.cloudKitEnabled = NO;

    XCTestExpectation *fetch = [self expectationWithDescription:@"fetch"];

    [_mockClient handlePath:@"/filters" usingBlock:^(int* status, NSDictionary** headers, NSData** body) {
        *status = 404;
    }];

    [_mockClient fetchFilterRulesForGroup:_adGroup outputDirectory:_tempDirectoryURL completionHandler:^(RBFilterGroupRules *filterRules, NSError *error) {
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, NSURLErrorDomain);
        XCTAssertEqual(error.code, NSURLErrorBadServerResponse);
        XCTAssertTrue([error.localizedDescription containsString:@"404"], @"%@", error.localizedDescription);

        [fetch fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testServerRedirectError {
    _mockClient.cloudKitEnabled = NO;

    XCTestExpectation *fetch = [self expectationWithDescription:@"fetch"];

    [_mockClient handlePath:@"/filters" usingBlock:^(int* status, NSDictionary** headers, NSData** body) {
        *status = 302;
        *headers = @{@"Location": @"/wow2"};
    }];

    [_mockClient fetchFilterRulesForGroup:_adGroup outputDirectory:_tempDirectoryURL completionHandler:^(RBFilterGroupRules *filterRules, NSError *error) {
        XCTAssertNotNil(error, "%@", filterRules);
        XCTAssertEqualObjects(error.domain, NSURLErrorDomain);
        XCTAssertEqual(error.code, NSURLErrorBadServerResponse);
        XCTAssertTrue([error.localizedDescription containsString:@"302"], @"%@", error.localizedDescription);

        [fetch fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
