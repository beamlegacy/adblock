//
//  RBFilterBuilder.h
//  rAdblock Manager
//
//  Created by Mikey on 16/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(FilterBuilder)

@interface RBFilterBuilder : NSObject

+ (NSProgress *)temporaryBuilderForFileURLs:(NSArray<NSURL *> *)fileURLs completionHandler:(void(^)(RBFilterBuilder *__nullable, NSError *__nullable))completionHandler;

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithOutputURL:(NSURL *)outputURL error:(NSError *__nullable*__nullable)outError NS_DESIGNATED_INITIALIZER;

@property(nonatomic,readonly) NSURL *outputURL;

- (BOOL)appendRulesFromFileURL:(NSURL *)fileURL error:(NSError *__nullable*)outError;
- (BOOL)appendRule:(NSDictionary *)ruleObj error:(NSError *__nullable*)outError;

- (void)flush;
- (void)close;

@end

NS_ASSUME_NONNULL_END
