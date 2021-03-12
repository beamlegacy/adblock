//
//  RBClient.m
//  rAdblock Manager
//
//  Created by Mikey on 16/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBClient-Private.h"
#import "RBDigest.h"
#import "RBUtils.h"
#import "RBFilterGroup-Private.h"
#import "RBZip.h"
#import "RBCodeSignature.h"


@interface RBClient()<NSURLSessionTaskDelegate>
@end


@implementation RBClient {
    CKDatabase *_database;
    NSURLSession *_session;
    dispatch_queue_t _downloadQueue;
}

+ (instancetype)defaultClient {
    static RBClient *defaultClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultClient = [[self alloc] init];
    });
    return defaultClient;
}

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;

    _cloudKitEnabled = YES;

    NSString *apiUrlString = NSProcessInfo.processInfo.environment[@"RADBLOCK_API_URL"];
    _url = apiUrlString != nil ? [NSURL URLWithString:apiUrlString] : [NSURL URLWithString:@"https://radblock.app/api"];
    _session = [NSURLSession sessionWithConfiguration:self._sessionConfiguration ?: NSURLSessionConfiguration.ephemeralSessionConfiguration delegate:self delegateQueue:nil];
    
    @try {
        _database = [[CKContainer containerWithIdentifier:@"iCloud.net.youngdynasty.radblock"] publicCloudDatabase];
    } @catch (NSException *exception) {
        NSNumber *errorCode = exception.userInfo ? RBKindOfClassOrNil(NSNumber, exception.userInfo[@"CKErrorCode"]) : nil;
        if (errorCode != nil && errorCode.intValue != CKErrorMissingEntitlement) {
            // Raise exception only if it's unrelated to entitlements (our test suite doesn't support / need the necessary entitlements)
            [exception raise];
        }

        _cloudKitEnabled = NO;
    }
    
    _downloadQueue = dispatch_queue_create("net.youngdynasty.radblock.filter.download", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
    
    return self;
}

#pragma mark -

- (NSProgress *)fetchFilterRulesForGroup:(RBFilterGroup *)group outputDirectory:(NSURL *)outputDirectoryURL completionHandler:(void(^)(RBFilterGroupRules*, NSError *))completionHandler {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:30];

    if (self.isCloudKitEnabled) {
        CKQuery *query = [[CKQuery alloc] initWithRecordType:@"Filter" predicate:group._filterPredicate];

        [progress addChild:[self _performQuery:query completionHandler:^(NSArray<CKRecord *> *records, NSError *error) {
            if (error != nil) {
                completionHandler(nil, error);
            } else {
                [progress addChild:[self _decompressRecords:records outputDirectory:outputDirectoryURL completionHandler:completionHandler] withPendingUnitCount:10];
            }
        }] withPendingUnitCount:20];
    } else {
        // Assume our caching layer will be smart about this...
        [progress addChild:[self _fetchFiltersWithCompletionHandler:^(NSArray<RBFilter *> *filters, NSError * _Nullable error) {
            if (error != nil) {
                completionHandler(nil, error);
            } else {
                [progress addChild:[self _downloadFilters:[group reduceFilters:filters]
                                          outputDirectory:outputDirectoryURL
                                        completionHandler:completionHandler] withPendingUnitCount:20];
            }
        }] withPendingUnitCount:10];
    }

    return progress;
}


#pragma mark - HTTP

- (NSProgress *)_downloadFilters:(NSArray<RBFilter *> *)filters outputDirectory:(NSURL *)outputDirectoryURL completionHandler:(void(^)(RBFilterGroupRules*, NSError *))completionHandler {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:filters.count + 1];
    dispatch_group_t downloadGroup = dispatch_group_create();

    __block NSMutableDictionary *results = [NSMutableDictionary dictionaryWithCapacity:filters.count];
    __block NSError *error = nil;

    // Use MD5 hashes to determine which filters need downloaded
    NSMutableArray *outOfSyncFilters = [NSMutableArray arrayWithCapacity:filters.count];

    for (RBFilter *filter in filters) {
        NSURL *destURL = [outputDirectoryURL URLByAppendingPathComponent:filter.uniqueIdentifier];
        NSString *md5 = [RBDigest MD5HashOfFileURL:destURL error:NULL];

        if (md5 == nil || ![md5 isEqualToString:filter.md5]) {
            [outOfSyncFilters addObject:filter];
        } else {
            results[filter] = destURL;
            progress.totalUnitCount -= 1;
        }
    }

    // Use a temporary directory so we can work atomically (we may otherwise produce corrupt output if canceled/errored while running)
    NSURL *tempDirectoryURL = nil;

    for (RBFilter *filter in outOfSyncFilters) {
        tempDirectoryURL = tempDirectoryURL ?: RBCreateTemporaryDirectory(&error);
        if (error != nil) {
            break;
        }

        NSURL *outputURL = [tempDirectoryURL URLByAppendingPathComponent:filter.uniqueIdentifier];

        dispatch_group_enter(downloadGroup);
        [progress addChild:[self _downloadFilter:filter toURL:outputURL completionHandler:^(NSError *downloadError) {
            if (downloadError == nil) {
                results[filter] = outputURL;
            } else if (progress.isCancelled) {
                error = [NSError errorWithDomain:CKErrorDomain code:CKErrorOperationCancelled userInfo:nil];
            } else {
                error = error ?: downloadError;
            }

            dispatch_group_leave(downloadGroup);
        }] withPendingUnitCount:1];
    }

    dispatch_group_notify(downloadGroup, self->_downloadQueue, ^{
        progress.completedUnitCount++;

        // Move / normalize results
        if (error == nil) {
            NSMutableDictionary *normalizedResults = [results mutableCopy];

            for (RBFilter *filter in results) {
                NSURL *outputURL = [outputDirectoryURL URLByAppendingPathComponent:filter.uniqueIdentifier];
                if ([results[filter] isEqual:outputURL]) {
                    continue;
                } else if (RBMoveFileURL(results[filter], outputURL, &error)) {
                    normalizedResults[filter] = outputURL;
                } else {
                    break;
                }
            }

            results = normalizedResults;
        }

        // Remove temporary directory
        if (tempDirectoryURL != nil) {
            [[NSFileManager defaultManager] removeItemAtURL:tempDirectoryURL error:NULL];
        }

        completionHandler(error == nil ? [results copy] : nil, error);
    });

    return progress;
}

