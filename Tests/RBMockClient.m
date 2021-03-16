//
//  RBMockClient.m
//  RadBlockTests
//
//  Created by Mikey on 16/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBMockClient.h"
#import "RBClient-Private.h"
#import "RBFilter+Mock.h"
#import "RBUtils.h"
#import "RBZip.h"

@interface RBMockClientProtocol : NSURLProtocol
@end


@implementation RBMockClient {
    NSMutableArray *_filters;
    NSMutableDictionary *_filterErrors;
    NSURL *_tempDirectoryURL;
    dispatch_queue_t _q;

    NSMapTable *_handlerMap;
    NSString *_uniqueIdentifier;
}
@synthesize cloudKitEnabled = _cloudKitEnabled;

+ (NSMapTable *)_registry {
    static NSMapTable *registry = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        registry = [NSMapTable strongToWeakObjectsMapTable];
    });
    
    return registry;
}

+ (void)_accessRegistryWithBlock:(void(^)(NSMapTable*))block {
    static NSMapTable *registry = nil;
    static dispatch_queue_t queue = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        registry = [NSMapTable strongToWeakObjectsMapTable];
        queue = dispatch_queue_create("net.youngdynasty.radblock.client.mock-queue", NULL);
    });
    
    dispatch_sync(queue, ^{
        block(registry);
    });
}

+ (RBMockClient *)_clientForIdentifier:(NSString *)identifier {
    __block RBMockClient *client = nil;
    [self _accessRegistryWithBlock:^(NSMapTable *r) {
        client = [r objectForKey:identifier];
    }];
    return client;
}

+ (NSData *)jsonData:(id)obj {
    return [NSJSONSerialization dataWithJSONObject:obj options:NSJSONWritingSortedKeys error:nil];
}

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    _filters = [NSMutableArray array];
    _filterErrors = [NSMutableDictionary dictionary];
    _tempDirectoryURL = RBCreateTemporaryDirectory(NULL);
    _q = dispatch_queue_create("net.youngdynasty.radblock.mockclient", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
    _cloudKitEnabled = YES;
    
    _handlerMap = [NSMapTable strongToStrongObjectsMapTable];
    _uniqueIdentifier = [[NSUUID UUID] UUIDString];

    [[self class] _accessRegistryWithBlock:^(NSMapTable *r) {
        [r setObject:self forKey:self->_uniqueIdentifier];
    }];
    
    return self;
}

- (void)dealloc {
    [[self class] _accessRegistryWithBlock:^(NSMapTable *r) {
        [r removeObjectForKey:self->_uniqueIdentifier];
    }];
}

- (void)invalidate {
    [[NSFileManager defaultManager] removeItemAtURL:_tempDirectoryURL error:NULL];
}

#pragma mark - Mock overrides

- (NSURL *)url {
    return [NSURL URLWithString:[NSString stringWithFormat:@"mock://%@", _uniqueIdentifier]];
}

- (NSURLSessionConfiguration *)_sessionConfiguration {
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration.ephemeralSessionConfiguration copy];
    sessionConfig.protocolClasses = @[[RBMockClientProtocol class]];
    
    return sessionConfig;
}

#pragma mark - Mocks

- (void)mockFilters:(NSArray<RBFilter*>*)filters {
    [_filters setArray:filters];
    
    NSMutableSet *oldFilters = [NSMutableSet setWithArray:_filterErrors.allKeys];
    [oldFilters minusSet:[NSSet setWithArray:filters]];
    [_filterErrors removeObjectsForKeys:[oldFilters allObjects]];
    
    [self _resetHandlerMap];
    
    [self handlePath:@"/filters" usingBlock:^(int *status, NSDictionary **headers, NSData **data) {
        (*data) = [NSJSONSerialization dataWithJSONObject:[filters valueForKeyPath:@"propertyList"] options:NSJSONWritingSortedKeys error:NULL];
    }];
    
    for (RBFilter *filter in filters) {
        [self handlePath:[@"/filter/" stringByAppendingString:filter.uniqueIdentifier] usingBlock:^(int *status, NSDictionary **headers, NSData **data) {
            (*data) = [NSJSONSerialization dataWithJSONObject:filter.rulesObject options:NSJSONWritingSortedKeys error:NULL];
        }];
    }
}

- (void)mockError:(NSError *)err forFilter:(RBFilter *)filter {
    if (err != nil) {
        _filterErrors[filter] = err;
    } else {
        [_filterErrors removeObjectForKey:filter];
    }
}

