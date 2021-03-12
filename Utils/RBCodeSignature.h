//
//  RBCodeSignature.h
//  RadBlock
//
//  Created by Mikey on 08/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*! A class to calculate and verify code signatures for executables or app bundles */
@interface RBCodeSignature : NSObject

/*! The code signature for the current running application / executable */
+ (instancetype)embeddedSignature;

/*!
 The designated initializer.
 
 \param fileURL     The URL to the executable or app bundle used to calculate the signature
 \param outError    An optional pointer to an error (used if a signature could not be calculated)
 
 \returns The code signature for fileURL or nil
 */
- (nullable instancetype)initWithFileURL:(NSURL *)fileURL error:(NSError **__nullable)outError NS_DESIGNATED_INITIALIZER;

/*! The version (CFBundleShortVersionString) of the code */
@property(nonatomic,readonly) NSString *__nullable version;

/*! The build number (CFBundleVersion) of the code */
@property(nonatomic,readonly) NSString *__nullable build;

/*! The format (architecture) of the executable */
@property(nonatomic,readonly) NSString *__nullable format;

/*! The identifier (CFBundleIdentifier) of the executable */
@property(nonatomic,readonly) NSString *__nullable identifier;

/*! The team identifier used to sign the executable */
@property(nonatomic,readonly) NSString *__nullable teamIdentifier;

/*! The subject of the certificate used to create the signature */
@property(nonatomic,readonly) NSString *__nullable certificateSubject;

/*! The requirements needed to match the signature */
@property(nonatomic,readonly) NSString *__nullable requirements;

/*! The date the signature was created. */
@property(nonatomic,readonly) NSDate *__nullable createDate;

/*!
 Verify equality between two signatures. Use this method to verify authenticity of a signature between two executables.
 
 \param signature The signature used to match against
 \param outError  An optional pointer to an error describing why a signature does not match
 
 \returns YES if the signatures match.
 */
- (BOOL)matches:(RBCodeSignature *)signature error:(NSError **__nullable)outError;

@end

NS_ASSUME_NONNULL_END
