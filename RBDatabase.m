//
//  RBDatabase.m
//  RadBlock
//
//  Created by Mike Pulaski on 23/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <sqlite3.h>

#import "RBDatabase-Private.h"
#import "RBWhitelistEntry-Private.h"
#import "RBStat-Private.h"

#import "RBFilterGroup.h"
#import "RBFilterManagerState.h"
#import "RBSQLite.h"
#import "RBUtils.h"

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif


@interface RBWhitelistEntry(SQLite)
+ (NSEnumerator *)_enumeratorForStatement:(sqlite3_stmt*)stmt;
@end

@interface RBStat(SQLite)
+ (NSEnumerator *)_enumeratorForStatement:(sqlite3_stmt*)stmt;
@end


@implementation RBDatabase {
    RBSQLitePool *_pool;
    dispatch_queue_t _q;
    
    BOOL _isReady;
    dispatch_semaphore_t _readySemaphore;
}
@synthesize _statDate = _statDate;

+ (instancetype)sharedDatabase {
    static dispatch_once_t onceToken;
    static RBDatabase *sharedDatabase = nil;
    dispatch_once(&onceToken, ^{
        sharedDatabase = [[RBDatabase alloc] initWithFileURL:[RBSharedApplicationDataURL URLByAppendingPathComponent:@"radblock.db"]];
    });
    return sharedDatabase;
}

- (instancetype)initWithFileURL:(NSURL *)fileURL {
    self = [super init];
    if (self == nil)
        return nil;
    
    _fileURL = fileURL;
    _q = dispatch_queue_create("net.youngdynasty.net.radblock.database", DISPATCH_QUEUE_CONCURRENT_WITH_AUTORELEASE_POOL);
    _readySemaphore = dispatch_semaphore_create(1);
    
    __weak RBDatabase *weakSelf = self;
    _pool = RBSQLitePoolCreate(5, ^sqlite3 *{
        return [weakSelf _createDatabaseConnection];
    });
    
#if TARGET_OS_IOS
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_drainPool) name:UIApplicationWillTerminateNotification object:nil];
#else
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_drainPool) name:NSApplicationWillTerminateNotification object:nil];
#endif
    
    [self _registerExternalObservers];
    
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithFileURL:_fileURL];
}

- (void)dealloc {
    [self _unregisterExternalObservers];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    RBSQLitePoolDrain(_pool);
    RBSQLitePoolFree(_pool);
}

#pragma mark - Whitelist

- (void)whitelistEntryForDomain:(NSString *)domain completionHandler:(void(^)(RBWhitelistEntry *__nullable, NSError *__nullable))completionHandler {
    [self _accessConnectionUsingBlock:^(sqlite3 *conn) {
        NSError *error = nil;
        RBWhitelistEntry *entry = [self _whitelistEntryForDomain:domain conn:conn error:&error];
        completionHandler(entry, nil);
    }];
}

- (RBWhitelistEntry *)_whitelistEntryForDomain:(NSString *)domain conn:(sqlite3 *)conn error:(NSError **)outError {
    dispatch_assert_queue(_q);
    
    sqlite3_stmt *stmt = NULL;
    int status = RBSQLitePrepare(conn, &stmt, @"\
                                 SELECT domain, group_concat(exception_group.name), create_date, modify_date, enabled \
                                 FROM exception, exception_group \
                                 WHERE domain = $1 AND exception_group.exception_domain = domain \
                                 GROUP BY domain \
                                 ORDER BY length(domain) DESC, domain, exception_group.name \
                                 ", _normalizeDomain(domain));
    
    RBWhitelistEntry *entry = nil;
    
    if (status == SQLITE_OK) {
        entry = [[RBWhitelistEntry _enumeratorForStatement:stmt] nextObject];
    }
    
    if (outError != NULL) {
        (*outError) = NSErrorFromSQLiteStatus(status);
    }
    
    sqlite3_finalize(stmt);
    
    return entry;
}

