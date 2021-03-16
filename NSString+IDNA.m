//
//  NSString+IDNA.m
//  RadBlockTests
//
//  Created by Mike Pulaski on 01/11/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "NSString+IDNA.h"
#import "punycode.h"


#if BYTE_ORDER == LITTLE_ENDIAN
    #define UTF32_ENCODING NSUTF32LittleEndianStringEncoding
#elif BYTE_ORDER == BIG_ENDIAN
    #define UTF32_ENCODING NSUTF32BigEndianStringEncoding
#else
    #error Unexpected BYTE_ORDER
#endif


@implementation NSString(IDNA)

- (NSString *)punyEncodedString {
    NSData *utf32Data = [self dataUsingEncoding:UTF32_ENCODING];
    punycode_uint utf32Points = (punycode_uint) utf32Data.length / sizeof(UTF32Char);
    unsigned char caseFlags[utf32Data.length];
    
    char output[utf32Data.length+1];
    punycode_uint outputLength = (punycode_uint) utf32Data.length;
    
    int status = punycode_encode(utf32Points, utf32Data.bytes, caseFlags, &outputLength, output);
    NSAssert(status == punycode_success, @"Could not encode buffer %d", status);
    
    if (status != punycode_success) {
        return self;
    }
    
    return [[NSString alloc] initWithBytes:output length:outputLength encoding:NSASCIIStringEncoding];
}

- (NSString *)punyDecodedString {
    NSData *asciiData = [self dataUsingEncoding:NSASCIIStringEncoding];
    punycode_uint outputPoints = (punycode_uint) asciiData.length;
    punycode_uint output[outputPoints * sizeof(UTF32Char) + 1];
    
    int status = punycode_decode((punycode_uint) asciiData.length, asciiData.bytes, &outputPoints, (punycode_uint*)output, NULL);
    NSAssert(status == punycode_success, @"Could not decode buffer %d", status);
    
    if (status != punycode_success) {
        return self;
    }
    
    return [[NSString alloc] initWithBytes:output length:outputPoints * sizeof(UTF32Char) encoding:UTF32_ENCODING];
}

- (NSString *)idnaEncodedString {
    NSRange atRange = [self rangeOfString:@"@"];
    if (atRange.location != NSNotFound) {
        NSString *address = [self substringToIndex:NSMaxRange(atRange)];
        NSString *domain = [self substringFromIndex:NSMaxRange(atRange)];
        return [address stringByAppendingString:[[domain precomposedStringWithCompatibilityMapping] _idnaEncodedString]];
    }
    
    return [[self precomposedStringWithCompatibilityMapping] _idnaEncodedString];
}

- (NSString *)_idnaEncodedString {
    static dispatch_once_t onceToken;
    static NSCharacterSet *nonAscii = nil;
    dispatch_once(&onceToken, ^{
        nonAscii = [[NSCharacterSet characterSetWithRange:NSMakeRange(1, 127)] invertedSet];
    });
    
    if ([self rangeOfCharacterFromSet:nonAscii].location == NSNotFound) {
        return [self lowercaseString];
    }
    
    NSMutableString *encoded = [NSMutableString string];

    [self _enumerateDomainComponentsUsingBlock:^(NSString *component, NSString *delimiter, BOOL *stop) {
        if (component != nil) {
            if ([component rangeOfCharacterFromSet:nonAscii].location != NSNotFound) {
                [encoded appendFormat:@"xn--%@", [component punyEncodedString]];
            } else {
                [encoded appendString:component];
            }
        }
        
        if (delimiter != nil) {
            [encoded appendString:delimiter];
        }
    }];
    
    return [encoded lowercaseString];
}

- (void)_enumerateDomainComponentsUsingBlock:(void(^)(NSString *__nullable component, NSString *__nullable delim, BOOL*))block {
    NSScanner *scanner = [NSScanner scannerWithString:self];
    NSCharacterSet *delimiters = [NSCharacterSet characterSetWithCharactersInString:@"\x2E\u3002\uFF0E\uFF61"]; // RFC 3490 separators
    
    NSString *component = nil;
    NSString *delimiter = nil;

    BOOL stop = NO;
    
    while (!stop && !scanner.atEnd) {
        if (![scanner scanUpToCharactersFromSet:delimiters intoString:&component]) {
            component = nil;
        }
        
        if (![scanner scanCharactersFromSet:delimiters intoString:&delimiter]) {
            delimiter = nil;
        }
        
        block(component, delimiter, &stop);
    }
}

- (NSString *)idnaDecodedString {
    NSRange atRange = [self rangeOfString:@"@"];
    if (atRange.location != NSNotFound) {
        NSString *address = [self substringToIndex:NSMaxRange(atRange)];
        NSString *domain = [self substringFromIndex:NSMaxRange(atRange)];
        return [address stringByAppendingString:[domain _idnaDecodedString]];
    }
    
    return [self _idnaDecodedString];
}

- (NSString *)_idnaDecodedString {
    NSMutableString *decoded = [NSMutableString string];

    [self _enumerateDomainComponentsUsingBlock:^(NSString *component, NSString *delimiter, BOOL *stop) {
        if (component != nil) {
            if ([component hasPrefix:@"xn--"]) {
                [decoded appendString:[[component substringFromIndex:4] punyDecodedString]];
            } else {
                [decoded appendString:component];
            }
        }
        
        if (delimiter != nil) {
            [decoded appendString:delimiter];
        }
    }];
    
    return [decoded copy];
}

@end
