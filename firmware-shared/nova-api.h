// (c) 2015, Joe Walnes, Sneaky Squid

#pragma once

/**
 * API to interact with Nova device logic.
 *
 * Implementations should call the nova_on_????() functions as events occur
 * on the hardware.
 */
#include <stdbool.h>
#include "nova.h"

/**
 * Should be called at device startup. Can also be called again to
 * effectively reset in memory state.
 */
void nova_on_reset(nova_t *nova);

/**
 * Should be called when user begins pressing down button.
 *
 * Before calling this, apply sensible debounce protection to prevent
 * short (<10 milliseconds) presses.
 */
void nova_on_button_pressdown(nova_t *nova);

/**
 * Should be called when user releases button to finish the press.
 *
 * Before calling this, apply sensible debounce protection to prevent
 * short (<10 milliseconds) presses.
 */
void nova_on_button_release(nova_t *nova);

/**
 * Should be called when App subscribes to Nova BLE characteristic.
 */
void nova_on_connect_app(nova_t *nova);

/**
 * Should be called when App UNsubscribes to Nova BLE characteristic.
 */
void nova_on_disconnect_app(nova_t *nova);

/**
 * Should be called when phone subscribes to HID characteristic.
 */
void nova_on_connect_hid(nova_t *nova);

/**
 * Should be called when phone UNsubscribes to HID characteristic.
 */
void nova_on_disconnect_hid(nova_t *nova);

/**
 * Should be called when Nova BLE characteristic receives a command
 * from the App.
 */
void nova_on_app_command(nova_t *nova, app_command_t *cmd);

/**
 * Device implementations should provide nova_timer_schedule() functions
 * (see nova-device.h). When the timer is complete it should call back
 * to this function.
 */
void nova_on_timer_complete(nova_t *nova);



// ----------------------------------------------------------------------------
// Convenience helpers.

/**
 * Determine if device is connected to Nova BLE characteristic.
 *
 * If called after nova_on_connect_app() returns true.
 * After nova_on_disconnect_app() returns false.
 */
bool nova_is_ble_app_connected(nova_t *nova);

/**
 * Determine if device is connected to HID characteristic.
 *
 * If called after nova_on_connect_hid() returns true.
 * After nova_on_disconnect_hid() returns false.
 */
bool nova_is_ble_hid_connected(nova_t *nova);