- (void)whitelistEntryEnumeratorForGroup:(nullable NSString *)group domain:(nullable NSString *)domain sortOrder:(RBWhitelistEntrySortOrder)sortOrder completionHandler:(void(^)(NSEnumerator<RBWhitelistEntry*>*,NSError *))completionHandler {
    [self _accessConnectionUsingBlock:^(sqlite3 *conn) {
        sqlite3_stmt *stmt = NULL;
        
        int status = RBSQLitePrepare(conn, &stmt, [@"\
                                                   WITH _group AS (\
                                                       SELECT exception_domain \
                                                       FROM exception_group \
                                                       WHERE $1 IS NULL OR name = $1 OR name = '*' \
                                                   ) \
                                                   SELECT domain, group_concat(exception_group.name), create_date, modify_date, enabled \
                                                   FROM exception, _group, exception_group \
                                                   WHERE domain = _group.exception_domain \
                                                   AND ($2 IS NULL OR domain = $2 OR in_domain($2, domain)) \
                                                   AND exception_group.exception_domain = domain \
                                                   GROUP BY domain \
                                                   ORDER BY " stringByAppendingString:sortOrder == RBWhitelistEntrySortOrderCreateDate
                                                                                       ? @"exception.create_date"
                                                                                       : @"root_domain(exception.domain), length(exception.domain), exception.domain"
                                                   ], group, domain);

        if (status == SQLITE_OK) {
            completionHandler([RBWhitelistEntry _enumeratorForStatement:stmt], nil);
        } else {
            completionHandler(nil, NSErrorFromSQLiteStatus(status));
        }
        
        sqlite3_finalize(stmt);
    }];
}

- (void)writeWhitelistEntryForDomain:(NSString *)domain usingBlock:(void(^)(RBMutableWhitelistEntry*, BOOL*))block completionHandler:(void(^)(RBWhitelistEntry *__nullable, NSError *__nullable))completionHandler {
    [self _accessConnectionUsingBlock:^(sqlite3 *conn) {
        __block BOOL existed = NO;
        NSError *error = nil;
        RBWhitelistEntry *entry = [self _upsertWhitelistEntryForDomain:domain usingBlock:^(RBMutableWhitelistEntry *entry, BOOL *stop) {
            existed = entry.existsInStore;
            if (block != nil) {
                block(entry, stop);
            }
        } conn:conn error:&error];
        
        if (error == nil && entry != nil) {
            if (existed) {
                [self _didUpdateEntryForDomain:entry.domain];
            } else {
                [self _didAddEntryForDomain:entry.domain];
            }
        }
        
        completionHandler(entry, error);
    }];
}

- (RBWhitelistEntry *)_upsertWhitelistEntryForDomain:(NSString *)domain usingBlock:(void(^)(RBMutableWhitelistEntry*, BOOL*))block conn:(sqlite3 *)conn error:(NSError **)outError {
    dispatch_assert_queue(_q);
    
    __block RBWhitelistEntry *result = nil;
    __block NSError *error = nil;
    
    int status = SQLITE_OK;
    
    for (int curTry = 0; curTry < 10; curTry++) {
        status = RBSQLiteTransaction(conn, ^int{
            RBWhitelistEntry *prevEntry = [self _whitelistEntryForDomain:domain conn:conn error:&error];
            if (error != nil) {
                return SQLITE_FAIL;
            }
            
            RBMutableWhitelistEntry *mutableEntry = nil;
            if (prevEntry == nil) {
                mutableEntry = [RBMutableWhitelistEntry new];
                mutableEntry.enabled = YES;
                mutableEntry.domain = domain;
            } else {
                mutableEntry = [prevEntry mutableCopy];
            }
            
            BOOL discard = NO;
            if (block != nil) {
                block(mutableEntry, &discard);
            }
            
            if (discard) {
                return SQLITE_DONE;
            }
            
            int status = SQLITE_OK;
            
            if (mutableEntry.domain.length == 0 || (mutableEntry.groupNames != nil && mutableEntry.groupNames.count == 0)) {
                status = SQLITE_CONSTRAINT;
            } else {
                status = RBSQLiteExecute(conn, @"\
                                         INSERT INTO exception(domain, create_date, modify_date, enabled) VALUES ($1, $2, $3, $4) \
                                         ON CONFLICT(domain) DO UPDATE SET modify_date = $3, enabled = $4 \
                                         ", _normalizeDomain(mutableEntry.domain), mutableEntry.dateCreated ?: [NSDate date], [NSDate date], @(mutableEntry.enabled));
            }

            if (status == SQLITE_DONE) {
                status = RBSQLiteExecute(conn, @"DELETE FROM exception_group WHERE exception_domain = $1", mutableEntry.domain);
            }
            
            if (status == SQLITE_DONE) {
                for (NSString *group in mutableEntry.groupNames ?: @[@"*"]) {
                    status = RBSQLiteExecute(conn, @"INSERT INTO exception_group(exception_domain, name) VALUES (?, ?)", mutableEntry.domain, group);
                    
                    if (status != SQLITE_DONE) {
                        break;
                    }
                }
            }
            
            if (status == SQLITE_DONE) {
                result = [self _whitelistEntryForDomain:domain conn:conn error:&error];
            }
            
            return status;
        });
        
        if (status != SQLITE_BUSY) {
            break;
        }
        
        usleep(arc4random_uniform(curTry * 100) * 1e2);
    }
    
    if (outError != NULL) {
        (*outError) = error ?: NSErrorFromSQLiteStatus(status);
    }
    
    return result;
}

