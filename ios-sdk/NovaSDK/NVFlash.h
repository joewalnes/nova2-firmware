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
#import "NVFlashSettings.h"
#import "NVFlashDefaults.h"



/** 
 * Enum to represent current status of a specific flash device.
 */
typedef NS_ENUM(NSInteger, NVFlashStatus)
{
    /**
     * Flash detected in range, and available to connect to.
     */
    NVFlashAvailable,

    /**
     * Flash that was previously in range is no longer available.
     * It may be out of range or run out of battery charge.
     */
    NVFlashUnavailable,

    /**
     * Flash is in the process of being connected to.
     */
    NVFlashConnecting,
    
    /**
     * Flash connected and ready for action.
     */
    NVFlashReady,
    
    /**
     * Flash is connected and currently processing a command.
     * It may not respond until the existing command has completed.
     * This state typically lasts 100-200ms.
     */
    NVFlashBusy

};



/**
 * Which model of Nova is it? See NVFlash.model
 */
typedef NS_ENUM(NSInteger, NVFlashModel)
{
    /**
     * Original Nova 1
     */
    NVFlashModelNova1,
    
    /**
     * Nova 2 (aka Nova Pro)
     */
    NVFlashModelNova2Pro

};



/**
 * Convenience function to convert NFFlashStatus into string (e.g. "Connecting").
 * These strings are not localized and are meant primarily for debug logging.
 */
NSString *NVFlashStatusString(NVFlashStatus status);



/**
 * User defined callback block that will be triggered when a flash command completes.
 * The BOOL indicates whether the command was successful.
 */
typedef void (^NVTriggerCallback)(BOOL success);



/**
 * See `NVFlash.saveFlashDefaults:withCallback:`.
 */
typedef void (^NVSaveFlashDefaultsCallback)(BOOL success);

/**
 * See `NVFlash.loadFlashDefaults:`.
 */
typedef void (^NVLoadFlashDefaultsCallback)(BOOL success, NVFlashDefaults* flashDefaults);

/**
 * See `NVFlashDelegate.
 */
typedef void (^NVTriggerCompletion)();

@protocol NVFlash;



/**
 * Protocol implemented by user delegate to handle events from the flash device.
 */
@protocol NVFlashDelegate<NSObject>

@optional

/**
 * Trigger button has been pressed down on flash device.
 *
 * This is followed by flashTriggerButtonReleased:withCompletion:
 *
 * This is only ever called if `NVFlash.remoteTriggerSupported` returns YES.
 */
- (void) flashTriggerButtonPressed:(id<NVFlash>) flash;

/**
 * Trigger button has released on flash device.
 *
 * When clients have finished doing the work (e.g. capture a photo), they
 * should call the completed() callback. To tell the flash that it may
 * deactivate and conserve power. This may happen asyncronously.
 * If the callback is not called in a timely manner, the flash will eventually
 * deactivate itself anyway, based on the regular.timeout setting saved on
 * the device by saveFlashDefaults:.
 *
 * This follows by flashTriggerButtonPressed:
 *
 * This is only ever called if `NVFlash.remoteTriggerSupported` returns YES.
 */
- (void) flashTriggerButtonReleased:(id<NVFlash>) flash withCompletion:(NVTriggerCompletion) completed;

@end



/**
 * Flash protocol. An instance of this is assigned to each physical flash device 
 * in the vicinity. This allows individual control of each flash.
 *
 * All properties are key-value-observable.
 */
@protocol NVFlash <NSObject>

/**
 * Optional delegate to handle events from the flash device.
 */
@property(weak, nonatomic) id<NVFlashDelegate> delegate;

/**
 * A unique string assigned to each flash. This is a long UUID-like string, that
 * may not be understandable by humans, but can be used as a key in apps to identify
 * the device.
 *
 * The unique string is consistent across multiple apps on the same iOS phone, however
 * the string will vary across multiple phones. This is a privacy feature of CoreBluetooth.
 *
 * Once an NVFlash is instantiated, the identifier will never change.
 */
@property (nonatomic, readonly) NSString* identifier;

/**
 * Which model of Nova is it? e.g. Nova classic vs Nova Pro.
 *
 * This should be used for user informational purposes only (e.g. display
 * a different icon). To check for feature differences it's better to use
 * the appropriate feature detection fields (e.g. `.isRemoteTriggerSupported`,
 * `.isBatteryLevelSupported` etc. This makes your app more robust
 * to future Nova models.
 */
