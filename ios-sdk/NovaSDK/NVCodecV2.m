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
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import <Foundation/Foundation.h>

#import "NVCodec.h"

#define CMD_ACK      0
#define CMD_PING     1
#define CMD_FLASH    2
#define CMD_OFF      3
#define CMD_TRIGGER  4

#define PADDING 0

// Break numbers into bytes and encode as big-endian
#define WRITE_U8(val) val
#define WRITE_U16_PART0(val) CFSwapInt16HostToBig(val & 0xFF00)
#define WRITE_U16_PART1(val) CFSwapInt16HostToBig(val << 8)

#define READ_U8(val) val
#define READ_U16(val_part1, val_part2) (\
            (CFSwapInt16BigToHost(val_part2) >> 8) + \
            (CFSwapInt16BigToHost(val_part1)))
#define READ_U32(val_part1, val_part2, val_part3, val_part4) (\
            (CFSwapInt32BigToHost(val_part4) >> 24) + \
            (CFSwapInt32BigToHost(val_part3) >> 16) + \
            (CFSwapInt32BigToHost(val_part2) >> 8) + \
            (CFSwapInt32BigToHost(val_part1)))


@implementation NVCodecV2

- (NSData*) encodePing:(uint16_t)requestId
{
    unsigned char bytes[] = {
        WRITE_U8(CMD_PING),
        WRITE_U8(PADDING),
        WRITE_U16_PART0(requestId),
        WRITE_U16_PART1(requestId)
    };
    return [NSData dataWithBytes:bytes length:4];
}

- (NSData*) encodeFlash:(uint16_t)requestId withWarm:(uint8_t)warmPwm withCool:(uint8_t)coolPwm withTimeout:(uint16_t)timeoutMillis
{
    unsigned char bytes[] = {
        WRITE_U8(CMD_FLASH),
        WRITE_U8(PADDING),
        WRITE_U16_PART0(requestId),
        WRITE_U16_PART1(requestId),
        WRITE_U16_PART0(timeoutMillis),
        WRITE_U16_PART1(timeoutMillis),
        WRITE_U8(warmPwm),
        WRITE_U8(coolPwm)
    };
    return [NSData dataWithBytes:bytes length:8];
 }

- (NSData*) encodeOff:(uint16_t)requestId
{
    unsigned char bytes[] = {
        WRITE_U8(CMD_OFF),
        WRITE_U8(PADDING),
        WRITE_U16_PART0(requestId),
        WRITE_U16_PART1(requestId)
    };
    return [NSData dataWithBytes:bytes length:4];
}

- (NSData*) encodeAck:(uint16_t)requestId
{
    unsigned char bytes[] = {
        WRITE_U8(CMD_ACK),
        WRITE_U8(PADDING),
        WRITE_U16_PART0(requestId),
        WRITE_U16_PART1(requestId)
    };
    return [NSData dataWithBytes:bytes length:4];
}

- (NSData*) encodeFlashDefaults:(NVFlashDefaults*) flashDefaults
{
    unsigned char bytes[] = {
        WRITE_U16_PART0(flashDefaults.regular.timeout),
        WRITE_U16_PART1(flashDefaults.regular.timeout),
        WRITE_U8(flashDefaults.regular.warm),
        WRITE_U8(flashDefaults.regular.cool),
        WRITE_U16_PART0(flashDefaults.preflash.timeout),
        WRITE_U16_PART1(flashDefaults.preflash.timeout),
        WRITE_U8(flashDefaults.preflash.warm),
        WRITE_U8(flashDefaults.preflash.cool),
    };
    return [NSData dataWithBytes:bytes length:8];
}

- (BOOL) decodeAck:(NSData*)data extractId:(uint16_t*) resultId
{
    const unsigned char *bytes = data.bytes;
    if (data.length != 4
            || READ_U8(bytes[0]) != CMD_ACK
            || READ_U8(bytes[1]) != PADDING) {
        return NO;
    }
    
    *resultId = READ_U16(bytes[2], bytes[3]);
    return YES;
}

- (BOOL) decodeTrigger:(NSData*)data extractId:(uint16_t*) resultId extractIsPressed:(BOOL*) resultIsPressed
{
    const unsigned char *bytes = data.bytes;
    if (data.length != 5
        || READ_U8(bytes[0]) != CMD_TRIGGER
        || READ_U8(bytes[1]) != PADDING) {
        return NO;
    }
    
    *resultId = READ_U16(bytes[2], bytes[3]);
    *resultIsPressed = READ_U8(bytes[4]);
    return YES;
}

- (BOOL) decodeFlashDefaults:(NSData*) data
             extractDefaults:(NVFlashDefaults**) resultFlashDefaults;
{
    const unsigned char *bytes = data.bytes;
    if (data.length != 8) {
        return NO;
    }
    
    NVFlashSettings *regular = [NVFlashSettings customWarm: READ_U8(bytes[2])
                                                      cool: READ_U8(bytes[3])
                                                   timeout: READ_U16(bytes[0], bytes[1])];
    
    NVFlashSettings *preflash = [NVFlashSettings customWarm: READ_U8(bytes[6])
                                                       cool: READ_U8(bytes[7])
                                                    timeout: READ_U16(bytes[4], bytes[5])];
    
    *resultFlashDefaults = [[NVFlashDefaults alloc] initWithRegular:regular preflash:preflash];

    return YES;
}

- (BOOL) decodeCounters:(NSData*) data
        extractCounters:(NSArray**) counters;
{
    const unsigned char *bytes = data.bytes;
    if (data.length % 4 != 0) {
        return NO;
    }
    
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:data.length / 4];
    
    for (int i = 0; i < data.length; i+=4) {
        [array addObject: [NSNumber numberWithUnsignedInt: READ_U32(bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3])]];
    }
    
    *counters = array;
    return YES;
}

@end

