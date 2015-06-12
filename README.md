Nova 2 Firmware
===============


Summary
-------

This is the specification for Nova V2 firmware.

There will be two hardware models for Nova V2 (`N2.x` and `N2.y`).
The PCB schematic and firmware will be identical. Only one edition will contain
a physical trigger button.



--------------------------------------------------------------------------------



Modes of Operation
------------------

Nova V2 offers three modes of operation:

### 1. Custom app pairing

This behaves similar to Nova V1: A custom App on the user's phone uses a
custom BLE service to trigger the flash.

In addition, the physical trigger button on the Nova device can also fire
the flash and request the App to take a photo.

The App automatically scans, discovers and pairs with devices in range upon
opening. Users do not need to explicitly pair.

### 2. Native OS pairing

The Nova device may also pair natively to the phone OS and trigger the regular
iPhone camera.

To do this, the device acts as an HID (Human Input Device) and acts as a remote
keyboard. When the user presses the pysical trigger button, the device sends
`Vol+` key codes, which will force the iPhone Camera App to take a photo.

Users have to explicitly pair the device in Bluetooth settings in order for this
to work.

### 3. Unpaired

When the device is not connected to a phone via BLE, the user can still use the
physical trigger button to enable the light. This acts as a convenient torch.

### Priorities

The Nova will always try to work in Custom app pairing mode first, if that's
not available try Native OS pairing, and finally try Unpaired.



--------------------------------------------------------------------------------



Features
--------

A quick summary of features available in Nova V2...

### Trigger button

Used to trigger the flash and photo from the Nova device. Also allows it
to work with the native Apple Camera App (when in Native OS pairing mode).

### Prelight

Before the main flash is triggered a "prelight" flash occurs. This is not
so bright and may last a few seconds. It assists camera focus and helps the
users preview and adjust the scene.

### Torch

Even when disconnected, the user can press and hold the button to use Nova
as a torch.

### Power switch

To conserve power and prevent accidental use, the device can be switched
on and off using a physical switch.

The power switch also allows for a "reboot" in the event the device gets
hung.

### Low power

Even when switched on, the firmware should use low power sleep modes as much
as possible.

### Dual LED arrays

Like Nova V1, there will be two LED arrays for warm and cool light.

Care must be taken to avoid "striping" effects caused by cameras picking up
PWM pulsing.

### Status indicator

Status indicators show battery charge level and BLE connectivity.

### Persistent state

The device must store non-volatile data. This data must be persisted in flash
storage to ensure that it does not get lost when the device is powered off:

*   **Usage counters:**   Retrievable by App to collect statistics
*   **Flash defaults:**   What light settings to use when user takes photo with trigger button.

### Serial number

Each device must contain a unique serial number that's exposed as a BLE GATT value.

By using this number it should be possible to trace back to manufacturing batch,
QA sign-off and shipment leaving the factory.

### Failsafes

The device should be protected from over-heating caused by lighting the LEDs for too long
or too bright.

*TODO: Discuss ideas for how to prevent over-heating.*



--------------------------------------------------------------------------------



Over-the-Air Updates
--------------------

A mechanism is required to allow the custom app to upgrade the firmware to a user's device without any additional equipment.


### Digital signature verification

When the device receives a new firmware binary image to install, it must also be accompanied by a digital signature. This signature is used to verify that the firmware is an official build and not malicious code built by a third party.

The verification mechanism consists of:

* A secret key, known only to Sneaky Squid
* A public key, embedded in the device firmware boot-loader
* When a new firmware image is created, a signature string is generated to accompany it
* When the firmware boot-loader accepts a new firmware image, it shall use the image, signature and public key to check the firmware is authentic

*To aid development, firmware developers may use their own key-pair, however the production units must be locked to the Sneaky Squid key.*

*NOTE: TI CC2541 natively supports signed AES firmware images when using built-in OAD updates:*
* http://processors.wiki.ti.com/images/8/82/OAD_for_CC254x.pdf


### "Brick" protection

The device must never get into an unrecoverable "bricked" state due to issues arising during the over-the-air upgrade process:

*   **Corrupted firmware image:** Suitable steps must be taken to ensure the image doesn't get corrupted during the transfer. The digital signature verification can help this.

*   **Signature failure:** In the event the image signature fails to verify, the previous image should be restored.

*   **Transfer interrupts:** If the image transfer is interrupted (e.g. device runs out of battery power, phone app crashes, radio disconnection, etc), the previous image should be restored.

Note: Due to memory constraints, it may not always be possible to store both the old and the new image on the device, making it impossible to provide automatic rollbacks in case of failure. If this is the case, then it's acceptable for the user to have to use the phone app to retry loading the firmware.


### Persistent state

Any user settings stored on the device should be retained between firmware upgrades. In the event that the structure of this data changes, the firmware should automatically migrate the data to the new structures.

*TODO: Determine what happens if a user attempts to rollback to an old firmware image.*



--------------------------------------------------------------------------------



Status Indicators
-----------------

The status indicators are small LEDs that display battery charge status and
BLE connectivity.

*TODO: Joe is rethinking how these should work to make it more intuitive to users. This section is left blank until details confirmed.*



--------------------------------------------------------------------------------



BLE GATT Services
-----------------

The device will offer 4 BLE GATT Services:

