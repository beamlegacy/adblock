#if __has_feature(objc_arc)
#error This file must be compiled without ARC for Swift interoperability. Please add the -fno-objc-arc flag to this file \
under "Project Settings > Current Target > Build Phases > Compile Sources".
#endif

//
//  RBSQLite.m
//  RadBlock
//
//  Created by Mike Pulaski on 26/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBSQLite.h"
#import "RBUtils.h"

static int _RBSQLiteBindList(sqlite3_stmt *stmt, va_list args);
static int _RBSQLiteBindObject(sqlite3_stmt *stmt, int idx, id obj);
static int _RBSQLitePrepareList(sqlite3 *db, sqlite3_stmt **stmt, NSString *query, va_list args);

int RBSQLitePrepare(sqlite3 *db, sqlite3_stmt **stmt, NSString *query, ...) {
    va_list args;
    va_start(args, query);
    int status = _RBSQLitePrepareList(db, stmt, query, args);
    va_end(args);
    
    return status;
}

int RBSQLiteBind(sqlite3_stmt *stmt, ...) {
    va_list args;
    va_start(args, stmt);
    int result = _RBSQLiteBindList(stmt, args);
    va_end(args);
    
    return result;
}

int RBSQLiteExecute(sqlite3 *db, NSString *query, ...) {
    va_list args;
    va_start(args, query);
    sqlite3_stmt *stmt = NULL;
    int result = _RBSQLitePrepareList(db, &stmt, query, args);
    va_end(args);
    
    if (result == SQLITE_OK) {
        result = sqlite3_step(stmt);
    }
    
    sqlite3_finalize(stmt);
    
    return result;
}

int RBSQLiteTransaction(sqlite3 *db, int(^block)(void)) {
    int status = RBSQLiteExecute(db, @"BEGIN TRANSACTION");
    
    if (status == SQLITE_DONE) {
        status = block();
    }
    
    switch (status) {
        case SQLITE_DONE:
        case SQLITE_OK:
            return RBSQLiteExecute(db, @"COMMIT TRANSACTION");
        default:
            RBSQLiteExecute(db, @"ROLLBACK TRANSACTION");
            return status;
    }
}

#pragma mark - Scanning

NSDate* RBSQLiteScanDate(sqlite3_stmt *stmt, int column) {
    switch (sqlite3_column_type(stmt, column)) {
        case SQLITE_NULL:
            return nil;
        case SQLITE_INTEGER:
            return [NSDate dateWithTimeIntervalSince1970:sqlite3_column_int64(stmt, column)];
        case SQLITE_FLOAT:
            return [NSDate dateWithTimeIntervalSince1970:sqlite3_column_double(stmt, column)];
        default:
            return nil;
    }
}

NSData* RBSQLiteScanData(sqlite3_stmt *stmt, int column) {
    switch (sqlite3_column_type(stmt, column)) {
        case SQLITE_NULL:
        case SQLITE_INTEGER:
        case SQLITE_FLOAT:
            return nil;
        case SQLITE_BLOB: {
            const char *dataBuffer = sqlite3_column_blob(stmt, column);
            if (dataBuffer == NULL) {
                return nil;
            }
            
            int dataSize = sqlite3_column_bytes(stmt, column);
            return [NSData dataWithBytes:(const void *)dataBuffer length:(NSUInteger)dataSize];
        }
        case SQLITE_TEXT:
        default: {
            const char *textBuffer = (const char *)sqlite3_column_text(stmt, column);
            if (textBuffer == NULL) {
                return nil;
            }
            
            return [NSData dataWithBytes:(const void*)textBuffer length:strlen(textBuffer)];
        }
    }
}

NSNumber* RBSQLiteScanNumber(sqlite3_stmt *stmt, int column) {
    int columnType = sqlite3_column_type(stmt, column);
    
    switch (columnType) {
        case SQLITE_INTEGER:
            return [NSNumber numberWithLongLong:sqlite3_column_int64(stmt, column)];
        case SQLITE_FLOAT:
            return [NSNumber numberWithDouble:sqlite3_column_double(stmt, column)];
        default:
            return nil;
    }
}

