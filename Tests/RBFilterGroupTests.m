//
//  RBFilterGroupTests.m
//  RadBlockTests
//
//  Created by Mike Pulaski on 24/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RBFilterGroup-Private.h"
#import "RBFilter+Mock.h"
#import "RBUtils.h"


@interface RBFilterGroupTests : XCTestCase

@end


@implementation RBFilterGroupTests {
    NSURL *_tempDirectoryURL;

    RBFilterGroup *_adGroup;
    RBRegionalFilterGroup *_regionalGroup;
    RBPrivacyFilterGroup *_privacyGroup;
    RBAnnoyanceFilterGroup *_annoyanceGroup;
}

- (void)setUp {
    _tempDirectoryURL = RBCreateTemporaryDirectory(NULL);

    _adGroup = [[RBAdsFilterGroup alloc] _initWithFileURL:[_tempDirectoryURL URLByAppendingPathComponent:@"ads"]];
    _regionalGroup = [[RBRegionalFilterGroup alloc] _initWithFileURL:[_tempDirectoryURL URLByAppendingPathComponent:@"regional"]];
    _privacyGroup = [[RBPrivacyFilterGroup alloc] _initWithFileURL:[_tempDirectoryURL URLByAppendingPathComponent:@"privacy"]];
    _annoyanceGroup = [[RBAnnoyanceFilterGroup alloc] _initWithFileURL:[_tempDirectoryURL URLByAppendingPathComponent:@"annoyance"]];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtURL:_tempDirectoryURL error:NULL];
    
    _adGroup = nil;
    _privacyGroup = nil;
    _regionalGroup = nil;
    _annoyanceGroup = nil;
}

- (void)testReduceAdGroup {
    NSMutableArray *localFilters = [NSMutableArray array];
    [localFilters addObject:[RBFilter mockFilterWithGroup:@"ads" rules:nil]];
    [localFilters addObject:[RBFilter mockFilterWithGroup:@"annoyance" rules:nil]];
    [localFilters addObject:[RBFilter mockFilterWithGroup:@"privacy" rules:nil]];
    
    [localFilters addObject:[[RBFilter mockFilterWithGroup:@"ads" rules:nil] copyByMergingPropertyList:@{@"language": @"fr"}]];
    
    NSArray *groupFilters = [_adGroup reduceFilters:localFilters];
    XCTAssertGreaterThan(groupFilters.count, 0);
    XCTAssertEqual([groupFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"group != 'ads'"]].count, (NSUInteger)0);
    XCTAssertEqual([groupFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"selector != ''"]].count, (NSUInteger)0);
    XCTAssertEqual([groupFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"language != ''"]].count, (NSUInteger)0);
}

- (void)testReducePrivacyGroup {
    NSMutableArray *localFilters = [NSMutableArray array];

    [localFilters addObject:[RBFilter mockFilterWithGroup:@"ads" rules:nil]];
    [localFilters addObject:[RBFilter mockFilterWithGroup:@"annoyance" rules:nil]];
    [localFilters addObject:[RBFilter mockFilterWithGroup:@"privacy" rules:nil]];
    
    [localFilters addObject:[[RBFilter mockFilterWithGroup:@"privacy" rules:nil] copyByMergingPropertyList:@{@"language": @"fr"}]];
    [localFilters addObject:[[RBFilter mockFilterWithGroup:@"privacy" rules:nil] copyByMergingPropertyList:@{@"selector": @"social"}]];
    [localFilters addObject:[[RBFilter mockFilterWithGroup:@"privacy" rules:nil] copyByMergingPropertyList:@{@"selector": @"cookies"}]];

    NSArray *groupFilters = [_privacyGroup reduceFilters:localFilters];
    XCTAssertGreaterThan(groupFilters.count, 0);
    XCTAssertEqual([groupFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"group != 'privacy'"]].count, (NSUInteger)0);
    XCTAssertEqual([groupFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"selector != ''"]].count, (NSUInteger)0);
    XCTAssertEqual([groupFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"language != ''"]].count, (NSUInteger)0);
    
    _privacyGroup.socialMediaFilterEnabled = YES;
    
    NSArray *socialFilters = [_privacyGroup reduceFilters:localFilters];
    XCTAssertGreaterThan(socialFilters.count, groupFilters.count);
    XCTAssertEqual([socialFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"group != 'privacy'"]].count, (NSUInteger)0);
    XCTAssertEqual([socialFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"language != ''"]].count, (NSUInteger)0);
    XCTAssertEqual([socialFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"selector != '' AND selector != 'social'"]].count, (NSUInteger)0);
    
    NSMutableSet *socialFilterSuperset = [NSMutableSet setWithArray:groupFilters];
    [socialFilterSuperset intersectSet:[NSSet setWithArray:socialFilters]];
    XCTAssertTrue([socialFilterSuperset isEqualToSet:[NSSet setWithArray:groupFilters]]);
}

