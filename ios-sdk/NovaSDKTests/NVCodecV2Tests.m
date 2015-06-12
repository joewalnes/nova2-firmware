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

@interface NVCodecV2Tests : XCTestCase
@end

#define assertEq(a, b) XCTAssertEqual(a, b)
#define assertTrue(v) XCTAssert(v)
#define assertFalse(v) XCTAssertFalse(v)
#define assertStr(a, b) XCTAssertEqualObjects(a, b)

@implementation NVCodecV2Tests

#pragma mark - Encoding tests

// README:
// These tests encode binary data as hex based strings, to aid readability.
// For example, "00 FF" means an array of two bytes with value [0x00, 0xFF].

- (void)testEncodePing
{
    //  ---------------- Cmd (1 => Ping)
    //  |  ------------- Padding (always 0)
    //  |  |   --------- Request ID, uint16_t big endian (e.g. 4E 20 => 20000)
    //  |  |   |
    // -- -- -----
    // 01 00 4E 20
    
    NVCodecV2 *codec = [NVCodecV2 new];
    assertStr(@"01 00 00 00", toHex([codec encodePing:0]));
    assertStr(@"01 00 00 0A", toHex([codec encodePing:10]));
    assertStr(@"01 00 00 FF", toHex([codec encodePing:255]));
    assertStr(@"01 00 01 00", toHex([codec encodePing:256]));
    assertStr(@"01 00 4E 20", toHex([codec encodePing:20000]));
    assertStr(@"01 00 FF FF", toHex([codec encodePing:65535]));
}

- (void)testEncodeFlash
{
    //  ------------------------- Cmd (2 => Flash)
    //  |  ---------------------- Padding (always 0)
    //  |  |   |----------------- Request ID, uint16_t big endian (e.g. 0A 47 => 2631)
    //  |  |   |    |------------ Flash auto-timeout in millis, uint16_t big endian (e.g. 13 88 => 5000ms)
    //  |  |   |    |     |------ Warm PWM (e.g. 20 => 32)
    //  |  |   |    |     |  |--- Cool PWM (e.g. FF => 255)
    //  |  |   |    |     |  |
    // -- -- ----- ----- -- --
    // 02 00 0A 47 13 88 20 FF

    NVCodecV2 *codec = [NVCodecV2 new];
    assertStr(@"02 00 00 00 00 00 00 00", toHex([codec encodeFlash:0
                                                          withWarm:0
                                                          withCool:0
                                                       withTimeout:0]));
    
    assertStr(@"02 00 00 0A 13 88 20 FF", toHex([codec encodeFlash:10
                                                          withWarm:32
                                                          withCool:255
                                                       withTimeout:5000]));
    
    assertStr(@"02 00 0A 47 FF FE FD FC", toHex([codec encodeFlash:2631
                                                          withWarm:253
                                                          withCool:252
                                                       withTimeout:65534]));
}

- (void)testEncodeOff
{
    //  ---------------- Cmd (3 => Off)
    //  |  ------------- Padding (always 0)
    //  |  |   --------- Request ID, uint16_t big endian (e.g. 4E 20 => 20000)
    //  |  |   |
    // -- -- -----
    // 03 00 4E 20
    
    NVCodecV2 *codec = [NVCodecV2 new];
    assertStr(@"03 00 00 00", toHex([codec encodeOff:0]));
    assertStr(@"03 00 00 0A", toHex([codec encodeOff:10]));
    assertStr(@"03 00 00 FF", toHex([codec encodeOff:255]));
    assertStr(@"03 00 01 00", toHex([codec encodeOff:256]));
    assertStr(@"03 00 4E 20", toHex([codec encodeOff:20000]));
    assertStr(@"03 00 FF FF", toHex([codec encodeOff:65535]));
}

- (void)testEncodeAck
{
    //  ---------------- Cmd (0 => Ack)
    //  |  ------------- Padding (always 0)
    //  |  |   --------- Request ID, uint16_t big endian (e.g. 4E 20 => 20000)
    //  |  |   |
    // -- -- -----
    // 00 00 4E 20
    
    NVCodecV2 *codec = [NVCodecV2 new];
    assertStr(@"00 00 00 00", toHex([codec encodeAck:0]));
    assertStr(@"00 00 00 0A", toHex([codec encodeAck:10]));
    assertStr(@"00 00 00 FF", toHex([codec encodeAck:255]));
    assertStr(@"00 00 01 00", toHex([codec encodeAck:256]));
    assertStr(@"00 00 4E 20", toHex([codec encodeAck:20000]));
    assertStr(@"00 00 FF FF", toHex([codec encodeAck:65535]));
}

