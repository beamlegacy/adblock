//
//  RBMockExtensionContext.m
//  RadBlockTests
//
//  Created by Mike Pulaski on 01/11/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBMockExtensionContext.h"

@interface RBMockExtensionContext()
@property(nonatomic,setter=_setIsComplete:) BOOL isComplete;
@property(nonatomic,nullable,setter=_setReturnedItems:) NSArray<NSExtensionItem*> *returnedItems;
@end

typedef void (^_RBMockExtensionContextBlock)(NSArray<NSExtensionItem *> *, NSError*);

@implementation RBMockExtensionContext {
    _RBMockExtensionContextBlock _block;
}

+ (instancetype)mockExtensionContextWithCompletionHandler:(_RBMockExtensionContextBlock)block {
    RBMockExtensionContext *ctx = [self new];
    ctx->_block = [block copy];
    return ctx;
}

- (void)completeRequestReturningItems:(NSArray *)items completionHandler:(void (^)(BOOL))completionHandler {
    _block(items, nil);
    
    if (completionHandler == nil) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        completionHandler(YES);
    });
}

- (void)cancelRequestWithError:(NSError *)error {
    _block(nil, error);
}

@end
