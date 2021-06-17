//
//  ContentBlockerRequestHandler.m
//  ContentBlocker
//
//  Created by Mike Pulaski on 29/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBContentBlocker.h"
#import "RBAllowlistEntry.h"
#import "RBContentBlocker.h"
#import "NSString+IDNA.h"
#import "RBDatabase.h"
#import "RBFilterBuilder.h"
#import "RBFilterGroup.h"
#import "RBUtils.h"

@interface _RBAllowlistEntryGroupedEnumerator : NSEnumerator
- (instancetype)initWithEnumerator:(NSEnumerator<RBAllowlistEntry *> *)enumerator;
@end


@implementation RBContentBlocker

- (instancetype)initWithFilterGroup:(RBFilterGroup *)filterGroup allowList:(RBDatabase *)allowList {
    self = [super init];
    if (self == nil)
        return nil;
    
    _filterGroup = filterGroup;
    _allowList = allowList;
    _rulesFileURL = filterGroup.fileURL;
    _maxNumberOfRules = 50000;
    _allowListGroupSize = 200;
    
    return self;
}

- (void)writeRulesWithCompletionHandler:(void (^)(NSURL*, NSError *))handler {
    [self _writeRulesWithCompletionHandler:^(NSURL *tempURL, NSError *error) {
        if (error == nil) {
            // Move rules to their final place
            RBMoveFileURL(tempURL, self.rulesFileURL, &error);
        } else {
            // Remove temp file
            [[NSFileManager defaultManager] removeItemAtURL:tempURL error:NULL];
        }
        
        if (error != nil) {
            NSLog(@"Warning: could not compile rules: %@", error);
        }
        
        // Finish; use rules at destURL if present regardless of error if it exists (it's better than nothing)
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.rulesFileURL.path]) {
            handler(self.rulesFileURL, nil);
        } else {
            handler([[NSBundle mainBundle] URLForResource:@"blockerList" withExtension:@"json"], nil);
        }
    }];
}

#pragma mark - Rules / Building

- (void)_writeRulesWithCompletionHandler:(void(^)(NSURL *, NSError *))completionHandler {
    [RBFilterBuilder temporaryBuilderForFileURLs:@[_filterGroup.fileURL] completionHandler:^(RBFilterBuilder *builder, NSError *error) {
        if (error != nil) {
            return completionHandler(nil, error);
        }
        
        // Assume that the server doesn't allow us to configure rule sets which exceed our limit
        __block NSUInteger ruleCount = self.filterGroup.numberOfRules;
        NSUInteger maxNumberOfRules = self.maxNumberOfRules;
        NSUInteger allowlistGroupSize = self.allowListGroupSize;
        
        // Block until we add our allowList entries so that the temporary builder doesn't get discarded
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        [self->_allowList allowlistEntryEnumeratorForGroup:self.filterGroup.name domain:nil sortOrder:RBAllowlistEntrySortOrderDomain completionHandler:^(NSEnumerator<RBAllowlistEntry *> *entryEnumerator, NSError *error) {
            if (error == nil) {
                NSEnumerator<NSArray<RBAllowlistEntry*>*> *domainEnumerator = [[_RBAllowlistEntryGroupedEnumerator alloc] initWithEnumerator:entryEnumerator];
                NSArray<RBAllowlistEntry*> *domainGroup = nil;
                NSMutableArray<RBAllowlistEntry *> *entryBuffer = [NSMutableArray arrayWithCapacity:allowlistGroupSize];
                
                while (error == nil && (domainGroup = domainEnumerator.nextObject) && ruleCount < maxNumberOfRules) {
                    if (_allowlistEntriesAreDisjointed(domainGroup)) {
                        [builder appendRule:[self _ignoreRuleForDisjointedEntries:domainGroup] error:&error];
                        ruleCount++;
                        continue;
                    }
                    
                    for (RBAllowlistEntry *entry in domainGroup) {
                        if (!entry.enabled) {
                            continue;
                        }
                        
                        [entryBuffer addObject:entry];
                        
                        if (entryBuffer.count >= allowlistGroupSize) {
                            [builder appendRule:[self _ignoreRuleForEntries:entryBuffer] error:&error];
                            ruleCount++;
                            [entryBuffer removeAllObjects];
                        }
                    }
                }
                
                if (entryBuffer.count > 0 && ruleCount < maxNumberOfRules) {
                    [builder appendRule:[self _ignoreRuleForEntries:entryBuffer] error:&error];
                    ruleCount++;
                }
            }
            
            [builder flush];
            
            completionHandler(builder.outputURL, error);
            
            dispatch_semaphore_signal(semaphore);
        }];
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }];
}