- (void)testEncodeFlashDefaults
{
    // Note: This doesn't have the command type or request Id as it is accessed directly as a GATT characteristic
    
    //                              [Regular]
    //   -------------------------- Flash auto-timeout in millis, uint16_t big endian (e.g. 20 FF => 5000ms)
    //   |    --------------------- Warm PWM (e.g. FF => 255)
    //   |    |  ------------------ Cool PWM (e.g. 10 => 16)
    //   |    |  |
    //   |    |  |                  [Preflash]
    //   |    |  |    ------------- Flash auto-timeout in millis, uint16_t big endian (e.g. 20 FF => 5000ms)
    //   |    |  |    |   --------- Warm PWM (e.g. FF => 255)
    //   |    |  |    |   |  ------ Cool PWM (e.g. 10 => 16)
    //   |    |  |    |   |  |
    // ----- -- -- ----- -- --
    // 20 FF FF 10 20 FF FF 10
    // ----------- -----------
    //   Regular    Preflash
    
    #define flashDefaults(regular, _preflash) [codec encodeFlashDefaults:[[NVFlashDefaults alloc] initWithRegular:regular preflash:_preflash]]
    
    NVCodecV2 *codec = [NVCodecV2 new];
    
    assertStr(@"00 00 00 00 00 00 00 00",
              toHex(flashDefaults([NVFlashSettings customWarm:0 cool:0 timeout:0],    // regular
                                  [NVFlashSettings customWarm:0 cool:0 timeout:0]))); // preflash
    
    assertStr(@"13 88 FF 10 13 86 FC 12",
              toHex(flashDefaults([NVFlashSettings customWarm:255 cool:16 timeout:5000],    // regular
                                  [NVFlashSettings customWarm:252 cool:18 timeout:4998]))); // preflash
}

#pragma mark - Decoding tests

- (void)testDecodeAck
{
    //  ---------------- Cmd (0 => Ack)
    //  |  ------------- Padding (always 0)
    //  |  |   --------- Request ID, uint16_t big endian (e.g. 4E 20 => 20000)
    //  |  |   |
    // -- -- -----
    // 00 00 4E 20

    NVCodecV2 *codec = [NVCodecV2 new];
    uint16_t decodedRequestId;
    
    // Valid cases
    
    assertTrue([codec decodeAck: fromHex(@"00 00 00 00") extractId: &decodedRequestId]);
    assertEq(0, decodedRequestId);
    
    assertTrue([codec decodeAck: fromHex(@"00 00 00 0A") extractId: &decodedRequestId]);
    assertEq(10, decodedRequestId);

    assertTrue([codec decodeAck: fromHex(@"00 00 00 FF") extractId: &decodedRequestId]);
    assertEq(255, decodedRequestId);
    
    assertTrue([codec decodeAck: fromHex(@"00 00 01 00") extractId: &decodedRequestId]);
    assertEq(256, decodedRequestId);
    
    assertTrue([codec decodeAck: fromHex(@"00 00 4E 20") extractId: &decodedRequestId]);
    assertEq(20000, decodedRequestId);
    
    assertTrue([codec decodeAck: fromHex(@"00 00 FF FF") extractId: &decodedRequestId]);
    assertEq(65535, decodedRequestId);
 
    // Invalid cases
    assertFalse([codec decodeAck: fromHex(@"03 00 00 0A") extractId: &decodedRequestId]);
    assertFalse([codec decodeAck: fromHex(@"00 01 00 0A") extractId: &decodedRequestId]);
    assertFalse([codec decodeAck: fromHex(@"00 00 00") extractId: &decodedRequestId]);
    assertFalse([codec decodeAck: fromHex(@"00 00 00 0A 00") extractId: &decodedRequestId]);
}

