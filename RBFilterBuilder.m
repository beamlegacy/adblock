//
//  RBFilterBuilder.m
//  rAdblock Manager
//
//  Created by Mikey on 16/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBFilterBuilder.h"
#import "RBUtils.h"
#import "RBDatabase.h"


@implementation RBFilterBuilder {
    NSFileHandle *_fh;
    BOOL _needsComma;
    NSUInteger _bytesWritten;
}

+ (NSProgress *)temporaryBuilderForFileURLs:(NSArray<NSURL *> *)fileURLs
                          completionHandler:(void(^)(RBFilterBuilder *__nullable, NSError *__nullable))completionHandler {
    static dispatch_once_t onceToken;
    static dispatch_queue_t queue;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("net.youngdynasty.filter-builder", DISPATCH_QUEUE_CONCURRENT_WITH_AUTORELEASE_POOL);
    });
    
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:fileURLs.count + 1];
    
    dispatch_async(queue, ^{
        __block RBFilterBuilder *builder = nil;
        __block NSError *error = nil;

        // Create temporary directory
        NSURL *tempDirectory = RBCreateTemporaryDirectory(&error);
        
        if (tempDirectory == nil) {
            return completionHandler(nil, error);
        }
        
        // Create temporary file and wrap completion handler to cleanup
        NSURL *tempFile = [tempDirectory URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
        
        void(^finish)(void) = ^{
            if (progress.isCancelled && error == nil) {
                error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
            }
            
            if (builder != nil) {
                [builder flush];
            }
            
            if (error != nil) {
                NSLog(@"ERROR IS %@", error);
            }

            completionHandler(error == nil ? builder : nil, error);

            if (builder != nil) {
                [builder close];
            }
            
            [[NSFileManager defaultManager] removeItemAtURL:tempFile error:NULL];
            [[NSFileManager defaultManager] removeItemAtURL:tempDirectory error:NULL];
        };
        
        NSEnumerator *fileEnumerator = [fileURLs objectEnumerator];
        NSURL *curFileURL = [fileEnumerator nextObject];

        // Copy first file to edit it in-place; it's more efficient than appending
        if (curFileURL != nil) {
            if (![[NSFileManager defaultManager] copyItemAtURL:curFileURL toURL:tempFile error:&error]) {
                return finish();
            }
        } else {
            // Create empty file
            if (![[NSData data] writeToURL:tempFile options:0 error:&error]) {
                return finish();
            }
        }
        
        progress.completedUnitCount++;

        // Append other files
        builder = [[RBFilterBuilder alloc] initWithOutputURL:tempFile error:&error];
        if (builder == nil) {
            return finish();
        }
        progress.completedUnitCount++;

        while ((curFileURL = [fileEnumerator nextObject])) {
            if (progress.isCancelled || ![builder appendRulesFromFileURL:curFileURL error:&error]) {
                return finish();
            }
            
            progress.completedUnitCount++;
        }
        
        finish();
    });
    
    return progress;
}

- (nullable instancetype)initWithOutputURL:(NSURL *)outputURL error:(NSError **)outError {
    NSFileHandle *fh = [NSFileHandle fileHandleForUpdatingURL:outputURL error:outError];
    BOOL needsComma = NO;
    
    if (fh == nil || !_prepareHandle(fh, &needsComma, outError)) {
        if (fh != nil) {
            [fh closeFile];
        }
        return nil;
    }
    
    self = [super init];
    if (self == nil)
        return nil;
    
    _fh = fh;
    _needsComma = needsComma;
    _outputURL = outputURL;
    
    return self;
}

static BOOL _prepareHandle(NSFileHandle *fh, BOOL *__nonnull needsComma, NSError *__nullable *__nullable outError) {
    [fh seekToFileOffset:0];
    
    // Make sure file represents an array
    NSData *buf = [fh readDataOfLength:1];
    if (buf.length == 0) {
        [fh writeData:[@"[]" dataUsingEncoding:NSUTF8StringEncoding]];
        return YES;
    }
    
    NSString *openingCharacters = [[NSString alloc] initWithData:buf encoding:NSUTF8StringEncoding];
    NSString *lastCharacters = nil;
    
    if (![openingCharacters hasPrefix:@"["]) {
        goto error;
    }

    [fh seekToEndOfFile];
    
    if (fh.offsetInFile < 2) {
        goto error;
    }
    
    [fh seekToFileOffset:fh.offsetInFile - 2];
    buf = [fh readDataOfLength:2];
    
    lastCharacters = [[NSString alloc] initWithData:buf encoding:NSUTF8StringEncoding];

    if (![lastCharacters hasSuffix:@"]"]) {
        goto error;
    }
    
    (*needsComma) = ![lastCharacters hasPrefix:@"["];
    
    return YES;
    
error:
    if (outError != NULL) {
        (*outError) = [NSError errorWithDomain:NSCocoaErrorDomain code:NSPropertyListReadCorruptError userInfo:nil];
    }
    
    return NO;
}

- (BOOL)appendRule:(NSDictionary *)ruleObj error:(NSError **)outError {
    __block NSData *data = [NSJSONSerialization dataWithJSONObject:ruleObj options:0 error:outError];
    if (data == nil)
        return NO;
    
    [self _appendDataUsingBlock:^NSData *{
        NSData *retData = data;
        data = [NSData data];
        return retData;
    }];
    
    return YES;
}

- (BOOL)appendRulesFromFileURL:(NSURL *)fileURL error:(NSError **)outError {
    NSFileHandle *r = [NSFileHandle fileHandleForReadingFromURL:fileURL error:outError];
    if (r == nil)
        return NO;
    
    // Trim opening bracket
    [r seekToFileOffset:1];
    
    [self _appendDataUsingBlock:^NSData *{
        return [r readDataOfLength:32768];
    }];
    
    [r closeFile];
    
    return YES;
}

- (void)_appendDataUsingBlock:(NSData *(^)(void))block {
    [_fh seekToEndOfFile];
    [_fh seekToFileOffset:_fh.offsetInFile - 1];
    
    NSData *data = nil;
    NSString *lastComponent = nil;
    
    while ([(data = block()) length]) {
        if (_needsComma) {
            [_fh writeData:[NSData dataWithBytes:"," length:1]];
            _needsComma = NO;
        }
        
        [_fh writeData:data];
        
        NSUInteger charPoint = sizeof(UTF8Char);
        NSUInteger charPoints = data.length / charPoint;
        
        NSData *lastComponentData = [data subdataWithRange:NSMakeRange(charPoints - charPoint, charPoint)];
        lastComponent = [[NSString alloc] initWithData:lastComponentData encoding:NSUTF8StringEncoding];
    }
    
    if (lastComponent != nil) {
        _needsComma = YES;
        
        if (![lastComponent isEqualToString:@"]"]) {
            NSError *error = nil;
            [_fh writeData:[NSData dataWithBytes:"]" length:1]
                     error:&error];
            
            if (error != nil) {
                NSLog(@"Write error: %@", error);
            }
        }
    }
}

- (void)flush {
    NSError *error = nil;
    [_fh synchronizeAndReturnError:&error];
    
    if (error != nil) {
        NSLog(@"Synchronization error: %@", error);
    }
}

- (void)close {
    NSError *error = nil;
    [_fh closeAndReturnError:&error];
    
    if (error != nil) {
        NSLog(@"Close file error: %@", error);
    }
}

@end
