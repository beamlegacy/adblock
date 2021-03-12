//
//  RBDigest.m
//  RadBlock
//
//  Created by Mikey on 17/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#include <CommonCrypto/CommonDigest.h>

#import "RBDigest.h"

@implementation RBDigest

+ (NSString *)MD5HashOfData:(NSData *)data {
    CC_MD5_CTX ctx;
    CC_MD5_Init(&ctx);
    CC_MD5_Update(&ctx, data.bytes, (CC_LONG)data.length);
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &ctx);
    
    return _MD5HexString(digest);
}

+ (NSString *)MD5HashOfUTF8String:(NSString *)string {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [self MD5HashOfData:data ?: [NSData data]];
}

+ (NSString *)MD5HashOfFileURL:(NSURL *)fileURL error:(NSError *__nonnull*_Nullable)outError {
    NSFileHandle *reader = [NSFileHandle fileHandleForReadingFromURL:fileURL error:outError];
    if (reader == nil) {
        return nil;
    }
    
    CC_MD5_CTX ctx;
    CC_MD5_Init(&ctx);
    
    NSData *chunk = nil;
    
    while ((chunk = [reader readDataOfLength:32*1028]) && chunk.length > 0) {
        CC_MD5_Update(&ctx, chunk.bytes, (CC_LONG)chunk.length);
    }
    
    [reader closeFile];
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &ctx);
    
    return _MD5HexString(digest);
}

static NSString* _MD5HexString(unsigned char digest[CC_MD5_DIGEST_LENGTH]) {
    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH*2];
    
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [ret appendFormat:@"%02x", digest[i]];
    }
    
    return [ret copy];
}

@end
