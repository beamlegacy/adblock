//
//  RBFilterBuilderTests.m
//  RadBlockTests
//
//  Created by Mikey on 16/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RBFilterBuilder.h"

@interface RBFilterBuilderTests : XCTestCase
@end

static NSURL *tempDirectoryURL  = nil;
static NSArray<NSURL*> *ruleFileURLs = nil;
static int rulesPerFile = 1000;

@implementation RBFilterBuilderTests

+ (void)setUp {
    NSURL *currentBundleURL = [NSBundle bundleForClass:[self class]].bundleURL;
    tempDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory inDomain:NSUserDomainMask appropriateForURL:currentBundleURL create:YES error:NULL];
    
    NSMutableArray *fileURLs = [NSMutableArray array];
    
    for (int i = 0; i < 5; i++) {
        NSMutableArray *mockRules = [NSMutableArray array];
        
        for (int j = 0; j < rulesPerFile; j++) {
            [mockRules addObject:@{
                @"trigger":@{@"url-filter":[[NSUUID UUID] UUIDString]},
                @"action":@{@"type":@"block"}
            }];
        }
        
        NSURL *url = [tempDirectoryURL URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
        [[NSJSONSerialization dataWithJSONObject:mockRules options:0 error:NULL] writeToURL:url atomically:YES];
        [fileURLs addObject:url];
    }
    
    ruleFileURLs = [fileURLs copy];
}

+ (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtURL:tempDirectoryURL error:NULL];
}

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
}

- (void)testEmpty {
    XCTestExpectation *build = [self expectationWithDescription:@"build"];
    
    [RBFilterBuilder temporaryBuilderForFileURLs:@[] completionHandler:^(RBFilterBuilder *builder, NSError *error) {
        XCTAssertNotNil(builder.outputURL, @"%@", error);
        [build fulfill];
    }];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAsync {
    XCTestExpectation *build = [self expectationWithDescription:@"build"];
    
    [RBFilterBuilder temporaryBuilderForFileURLs:ruleFileURLs completionHandler:^(RBFilterBuilder *builder, NSError *error) {
        NSData *data = [NSData dataWithContentsOfURL:builder.outputURL options:0 error:&error];
        XCTAssertNotNil(data, @"%@", error);
        
        NSArray *decodedData = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        XCTAssertNotNil(decodedData, @"%@", error);

        XCTAssertEqual(rulesPerFile * ruleFileURLs.count, decodedData.count);
        
        [build fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAsyncCancel {
    XCTestExpectation *build = [self expectationWithDescription:@"build"];
    
    [[RBFilterBuilder temporaryBuilderForFileURLs:ruleFileURLs completionHandler:^(RBFilterBuilder *builder, NSError *error) {
        XCTAssertEqualObjects(error.domain, NSCocoaErrorDomain, @"%@", error);
        XCTAssertEqual(error.code, NSUserCancelledError, @"%@", error);
        
        [build fulfill];
    }] cancel];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testAsyncError {
    XCTestExpectation *build = [self expectationWithDescription:@"build"];
    NSArray<NSURL*> *badRules = [ruleFileURLs arrayByAddingObject:[NSURL fileURLWithPath:@"/not/a/valid/file"]];
    
    [RBFilterBuilder temporaryBuilderForFileURLs:badRules completionHandler:^(RBFilterBuilder *builder, NSError *error) {
        XCTAssertNil(builder.outputURL);
        XCTAssertEqualObjects(error.domain, NSCocoaErrorDomain, @"%@", error);
        XCTAssertEqual(error.code, NSFileNoSuchFileError, @"%@", error);
        
        [build fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
