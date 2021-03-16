//
//  RBUtils.m
//  RadBlock
//
//  Created by Mikey on 18/10/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RBUtils.h"

NSString *const RBAppGroupIdentifier = @"EEQTQC5N2L.radblock";
NSUserDefaults *RBSharedUserDefaults = nil;

BOOL RBIsDateDurationFake = NO;

NSURL *RBApplicationDataURL = nil;
NSURL *RBSharedApplicationDataURL = nil;

__attribute__((constructor)) static void init() {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSURL *supportDirectory = [fileManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
    assert(supportDirectory != nil);
    
    RBApplicationDataURL = [supportDirectory URLByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier] isDirectory:YES];
//    RBSharedApplicationDataURL = [fileManager containerURLForSecurityApplicationGroupIdentifier:RBAppGroupIdentifier];
    RBSharedApplicationDataURL = RBApplicationDataURL; // TODO(nl) check that swapping this root path is OK
    
    assert(RBSharedApplicationDataURL != nil);
    
    // Make sure directories actually exist
    if (![fileManager fileExistsAtPath:RBApplicationDataURL.path]) {
        assert([fileManager createDirectoryAtURL:RBApplicationDataURL withIntermediateDirectories:YES attributes:nil error:NULL]);
    }

    if (![fileManager fileExistsAtPath:RBSharedApplicationDataURL.path]) {
        assert([fileManager createDirectoryAtURL:RBSharedApplicationDataURL withIntermediateDirectories:YES attributes:nil error:NULL]);
    }

    #ifdef DEBUG
        RBIsDateDurationFake = [(NSProcessInfo.processInfo.environment[@"RADBLOCK_FAKE_DATE_DURATIONS"] ?: @"") boolValue];
    #endif
    
    RBSharedUserDefaults = [[NSUserDefaults alloc] initWithSuiteName:RBAppGroupIdentifier];
}

BOOL RBSafariServicesIsVersion13OrHigher() {
    NSOperatingSystemVersion osVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
    switch (osVersion.majorVersion) {
        case 11:
            return YES;
        case 10:
            if (osVersion.minorVersion == 13) {
                return osVersion.patchVersion >= 6;
            } else if (osVersion.minorVersion == 14) {
                return osVersion.patchVersion >= 5;
            } else {
                return osVersion.minorVersion >= 15;
            }
        default:
            return NO;
    }
}

NSString* RBRootDomain(NSString *domain) {
    NSRange lastDot = [domain rangeOfString:@"." options:NSBackwardsSearch];
    if (lastDot.location == NSNotFound) {
        return domain;
    }
    
    NSRange prevDot = [domain rangeOfString:@"." options:NSBackwardsSearch range:NSMakeRange(0, lastDot.location)];
    if (prevDot.location == NSNotFound) {
        return domain;
    }
    
    return [domain substringFromIndex:prevDot.location+1];
}

#pragma mark -

BOOL RBMoveFileURL(NSURL *sourceURL, NSURL *destURL, NSError **outError) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Make sure filters directory exists
    NSURL *destDirectory = destURL.URLByDeletingLastPathComponent;
    if (![fileManager fileExistsAtPath:destDirectory.path]) {
        if (![fileManager createDirectoryAtURL:destDirectory withIntermediateDirectories:YES attributes:nil error:outError]) {
            return NO;
        }
    }
    
    NSError *error = nil;
    [fileManager replaceItemAtURL:destURL
                    withItemAtURL:sourceURL
                   backupItemName:[NSString stringWithFormat:@".%@.tmp", destURL.lastPathComponent]
                          options:NSFileManagerItemReplacementUsingNewMetadataOnly
                 resultingItemURL:nil
                            error:&error];
    
    if (error != nil) {
        // Revert replacement if needed
        NSURL *misplacedLocation = error.userInfo[@"NSFileOriginalItemLocationKey"];
        
        if (misplacedLocation != nil) {
            NSError *revertError = nil;
            
            if (![fileManager moveItemAtURL:misplacedLocation toURL:destURL error:&revertError]) {
                NSLog(@"WARNING: Could not revert copy for %@: %@", destURL.path, revertError);
            }
        }
    }
    
    if (outError != NULL) {
        (*outError) = error;
    }
    
    return error == nil;
}

NSURL *__nullable RBCreateTemporaryDirectory(NSError **outError) {
    NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];
    return [[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory inDomain:NSUserDomainMask appropriateForURL:bundleURL create:YES error:outError];
}

#pragma mark - Locks

static inline NSURL *_RBInterProcessLockURL(NSString *name) {
    return [RBSharedApplicationDataURL URLByAppendingPathComponent:[NSString stringWithFormat:@".%@.lock", name]];
}

int RBInterProcessLock(NSString *name) {
    return open(
                _RBInterProcessLockURL(name).fileSystemRepresentation,
                O_CREAT | // create the file if it's not present.
                O_WRONLY | // only need write access for the internal locking semantics.
                O_EXLOCK, // use an exclusive lock when opening the file.
                S_IRUSR | S_IWUSR); //permissions on the file, 600 here.
}

void RBInterProcessUnlock(int fd) {
    close(fd);
}