- (void)testDecodeTrigger
{
    //  ---------------- Cmd (4 => Trigger)
    //  |  ------------- Padding (always 0)
    //  |  |   --------- Request ID, uint16_t big endian (e.g. 4E 20 => 20000)
    //  |  |   |    ---- Is button pressed (1 => true)
    //  |  |   |    |
    // -- -- ----- --
    // 04 00 4E 20 01

    NVCodecV2 *codec = [NVCodecV2 new];
    uint16_t decodedRequestId;
    BOOL decodedIsPressed;
    
    // Valid cases
    
    assertTrue([codec decodeTrigger: fromHex(@"04 00 00 00 00")
                          extractId: &decodedRequestId
                   extractIsPressed: &decodedIsPressed]);
    assertEq(0, decodedRequestId);
    assertFalse(decodedIsPressed);
    
    assertTrue([codec decodeTrigger: fromHex(@"04 00 00 0A 01")
                          extractId: &decodedRequestId
                   extractIsPressed: &decodedIsPressed]);
    assertEq(10, decodedRequestId);
    assertTrue(decodedIsPressed);
    
    assertTrue([codec decodeTrigger: fromHex(@"04 00 00 FF 00")
                          extractId: &decodedRequestId
                   extractIsPressed: &decodedIsPressed]);
    assertEq(255, decodedRequestId);
    assertFalse(decodedIsPressed);
    
    assertTrue([codec decodeTrigger: fromHex(@"04 00 01 00 01")
                          extractId: &decodedRequestId
                   extractIsPressed: &decodedIsPressed]);
    assertEq(256, decodedRequestId);
    assertTrue(decodedIsPressed);
    
    assertTrue([codec decodeTrigger: fromHex(@"04 00 4E 20 00")
                          extractId: &decodedRequestId
                   extractIsPressed: &decodedIsPressed]);
    assertEq(20000, decodedRequestId);
    assertFalse(decodedIsPressed);
    
    assertTrue([codec decodeTrigger: fromHex(@"04 00 FF FF 01")
                          extractId: &decodedRequestId
                   extractIsPressed: &decodedIsPressed]);
    assertEq(65535, decodedRequestId);
    assertTrue(decodedIsPressed);
    
    // Invalid cases
    assertFalse([codec decodeTrigger: fromHex(@"03 00 00 0A 00")
                           extractId: &decodedRequestId
                    extractIsPressed: &decodedIsPressed]);
    assertFalse([codec decodeTrigger: fromHex(@"04 01 00 0A 00")
                           extractId: &decodedRequestId
                    extractIsPressed: &decodedIsPressed]);
    assertFalse([codec decodeTrigger: fromHex(@"04 00 00 0A")
                           extractId: &decodedRequestId
                    extractIsPressed: &decodedIsPressed]);
    assertFalse([codec decodeTrigger: fromHex(@"04 00 00 0A 00 00")
                           extractId: &decodedRequestId
                    extractIsPressed: &decodedIsPressed]);
}

- (void)testDecodeFlashDefaults
{
    // See testEncodeFlashDefaults for binary details
    
    NVCodecV2 *codec = [NVCodecV2 new];
    NVFlashDefaults *defaults;
    
    // Valid cases
    
    assertTrue([codec decodeFlashDefaults: fromHex(@"00 00 00 00 00 00 00 00")
                          extractDefaults: &defaults]);
    assertEq(0, defaults.regular.warm);
    assertEq(0, defaults.regular.cool);
    assertEq(0, defaults.regular.timeout);
    assertEq(0, defaults.preflash.warm);
    assertEq(0, defaults.preflash.cool);
    assertEq(0, defaults.preflash.timeout);

    assertTrue([codec decodeFlashDefaults: fromHex(@"13 88 FF 10 13 86 FC 12")
                          extractDefaults: &defaults]);
    assertEq(255 , defaults.regular.warm);
    assertEq(16  , defaults.regular.cool);
    assertEq(5000, defaults.regular.timeout);
    assertEq(252 , defaults.preflash.warm);
    assertEq(18  , defaults.preflash.cool);
    assertEq(4998, defaults.preflash.timeout);
    
    // Invalid cases

    assertFalse([codec decodeFlashDefaults: fromHex(@"13 88 FF 10 13 86 FC")
                           extractDefaults: &defaults]);
    
    assertFalse([codec decodeFlashDefaults: fromHex(@"13 88 FF 10 13 86 FC 12 00")
                           extractDefaults: &defaults]);
    
}

