//
//  RBKVO.m
//  RadBlock
//
//  Created by Mike Pulaski on 22/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#include <stdatomic.h>
#import "RBKVO.h"

typedef void(^_RBKVOBlock)(id,NSDictionary<NSKeyValueChangeKey,id>*);

@implementation RBKVO {
    __weak id _object;
    NSArray<NSString*> *_keyPaths;
    _RBKVOBlock _block;

    atomic_int _numInvalidations;
}

+ (instancetype)observe:(id)object keyPath:(NSString *)keyPath usingBlock:(void(^)(id))block {
    return [self observe:object keyPaths:@[keyPath] usingBlock:block];
}

+ (instancetype)observe:(id)object keyPaths:(NSArray<NSString*>*)keyPaths usingBlock:(void(^)(id))block {
    return [self observe:object keyPaths:keyPaths options:NSKeyValueObservingOptionNew usingBlock:^(id obj, NSDictionary<NSKeyValueChangeKey,id>* changes) {
        block(obj);
    }];
}

+ (instancetype)observe:(id)object keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options usingBlock:(_RBKVOBlock)block {
    return [self observe:object keyPaths:@[keyPath] options:options usingBlock:block];
}

+ (instancetype)observe:(id)object keyPaths:(NSArray<NSString*>*)keyPaths options:(NSKeyValueObservingOptions)options usingBlock:(_RBKVOBlock)block {
    return [[self alloc] _initWithObject:object keyPaths:keyPaths options:options block:block];
}

- (instancetype)_initWithObject:(id)object keyPaths:(NSArray<NSString*>*)keyPaths options:(NSKeyValueObservingOptions)options block:(_RBKVOBlock)block {
    self = [super init];
    if (self == nil)
        return nil;
    
    _object = object;
    _keyPaths = keyPaths;
    _block = [block copy];
    
    for (NSString *keyPath in keyPaths) {
        [object addObserver:self forKeyPath:keyPath options:options context:NULL];
    }
    
    return self;
}

- (void)dealloc {
    [self invalidate];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    _block(object, change ?: @{});
}

- (void)invalidate {
    if (atomic_fetch_add(&_numInvalidations, 1) != 0) {
        return;
    }

    id strongObject = _object;
    if (strongObject != nil) {
        for (NSString *keyPath in _keyPaths) {
            [strongObject removeObserver:self forKeyPath:keyPath];
        }
        
        _object = nil;
        _block = nil;
    }
}

@end