- (void)testReduceAnnoyanceGroup {
    NSMutableArray *localFilters = [NSMutableArray array];

    [localFilters addObject:[RBFilter mockFilterWithGroup:@"ads" rules:nil]];
    [localFilters addObject:[RBFilter mockFilterWithGroup:@"annoyance" rules:nil]];
    [localFilters addObject:[RBFilter mockFilterWithGroup:@"privacy" rules:nil]];
    
    [localFilters addObject:[[RBFilter mockFilterWithGroup:@"annoyance" rules:nil] copyByMergingPropertyList:@{@"language": @"fr"}]];
    [localFilters addObject:[[RBFilter mockFilterWithGroup:@"annoyance" rules:nil] copyByMergingPropertyList:@{@"selector": @"cookies"}]];

    NSArray *groupFilters = [_annoyanceGroup reduceFilters:localFilters];
    XCTAssertGreaterThan(groupFilters.count, 0);
    XCTAssertEqual([groupFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"group != 'annoyance'"]].count, (NSUInteger)0);
    XCTAssertEqual([groupFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"selector != ''"]].count, (NSUInteger)0);
    XCTAssertEqual([groupFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"language != ''"]].count, (NSUInteger)0);
    
    _annoyanceGroup.cookiesFilterEnabled = YES;
    
    NSArray *cookieFilters = [_annoyanceGroup reduceFilters:localFilters];
    XCTAssertGreaterThan(cookieFilters.count, groupFilters.count);
    XCTAssertEqual([cookieFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"group != 'annoyance'"]].count, (NSUInteger)0);
    XCTAssertEqual([cookieFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"language != ''"]].count, (NSUInteger)0);
    XCTAssertEqual([cookieFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"selector != '' AND selector != 'cookies'"]].count, (NSUInteger)0);
    
    NSMutableSet *cookiesFilterSuperset = [NSMutableSet setWithArray:groupFilters];
    [cookiesFilterSuperset intersectSet:[NSSet setWithArray:cookieFilters]];
    XCTAssertTrue([cookiesFilterSuperset isEqualToSet:[NSSet setWithArray:groupFilters]]);
}

- (void)testReduceRegionalGroup {
    NSMutableArray *localFilters = [NSMutableArray array];

    [localFilters addObject:[RBFilter mockFilterWithGroup:@"ads" rules:nil]];
    [localFilters addObject:[RBFilter mockFilterWithGroup:@"annoyance" rules:nil]];
    [localFilters addObject:[RBFilter mockFilterWithGroup:@"privacy" rules:nil]];
    
    [localFilters addObject:[[RBFilter mockFilterWithGroup:@"ads" rules:nil] copyByMergingPropertyList:@{@"language": @"fr"}]];
    [localFilters addObject:[[RBFilter mockFilterWithGroup:@"ads" rules:nil] copyByMergingPropertyList:@{@"language": @"de"}]];
    
    _regionalGroup.languageCodes = @[];
    XCTAssertEqual([[_regionalGroup reduceFilters:localFilters] count], 0);
    
    _regionalGroup.languageCodes = @[@"fr"];
    
    NSArray *frenchFilters = [_regionalGroup reduceFilters:localFilters];
    XCTAssertEqual(frenchFilters.count, 1);
    XCTAssertEqual([frenchFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"group != 'ads'"]].count, (NSUInteger)0);
    XCTAssertEqual([frenchFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"language != 'fr'"]].count, (NSUInteger)0);
    
    _regionalGroup.languageCodes = @[@"de"];
    
    NSArray *germanFilters = [_regionalGroup reduceFilters:localFilters];
    XCTAssertEqual(germanFilters.count, 1);
    XCTAssertEqual([germanFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"group != 'ads'"]].count, (NSUInteger)0);
    XCTAssertEqual([germanFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"language != 'de'"]].count, (NSUInteger)0);
    
    _regionalGroup.languageCodes = @[@"fr", @"de"];
    
    NSArray *frenchGermanFilters = [_regionalGroup reduceFilters:localFilters];
    XCTAssertEqual(frenchGermanFilters.count, 2);
    XCTAssertEqual([frenchGermanFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"group != 'ads'"]].count, (NSUInteger)0);
    XCTAssertEqual([frenchGermanFilters filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"language != 'de' AND language != 'fr'"]].count, (NSUInteger)0);
}

@end
