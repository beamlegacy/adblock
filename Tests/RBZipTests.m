//
//  RBZipTests.m
//  RadBlockTests
//
//  Created by Mike Pulaski on 06/11/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RBZip.h"
#import "RBUtils.h"
#import "RBDigest.h"


@interface RBZipTests : XCTestCase

@end


@implementation RBZipTests {
    NSURL *_tempDirectoryURL;
}

- (void)setUp {
    self.continueAfterFailure = NO;
    _tempDirectoryURL = RBCreateTemporaryDirectory(NULL);
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtURL:_tempDirectoryURL error:NULL];
}

- (void)testUnzipSuccess {
    NSURL *input = [[NSBundle bundleForClass:[self class]] URLForResource:@"kith" withExtension:@"gz"];
    NSURL *output = [_tempDirectoryURL URLByAppendingPathComponent:@"kith.jpg" isDirectory:NO];
    NSError *error = nil;
    
    XCTAssertTrue([RBZip inflateContentsOfFileURL:input toFileURL:output error:&error], @"%@", error);
    XCTAssertEqualObjects([RBDigest MD5HashOfFileURL:output error:NULL], @"bac8b8eeeecd7a48317c02d953d04a31");
}

- (void)testUnzipBadInput {
    NSURL *kith = [NSURL fileURLWithPath:@"/no/such/path"];
    NSURL *output = [_tempDirectoryURL URLByAppendingPathComponent:@"kith.jpg" isDirectory:NO];
    NSError *error = nil;
    XCTAssertFalse([RBZip inflateContentsOfFileURL:kith toFileURL:output error:&error]);
    XCTAssertEqualObjects(error.domain, NSCocoaErrorDomain);
    XCTAssertEqual(error.code, NSFileReadUnknownError);
    XCTAssertEqualObjects(error.userInfo[NSFilePathErrorKey], output.path);
}

- (void)testUnzipBadOutput {
    NSURL *kith = [[NSBundle bundleForClass:[self class]] URLForResource:@"kith" withExtension:@"gz"];
    NSURL *output = [NSURL fileURLWithPath:@"/no/such/path"];
    NSError *error = nil;
    XCTAssertFalse([RBZip inflateContentsOfFileURL:kith toFileURL:output error:&error]);
    XCTAssertEqualObjects(error.domain, NSCocoaErrorDomain);
    XCTAssertEqual(error.code, NSFileWriteUnknownError);
    XCTAssertEqualObjects(error.userInfo[NSFilePathErrorKey], output.path);
}

@end
