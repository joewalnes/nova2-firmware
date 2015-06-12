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

@implementation NVCodecV1

- (NSData*) encodePing:(uint16_t)requestId
{
    return frameV1Msg(requestId, @"P");
}

- (NSData*) encodeFlash:(uint16_t)requestId withWarm:(uint8_t)warmPwm withCool:(uint8_t)coolPwm withTimeout:(uint16_t)timeoutMillis
{
    // Light cmd is formatted "L,w,c,t" where w and c are warm/cool pwm duty cycles as 2 digit hex
    // and t is 4 digit hex timeout.
    // e.g. "L,00,FF,05DC" (means light with warm=0, cool=255, timeout=1500ms)
    return frameV1Msg(requestId, [NSString stringWithFormat:@"L,%02X,%02X,%04X", warmPwm, coolPwm, timeoutMillis]);
}

- (NSData*) encodeOff:(uint16_t)requestId
{
    return frameV1Msg(requestId, @"O");
}

- (BOOL) decodeAck:(NSData*)data extractId:(uint16_t*) resultId
{
    NSString* str = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    
    // Parses "(xx:A)" packet where xx is hex value for resultId.
    
    NSError *regexError = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\(([0-9A-Za-z][0-9A-Za-z]):A\\)"
                                                                           options:0
                                                                             error:&regexError];
    
    NSRange range = NSMakeRange(0, [str length]);
    NSArray *matches = [regex matchesInString:str options:0 range:range];
    if (matches.count == 0) {
        *resultId = 0;
        return NO;
    }
    
    unsigned scanned;
    NSString *hex = [str substringWithRange:[[matches objectAtIndex:0] rangeAtIndex:1]];
    [[NSScanner scannerWithString:hex] scanHexInt:(unsigned*)&scanned];
    
    *resultId = (uint16_t)scanned;
    return YES;
}

NSData* frameV1Msg(uint16_t requestId, NSString *body)
{
    // Requests are framed "(xx:yy)" where xx is 2 digit hex requestId and yy is body string.
    // e.g. "(00:P)"
    //      "(4A:L,00,FF,05DC)"
    return [[NSString stringWithFormat:@"(%02X:%@)", requestId, body] dataUsingEncoding:NSASCIIStringEncoding];
}

@end