@property (nonatomic, readonly) NVFlashModel model;

/**
 * Status of flash. See NVFlashStatus.
 *
 * Key-value-observable.
 */
@property (nonatomic, readonly) NVFlashStatus status;

/**
 * Signal strength of flash. Range from 0.0 (weakest) to 1.0 (strongest).
 *
 * This can be used to display an indicator, and also to estimate which flashes are closer
 * or further away from the iOS phone.
 *
 * Key-value-observable.
 */
@property (nonatomic, readonly) float signalStrength;

/**
 * Battery strength of flash. Range from 0.0 (weakest) to 1.0 (strongest).
 *
 * This is only available on NovaPro devices and onwards. Check for support
 * by calling batteryStrengthSupported first. If not supported, this will
 * return NAN.
 *
 * Key-value-observable.
 */
@property (nonatomic, readonly) float batteryStrength;

/**
 * Whether the connected device supports reading of batteryStrength.
 */
@property (nonatomic, readonly) BOOL batteryStrengthSupported;

/**
 * Is the flash currently lit?
 *
 * Note that this is best-guess optimistic estimate. The flash can take up to 300ms to acknowledge
 * the response, and this bool will be set before the result is known. Use it for displaying feedback 
 * user interface feedback and to prevent additional flashes before the last has completed.
 * However, it should not be used to time the camera (see beginFlash:withCallback: for that).
 *
 * Key-value-observable.
 */
@property (nonatomic, readonly) BOOL lit;

/**
 * Connect to the flash (if not already connected).
 *
 * Observe status property to monitor result.
 */
- (void) connect;

/**
 * Disconnect from the flash (if connected).
 *
 * Observe status property to monitor result.
 */
- (void) disconnect;

/**
 * Begins the flash (turns the light on). The brightness, color temperature and 
 * timeout are passed as NVFlashSettings.
 *
 * The callback signals that the flash is on. It is the time to actually take
 * a photo. The callback is also passed a success bool which should be checked
 * to confirm that the flash actually began successfully.
 *
 * To turn the flash off, call endFlash or endFlashWithCallback:.
 *
 * Timeout (a property of NVFlashSettings) is a safety mechanism to ensure the
 * flash eventually turns itself off in the event endFlash is not called (e.g.
 * if the app hangs).
 */
- (void) beginFlash:(NVFlashSettings*)settings withCallback:(NVTriggerCallback)callback;

/**
 * See beginFlash:withCallback:. Convience method with no-op callback.
 */
- (void) beginFlash:(NVFlashSettings*)settings;

/**
 * Ends the flash (turns the light off). See beginFlash:withCallback:.
 */
- (void) endFlashWithCallback:(NVTriggerCallback)callback;

/**
 * See endFlashWithCallback:. Convience method with no-op callback.
 */
- (void) endFlash;

/**
 * Pings the flash. Sends a roundtrip no-op message. Can be used to verify flash
 * is working and measure roundtrip communication time.
 */
- (void) pingWithCallback:(NVTriggerCallback)callback;

/**
 * Saves on-device flash default settings (that get used when triggered via on-board button).
 *
 * Supplied callback will get called with a boolean indicating whether values were
 * saved successfully.
 *
 * Only supported on devices where `flashDefaultsSupported` == YES.
 */
- (void) saveFlashDefaults:(NVFlashDefaults*)defaults withCallback:(NVSaveFlashDefaultsCallback) callback;

/**
 * See `saveFlashDefaults:withCallback:`. This uses a no-op callback.
 */
- (void) saveFlashDefaults:(NVFlashDefaults*)defaults;

/**
 * Loads on-device previously saved flash default settings.
 *
 * Supplied callback will get called with a boolean indicating success and
 * (if successful) the loaded values.
 *
 * Only supported on devices where `flashDefaultsSupported` == YES.
 */
- (void) loadFlashDefaults:(NVLoadFlashDefaultsCallback) callback;

/**
 * Whether the connected device supports storing of flash defaults.
 * See saveFlashDefaults:withCallback:
 */
@property (nonatomic, readonly) BOOL flashDefaultsSupported;

/**
 * Whether the connected device supports remote trigger button.
 */
@property (nonatomic, readonly) BOOL remoteTriggerSupported;

/**
 * Whether the connected device supports triggering of native camera app.
 */
@property (nonatomic, readonly) BOOL nativeTriggerSupported;



// Include key-value-observer methods in NVFlash protocol for convenience.

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context;
- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context;
- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;

@end