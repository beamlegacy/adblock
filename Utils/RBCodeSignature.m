//
//  RBCodeSignature.m
//  RadBlock
//
//  Created by Mikey on 08/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "RBCodeSignature.h"

@implementation RBCodeSignature {
    SecStaticCodeRef _code;
    SecRequirementRef _requirement;
}

+ (instancetype)embeddedSignature {
    static dispatch_once_t onceToken;
    static RBCodeSignature* embeddedSignature = nil;
    
    dispatch_once(&onceToken, ^{
        embeddedSignature = [[self alloc] initWithFileURL:[NSURL fileURLWithPath:NSProcessInfo.processInfo.arguments.firstObject isDirectory:NO] error:NULL];
        if (embeddedSignature == nil) {
            embeddedSignature = [[RBCodeSignature alloc] init];
        }
    });
    
    return embeddedSignature;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)init {
    [NSException raise:NSInternalInconsistencyException format:@"-[%@ %@] cannot be called directly", self.className, NSStringFromSelector(_cmd)];
    return nil;
}
#pragma clang diagnostic pop

- (instancetype)initWithFileURL:(NSURL *)fileURL error:(NSError **)outError {
    self = [super init];
    if (self == nil)
        return nil;
    
    OSStatus result = SecStaticCodeCreateWithPath((__bridge CFURLRef)fileURL, kSecCSDefaultFlags, &_code);
    if (result == noErr) {
        result = SecCodeCopyDesignatedRequirement(_code, kSecCSDefaultFlags, &_requirement);
    }
    
    CFDictionaryRef signingInfo = NULL;
    if (result == noErr) {
        result = SecCodeCopySigningInformation(_code, kSecCSSigningInformation | kSecCSRequirementInformation | kSecCSDynamicInformation | kSecCSContentInformation, &signingInfo);
    }

    if (result != noErr) {
        if (outError != NULL) {
            (*outError) = [NSError errorWithDomain:NSOSStatusErrorDomain code:result userInfo:@{ NSURLErrorFailingURLErrorKey: fileURL }];
        }
        
        return nil;
    }
    
    _format = (__bridge NSString *)CFDictionaryGetValue(signingInfo, kSecCodeInfoFormat);
    _teamIdentifier = (__bridge NSString *)CFDictionaryGetValue(signingInfo, kSecCodeInfoTeamIdentifier);
    _requirements = (__bridge NSString *)CFDictionaryGetValue(signingInfo, kSecCodeInfoRequirements);
    _identifier = (__bridge NSString *)CFDictionaryGetValue(signingInfo, kSecCodeInfoIdentifier);
    _createDate = (__bridge NSDate *)CFDictionaryGetValue(signingInfo, kSecCodeInfoTimestamp);

    CFDictionaryRef infoPlist = CFDictionaryGetValue(signingInfo, kSecCodeInfoPList);
    if (infoPlist != nil) {
        _version = (__bridge NSString *)CFDictionaryGetValue(infoPlist, CFSTR("CFBundleShortVersionString"));
        _build = (__bridge NSString *)CFDictionaryGetValue(infoPlist, kCFBundleVersionKey);
    }
    
    CFArrayRef certificates = CFDictionaryGetValue(signingInfo, kSecCodeInfoCertificates);
    if (certificates != nil && CFArrayGetCount(certificates) > 0) {
        CFStringRef commonName = NULL;
        SecCertificateCopyCommonName((SecCertificateRef)CFArrayGetValueAtIndex(certificates, 0), &commonName);
        
        if (commonName != NULL) {
            _certificateSubject = (__bridge_transfer NSString *)commonName;
        }
    }
    
    if (signingInfo != NULL) {
        CFRelease(signingInfo);
    }
    
    return self;
}

- (void)dealloc {
    if (_code != NULL) {
        CFRelease(_code);
    }
    
    if (_requirement != NULL) {
        CFRelease(_requirement);
    }
}

- (BOOL)matches:(RBCodeSignature *)otherSignature error:(NSError **)outError {
    if (_requirement == NULL || _code == NULL || otherSignature->_code == NULL) {
        return NO;
    }
    
    CFErrorRef cfError = NULL;
    OSStatus result = SecStaticCodeCheckValidityWithErrors(otherSignature->_code, kSecCSDefaultFlags | kSecCSCheckAllArchitectures, _requirement, &cfError);
    
    if (outError != NULL) {
        (*outError) = CFBridgingRelease(cfError);
    }
    
    return (result == noErr);
}

@end
