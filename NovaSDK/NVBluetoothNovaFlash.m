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

#import "NVBluetoothNovaFlash.h"
#import "NVCodec.h"

static NSTimeInterval const ackTimeout = 2; // How long before we give up waiting for ack from device, in seconds.
static NSTimeInterval const rssiInterval = 1; // How long between RSSI checks, in seconds.

extern NSString* const kNovaV1DeviceName;
extern NSString* const kNovaV2ProDeviceName;

extern NSString* const kNovaV1ServiceUUID;
extern NSString* const kNovaV2ServiceUUID;

NSString* const kNovaV1DeviceName    = @"Nova";
NSString* const kNovaV2ProDeviceName = @"Nova2";

NSString* const kNovaV1ServiceUUID = @"FFF0";
NSString* const kNovaV2ServiceUUID = @"EFF0";

static NSString* const kDeviceInformationServiceUUID = @"180A";
static NSString* const kSystemIdCharacteristicUUID = @"2A23";
static NSString* const kNovaV1RequestCharacteristicUUID = @"FFF3";
static NSString* const kNovaV1ResponseCharacteristicUUID = @"FFF4";
static NSString* const kNovaV2RequestCharacteristicUUID = @"EFF1";
static NSString* const kNovaV2ResponseCharacteristicUUID = @"EFF2";
static NSString* const kNovaV2FlashDefaultsCharacteristicUUID = @"EFF3";
static NSString* const kNovaV2CountersCharacteristicUUID = @"EFF4";

@implementation NVCommand
@end

@interface NVBluetoothNovaFlash()
// Override interface declarations so we can change the value.
@property (nonatomic) NVFlashModel model;
@property (nonatomic) NVFlashStatus status;
@property (nonatomic) float signalStrength;
@property (nonatomic) float batteryStrength;
@property (nonatomic) BOOL batteryStrengthSupported;
@property (nonatomic) BOOL flashDefaultsSupported;
@property (nonatomic) BOOL remoteTriggerSupported;
@property (nonatomic) BOOL nativeTriggerSupported;
@property (nonatomic) BOOL lit;
@end


@implementation NVBluetoothNovaFlash
{
    NSString *novaServiceUUID;
    NSString *requestCharacteristicUUID;
    NSString *responseCharacteristicUUID;
    id<NVCodec> codec;
    CBPeripheral *activePeripheral;
    CBCentralManager *centralManager;
    CBCharacteristic *requestCharacteristic;
    CBCharacteristic *responseCharacteristic;
    NVCommand *awaitingAck;
    NSTimer *ackTimer;
    NSTimer *rssiTimer;
    NSTimer *flashTimeoutTimer;
    uint16_t _nextRequestId;
    uint16_t maxRequestId;
    NSMutableArray *awaitingSend;
    NSString *_identifier;
}

@synthesize delegate;

- (id) initNovaV1WithPeripheral:(CBPeripheral*)peripheral
             withCentralManager:(CBCentralManager*) cm
{
    self = [super init];
    if (self) {
        [self sharedInitWithPeripheral:peripheral
                    withCentralManager:cm];
        novaServiceUUID = kNovaV1ServiceUUID;
        requestCharacteristicUUID = kNovaV1RequestCharacteristicUUID;
        responseCharacteristicUUID = kNovaV1ResponseCharacteristicUUID;
        maxRequestId = 255;
        codec = [NVCodecV1 new];
        self.model = NVFlashModelNova1;
        self.batteryStrengthSupported = NO;
        self.flashDefaultsSupported = NO;
        self.remoteTriggerSupported = NO;
        self.nativeTriggerSupported = NO;
    }
    return self;
}

- (id) initNovaV2ProWithPeripheral:(CBPeripheral*)peripheral
                withCentralManager:(CBCentralManager*) cm
{
    self = [super init];
    if (self) {
        [self sharedInitWithPeripheral:peripheral
                    withCentralManager:cm];
        novaServiceUUID = kNovaV2ServiceUUID;
        requestCharacteristicUUID = kNovaV2RequestCharacteristicUUID;
        responseCharacteristicUUID = kNovaV2ResponseCharacteristicUUID;
        maxRequestId = 65535;
        codec = [NVCodecV2 new];
        self.model = NVFlashModelNova2Pro;
        self.batteryStrengthSupported = YES;
        self.flashDefaultsSupported = YES;
        self.remoteTriggerSupported = YES;
        self.nativeTriggerSupported = YES;
    }
    return self;
}