- (void)removeWhitelistEntryForDomain:(NSString *)domain completionHandler:(void (^)(NSError * _Nonnull))completionHandler {
    [self removeWhitelistEntriesForDomains:@[domain] completionHandler:completionHandler];
}

- (void)removeWhitelistEntriesForDomains:(NSArray *)domains completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    [self _accessConnectionUsingBlock:^(sqlite3 *conn) {
        NSError *error = nil;
        NSArray *removedDomains = [self _removeWhitelistEntriesForDomains:domains conn:conn error:&error];
        
        if (removedDomains != nil) {
            for (NSString *domain in removedDomains) {
                [self _didRemoveEntryForDomain:domain];
            }
        }
        
        completionHandler(error);
    }];
}

- (NSArray<NSString *> *)_removeWhitelistEntriesForDomains:(NSArray<NSString*> *)domains conn:(sqlite3 *)conn error:(NSError **)outError {
    dispatch_assert_queue(_q);
    
    sqlite3_stmt *stmt = NULL;
    int status = RBSQLitePrepare(conn, &stmt, @"DELETE FROM exception WHERE domain = ?", @"__replaced__");
    
    NSMutableArray *removed = [NSMutableArray array];
    NSEnumerator *domainEnumerator = [domains objectEnumerator];
    NSString *currentDomain = nil;
    
    while (status == SQLITE_OK && (currentDomain = domainEnumerator.nextObject)) {
        status = RBSQLiteBind(stmt, _normalizeDomain(currentDomain));
        if (status == SQLITE_OK) {
            status = sqlite3_step(stmt);
        }
        
        if (status == SQLITE_DONE) {
            if (sqlite3_changes(conn) > 0) {
                [removed addObject:currentDomain];
            }

            status = SQLITE_OK;
            sqlite3_reset(stmt);
        }
    }
    
    sqlite3_finalize(stmt);
    
    if (outError != NULL) {
        (*outError) = NSErrorFromSQLiteStatus(status);
    }
    
    return status == SQLITE_OK ? [removed copy] : nil;
}

