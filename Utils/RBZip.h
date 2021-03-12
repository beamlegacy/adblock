//
//  RBZip.h
//  RadBlock
//
//  Created by Mike Pulaski on 05/11/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RBZip : NSObject

+ (BOOL)deflateData:(NSData *)data toFileURL:(NSURL *)fileURL error:(NSError *__nullable *__nullable)outError;

+ (BOOL)inflateContentsOfFileURL:(NSURL *)inputURL toFileURL:(NSURL *)outputURL error:(NSError *__nullable *__nullable)outError;

@end

NS_ASSUME_NONNULL_END
