//  The MIT License (MIT)
//
//  Copyright (c) 2013-2015 Joe Walnes, Sneaky Squid LLC.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial ions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import <XCTest/XCTest.h>
#import "NVCodec.h"

@interface NVCodecV1Tests : XCTestCase
@end

#define assertEq(a, b) XCTAssertEqual(a, b)
#define assertTrue(v) XCTAssert(v)
#define assertFalse(v) XCTAssertFalse(v)
#define assertStr(a, b) XCTAssertEqualObjects(a, b)

#define dataToStr(data) [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]
#define strToData(str) [str dataUsingEncoding:NSASCIIStringEncoding]

@implementation NVCodecV1Tests

- (void)testEncodePing
{
    NVCodecV1 *codec = [NVCodecV1 new];
    assertStr(@"(00:P)", dataToStr([codec encodePing:0]));
    assertStr(@"(0A:P)", dataToStr([codec encodePing:10]));
    assertStr(@"(FF:P)", dataToStr([codec encodePing:255]));
}

- (void)testEncodeFlash
{
    NVCodecV1 *codec = [NVCodecV1 new];
    assertStr(@"(00:L,00,00,0000)", dataToStr([codec encodeFlash:0
                                                        withWarm:0
                                                        withCool:0
                                                     withTimeout:0]));
    
    assertStr(@"(0A:L,20,FF,1388)", dataToStr([codec encodeFlash:10
                                                        withWarm:32
                                                        withCool:255
                                                     withTimeout:5000]));
    
    assertStr(@"(FF:L,FF,FF,FFFF)", dataToStr([codec encodeFlash:255
                                                        withWarm:255
                                                        withCool:255
                                                     withTimeout:65535]));
}

- (void)testEncodeOff
{
    NVCodecV1 *codec = [NVCodecV1 new];
    assertStr(@"(00:O)", dataToStr([codec encodeOff:0]));
    assertStr(@"(0A:O)", dataToStr([codec encodeOff:10]));
    assertStr(@"(FF:O)", dataToStr([codec encodeOff:255]));
}

- (void)testDecodeAck
{
    NVCodecV1 *codec = [NVCodecV1 new];
    uint16_t decodedRequestId;
    
    // Valid cases
    
    assertTrue([codec decodeAck: strToData(@"(00:A)") extractId: &decodedRequestId]);
    assertEq(0, decodedRequestId);

    assertTrue([codec decodeAck: strToData(@"(0A:A)") extractId: &decodedRequestId]);
    assertEq(10, decodedRequestId);
    
    assertTrue([codec decodeAck: strToData(@"(FF:A)") extractId: &decodedRequestId]);
    assertEq(255, decodedRequestId);
    
    // Invalid cases
    assertFalse([codec decodeAck: strToData(@"(00:X)") extractId: &decodedRequestId]);
    assertFalse([codec decodeAck: strToData(@"(00:A") extractId: &decodedRequestId]);
    assertFalse([codec decodeAck: strToData(@"00:A)") extractId: &decodedRequestId]);
}

@end
