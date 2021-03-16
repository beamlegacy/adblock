//
//  NSString+IDNA.h
//  RadBlockTests
//
//  Created by Mike Pulaski on 01/11/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString(IDNA)

@property(nonatomic,readonly) NSString *idnaEncodedString;
@property(nonatomic,readonly) NSString *idnaDecodedString;

@property(nonatomic,readonly) NSString *punyEncodedString;
@property(nonatomic,readonly) NSString *punyDecodedString;

@end

NS_ASSUME_NONNULL_END