NSString* RBSQLiteScanString(sqlite3_stmt *stmt, int column) {
    const char *c = (const char *)sqlite3_column_text(stmt, column);
    if (c == NULL) {
        return nil;
    }
    return [NSString stringWithUTF8String:c];
}

NSErrorDomain RBSQLiteErrorDomain = @"RBSQLiteErrorDomain";

NSError* NSErrorFromSQLiteStatus(int status) {
    switch (status) {
        case SQLITE_OK:
        case SQLITE_DONE:
        case SQLITE_ROW:
        case SQLITE_NOTICE:
        case SQLITE_WARNING:
            return nil;
        default:
            return [NSError errorWithDomain:RBSQLiteErrorDomain code:status userInfo:@{
                NSLocalizedDescriptionKey: @(sqlite3_errstr(status))
            }];
    }
}

#pragma mark - Resource Sharing

typedef struct _RBSQLitePool {
    sqlite3 *(^constructor)(void);
    NSHashTable *resources;
    dispatch_semaphore_t semaphore;
    dispatch_semaphore_t resourcesSemaphore;
    NSInteger leases;
} RBSQLitePool;

RBSQLitePoolRef RBSQLitePoolCreate(int capacity, sqlite3*(^constructorBlock)(void)) {
    RBSQLitePoolRef pool = malloc(sizeof(RBSQLitePool));
    
    if (pool != NULL) {
        pool->constructor = [constructorBlock copy];
        pool->resources = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsOpaqueMemory|NSPointerFunctionsOpaquePersonality capacity:capacity];
        pool->semaphore = dispatch_semaphore_create(1);
        pool->resourcesSemaphore = dispatch_semaphore_create(capacity);
        pool->leases = 0;
    }
    
    return pool;
}

void RBSQLitePoolFree(RBSQLitePoolRef pool) {
    if (pool != NULL) {
        [pool->resources release];
        [pool->constructor release];
        dispatch_release(pool->semaphore);
        dispatch_release(pool->resourcesSemaphore);
        
        free(pool);
    }
}

sqlite3* RBSQLitePoolGet(RBSQLitePoolRef pool) {
    sqlite3 *db = NULL;
    
    // Wait for a resource to become available
    dispatch_semaphore_wait(pool->resourcesSemaphore, DISPATCH_TIME_FOREVER);
    
    // Get existing item from pool or create a new one
    dispatch_semaphore_wait(pool->semaphore, DISPATCH_TIME_FOREVER);
    {
        db = (sqlite3*)[pool->resources anyObject];
        if (db != nil) {
            [pool->resources removeObject:(id)(db)];
        }
        pool->leases++;
    }
    dispatch_semaphore_signal(pool->semaphore);
    
    return db ?: pool->constructor();
}

void RBSQLitePoolPut(RBSQLitePoolRef pool, sqlite3 *db) {
    dispatch_semaphore_wait(pool->semaphore, DISPATCH_TIME_FOREVER);
    {
        [pool->resources addObject:(id)db];
        pool->leases--;
    }
    dispatch_semaphore_signal(pool->semaphore);
    
    // Signal that we have a resource has become available
    dispatch_semaphore_signal(pool->resourcesSemaphore);
}

void RBSQLitePoolDrain(RBSQLitePoolRef pool) {
    NSHashTable *resources = nil;
    
    dispatch_semaphore_wait(pool->semaphore, DISPATCH_TIME_FOREVER);
    {
        assert(pool->leases == 0);
        
        resources = [pool->resources copy];
        [pool->resources removeAllObjects];
    }
    dispatch_semaphore_signal(pool->semaphore);
    
    if (resources == nil) {
        return;
    }
    
    while (resources.count > 0) {
        sqlite3 *db = (sqlite3*)[resources anyObject];
        sqlite3_close(db);
        [resources removeObject:(id)db];
    }
    
    [resources release];
}