- (NSProgress *)_downloadFilter:(RBFilter *)filter toURL:(NSURL *)destURL completionHandler:(void (^)(NSError *))completionHandler {
    return [self _downloadJSONDataAtPath:[@"/filter/" stringByAppendingString:filter.uniqueIdentifier] completionHandler:^(NSURL *tempURL, NSError *error) {

        // Check MD5 hash
        NSString *md5 = nil;
        if (error == nil) {
            md5 = [RBDigest MD5HashOfFileURL:tempURL error:&error];

            if (error == nil && [md5 caseInsensitiveCompare:filter.md5] != NSOrderedSame) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat: @"MD5 hashes do not match: %@ != %@", md5, filter.md5]
                };
                error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotParseResponse userInfo:userInfo];
            }
        }

        // Perform move
        if (error == nil) {
            RBMoveFileURL(tempURL, destURL, &error);
        }

        completionHandler(error);
    }];
}

- (NSProgress *)_fetchFiltersWithCompletionHandler:(void(^)(NSArray<RBFilter*> *_Nullable filters, NSError *_Nullable error))completionHandler {
    return [self _fetchJSONArrayAtPath:@"/filters" completionHandler:^(NSArray *plists, NSError *error) {
        if (error != nil) {
            return completionHandler(nil, error);
        }

        NSMutableArray *items = [NSMutableArray array];

        for (NSDictionary *plist in plists) {
            RBFilter *item = [[RBFilter alloc] initWithPropertyList:plist];
            if (item != nil) {
                [items addObject:item];
            }
        }

        completionHandler([items copy], nil);
    }];
}

- (NSURLRequest *)_requestForPath:(NSString *)path {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[self.url URLByAppendingPathComponent:path]];
    [req addValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    return req;
}

- (NSProgress *)_downloadJSONDataAtPath:(NSString *)path completionHandler:(void(^)(NSURL *__nullable, NSError *__nullable))completionHandler {
    NSURLRequest *req = [self _requestForPath:path];
    NSURLSessionDownloadTask *task = [_session downloadTaskWithRequest:req completionHandler:^(NSURL *url, NSURLResponse *response, NSError *error) {
        error = error ?: _errorFromJSONResponse(response);
        completionHandler(error ? nil : url, error);
    }];

    [task resume];

    return task.progress;
}

- (NSProgress *)_fetchJSONDataAtPath:(NSString *)path completionHandler:(void(^)(NSData *, NSError *))completionHandler {
    NSURLRequest *req = [self _requestForPath:path];
    NSURLSessionDataTask *task = [_session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        error = error ?: _errorFromJSONResponse(response);
        completionHandler(error ? nil : data, error);
    }];

    [task resume];

    return task.progress;
}

- (NSProgress *)_fetchJSONArrayAtPath:(NSString *)path completionHandler:(void(^)(NSArray *, NSError *))completionHandler {
    return [self _fetchJSONDataAtPath:path completionHandler:^(NSData *data, NSError *error) {
        NSArray *result = nil;

        if (error == nil) {
            result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];

            if (error == nil && (result == nil || ![result isKindOfClass:[NSArray class]])) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unexpected response type: %@", result ? NSStringFromClass([result class]) : @"null"]
                };

                error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:userInfo];
            }
        }

        completionHandler(result, error);
    }];
}

static NSError *_errorFromJSONResponse(NSURLResponse *response) {
    NSInteger statusCode = -1;
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        statusCode = ((NSHTTPURLResponse *)response).statusCode;
    }

    if (statusCode < 0 || statusCode > 299) {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unexpected HTTP Status: %ld", statusCode]};
        return [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:userInfo];
    } else if (![response.MIMEType ?: @"" hasPrefix:@"application/json"]) {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unexpected Content-Type: %@", response.MIMEType]};
        return [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:userInfo];
    }

    return nil;
}