1.   **Device information service:** Standard BLE service required by all devices.

2.   **Battery service:** Standard BLE service to report battery level.

3.   **Human Input Device service:** Allows device to be paired with OS and trigger native camera app by sending volume key press.

4.   **Nova service:** Custom service used by custom Nova app. Allow full control of device, including adjusting default settings.

This section details how these services (and associated characteristics) should be implemented.


### Advertising Data

The BLE advertising advice name should be `Nova2`


### 1. Device information service [0x180A]

The device should support the standard BLE device information service. This is a basic requirement of BLE devices.

* https://developer.bluetooth.org/gatt/services/Pages/ServiceViewer.aspx?u=org.bluetooth.service.device_information.xml

| Name                      | Assigned Number | Value                                                     |
| ------------------------- | --------------- | ----------------------------------------------------------|
| Manufacturer Name String  | 0x2A29          | Constant: `Sneaky Squid`                                  |
| Model Number String       | 0x2A24          | Constant: `N2.x` (unit with no button) or `N2.y` (button) |
| Serial Number String      | 0x2A25          | See below                                                 |
| Hardware Revision String  | 0x2A27          | Increment this value for each change in PCB               |
| Firmware Revision String  | 0x2A26          | Increment this value for each firmware revision           |

The serial number should be a unique number associated with each device. This should be in format `batch.unit` where batch is a number that increments for each manufacturing batch and unit is a unique value for each device in the batch. e.g. `3.10`

*TODO: Determine if other characteristics are required? (e.g. PnP ID, certification list, etc).*


### 2. Battery service [0x180F]

The device should support the standard BLE battery service, allowing the phone to determine the level of the LiPoly battery.

* https://developer.bluetooth.org/gatt/services/Pages/ServiceViewer.aspx?u=org.bluetooth.service.battery_service.xml


### 3. Human Input Device (HID) service [0x1812]

HOGP (HID Over GATT Profile) allows the native iOS phone to pair to the device and treat it like an input device.

The device should appear as an HID Keyboard. The device can then send the "multimedia volume up" key `0x20` followed by "multimedia key release" `0x00` to trigger the native iOS camera.

* https://developer.bluetooth.org/gatt/services/Pages/ServiceViewer.aspx?u=org.bluetooth.service.human_interface_device.xml
* https://developer.bluetooth.org/TechnologyOverview/Pages/HOGP.aspx

*NOTE: In theory this is possible and there are many BLE accessories that do this but I cannot find any cases of it being performed with TI CC2541. Some useful discussions:*
* https://e2e.ti.com/support/wireless_connectivity/f/538/p/409336/1468585
* https://devzone.nordicsemi.com/question/7737/sending-media-keys-over-the-keyboard-hid/
* http://www.microchip.com/forums/m618147.aspx
* http://www.embeda.com.tw/ucxpresso/?article=2-2-make-your-own-camera-shutter


### 4. Nova service [0xEFF0]

The Nova Service can be used by the custom Nova app installed on phone. It offers the most level of control over the Nova device. The Service UUID is `EFF0`.

#### Nova GATT characteristics

| Name                     | Operations | UUID | Description                                                             |
| ------------------------ | ---------- | ---- | ------------------------------------------------------------------------|
| Commands: App to Device  | WRITE      | EFF1 | For sending commands (see below) from App to device                     |
| Commands: Device to App  | NOTIFY     | EFF2 | For sending commands (see below) from device to App                     |
| Flash defaults           | READ/WRITE | EFF3 | Reads or writes user's flash settings used when triggering using button |
| Counters                 | READ       | EFF4 | Reads usage counters from device                                        |

#### Commands

Commands can be sent from the App to device or device to App.

*   **ACK [0]** -- source: App or device

    Whenever the device or remote App receives a non-ACK command it will respond with an ACK.

    The id of the ACK matches the id of the original request.

*   **PING [1]** -- source: App only

    No-op command. Can be used to test connectivity (check ACK is returned).

*   **FLASH [2]** -- source: App only

    Sent from app to Nova device. Initiate a flash of light.

    The command also contains warm/cool brightness and timeout.

*   **OFF [3]** -- source: App only

    Sent from app to Nova device. Turn off lights.

*   **TRIGGER[4]** -- source: Device only

    Sent from Nova device to app to indicate the user has
    triggered a flash by pressing the button.

    The device will actually send two trigger commands:
    1. When the button is pressed-down
    2. When the button is released

    The pressed-down or released state is included in the body of the command.

#### Encoding

All data transferred via the GATT characteristics are the binary representation of C
structs with numbers encoded as big-endian.

The structs are defined in **[nova.h](firmware-shared/nova.h)**:
*  `app_command_t`
*  `flash_defaults_t`
*  `counters_t`



--------------------------------------------------------------------------------



Control Flow
============

A cross-platform device-agnostic reference implementation of the firmware is
provided that explains the flow of control:

*   See **[nova.c](firmware-shared/nova.c)**



--------------------------------------------------------------------------------



Resources
=========

*   **[Firmware reference implementation](firmware-shared/)**
*   **[Firmware simulator + UI](firmware-ui/)**
*   **[Communication protocol structs](firmware-shared/nova.h)**
*   **[Control flow](firmware-shared/nova.c)**



----

*(c) 2015, Joe Walnes, Sneaky Squid*