- (void) sharedInitWithPeripheral:(CBPeripheral*)peripheral
               withCentralManager:(CBCentralManager*) cm
{
    awaitingSend = [NSMutableArray array];
    activePeripheral = peripheral;
    activePeripheral.delegate = self;
    centralManager = cm;
    _identifier = peripheral.identifier.UUIDString;
    _nextRequestId = 0;
    self.status = NVFlashAvailable;
    self.lit = NO;
    self.delegate = Nil;
    self.signalStrength = 0;
    self.batteryStrength = NAN;
}

- (NSString*) identifier
{
    return _identifier;
}

- (void) setRssi:(NSNumber *)rssi
{
    if (rssi.integerValue == RSSI_UNAVAILABLE) {
        self.signalStrength = 0;
        if (self.status != NVFlashUnavailable) {
            [self disconnect];
            self.status = NVFlashUnavailable;
        }
    } else {
        // Converts db rating into simpler 0.0 (weakest) to 1.0 (strongest) scale.
        // These numbers are fairly subjective and based trial and error and what 'feels right'.
        self.signalStrength = MAX(0.0, MIN(5.0, 9.0 + rssi.floatValue / 10.0)) / 5.0;
        if (self.status == NVFlashUnavailable) {
            self.status = NVFlashAvailable;
        }
    }
}

- (void) connect
{
    switch (self.status) { // defensive guard to ensure all status cases are covered
        case NVFlashConnecting:
        case NVFlashReady:
        case NVFlashBusy:
        case NVFlashUnavailable:
            return; // connect to possible at this time
        case NVFlashAvailable:
            ; // carry on with connection
    }
    
    self.status = NVFlashConnecting;
    
    // Connects to the discovered peripheral.
    // Calls [flash centralManager:didFailToConnectPeripheral:error:]
    // or [flash centralManager:didConnectPeripheral:]
    [centralManager connectPeripheral:activePeripheral options:nil];
}

- (void) discoverServices
{
    // Asks the peripheral to discover the service
    // Calls [self peripheral:didDiscoverServices:]
    NSArray *services = @[[CBUUID UUIDWithString:novaServiceUUID]];
    [activePeripheral discoverServices:services];
}

- (void) disconnect
{
    switch (self.status) { // defensive guard to ensure all status cases are covered
        case NVFlashAvailable:
        case NVFlashUnavailable:
            return; // no bluetooth connection. nothing to do
        case NVFlashConnecting:
        case NVFlashReady:
        case NVFlashBusy:
            ; // carry on with disconnection
    }
    
    [centralManager cancelPeripheralConnection:activePeripheral];

    if (responseCharacteristic != nil) {
        [activePeripheral setNotifyValue:NO forCharacteristic:responseCharacteristic];
    }
    
    requestCharacteristic = nil;
    responseCharacteristic = nil;
    
    self.lit = NO;
    
    [ackTimer invalidate];
    ackTimer = nil;
    
    [rssiTimer invalidate];
    rssiTimer = nil;

    [flashTimeoutTimer invalidate];
    flashTimeoutTimer = nil;

    // Abort any queued requests.
    if (awaitingAck != nil) {
        awaitingAck.callback(NO);
        awaitingAck = nil;
    }
    for (NVCommand *cmd in awaitingSend) {
        cmd.callback(NO);
    }
    [awaitingSend removeAllObjects];
    
    self.status = self.signalStrength == 0 ? NVFlashUnavailable : NVFlashAvailable;
    self.signalStrength = 0;
}

- (void) beginFlash:(NVFlashSettings*)settings
{
    [self beginFlash:settings withCallback:^(BOOL success) {}];
}

- (void) beginFlash:(NVFlashSettings*)settings withCallback:(NVTriggerCallback)callback
{
    [flashTimeoutTimer invalidate];
    flashTimeoutTimer = nil;

    if ((settings.warm == 0 && settings.cool == 0) || settings.timeout == 0) {
        // settings say that flash is effectively off
        self.lit = NO;
        uint16_t requestId = [self nextRequestId];
        [self request:[codec encodeOff:requestId] withId:requestId withCallback:callback];
    } else {
        self.lit = YES;
        uint16_t requestId = [self nextRequestId];
        [self request:[codec encodeFlash:requestId withWarm:settings.warm withCool:settings.cool withTimeout:settings.timeout]
               withId:requestId
         withCallback:^(BOOL success) {
            if (success) {
                double timeout = (double)settings.timeout / 1000.0;
                flashTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:timeout
                                                            target:self
                                                          selector:@selector(flashTimeout)
                                                          userInfo:nil
                                                           repeats:NO];
            } else {
                self.lit = NO;
            }
            callback(success);
        }];
    }
}

