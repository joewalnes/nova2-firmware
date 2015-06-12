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

#import "NVFlashService.h"
#import "NVBluetoothNovaFlash.h"

static NSTimeInterval const scanInterval = 4; // How long between scans, in seconds.
static NSTimeInterval const scanDuration = 0.9; // How long to scan for, in seconds.
static float const autoConnectDefaultMinSignalStrength = 0.1;
static void *statusUpdateContext = &statusUpdateContext;

NSString *NVFlashServiceStatusString(NVFlashServiceStatus status)
{
    switch (status) {
        case NVFlashServiceDisabled:
            return @"Disabled";
        case NVFlashServiceIdle:
            return @"Idle";
        case NVFlashServiceScanning:
            return @"Scanning";
    }
}

@interface NVFlashService()
// Override interface declaration so we can change the value.
@property (nonatomic) NVFlashServiceStatus status;
@end

@implementation NVFlashService
{
    BOOL enabled;
    CBCentralManager *central;
    NSTimer *startScanTimer;
    NSTimer *stopScanTimer;
    NSMutableArray *allFlashes; // array of id<NVBluetoothNovaFlash>
    NSMutableDictionary *rssiSamples; // dictionary of identifier (NSString) -> NSMutableArray of NSNumber
}

#pragma mark - Initialization

- (id) init
{
    self = [super init];
    if (self) {
        enabled = NO;
        central = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        allFlashes = [NSMutableArray array];
        self.autoConnect = NO;
        self.autoConnectMaxFlashes = 1;
        self.autoConnectMinSignalStrength = autoConnectDefaultMinSignalStrength;
        self.autoConnectWhitelist = [NSArray array];
        self.autoConnectBlacklist = [NSArray array];
    }
    return self;
}

// Callback from [CBCentralManager initWithDelegate:queue:]
// Tells us whether we have access to the Bluetooth stack (i.e. running on a suitable device).
- (void) centralManagerDidUpdateState:(CBCentralManager *)cm
{
    if (central.state == CBCentralManagerStatePoweredOn) {
        if (enabled) {
            [self startScan];
        }
    } else {
        self.status = NVFlashServiceDisabled;
    }
}

#pragma mark - Flash accessors

- (NSArray*) flashes {
    return [NSArray arrayWithArray:allFlashes];
}

- (NSArray*) connectedFlashes {
    return [allFlashes filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
        NVBluetoothNovaFlash* flash = obj;
        return flash.status == NVFlashReady || flash.status == NVFlashBusy;
    }]];
}

#pragma mark - Lifecycle implementation

- (void) enable
{
    if (enabled) {
        return;
    }
    
    enabled = YES;
    
    [startScanTimer invalidate];
    [stopScanTimer invalidate];
    stopScanTimer = nil;
    
    self.status = NVFlashServiceIdle;
    
    startScanTimer = [NSTimer scheduledTimerWithTimeInterval:scanInterval
                                                      target:self
                                                    selector:@selector(startScan)
                                                    userInfo:nil
                                                     repeats:YES];
    [self startScan];
}

- (void) disable
{
    if (!enabled) {
        return;
    }
    
    enabled = NO;
    
    if (central.state != CBCentralManagerStatePoweredOn) {
        return;
    }

    [central stopScan];
    
    [startScanTimer invalidate];
    [stopScanTimer invalidate];
    startScanTimer = nil;
    stopScanTimer = nil;

    for (long i = allFlashes.count - 1; i >= 0; i--) {
        NVBluetoothNovaFlash* flash = allFlashes[i];
        [flash disconnect];
        [self unregisterFlash: flash];
    }
    
    self.status = NVFlashServiceDisabled;
}

