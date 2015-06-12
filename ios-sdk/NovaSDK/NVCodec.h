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
#import "NVFlashDefaults.h"

@protocol NVCodec<NSObject>

@required // All protocols

- (NSData*) encodePing:(uint16_t) requestId;

- (NSData*) encodeFlash:(uint16_t) requestId
               withWarm:(uint8_t) warmPwm
               withCool:(uint8_t) coolPwm
            withTimeout:(uint16_t) timeoutMillis;

- (NSData*) encodeOff:(uint16_t) requestId;

@optional // Added in V2 protocol

- (NSData*) encodeAck:(uint16_t) requestId;

- (NSData*) encodeFlashDefaults:(NVFlashDefaults*) flashDefaults;

@required // All protocols

- (BOOL) decodeAck:(NSData*) data
         extractId:(uint16_t*) resultId;

@optional // Added in V2 protocol

- (BOOL) decodeTrigger:(NSData*) data
             extractId:(uint16_t*) result
      extractIsPressed:(BOOL*) resultIsPressed;

- (BOOL) decodeFlashDefaults:(NSData*) data
             extractDefaults:(NVFlashDefaults**) resultFlashDefaults;

- (BOOL) decodeCounters:(NSData*) data
        extractCounters:(NSArray**) counters;

@end

@interface NVCodecV1 : NSObject<NVCodec>
@end

@interface NVCodecV2 : NSObject<NVCodec>
@end