static inline NSString *_normalizeDomain(NSString *domain) {
    // NOTE: Do not alter case; we can't assume the locale of the domain
    return [domain stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)incrementStatWithName:(NSString *)name by:(NSUInteger)delta completionHandler:(void(^)(NSError *))completionHandler {
    NSDate *date = _statDate ?: [NSDate date];
    
    [self _accessConnectionUsingBlock:^(sqlite3 *conn) {
        int status = SQLITE_DONE;
        
        for (int curTry = 0; curTry < 2; curTry++) {
            status = RBSQLiteExecute(conn, [NSString stringWithFormat:@"UPDATE stat \
                                            SET value = value + %ld \
                                            WHERE date = date(datetime($1, 'unixepoch')) AND name = $2 \
                                            ", delta], date, name);
            
            if (status == SQLITE_DONE && sqlite3_changes(conn) == 0) {
                status = RBSQLiteExecute(conn, @"INSERT OR IGNORE INTO stat (date, name, value) VALUES (date(datetime($1, 'unixepoch')), $2, 0)", date, name);
                
                if (status == SQLITE_DONE) {
                    continue;
                }
            }
            
            break;
        }
        
        if (completionHandler != nil) {
            completionHandler(NSErrorFromSQLiteStatus(status));
        }
    }];
}

- (void)getStatsInDateRange:(RBDateRange *)dateRange completionHandler:(nonnull void (^)(NSArray<RBStat *>*, NSError *))completionHandler {
    [self _accessConnectionUsingBlock:^(sqlite3 *conn) {
        NSDate *startDate, *endDate = nil;
        [dateRange startDate:&startDate endDate:&endDate];
        
        sqlite3_stmt *stmt = NULL;
        int status = RBSQLitePrepare(conn, &stmt, @"\
                                     SELECT name, SUM(value) FROM stat \
                                     WHERE date > date(datetime($1, 'unixepoch')) AND date <= date(datetime($2, 'unixepoch')) \
                                     GROUP BY name ORDER BY name \
                                     ", startDate, endDate);
        
        if (status == SQLITE_OK) {
            completionHandler([[RBStat _enumeratorForStatement:stmt] allObjects], nil);
        } else {
            completionHandler(nil, NSErrorFromSQLiteStatus(status));
        }
        
        sqlite3_finalize(stmt);
    }];
}

#pragma mark - Database resources

- (sqlite3 *)_createDatabaseConnection {
    // Make sure the directory exists for the database
    NSURL *directoryURL = [_fileURL URLByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] fileExistsAtPath:directoryURL.path]) {
        [[NSFileManager defaultManager] createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    sqlite3 *conn = NULL;
    int status = sqlite3_open_v2(_fileURL.fileSystemRepresentation, &conn, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, NULL);

    if (status == SQLITE_OK) {
        status = sqlite3_busy_timeout(conn, 1500);
    }
    
    if (status == SQLITE_OK) {
        status = sqlite3_create_function(conn, "root_domain", 1, SQLITE_UTF8, NULL, root_domain, NULL, NULL);
    }
    
    if (status == SQLITE_OK) {
        status = sqlite3_create_function(conn, "in_domain", 2, SQLITE_UTF8, NULL, in_domain, NULL, NULL);
    }
    
    NSAssert(status == SQLITE_OK, @"Database database did not open: %s", sqlite3_errstr(status));
    
    return conn;
}

static void root_domain(sqlite3_context *ctx, int num_values, sqlite3_value **values) {
    if (sqlite3_value_type(values[0]) != SQLITE_TEXT) {
        return sqlite3_result_error(ctx, "root_domain(): wrong parameter type", -1);
    }
    
    const char *inputText = (const char*)sqlite3_value_text(values[0]);
    NSString *input = @(inputText);
    NSString *output = RBRootDomain(input);
    
    if (input == output) {
        sqlite3_result_text(ctx, inputText, -1, SQLITE_TRANSIENT);
    } else {
        sqlite3_result_text(ctx, [output UTF8String], -1, SQLITE_TRANSIENT);
    }
}

static void in_domain(sqlite3_context *ctx, int num_values, sqlite3_value **values) {
    if (sqlite3_value_type(values[0]) != SQLITE_TEXT || sqlite3_value_type(values[1]) != SQLITE_TEXT) {
        return sqlite3_result_error(ctx, "in_domain(): wrong parameter type", -1);
    }
    
    const char *innerText = (const char*)sqlite3_value_text(values[0]);
    const char *outerText = (const char*)sqlite3_value_text(values[1]);

    if (strlen(innerText) > strlen(outerText)) {
        return sqlite3_result_int(ctx, 0);
    }
    
    NSString *outer = @(outerText);
    NSRange range = [outer rangeOfString:@(innerText) options:NSCaseInsensitiveSearch|NSBackwardsSearch];
    
    sqlite3_result_int(ctx, NSMaxRange(range) == outer.length);
}

- (void)_accessConnectionUsingBlock:(void(^)(sqlite3*))block {
    dispatch_async(_q, ^{
        sqlite3 *conn = RBSQLitePoolGet(self->_pool);
        {
            // Initialize first connection (the rest will inherit the schema etc)
            dispatch_semaphore_wait(self->_readySemaphore, DISPATCH_TIME_FOREVER);
            {
                if (!self->_isReady) {
                    // The database is shared between multiple bundles; make sure init happens synchronously
                    int lock = RBInterProcessLock(@"database-init");
                    {
                        NSError *error = nil;
                        
                        if ([self _createTablesWithConnection:conn error:&error]) {
                            self->_isReady = YES;
                        } else {
                            NSLog(@"Could not initialize database: %@", error);
                        }
                    }
                    RBInterProcessUnlock(lock);
                }
            }
            dispatch_semaphore_signal(self->_readySemaphore);
            
            // Invoke accessor block now that the database is (hopefully) initialized
            block(conn);
        }
        RBSQLitePoolPut(self->_pool, conn);
    });
}

- (BOOL)_createTablesWithConnection:(sqlite3 *)conn error:(NSError **)outError {
    dispatch_assert_queue(_q);

    int status = RBSQLiteExecute(conn, @"PRAGMA journal_mode = 'WAL'");
    if (status == SQLITE_ROW) {
        status = SQLITE_DONE; // ignore result
    }
    
    if (status == SQLITE_DONE) {
        status = RBSQLiteExecute(conn, @"PRAGMA foreign_keys = on");
        if (status == SQLITE_ROW) {
            status = SQLITE_DONE; // ignore result
        }
    }
    
    if (status == SQLITE_DONE) {
        status = RBSQLiteExecute(conn, @"\
                                 CREATE TABLE IF NOT EXISTS exception ( \
                                    domain text PRIMARY KEY NOT NULL COLLATE NOCASE CHECK(length(domain) > 0), \
                                    enabled boolean NOT NULL DEFAULT true, \
                                    create_date date NOT NULL, \
                                    modify_date date NOT NULL \
                                 )");
    }
    
    if (status == SQLITE_DONE) {
        status = RBSQLiteExecute(conn, @"\
                                 CREATE TABLE IF NOT EXISTS exception_group ( \
                                    exception_domain text REFERENCES exception(domain) ON DELETE CASCADE, \
                                    name text NOT NULL COLLATE NOCASE CHECK(length(name) > 0) \
                                 )");
    }
    
    if (status == SQLITE_DONE) {
        status = RBSQLiteExecute(conn, @"\
                                 CREATE TABLE IF NOT EXISTS stat ( \
                                    date date NOT NULL, \
                                    name text NOT NULL COLLATE NOCASE CHECK(length(name) > 0), \
                                    value int NOT NULL DEFAULT 0, \
                                    PRIMARY KEY (date, name) \
                                 )");
    }
    
    if (outError != NULL) {
        (*outError) = NSErrorFromSQLiteStatus(status);
    }
    
    return (status == SQLITE_DONE);
}

- (void)_drainPool {
    dispatch_assert_queue_not(_q);
    
    dispatch_barrier_sync(_q, ^{
        RBSQLitePoolDrain(_pool);
    });
}

#pragma mark - Observing

NSNotificationName RBDatabaseDidAddEntryNotification = @"RBDatabaseDidAddEntryNotification";
NSNotificationName RBDatabaseDidUpdateEntryNotification = @"RBDatabaseDidUpdateEntryNotification";
NSNotificationName RBDatabaseDidRemoveEntryNotification = @"RBDatabaseDidRemoveEntryNotification";

NSString *const RBWhitelistEntryDomainKey = @"RBWhitelistEntryDomainKey";
NSString *const RBDatabaseLocalModificationKey = @"RBDatabaseLocalModificationKey";

- (void)_didAddEntryForDomain:(NSString *)domain {
    [[NSNotificationCenter defaultCenter] postNotificationName:RBDatabaseDidAddEntryNotification object:self userInfo:@{
        RBWhitelistEntryDomainKey: domain,
        RBDatabaseLocalModificationKey: @(YES)
    }];
    
    [self _postDistributedNotificationName:RBDatabaseDidAddEntryNotification object:domain];
}

- (void)_didRemoveEntryForDomain:(NSString *)domain {
    [[NSNotificationCenter defaultCenter] postNotificationName:RBDatabaseDidRemoveEntryNotification object:self userInfo:@{
        RBWhitelistEntryDomainKey: domain,
        RBDatabaseLocalModificationKey: @(YES)
    }];

    [self _postDistributedNotificationName:RBDatabaseDidRemoveEntryNotification object:domain];
}

- (void)_didUpdateEntryForDomain:(NSString *)domain {
    [[NSNotificationCenter defaultCenter] postNotificationName:RBDatabaseDidUpdateEntryNotification object:self userInfo:@{
        RBWhitelistEntryDomainKey: domain,
        RBDatabaseLocalModificationKey: @(YES)
    }];

    [self _postDistributedNotificationName:RBDatabaseDidUpdateEntryNotification object:domain];
}

- (void)_instanceDidAddEntry:(NSNotification *)note {
    NSString *domain = nil;
    BOOL isLocal = NO;
    [self _scanDistributedNotificationObject:note.object original:&domain isLocal:&isLocal];
    
    if (domain == nil || isLocal) {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RBDatabaseDidAddEntryNotification object:self userInfo:@{
        RBWhitelistEntryDomainKey: domain,
        RBDatabaseLocalModificationKey: @(NO)
    }];
}

- (void)_instanceDidRemoveEntry:(NSNotification *)note {
    NSString *domain = nil;
    BOOL isLocal = NO;
    [self _scanDistributedNotificationObject:note.object original:&domain isLocal:&isLocal];
    
    if (domain == nil || isLocal) {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RBDatabaseDidRemoveEntryNotification object:self userInfo:@{
        RBWhitelistEntryDomainKey: domain,
        RBDatabaseLocalModificationKey: @(NO)
    }];
}

- (void)_instanceDidUpdateEntry:(NSNotification *)note {
    NSString *domain = nil;
    BOOL isLocal = NO;
    [self _scanDistributedNotificationObject:note.object original:&domain isLocal:&isLocal];
    
    if (domain == nil || isLocal) {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RBDatabaseDidUpdateEntryNotification object:self userInfo:@{
        RBWhitelistEntryDomainKey: domain,
        RBDatabaseLocalModificationKey: @(NO)
    }];
}

#pragma mark - Distributed observing

- (NSUInteger)_distributedHash {
    return (long)(__bridge void *)self ^ getpid();
}

- (NSString *)_distributedNotificationObject:(NSString *)obj {
    return [NSString stringWithFormat:@"%ld-%@", [self _distributedHash], obj];
}

- (BOOL)_scanDistributedNotificationObject:(id)obj original:(NSString **)outOriginal isLocal:(BOOL*)outLocal {
    NSString *str = RBKindOfClassOrNil(NSString, obj);
    if (str == nil) {
        return NO;
    }
    
    NSRange separator = [str rangeOfString:@"-"];
    if (separator.location == NSNotFound) {
        return NO;
    }
    
    if (outLocal != NULL) {
        NSUInteger hash = [[str substringToIndex:separator.location] integerValue];
        (*outLocal) = (hash == [self _distributedHash]);
    }
    
    if (outOriginal != NULL) {
        (*outOriginal) = [str substringFromIndex:NSMaxRange(separator)];
    }
    
    return YES;
}

#if TARGET_OS_IOS
#pragma mark iOS

- (void)_registerExternalObservers {}
- (void)_unregisterExternalObservers {}
- (void)_postDistributedNotificationName:(NSNotificationName)noteName object:(id)object {}

#else
#pragma mark macOS

- (void)_registerExternalObservers {
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(_instanceDidAddEntry:) name:RBDatabaseDidAddEntryNotification object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(_instanceDidUpdateEntry:) name:RBDatabaseDidUpdateEntryNotification object:nil];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(_instanceDidRemoveEntry:) name:RBDatabaseDidRemoveEntryNotification object:nil];
}