- (void)registerFlash:(NVBluetoothNovaFlash*) flash
{
    [allFlashes addObject:flash];
    if ([self.delegate respondsToSelector:@selector(flashServiceAddedFlash:)]) {
        [self.delegate flashServiceAddedFlash:flash];
    }
    if ((flash.status == NVFlashReady || flash.status == NVFlashBusy)
        && [self.delegate respondsToSelector:@selector(flashServiceConnectedFlash:)]) {
        [self.delegate flashServiceConnectedFlash:flash];
    }
    [flash addObserver: self
            forKeyPath: @"status"
               options: (NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
               context: statusUpdateContext];
}

- (void)unregisterFlash:(NVBluetoothNovaFlash*) flash
{
    [flash removeObserver: self forKeyPath:@"status" context: statusUpdateContext];
    [flash disconnect];
    [allFlashes removeObject:flash];
    if ((flash.status == NVFlashReady || flash.status == NVFlashBusy)
        && [self.delegate respondsToSelector:@selector(flashServiceDisconnectedFlash:)]) {
        [self.delegate flashServiceDisconnectedFlash:flash];
    }
    if ([self.delegate respondsToSelector:@selector(flashServiceRemovedFlash:)]) {
        [self.delegate flashServiceRemovedFlash:flash];
    }
}

- (NVBluetoothNovaFlash*) lookupFlash:(CBPeripheral*) peripheral
{
    return (NVBluetoothNovaFlash*)[self flashWithIdentifier:peripheral.identifier.UUIDString];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == statusUpdateContext) {
        NVBluetoothNovaFlash *flash = object;
        NVFlashStatus oldStatus = (NVFlashStatus) [[change valueForKey:NSKeyValueChangeOldKey] integerValue];
        NVFlashStatus newStatus = (NVFlashStatus) [[change valueForKey:NSKeyValueChangeNewKey] integerValue];
        bool wasConnected = oldStatus == NVFlashReady || oldStatus == NVFlashBusy;
        bool isConnected = newStatus == NVFlashReady || newStatus == NVFlashBusy;
        if (wasConnected != isConnected) {
            if (isConnected) {
                if ([self.delegate respondsToSelector:@selector(flashServiceConnectedFlash:)]) {
                    [self.delegate flashServiceConnectedFlash:flash];
                }
            } else {
                if ([self.delegate respondsToSelector:@selector(flashServiceDisconnectedFlash:)]) {
                    [self.delegate flashServiceDisconnectedFlash:flash];
                }
            }
        }
    }
}

#pragma mark - Scan for devices in range.

// Periodically called by timer.
- (void)startScan
{
    if (stopScanTimer != nil) {
        return; // Scan is already in progress.
    }
    
    if (central.state != CBCentralManagerStatePoweredOn) {
        return; // Bluetooth stack is not ready yet. Try again later.
    }
    
    if (self.status != NVFlashServiceIdle) {
        return; // Either BT is disabled, or we're already attempting to connect.
    }

    // Clear RSSI samples
    rssiSamples = [NSMutableDictionary dictionary];
    
    NSDictionary *options = @{CBCentralManagerScanOptionAllowDuplicatesKey : @YES};
    // Calls [self centralManager:didDiscoverPeripheral:advertisementData:RSSI:] when peripheral discovered.
    [central scanForPeripheralsWithServices: @[[CBUUID UUIDWithString:kNovaV1ServiceUUID]] options: options];

    self.status = NVFlashServiceScanning;
    
    // Stop scanning after scanDuration.
    stopScanTimer = [NSTimer scheduledTimerWithTimeInterval:scanDuration
                                                     target:self
                                                   selector:@selector(stopScan)
                                                   userInfo:nil
                                                    repeats:NO];
}

// Callback from [CBCentralManager scanForPeripheralsWithServices:options:]
// Tells us that a peripheral that supports our service was discovered.
- (void) centralManager:(CBCentralManager *)cm
  didDiscoverPeripheral:(CBPeripheral *)peripheral
      advertisementData:(NSDictionary *)advertisementData
                   RSSI:(NSNumber *)rssi
{
    NVBluetoothNovaFlash *flash = [self lookupFlash:peripheral];
    
    if (flash == nil) {
        // Newly discovered device...
        
        if ([peripheral.name isEqual:kNovaV1DeviceName]) {
            // It's a Nova V1!
            flash = [[NVBluetoothNovaFlash alloc] initNovaV1WithPeripheral:peripheral
                                                        withCentralManager:central];
            
        } else if ([peripheral.name isEqual:kNovaV2ProDeviceName]) {
            // It's a Nova V2 Pro!
            flash = [[NVBluetoothNovaFlash alloc] initNovaV2ProWithPeripheral:peripheral
                                                           withCentralManager:central];
        } else {
            // Some other device. Ignore it.
            return;
        }
        
        [self registerFlash:flash];
    }
    
    NSMutableArray *samplesForDevice = rssiSamples[flash.identifier];
    if (samplesForDevice == nil) {
        samplesForDevice = [NSMutableArray array];
        rssiSamples[flash.identifier] = samplesForDevice;
    }
    [samplesForDevice addObject:rssi];
}

- (void) updateAllRssiValues
{
    for (NVBluetoothNovaFlash *flash in allFlashes) {
        if (flash.status == NVFlashAvailable || flash.status == NVFlashUnavailable) {
            NSNumber* rssi = [self averageRssi:rssiSamples[flash.identifier]];
            [flash setRssi:rssi];
        }
        // else: peripheral is no longer appearing in scan and so is responsible for setting its own RSSI.
    }
    if (self.autoConnect) {
        [self performAutoConnect];
    }
}

