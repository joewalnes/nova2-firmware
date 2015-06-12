//  The MIT License (MIT)
//
//  Copyright (c) 2015 Joe Walnes, Sneaky Squid LLC.
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
#import "NVFlashSettings.h"

// Flash defaults are settings that are stored on the Nova device and used
// when the user triggers the light from the physical on-device button.
// They settings have to be sent to the device before the photo is taken.
// There are two settings:
// - regular: brightness/timeout values for the regular flash
// - preflash: brightness/timeout value for lower intensity light used before
//             the actual photo, to aid focusing and scene composition.
@interface NVFlashDefaults : NSObject

// Set intensity of warm LEDs. Any value from 0-255, where 0=off and 255=max.
@property (nonatomic, readonly) NVFlashSettings *regular;
@property (nonatomic, readonly) NVFlashSettings *preflash;

// Constructor. Initialize with default (zeroed) values.
- (id) init;

// Constructor with specific settings.
- (id) initWithRegular:(NVFlashSettings*)regular preflash:(NVFlashSettings*)preflash;

// Creates a copy of the current flash defaults but with new "regular" settings.
- (NVFlashDefaults*) withRegular:(NVFlashSettings*)regular;

// Creates a copy of the current flash defaults but with new "preflash" settings.
- (NVFlashDefaults*) withPreflash:(NVFlashSettings*)preflash;

@end