- (void) endFlash
{
    [self endFlashWithCallback:^(BOOL success) {}];
}

- (void) endFlashWithCallback:(NVTriggerCallback)callback
{
    [flashTimeoutTimer invalidate];
    flashTimeoutTimer = nil;

    self.lit = NO;
    uint16_t requestId = [self nextRequestId];
    [self request:[codec encodeOff:requestId] withId:requestId withCallback:callback];
}

- (void) pingWithCallback:(NVTriggerCallback)callback
{
    uint16_t requestId = [self nextRequestId];
    [self request:[codec encodePing:requestId] withId:requestId withCallback:callback];
}

- (void)flashTimeout
{
    [flashTimeoutTimer invalidate];
    flashTimeoutTimer = nil;
    self.lit = NO;
}

- (void) saveFlashDefaults:(NVFlashDefaults*)defaults withCallback:(NVSaveFlashDefaultsCallback) callback
{
    // TODO
}

- (void) saveFlashDefaults:(NVFlashDefaults*)defaults
{
    // TODO
}

- (void) loadFlashDefaults:(NVLoadFlashDefaultsCallback) callback
{
    // TODO
}

#pragma mark - Service/characteristic discovery

// Callback from [CBPeripheral discoverServices:]
- (void) peripheral:(CBPeripheral *)peripheral
didDiscoverServices:(NSError *)error
{
    if (error) {
        [self disconnect];
        return;
    }
    
    rssiTimer = [NSTimer scheduledTimerWithTimeInterval: rssiInterval
                                                 target: self
                                               selector: @selector(checkRssi)
                                               userInfo: nil
                                                repeats: YES];
   
    for (CBService* service in peripheral.services) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:novaServiceUUID]]) {
            // Found Nova service
            // Discovers the characteristics for the service
            // Calls [self peripheral:didDiscoverCharacteristicsForService:error:]
            NSArray *characteristics = @[[CBUUID UUIDWithString:requestCharacteristicUUID],
                                         [CBUUID UUIDWithString:responseCharacteristicUUID]];
            [peripheral discoverCharacteristics:characteristics forService:service];
        }
        if ([service.UUID isEqual:[CBUUID UUIDWithString:kDeviceInformationServiceUUID]]) {
            // Found device information service
            // Discovers the characteristics for the service
            // Calls [self peripheral:didDiscoverCharacteristicsForService:error:]
            NSArray *characteristics = @[[CBUUID UUIDWithString:kSystemIdCharacteristicUUID]];
            [peripheral discoverCharacteristics:characteristics forService:service];
        }
    }
}

// Callback from [CBPeripheral discoverCharacteristics:forService]
- (void)                  peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
                               error:(NSError *)error
{
    if (![service.UUID isEqual:[CBUUID UUIDWithString:novaServiceUUID]]
        && ![service.UUID isEqual:[CBUUID UUIDWithString:kDeviceInformationServiceUUID]]) {
        return;
    }
    
    if (error) {
        [self disconnect];
        return;
    }
    
    for (CBCharacteristic* characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:requestCharacteristicUUID]]) {
            requestCharacteristic = characteristic;
        }
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:responseCharacteristicUUID]]) {
            responseCharacteristic = characteristic;
            // Subscribe to notifications
            [peripheral setNotifyValue:YES forCharacteristic:responseCharacteristic];
        }
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kSystemIdCharacteristicUUID]]) {
            [peripheral readValueForCharacteristic:characteristic];
        }
    }
    
    if (requestCharacteristic != nil && responseCharacteristic != nil) {
        // All set. We're now ready to send commands to the device.
        self.status = NVFlashReady;
    } else if ([service.UUID isEqual:[CBUUID UUIDWithString:novaServiceUUID]]) {
        // Characteristics not found in NovaV1 service. Abort.
        [self disconnect];
    }
}