- (NSNumber*) averageRssi:(NSMutableArray*) samples;
{
    if (samples == nil) {
        return @(RSSI_UNAVAILABLE);
    }
    
    float sum = 0;
    int count = 0;
    for (NSNumber *sample in samples) {
        if (sample.integerValue != RSSI_UNAVAILABLE) {
            sum += sample.floatValue;
            count++;
        }
    }
    
    if (count == 0) {
        return @(RSSI_UNAVAILABLE);
    } else {
        return @(sum / (float)count);
    }
}

// Periodicaly called by timer, sometime after startScan.
- (void)stopScan
{
    [self updateAllRssiValues];
    
    [central stopScan];
    [stopScanTimer invalidate];
    stopScanTimer = nil;

    self.status = NVFlashServiceIdle;
}

#pragma mark - Establish connection to device

// Callback from [CBCentralManager connectPeripheral:options:]
// Failed to connect.
- (void)    centralManager:(CBCentralManager *)cm
didFailToConnectPeripheral:(CBPeripheral *)peripheral
                     error:(NSError *)error
{
    NVBluetoothNovaFlash *flash = [self lookupFlash:peripheral];

    if (flash != nil) {
        [flash disconnect];
    }
}

// Callback from [CBCentralManager connectPeripheral:options:]
// Yay! Connected to peripheral.
- (void) centralManager:(CBCentralManager *)cm
   didConnectPeripheral:(CBPeripheral *)peripheral
{
    NVBluetoothNovaFlash *flash = [self lookupFlash:peripheral];
    
    if (flash != nil) {
        [flash discoverServices];
    }
}

- (void) centralManager:(CBCentralManager *)cm
didDisconnectPeripheral:(CBPeripheral *)peripheral
                  error:(NSError *)error
{
    NVBluetoothNovaFlash *flash = [self lookupFlash:peripheral];

    if (flash != nil) {
        [flash disconnect];
    }
}

#pragma mark - Access available flashes (public)

- (id<NVFlash>) flashWithIdentifier:(NSString*)identifier
{
    for (NVBluetoothNovaFlash *flash in allFlashes) {
        if ([flash.identifier isEqualToString:identifier]) {
            return flash;
        }
    }
    return nil;
}

- (void) disconnectAll
{
    for (NVBluetoothNovaFlash *flash in allFlashes) {
        [flash disconnect]; // no-op on non-connected flashes
    }
}

#pragma mark - Autoconnect

- (void) performAutoConnect
{
    // Step 1: ignore any unavailable flashes
    NSMutableArray *filteredFlashes = [NSMutableArray arrayWithCapacity:allFlashes.count];
    for (NVBluetoothNovaFlash *flash in allFlashes) {
        if (flash.status != NVFlashUnavailable) {
            [filteredFlashes addObject:flash];
        }
    }
    
    // Step 2: sort remaining flashes by signal strength
    NSArray *sortedFlashes = [filteredFlashes sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"signalStrength"
                                                                                                          ascending:NO]]];

    // Step 3: disconnect any that should no longer be connected
    int connectedCount = 0;
    for (NVBluetoothNovaFlash *flash in sortedFlashes) {
        bool isConnected = flash.status == NVFlashConnecting || flash.status == NVFlashReady || flash.status == NVFlashBusy;
        if (isConnected) {
            bool shouldStillBeConnected = connectedCount < self.autoConnectMaxFlashes
                && flash.signalStrength >= self.autoConnectMinSignalStrength
                && (self.autoConnectWhitelist == nil || self.autoConnectWhitelist.count == 0 || [self.autoConnectWhitelist containsObject:flash.identifier])
                && (self.autoConnectBlacklist == nil || ![self.autoConnectBlacklist containsObject:flash.identifier]);
            if (shouldStillBeConnected) {
                connectedCount++;
            } else {
                [flash disconnect];
            }
        }
    }

    // Step 4: if connectedCount not met, connect some more
    for (NVBluetoothNovaFlash *flash in sortedFlashes) {
        bool isConnected = flash.status == NVFlashConnecting || flash.status == NVFlashReady || flash.status == NVFlashBusy;
        if (!isConnected) {
            bool shouldBeConnected = connectedCount < self.autoConnectMaxFlashes
                    && flash.signalStrength >= self.autoConnectMinSignalStrength
                    && (self.autoConnectWhitelist == nil || self.autoConnectWhitelist.count == 0 || [self.autoConnectWhitelist containsObject:flash.identifier])
                    && (self.autoConnectBlacklist == nil || ![self.autoConnectBlacklist containsObject:flash.identifier]);
            if (shouldBeConnected) {
                [flash connect];
                connectedCount++;
            }
        }
    }
}
@end