- (void)_unregisterExternalObservers {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

- (void)_postDistributedNotificationName:(NSNotificationName)noteName object:(id)object {
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:noteName
                                                                   object:[self _distributedNotificationObject:object]
                                                                 userInfo:nil
                                                       deliverImmediately:YES];
}

#endif

@end

#pragma mark - Scanning

@interface _RBWhitelistEntryEnumerator : NSEnumerator
- (instancetype)initWithStatement:(sqlite3_stmt*)stmt;
@end

@implementation RBWhitelistEntry(SQLite)
+ (NSEnumerator *)_enumeratorForStatement:(sqlite3_stmt*)stmt {
    return [[_RBWhitelistEntryEnumerator alloc] initWithStatement:stmt];
}
+ (nullable instancetype)_entryWithStatement:(sqlite3_stmt*)stmt {
    RBWhitelistEntry *entry = [RBWhitelistEntry new];
    
    entry.domain = RBSQLiteScanString(stmt, 0);
    entry.groupNames = [RBSQLiteScanString(stmt, 1) componentsSeparatedByString:@","];
    
    if (entry.groupNames.count == 1 && [entry.groupNames.firstObject isEqualToString:@"*"]) {
        entry.groupNames = nil;
    }
    
    entry.dateCreated = RBSQLiteScanDate(stmt, 2);
    entry.dateModified = RBSQLiteScanDate(stmt, 3);
    entry.enabled = [RBSQLiteScanNumber(stmt, 4) boolValue];
    entry.existsInStore = YES;
    
    return entry;
}
@end

