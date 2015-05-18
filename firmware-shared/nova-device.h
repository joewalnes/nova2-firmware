// (c) 2015, Joe Walnes, Sneaky Squid

#pragma once

/**
 * Nova device platform hooks.
 *
 * These functions must be implemented for the underlying hardware device
 * in order for Nova to work.
 *
 * On an embedded hardware device, these implementations may interact
 * with GPIO peripherals, timer registers, BLE stack, flash memory, etc.
 *
 * On a software implementation such as a simulator, these may interact
 * with a GUI, fake data, etc.
 */

#include <stdbool.h>
#include "nova.h"

/**
 * Load counter data (diagnostic stats) from persistent store
 * (e.g. flash memory).
 */
void nova_load_counters(nova_t *nova, counters_t *counters);

/**
 * Save counter data (diagnostic stats) to persistent store
 * (e.g. flash memory).
 */
void nova_save_counters(nova_t *nova, counters_t *counters);

/**
 * Load user defined default flash settings (brightness, duration).
 *
 * These are changed externally, e.g. using a BLE characteristic.
 *
 * If no user data is known, it should do nothing, or return zeros for
 * all fields. The main Nova program will notice this and use a
 * sensible default instead.
 */
void nova_load_flash_defaults(nova_t *nova, flash_defaults_t *flash_defaults);

/**
 * Send a BLE command to Nova app.
 *
 * This will only ever be called if the
 * app is connected (i.e. between nova_on_connect_app() and
 * nova_on_disconnect_app()) as defined in nova-api.h.
 *
 * Implementations should encode the struct and write it to the BLE
 * GATT characteristic for communicating with the custom Nova app.
 */
void nova_send_app_command(nova_t *nova, app_command_t *cmd);

/**
 * Send a BLE Human Input Device (HID) key press to a connected device.
 *
 * This will only ever be called if the device is paired using the HID profile
 * (i.e. between nova_on_connect_hid() and nova_on_disconnect_hid())
 * as defined in nova-api.h.
 *
 * Implementations should send the key code over BLE using the HID profile.
 */
void nova_send_hid_key(nova_t *nova, char key_code);

/**
 * Set the status of the LED indicator (lit or not lit).
 */
void nova_set_status_indicator(nova_t *nova, bool lit);

/**
 * Light up the main flash LED banks.
 *
 * Pass PWM settings (0=off, 255=full) for warm and cool LED colors.
 */
void nova_set_lights(nova_t *nova, uint8_t warm_pwm, uint8_t cool_pwm);

/**
 * Schedule a timer to fire in a given number of milliseconds.
 *
 * This is used to automatically turn the lights off if left on too long
 * (e.g. if the App crashes).
 *
 * There will only ever be one timer scheduled at a time. If another
 * timer is to be scheduled before this one completes, nova_timer_clear()
 * will be called first.
 *
 * When the timer has elapsed, implementations should call
 * nova_on_timer_complete() as defined in nova-api.h
 */
void nova_timer_schedule(nova_t *nova, milliseconds_t timeout);

/**
 * Cancel a timer previously scheduled with nova_timer_schedule().
 *
 * If there is no timer (or it has already been cancelled), this
 * should do nothing.
 */
void nova_timer_clear(nova_t *nova);