- (void)             peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
                          error:(NSError *)error
{
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:responseCharacteristicUUID]]) {
        [self handleResponse:characteristic.value];
    } else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kSystemIdCharacteristicUUID]]) {
        // TODO: systemId
        // NSLog(@"systemID %@", characteristic.value);
    }
}

- (void) handleResponse:(NSData*)data
{
    uint16_t responseId;
    if (![codec decodeAck:data extractId:&responseId]) {
        //NSLog(@"Failed to parse response: %@", response);
        [self disconnect];
        return;
    }
    
    if (awaitingAck == nil) {
        //NSLog(@"Was not expecting ack (got: %u)", responseId);
        [self disconnect];
        return;
    }
    
    if (awaitingAck.requestId != responseId) {
        //NSLog(@"Unexpected ack (got: %u, expected: %u)", responseId, awaitingAck.requestId);
        [self disconnect];
        return;
    }
    
    NVTriggerCallback callback = awaitingAck.callback;
    
    // No longer awaiting the ack.
    awaitingAck = nil;
    
    // Cancel timeout timer.
    [ackTimer invalidate];
    ackTimer = nil;
    
    self.status = NVFlashReady;

    // Send any queued outbound messages.
    [self processSendQueue];
    
    // Trigger user callback.
    callback(YES);
}

#pragma mark - RSSI check

- (void) checkRssi
{
    switch (self.status) { // defensive guard to ensure all status cases are covered
        case NVFlashAvailable:
        case NVFlashUnavailable:
        case NVFlashConnecting:
            return;
        case NVFlashReady:
        case NVFlashBusy:
            ; // carry on with disconnection
    }
    [activePeripheral readRSSI];
}

- (void)peripheral:(CBPeripheral*)peripheral didReadRSSI:(NSNumber*)RSSI error:(NSError*)error
{
    // There appears to be bug in some versions of iOS where sometimes this callback just stops getting fired.
    // Only known workaround is to go into device settings, turn bluetooth off and on again.
    [self setRssi:RSSI];
}

#pragma mark - Protocol handling

- (uint16_t) nextRequestId
{
    if (_nextRequestId == maxRequestId) {
        _nextRequestId = 0; // wrap around
    } else {
        _nextRequestId++;
    }
    return _nextRequestId;
}

- (void) request:(NSData*)msg withId:(uint16_t)requestId withCallback:(NVTriggerCallback)callback
{
    switch (self.status) { // defensive guard to ensure all status cases are covered
        case NVFlashAvailable:
        case NVFlashUnavailable:
        case NVFlashConnecting:
            // not connected yet. fail.
            {
                dispatch_async(dispatch_get_main_queue(), ^{ callback(NO); });
            }
            return; // not connected yet
        case NVFlashReady:
        case NVFlashBusy:
            ; // carry on with disconnection
    }

    NVCommand* cmd = [NVCommand new];
    cmd.requestId = requestId;
    cmd.msg = msg;
    cmd.callback = callback;

    [awaitingSend addObject:cmd];
    [self processSendQueue];
}

-(void) processSendQueue
{
    // If we're not waiting for anything to be acked, go ahead and send the next cmd in the outbound queue.
    if (awaitingAck == nil && awaitingSend.count > 0) {
        
        self.status = NVFlashBusy;
        
        // Shift first command from front of awaitingSend queue.
        NVCommand* cmd = [awaitingSend objectAtIndex:0];
        [awaitingSend removeObjectAtIndex:0];
        
        // Write to device.
        [activePeripheral writeValue:cmd.msg
                   forCharacteristic:requestCharacteristic
                                type:CBCharacteristicWriteWithResponse];
        
        // Now we're waiting for this.
        awaitingAck = cmd;
        
        // Set timer for acks so we don't hang forever waiting.
        ackTimer = [NSTimer scheduledTimerWithTimeInterval:ackTimeout
                                                    target:self
                                                  selector:@selector(ackTookTooLong)
                                                  userInfo:nil
                                                   repeats:NO];
    }
}

- (void)ackTookTooLong
{
    [ackTimer invalidate];
    ackTimer = nil;
    
    if (awaitingAck != nil) {
        awaitingAck.callback(NO);
    }
    
    awaitingAck = nil;
    self.status = NVFlashReady;

    [self processSendQueue];
}

@end