#pragma mark - Mock CloudKit

- (NSProgress *)_performQuery:(CKQuery *)query completionHandler:(void (^)(NSArray<CKRecord *>*, NSError *))completionHandler {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:1];
    
    dispatch_async(_q, ^{
        if (progress.isCancelled) {
            completionHandler(nil, [NSError errorWithDomain:CKErrorDomain code:CKErrorOperationCancelled userInfo:nil]);
        } else {
            NSError *error = nil;
            NSArray *records = nil;
            
            if ([query.recordType isEqualToString:@"Filter"]) {
                records = [self _mockRecordsForPredicate:query.predicate error:&error];
            }
            
            progress.completedUnitCount++;
            completionHandler(error == nil ? records : nil, error);
        }
    });
    
    return progress;
}

- (NSArray<CKRecord*>*)_mockRecordsForPredicate:(NSPredicate *)predicate error:(NSError**)outError {
    RBFilter *filterWithError = [[_filterErrors.allKeys filteredArrayUsingPredicate:predicate] firstObject];
    if (filterWithError != nil) {
        if (outError != nil) {
            (*outError) = _filterErrors[filterWithError];
        }
        return nil;
    }
    
    NSArray *filters = [_filters filteredArrayUsingPredicate:predicate];
    NSMutableArray *records = [NSMutableArray arrayWithCapacity:filters.count];
    
    for (RBFilter *filter in filters) {
        NSData *rulesData = [RBMockClient jsonData:filter.rulesObject];
        NSURL *tempURL = [_tempDirectoryURL URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
        
        if (![RBZip deflateData:rulesData toFileURL:tempURL error:outError]) {
            return nil;
        }
        
        CKRecord *record = [[CKRecord alloc] initWithRecordType:@"Filter" recordID:[[CKRecordID alloc] initWithRecordName:filter.uniqueIdentifier]];
        
        for (NSString *key in filter.propertyList) {
            if ([key isEqualToString:@"id"]) {
                continue;
            }
            
            record[key] = filter.propertyList[key];
        }
        
        record[@"asset"] = [[CKAsset alloc] initWithFileURL:tempURL];
        record[@"compression"] = @"deflate";
        
        [records addObject:record];
    }
    
    return records;
}

#pragma mark - Mock Server

- (void)_resetHandlerMap {
    [_handlerMap removeAllObjects];
}

- (void)handlePath:(NSString *)path usingBlock:(RBMockClientHandler)handler {
    [_handlerMap setObject:[handler copy] forKey:path];
}

- (RBMockClientHandler)handlerForPath:(NSString *)path {
    RBMockClientHandler handler = [_handlerMap objectForKey:path];
    return handler ? [handler copy] : nil;
}

- (id)_handlerOrErrorForPath:(NSString *)path {
    if ([path hasPrefix:@"/filter/"]) {
        NSString *identifier = path.lastPathComponent;
        
        for (RBFilter *filter in _filterErrors.allKeys) {
            if ([filter.uniqueIdentifier isEqualToString:identifier]) {
                return _filterErrors[filter];
            }
        }
    }
    
    RBMockClientHandler handler = [_handlerMap objectForKey:path];
    return handler ? [handler copy] : nil;
}

@end

#pragma mark - RBMockClientProtocol

@implementation RBMockClientProtocol

- (instancetype)initWithTask:(NSURLSessionTask *)task cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id<NSURLProtocolClient>)client {
    self = [super initWithTask:task cachedResponse:cachedResponse client:client];
    if (self == nil)
        return nil;
    
    return self;
}

+ (BOOL)canInitWithTask:(NSURLSessionTask *)task {
    return [task.originalRequest.URL.scheme isEqualToString:@"mock"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    RBMockClient *mock = [RBMockClient _clientForIdentifier:self.request.URL.host];
    RBMockClientHandler handler = mock ? [mock _handlerOrErrorForPath:self.request.URL.path] : nil;
    
    if ([handler isKindOfClass:[NSError class]]) {
        [self.client URLProtocol:self didFailWithError:(id)handler];
        [self.client URLProtocolDidFinishLoading:self];
        return;
    }
    
    int status = handler ? 200 : 404;
    NSDictionary *headers = @{@"Content-Type": @"application/json"};
    NSData *data = nil;
    
    if (handler != nil) {
        handler(&status, &headers, &data);
    }
    
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:status HTTPVersion:@"1.1" headerFields:headers];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:data ?: [NSData data]];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {
    
}

@end
