//
//  RBDigest.h
//  RadBlock
//
//  Created by Mikey on 17/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RBDigest : NSObject

+ (NSString *)MD5HashOfData:(NSData *)data;
+ (NSString *)MD5HashOfUTF8String:(NSString *)string;
+ (NSString *_Nullable)MD5HashOfFileURL:(NSURL *)fileURL error:(NSError *__nonnull*_Nullable)outError;

@end

NS_ASSUME_NONNULL_END
