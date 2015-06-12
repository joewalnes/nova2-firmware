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

#import "NVFlashDefaults.h"

@interface NVFlashDefaults()
@property (nonatomic) NVFlashSettings* regular;
@property (nonatomic) NVFlashSettings* preflash;
@end

@implementation NVFlashDefaults

- (id) init
{
    self = [super init];
    if (self) {
        self.regular = [NVFlashSettings off];
        self.preflash = [NVFlashSettings off];
    }
    return self;
}

- (id) initWithRegular:(NVFlashSettings*)regular preflash:(NVFlashSettings*)preflash
{
    self = [super init];
    if (self) {
        self.regular = regular;
        self.preflash = preflash;
    }
    return self;
}

- (NVFlashDefaults*) withRegular:(NVFlashSettings*)regular
{
    return [[NVFlashDefaults alloc] initWithRegular:regular preflash:self.preflash];
}

// Creates a copy of the current flash defaults but with new "preflash" settings.
- (NVFlashDefaults*) withPreflash:(NVFlashSettings*)preflash
{
    return [[NVFlashDefaults alloc] initWithRegular:self.regular preflash:preflash];
}

@end