#pragma mark -

static int _RBSQLitePrepareList(sqlite3 *db, sqlite3_stmt **stmt, NSString *query, va_list args) {
    int status = sqlite3_prepare_v2(db, query.UTF8String, -1, stmt, NULL);

    if (status == SQLITE_OK) {
        status = _RBSQLiteBindList(*stmt, args);
    }
    
    return status;
}

static int _RBSQLiteBindList(sqlite3_stmt *stmt, va_list args) {
    int len = sqlite3_bind_parameter_count(stmt);
    int status = sqlite3_clear_bindings(stmt);
    
    for (int i = 0; i < len && status == SQLITE_OK; i++) {
        status = _RBSQLiteBindObject(stmt, i+1, va_arg(args, id));
    }
    
    return status;
}

// Modified from FMDB
int _RBSQLiteBindObject(sqlite3_stmt *stmt, int idx, id obj) {
    if ((obj == nil) || ((NSNull *)obj == [NSNull null])) {
        return sqlite3_bind_null(stmt, idx);
    }
    else if ([obj isKindOfClass:[NSData class]]) {
        return sqlite3_bind_blob(stmt, idx, [obj bytes] ?: "", (int)[obj length], SQLITE_STATIC);
    }
    else if ([obj isKindOfClass:[NSDate class]]) {
        return sqlite3_bind_double(stmt, idx, [obj timeIntervalSince1970]);
    }
    else if ([obj isKindOfClass:[NSNumber class]]) {
        const char *objCType = [obj objCType];
        
        if (strcmp(objCType, @encode(char)) == 0) {
            return sqlite3_bind_int(stmt, idx, [obj charValue]);
        } else if (strcmp(objCType, @encode(unsigned char)) == 0) {
            return sqlite3_bind_int(stmt, idx, [obj unsignedCharValue]);
        } else if (strcmp(objCType, @encode(short)) == 0) {
            return sqlite3_bind_int(stmt, idx, [obj shortValue]);
        } else if (strcmp(objCType, @encode(unsigned short)) == 0) {
            return sqlite3_bind_int(stmt, idx, [obj unsignedShortValue]);
        } else if (strcmp(objCType, @encode(int)) == 0) {
            return sqlite3_bind_int(stmt, idx, [obj intValue]);
        } else if (strcmp(objCType, @encode(unsigned int)) == 0) {
            return sqlite3_bind_int64(stmt, idx, (long long)[obj unsignedIntValue]);
        } else if (strcmp(objCType, @encode(long)) == 0) {
            return sqlite3_bind_int64(stmt, idx, [obj longValue]);
        } else if (strcmp(objCType, @encode(unsigned long)) == 0) {
            return sqlite3_bind_int64(stmt, idx, (long long)[obj unsignedLongValue]);
        } else if (strcmp(objCType, @encode(long long)) == 0) {
            return sqlite3_bind_int64(stmt, idx, [obj longLongValue]);
        } else if (strcmp(objCType, @encode(unsigned long long)) == 0) {
            return sqlite3_bind_int64(stmt, idx, (long long)[obj unsignedLongLongValue]);
        } else if (strcmp(objCType, @encode(float)) == 0) {
            return sqlite3_bind_double(stmt, idx, [obj floatValue]);
        } else if (strcmp(objCType, @encode(double)) == 0) {
            return sqlite3_bind_double(stmt, idx, [obj doubleValue]);
        } else if (strcmp(objCType, @encode(BOOL)) == 0) {
            return sqlite3_bind_int(stmt, idx, ([obj boolValue] ? 1 : 0));
        } else {
            return sqlite3_bind_text(stmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
        }
    }
    else {
        return sqlite3_bind_text(stmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
    }
}