#pragma mark - CloudKit

- (NSProgress *)_decompressRecords:(NSArray<CKRecord*>*)records outputDirectory:(NSURL *)outputDirectoryURL completionHandler:(void(^)(RBFilterGroupRules*, NSError *))completionHandler {
    __block NSMutableDictionary *results = [NSMutableDictionary dictionaryWithCapacity:records.count];
    __block NSError *error = nil;
    
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:records.count + 1]; // make sure our progress is never indeterminate
    dispatch_group_t group = dispatch_group_create();
    
    // Use a temporary directory so we can work atomically (we may otherwise produce corrupt output if canceled/errored while running)
    NSURL *tempDirectoryURL = RBCreateTemporaryDirectory(&error);
    
    for (CKRecord *record in records) {
        if (error != nil) {
            break;
        }
        
        dispatch_group_async(group, _downloadQueue, ^{
            if (error != nil) {
                return;
            } else if (progress.isCancelled) {
                error = [NSError errorWithDomain:CKErrorDomain code:CKErrorOperationCancelled userInfo:nil];
                return;
            }
            
            RBFilter *filter = [[RBFilter alloc] initWithRecord:record];
            CKAsset *asset = RBKindOfClassOrNil(CKAsset, record[@"asset"]);
            NSString *compression = RBKindOfClassOrNil(NSString, record[@"compression"]);
            
            if (filter == nil || asset == nil || asset.fileURL == nil) {
                NSLog(@"WARNING: Could not create filter / asset from record: %@", record);
            } else {
                NSURL *outputURL = [tempDirectoryURL URLByAppendingPathComponent:filter.uniqueIdentifier];
                
                if (compression == nil || compression.length == 0) {
                    [[NSFileManager defaultManager] copyItemAtURL:asset.fileURL toURL:outputURL error:&error];
                } else if ([compression isEqualToString:@"deflate"]) {
                    if (![RBZip inflateContentsOfFileURL:asset.fileURL toFileURL:outputURL error:&error]) {
                        error = [NSError errorWithDomain:CKErrorDomain code:CKErrorAssetNotAvailable userInfo:@{
                            NSLocalizedDescriptionKey: @"Could not inflate assets",
                            NSUnderlyingErrorKey: error,
                            NSURLPathKey: asset.fileURL.path
                        }];
                    }
                } else {
                    error = [NSError errorWithDomain:CKErrorDomain code:CKErrorAssetNotAvailable userInfo:@{
                        NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unrecognized compression algorithm: %@", compression],
                    }];
                }
                
                // Check MD5 hash
                if (error == nil && filter.md5 != nil) {
                    NSString *md5 = [RBDigest MD5HashOfFileURL:outputURL error:&error];

                    if (error == nil && [md5 caseInsensitiveCompare:filter.md5] != NSOrderedSame) {
                        error = [NSError errorWithDomain:CKErrorDomain code:CKErrorAssetFileModified userInfo:@{
                            NSLocalizedDescriptionKey: [NSString stringWithFormat: @"MD5 hashes do not match: %@ != %@", md5, filter.md5]
                        }];
                    }
                }

                if (error == nil) {
                    results[filter] = outputURL;
                }
            }
            
            progress.completedUnitCount++;
        });
    }
    
    dispatch_group_notify(group, _downloadQueue, ^{
        progress.completedUnitCount++;
        
        // Move / normalize results
        if (error == nil) {
            NSMutableDictionary *normalizedResults = [NSMutableDictionary dictionaryWithCapacity:results.count];
            
            for (RBFilter *filter in results) {
                NSURL *outputURL = [outputDirectoryURL URLByAppendingPathComponent:filter.uniqueIdentifier];
                if (!RBMoveFileURL(results[filter], outputURL, &error)) {
                    break;
                }
                normalizedResults[filter] = outputURL;
            }
            
            results = normalizedResults;
        }
        
        // Remove temporary directory
        if (tempDirectoryURL != nil) {
            [[NSFileManager defaultManager] removeItemAtURL:tempDirectoryURL error:NULL];
        }
        
        completionHandler(error == nil ? [results copy] : nil, error);
    });
    
    return progress;
}

- (NSProgress *)_performQuery:(CKQuery *)query completionHandler:(void (^)(NSArray<CKRecord *> *, NSError *))completionHandler {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:1];
    CKQueryOperation *operation = [[CKQueryOperation alloc] initWithQuery:query];
    
    progress.cancellationHandler = ^{
        [operation cancel];
    };
    
    NSMutableArray *results = [NSMutableArray array];
    
    operation.recordFetchedBlock = ^(CKRecord *record) {
        [results addObject:record];
    };
    
    operation.queryCompletionBlock = ^(CKQueryCursor *cursor, NSError *error) {
        progress.completedUnitCount++;
        completionHandler(results, error);
    };
    
    [_database addOperation:operation];
    
    return progress;
}

@end