- (void) testDecodeCounters
{
    
    NVCodecV2 *codec = [NVCodecV2 new];
    NSArray *counters;
    
    // Counters are represented as a list of 32 bit unsigned ints (4 bytes).
    // The number of counters may change over time. The decoder simply returns an
    // array of uint32_t.
    
    // Valid cases
    assertTrue([codec decodeCounters: fromHex(@"00 00 00 00 "
                                              @"00 00 00 63 "
                                              @"00 BC 61 4E "
                                              @"49 96 02 D2 "
                                              @"00 00 00 16 "
                                              @"00 00 00 64 "
                                              @"FF FF FF FF")
                    extractCounters: &counters]);
    assertEq(7         , counters.count);
    assertEq(0         , [(NSNumber*)counters[0] unsignedIntValue]);
    assertEq(99        , [(NSNumber*)counters[1] unsignedIntValue]);
    assertEq(12345678  , [(NSNumber*)counters[2] unsignedIntValue]);
    assertEq(1234567890, [(NSNumber*)counters[3] unsignedIntValue]);
    assertEq(22        , [(NSNumber*)counters[4] unsignedIntValue]);
    assertEq(100       , [(NSNumber*)counters[5] unsignedIntValue]);
    assertEq(4294967295, [(NSNumber*)counters[6] unsignedIntValue]);
    
    assertTrue([codec decodeCounters: fromHex(@"00 00 00 00 "
                                              @"00 00 00 63 "
                                              @"00 BC 61 4E "
                                              @"49 96 02 D2 "
                                              @"00 00 00 16 "
                                              @"00 00 00 64 "
                                              @"FF FF FF FF "
                                              @"00 00 00 63 "
                                              @"00 BC 61 4E "
                                              @"49 96 02 D2 "
                                              @"00 00 00 16 "
                                              @"00 00 00 64")
                    extractCounters: &counters]);
    assertEq(12        , counters.count);
    assertEq(0         , [(NSNumber*)counters[0] unsignedIntValue]);
    assertEq(99        , [(NSNumber*)counters[1] unsignedIntValue]);
    assertEq(12345678  , [(NSNumber*)counters[2] unsignedIntValue]);
    assertEq(1234567890, [(NSNumber*)counters[3] unsignedIntValue]);
    assertEq(22        , [(NSNumber*)counters[4] unsignedIntValue]);
    assertEq(100       , [(NSNumber*)counters[5] unsignedIntValue]);
    assertEq(4294967295, [(NSNumber*)counters[6] unsignedIntValue]);
    assertEq(99        , [(NSNumber*)counters[7] unsignedIntValue]);
    assertEq(12345678  , [(NSNumber*)counters[8] unsignedIntValue]);
    assertEq(1234567890, [(NSNumber*)counters[9] unsignedIntValue]);
    assertEq(22        , [(NSNumber*)counters[10] unsignedIntValue]);
    assertEq(100       , [(NSNumber*)counters[11] unsignedIntValue]);
    
    assertTrue([codec decodeCounters: fromHex(@"00 00 00 00 "
                                              @"FF FF FF FF")
                    extractCounters: &counters]);
    assertEq(2         , counters.count);
    assertEq(0         , [(NSNumber*)counters[0] unsignedIntValue]);
    assertEq(4294967295, [(NSNumber*)counters[1] unsignedIntValue]);
    
    assertTrue([codec decodeCounters: [NSData data] // no-counters: this is valide
                    extractCounters: &counters]);
    assertEq(0         , counters.count);
   
    // Invalid cases
    assertFalse([codec decodeCounters: fromHex(@"00 00 00 00 "
                                               @"00 00 00 63 "
                                               @"00 BC 61 4E "
                                               @"49 96 02 D2 "
                                               @"00 00 00 16 "
                                               @"00 00 00 64 "
                                               @"FF FF FF") // missing byte
                     extractCounters: &counters]);

    assertFalse([codec decodeCounters: fromHex(@"00 00 00 00 "
                                               @"00 00 00 63 "
                                               @"00 BC 61 4E "
                                               @"49 96 02 D2 "
                                               @"00 00 00 16 "
                                               @"00 00 00 64 "
                                               @"FF FF FF FF FF") // extra byte
                     extractCounters: &counters]);

}

#pragma mark - Helper functions

// Covert binary data into human readable string of hex pairs, one for each byte: (e.g. "00 FA 3C")
NSString *toHex(NSData *data)
{
    NSMutableString *str = [NSMutableString stringWithCapacity:(data.length * 3) - 1];
    const unsigned char *bytes = data.bytes;
    for (int i = 0; i < data.length; i++) {
        if (i > 0) {
            [str appendString:@" "];
        }
        [str appendFormat:@"%02X", bytes[i]];
    }
    return str;
}

// Opposite of toHex()
NSData *fromHex(NSString *str)
{
    NSArray *hexes = [str componentsSeparatedByString:@" "];
    NSMutableData *data = [NSMutableData dataWithCapacity:hexes.count];
    [hexes enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL *stop) {
        NSString *hex = object;
        unsigned scanned;
        [[NSScanner scannerWithString:hex] scanHexInt:(unsigned*)&scanned];
        const unsigned char byte = scanned;
        [data appendBytes:&byte length:1];
    }];
    return data;
}


@end