- (NSDictionary *)_ignoreRuleForEntries:(NSArray<RBAllowlistEntry*> *)entries {
    NSAssert(entries.count > 0, @"Empty rules can cause unexpected behavior");
    
    NSMutableArray *encodedDomains = [NSMutableArray arrayWithCapacity:entries.count];
    for (RBAllowlistEntry *entry in entries) {
        [encodedDomains addObject:[@"*" stringByAppendingString:entry.domain.idnaEncodedString]];
    }
    
    return @{
        @"action": @{ @"type": @"ignore-previous-rules" },
        @"trigger": @{ @"url-filter": @".*", @"if-domain": encodedDomains },
    };
}

static BOOL _allowlistEntriesAreDisjointed(NSArray<RBAllowlistEntry *> *entries) {
    if (entries.count == 0) {
        return NO;
    }
    
    NSString *firstEntryDomain = entries.firstObject.domain.idnaEncodedString;
    NSString *encodedRootDomain = RBRootDomain(firstEntryDomain);
    
    if (entries.firstObject.isEnabled && [encodedRootDomain isEqualToString:firstEntryDomain]) {
        for (RBAllowlistEntry *entry in entries) {
            if (!entry.enabled) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (NSDictionary *)_ignoreRuleForDisjointedEntries:(NSArray<RBAllowlistEntry*> *)entries {
    NSAssert(entries.count > 0, @"Empty rules can cause unexpected behavior");
    
    NSMutableArray *encodedDomains = [NSMutableArray arrayWithCapacity:entries.count];
    for (RBAllowlistEntry *entry in entries) {
        if (!entry.enabled) {
            [encodedDomains addObject:entry.domain.idnaEncodedString];
        }
    }
    
    NSString *encodedRootDomain = RBRootDomain(entries.firstObject.domain).idnaEncodedString;
    NSString *rootDomainFilter = [NSString stringWithFormat:@"^[htpsw]+:\\/\\/([a-z0-9-]+\\.)*%@[/:&?]?", [NSRegularExpression escapedPatternForString:encodedRootDomain]];
    
    return @{
        @"action": @{ @"type": @"ignore-previous-rules" },
        @"trigger": @{ @"url-filter": rootDomainFilter, @"unless-domain": encodedDomains },
    };
}

@end


@implementation _RBAllowlistEntryGroupedEnumerator {
    NSEnumerator *_original;
    RBAllowlistEntry *_buffer;
    BOOL _eof;
}

- (instancetype)initWithEnumerator:(NSEnumerator<RBAllowlistEntry *> *)enumerator {
    self = [super init];
    if (self == nil)
        return nil;
    
    _original = enumerator;
    
    return self;
}

- (nullable NSArray <RBAllowlistEntry *> *)nextObject {
    if (_eof) {
        return nil;
    }
    
    RBAllowlistEntry *currentEntry = _buffer ?: [_original nextObject];
    if (currentEntry == nil) {
        return nil;
    }
    
    _buffer = nil;
    
    NSMutableArray *group = [NSMutableArray arrayWithObject:currentEntry];
    NSString *domain = RBRootDomain(currentEntry.domain);
    
    while ((currentEntry = [_original nextObject])) {
        NSString *currentDomain = RBRootDomain(currentEntry.domain);
        if ([currentDomain caseInsensitiveCompare:domain] != NSOrderedSame) {
            _buffer = currentEntry;
            break;
        }
        
        [group addObject:currentEntry];
    }
    
    _eof = (_buffer == nil);
    
    return group;
}

@end