@implementation _RBWhitelistEntryEnumerator {
    sqlite3_stmt *_stmt;
    BOOL _isNextNull;
    __weak RBDatabase *_database;
}

- (instancetype)initWithStatement:(sqlite3_stmt *)stmt {
    self = [super init];
    if (self == nil)
        return nil;
    
    _stmt = stmt;
    
    return self;
}

- (nullable RBWhitelistEntry *)nextObject {
    if (sqlite3_step(_stmt) != SQLITE_ROW) {
        return nil;
    }
    
    return [RBWhitelistEntry _entryWithStatement:_stmt];
}

@end

@interface _RBStatEnumerator : NSEnumerator
- (instancetype)initWithStatement:(sqlite3_stmt*)stmt;
@end

@implementation RBStat(SQLite)
+ (NSEnumerator *)_enumeratorForStatement:(sqlite3_stmt*)stmt {
    return [[_RBStatEnumerator alloc] initWithStatement:stmt];
}
+ (nullable instancetype)_entryWithStatement:(sqlite3_stmt*)stmt {
    RBStat *stat = [RBStat new];
    stat.name = RBSQLiteScanString(stmt, 0);
    stat.value = [RBSQLiteScanNumber(stmt, 1) unsignedIntegerValue];
    return stat;
}

@end

@implementation _RBStatEnumerator {
    sqlite3_stmt *_stmt;
    BOOL _isNextNull;
    __weak RBDatabase *_database;
}

- (instancetype)initWithStatement:(sqlite3_stmt *)stmt {
    self = [super init];
    if (self == nil)
        return nil;
    
    _stmt = stmt;
    
    return self;
}

- (nullable RBStat *)nextObject {
    if (sqlite3_step(_stmt) != SQLITE_ROW) {
        return nil;
    }
    
    return [RBStat _entryWithStatement:_stmt];
}

@end
