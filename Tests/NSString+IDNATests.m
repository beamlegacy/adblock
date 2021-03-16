//
//  NSString+IDNATests.m
//  RadBlockTests
//
//  Created by Mike Pulaski on 01/11/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSString+IDNA.h"

@interface NSString_IDNATests : XCTestCase

@end


@implementation NSString_IDNATests

// From https://tools.ietf.org/html/rfc3492#section-7.1

- (void)testPunycodeEncoding {
    XCTAssertEqualObjects(
        [[@"\u0644\u064A\u0647\u0645\u0627\u0628\u062A\u0643\u0644\u0645\u0648\u0634\u0639\u0631\u0628\u064A\u061F" punyEncodedString] lowercaseString],
        @"egbpdaj6bu4bxfgehfvwxn"
    );
    XCTAssertEqualObjects(
        [[@"\u4ED6\u4EEC\u4E3A\u4EC0\u4E48\u4E0D\u8BF4\u4E2d\u6587" punyEncodedString] lowercaseString],
        @"ihqwcrb4cv8a8dqg056pqjye"
    );
    XCTAssertEqualObjects(
        [[@"\u4ED6\u5011\u7232\u4EC0\u9EBD\u4E0D\u8AAA\u4E2D\u6587" punyEncodedString] lowercaseString],
        @"ihqwctvzc91f659drss3x8bo0yb"
    );
    XCTAssertEqualObjects(
        [[@"pročprostěnemluvíčesky" punyEncodedString] lowercaseString], // Pro\u010Dprost\u011Bnemluv\xED\u010Desky
        @"proprostnemluvesky-uyb24dma41a"
    );
    XCTAssertEqualObjects(
        [[@"\u05DC\u05DE\u05D4\u05D4\u05DD\u05E4\u05E9\u05D5\u05D8\u05DC\u05D0\u05DE\u05D3\u05D1\u05E8\u05D9\u05DD\u05E2\u05D1\u05E8\u05D9\u05EA" punyEncodedString] lowercaseString],
        @"4dbcagdahymbxekheh6e0a7fei0b"
    );
    XCTAssertEqualObjects(
        [[@"\u092F\u0939\u0932\u094B\u0917\u0939\u093F\u0928\u094D\u0926\u0940\u0915\u094D\u092F\u094B\u0902\u0928\u0939\u0940\u0902\u092C\u094B\u0932\u0938\u0915\u0924\u0947\u0939\u0948\u0902" punyEncodedString] lowercaseString],
        @"i1baa7eci9glrd9b2ae1bj0hfcgg6iyaf8o0a1dig0cd"
    );
    XCTAssertEqualObjects(
        [[@"\u306A\u305C\u307F\u3093\u306A\u65E5\u672C\u8A9E\u3092\u8A71\u3057\u3066\u304F\u308C\u306A\u3044\u306E\u304B" punyEncodedString] lowercaseString],
        @"n8jok5ay5dzabd5bym9f0cm5685rrjetr6pdxa"
    );
    XCTAssertEqualObjects(
        [[@"\uC138\uACC4\uC758\uBAA8\uB4E0\uC0AC\uB78C\uB4E4\uC774\uD55C\uAD6D\uC5B4\uB97C\uC774\uD574\uD55C\uB2E4\uBA74\uC5BC\uB9C8\uB098\uC88B\uC744\uAE4C" punyEncodedString] lowercaseString],
        @"989aomsvi5e83db1d2a355cv1e0vak1dwrv93d5xbh15a0dt30a5jpsd879ccm6fea98c"
    );
    XCTAssertEqualObjects(
        [[@"\u043F\u043E\u0447\u0435\u043C\u0443\u0436\u0435\u043E\u043D\u0438\u043D\u0435\u0433\u043E\u0432\u043E\u0440\u044F\u0442\u043F\u043E\u0440\u0443\u0441\u0441\u043A\u0438" punyEncodedString] lowercaseString],
        @"b1abfaaepdrnnbgefbadotcwatmq2g4l"
    );
    XCTAssertEqualObjects(
        [[@"porquénopuedensimplementehablarenEspañol" punyEncodedString] lowercaseString],
        [@"porqunopuedensimplementehablarenEspaol-fmd56a" lowercaseString]
    );
    XCTAssertEqualObjects(
        [[@"TạisaohọkhôngthểchỉnóitiếngViệt" punyEncodedString] lowercaseString],
        [@"TisaohkhngthchnitingVit-kjcr8268qyxafd2f1b9g" lowercaseString]
    );
    XCTAssertEqualObjects(
        [[@"3\u5E74B\u7D44\u91D1\u516B\u5148\u751F" punyEncodedString] lowercaseString],
        [@"3B-ww4c5e180e575a65lsy2b" lowercaseString]
    );
    XCTAssertEqualObjects(
        [[@"\u5B89\u5BA4\u5948\u7F8E\u6075-with-SUPER-MONKEYS" punyEncodedString] lowercaseString],
        [@"-with-SUPER-MONKEYS-pc58ag80a8qai00g7n9n" lowercaseString]
    );
    XCTAssertEqualObjects(
        [[@"Hello-Another-Way-\u305D\u308C\u305E\u308C\u306E\u5834\u6240" punyEncodedString] lowercaseString],
        [@"Hello-Another-Way--fc4qua05auwb3674vfr0b" lowercaseString]
    );
    XCTAssertEqualObjects(
        [[@"\u3072\u3068\u3064\u5C4B\u6839\u306E\u4E0B2" punyEncodedString] lowercaseString],
        @"2-u9tlzr9756bt3uc0v"
    );
    XCTAssertEqualObjects(
        [[@"Maji\u3067Koi\u3059\u308B5\u79D2\u524D" punyEncodedString] lowercaseString],
        [@"MajiKoi5-783gue6qz075azm5e" lowercaseString]
    );
    XCTAssertEqualObjects(
        [[@"\u30D1\u30D5\u30A3\u30FCde\u30EB\u30F3\u30D0" punyEncodedString] lowercaseString],
        @"de-jg4avhby1noc0d"
    );
    XCTAssertEqualObjects(
        [[@"\u305D\u306E\u30B9\u30D4\u30FC\u30C9\u3067" punyEncodedString] lowercaseString],
        @"d9juau41awczczp"
    );
    XCTAssertEqualObjects(
        [[@"-> $1.00 <-" punyEncodedString] lowercaseString],
        @"-> $1.00 <--"
    );
}

