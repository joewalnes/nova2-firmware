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

#import "NVFlashSettings.h"

uint16_t const NV_DEFAULT_FLASH_TIMEOUT = 10000;

@interface NVFlashSettings()
@property (nonatomic) uint8_t warm;
@property (nonatomic) uint8_t cool;
@property (nonatomic) uint16_t timeout;
@end

@implementation NVFlashSettings

- (id) initWithWarm:(uint8_t)warm cool:(uint8_t)cool timeout:(uint16_t)timeout;
{
    self = [super init];
    if (self) {
        self.warm = warm;
        self.cool = cool;
        self.timeout = timeout;
    }
    return self;
}

+ (NVFlashSettings *)off
{
    return [NVFlashSettings customWarm:0 cool:0 timeout: 0];
}

+ (NVFlashSettings *)gentle
{
    return [NVFlashSettings customWarm:31 cool:31];
}

+ (NVFlashSettings *)neutral
{
    return [NVFlashSettings customWarm:0 cool:255];
}

+ (NVFlashSettings *)warm
{
    return [NVFlashSettings customWarm:255 cool:127];
}

+ (NVFlashSettings *)bright
{
    return [NVFlashSettings customWarm:255 cool:255];
}

+ (NVFlashSettings *)customWarm:(uint8_t)warm cool:(uint8_t)cool
{
    return [NVFlashSettings customWarm:warm cool:cool timeout:NV_DEFAULT_FLASH_TIMEOUT];
}

+ (NVFlashSettings *)customWarm:(uint8_t)warm cool:(uint8_t)cool timeout:(uint16_t)timeout
{
    return [[NVFlashSettings alloc] initWithWarm:warm cool:cool timeout:timeout];
}

- (NVFlashSettings *)flashSettingsWithTimeout:(uint16_t)timeout
{
    return [NVFlashSettings customWarm:self.warm cool:self.cool timeout:timeout];
}
@end