- (void)testPunycodeDecoding {
    XCTAssertEqualObjects(
        @"\u0644\u064A\u0647\u0645\u0627\u0628\u062A\u0643\u0644\u0645\u0648\u0634\u0639\u0631\u0628\u064A\u061F",
        [@"egbpdaj6bu4bxfgehfvwxn" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"\u4ED6\u4EEC\u4E3A\u4EC0\u4E48\u4E0D\u8BF4\u4E2d\u6587",
        [@"ihqwcrb4cv8a8dqg056pqjye" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"\u4ED6\u5011\u7232\u4EC0\u9EBD\u4E0D\u8AAA\u4E2D\u6587",
        [@"ihqwctvzc91f659drss3x8bo0yb" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"pročprostěnemluvíčesky", // Pro\u010Dprost\u011Bnemluv\xED\u010Desky
        [@"proprostnemluvesky-uyb24dma41a" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"\u05DC\u05DE\u05D4\u05D4\u05DD\u05E4\u05E9\u05D5\u05D8\u05DC\u05D0\u05DE\u05D3\u05D1\u05E8\u05D9\u05DD\u05E2\u05D1\u05E8\u05D9\u05EA",
        [@"4dbcagdahymbxekheh6e0a7fei0b" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"\u092F\u0939\u0932\u094B\u0917\u0939\u093F\u0928\u094D\u0926\u0940\u0915\u094D\u092F\u094B\u0902\u0928\u0939\u0940\u0902\u092C\u094B\u0932\u0938\u0915\u0924\u0947\u0939\u0948\u0902",
        [@"i1baa7eci9glrd9b2ae1bj0hfcgg6iyaf8o0a1dig0cd" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"\u306A\u305C\u307F\u3093\u306A\u65E5\u672C\u8A9E\u3092\u8A71\u3057\u3066\u304F\u308C\u306A\u3044\u306E\u304B",
        [@"n8jok5ay5dzabd5bym9f0cm5685rrjetr6pdxa" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"\uC138\uACC4\uC758\uBAA8\uB4E0\uC0AC\uB78C\uB4E4\uC774\uD55C\uAD6D\uC5B4\uB97C\uC774\uD574\uD55C\uB2E4\uBA74\uC5BC\uB9C8\uB098\uC88B\uC744\uAE4C",
        [@"989aomsvi5e83db1d2a355cv1e0vak1dwrv93d5xbh15a0dt30a5jpsd879ccm6fea98c" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"\u043F\u043E\u0447\u0435\u043C\u0443\u0436\u0435\u043E\u043D\u0438\u043D\u0435\u0433\u043E\u0432\u043E\u0440\u044F\u0442\u043F\u043E\u0440\u0443\u0441\u0441\u043A\u0438",
        [@"b1abfaaepdrnnbgefbadotcwatmq2g4l" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"porquénopuedensimplementehablarenEspañol",
        [@"porqunopuedensimplementehablarenEspaol-fmd56a" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"TạisaohọkhôngthểchỉnóitiếngViệt",
        [@"TisaohkhngthchnitingVit-kjcr8268qyxafd2f1b9g" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"3\u5E74B\u7D44\u91D1\u516B\u5148\u751F",
        [@"3B-ww4c5e180e575a65lsy2b" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"\u5B89\u5BA4\u5948\u7F8E\u6075-with-SUPER-MONKEYS",
        [@"-with-SUPER-MONKEYS-pc58ag80a8qai00g7n9n" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"Hello-Another-Way-\u305D\u308C\u305E\u308C\u306E\u5834\u6240",
        [@"Hello-Another-Way--fc4qua05auwb3674vfr0b" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"\u3072\u3068\u3064\u5C4B\u6839\u306E\u4E0B2",
        [@"2-u9tlzr9756bt3uc0v" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"Maji\u3067Koi\u3059\u308B5\u79D2\u524D",
        [@"MajiKoi5-783gue6qz075azm5e" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"\u30D1\u30D5\u30A3\u30FCde\u30EB\u30F3\u30D0",
        [@"de-jg4avhby1noc0d" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"\u305D\u306E\u30B9\u30D4\u30FC\u30C9\u3067",
        [@"d9juau41awczczp" punyDecodedString]
    );
    XCTAssertEqualObjects(
        @"-> $1.00 <-",
        [@"-> $1.00 <--" punyDecodedString]
    );
}

// From https://github.com/bestiejs/punycode.js/blob/98fb2ca34e0fe9afaeaca0abd14749557def9bfc/tests/tests.js

- (void)testIDNAEncoding {
    XCTAssertEqualObjects([@"mañana.com" idnaEncodedString], @"xn--maana-pta.com");
    XCTAssertEqualObjects([@"example.com." idnaEncodedString], @"example.com.");
    XCTAssertEqualObjects([@"bücher.com" idnaEncodedString], @"xn--bcher-kva.com");
    XCTAssertEqualObjects([@"café.com" idnaEncodedString], @"xn--caf-dma.com");
    XCTAssertEqualObjects([@"☃-⌘.com" idnaEncodedString], @"xn----dqo34k.com");
    XCTAssertEqualObjects([@"퐀☃-⌘.com" idnaEncodedString], @"xn----dqo34kn65z.com");
    XCTAssertEqualObjects([@"💩.la" idnaEncodedString], @"xn--ls8h.la");
    XCTAssertEqualObjects([@"\u0434\u0436\u0443\u043C\u043B\u0430@\u0434\u0436p\u0443\u043C\u043B\u0430\u0442\u0435\u0441\u0442.b\u0440\u0444a" idnaEncodedString], @"\u0434\u0436\u0443\u043C\u043B\u0430@xn--p-8sbkgc5ag7bhce.xn--ba-lmcq");
    XCTAssertEqualObjects([@"goo.gl" idnaEncodedString], @"goo.gl");
}

- (void)testIDNADecoding {
    XCTAssertEqualObjects([@"xn--maana-pta.com" idnaDecodedString], @"mañana.com");
    XCTAssertEqualObjects([@"example.com." idnaDecodedString], @"example.com.");
    XCTAssertEqualObjects([@"xn--bcher-kva.com" idnaDecodedString], @"bücher.com");
    XCTAssertEqualObjects([@"xn--caf-dma.com" idnaDecodedString], @"café.com");
    XCTAssertEqualObjects([@"xn----dqo34k.com" idnaDecodedString], @"☃-⌘.com");
    XCTAssertEqualObjects([@"xn----dqo34kn65z.com" idnaDecodedString], @"퐀☃-⌘.com");
    XCTAssertEqualObjects([@"xn--ls8h.la" idnaDecodedString], @"💩.la");
    XCTAssertEqualObjects([@"\u0434\u0436\u0443\u043C\u043B\u0430@xn--p-8sbkgc5ag7bhce.xn--ba-lmcq" idnaDecodedString], @"\u0434\u0436\u0443\u043C\u043B\u0430@\u0434\u0436p\u0443\u043C\u043B\u0430\u0442\u0435\u0441\u0442.b\u0440\u0444a");
    XCTAssertEqualObjects([@"goo.gl" idnaDecodedString], @"goo.gl");
}

@end
