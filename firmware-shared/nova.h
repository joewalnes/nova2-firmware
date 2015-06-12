// (c) 2015, Joe Walnes, Sneaky Squid

#pragma once

/**
 * Core Nova types. This file contains definitions of:
 *
 * - opaque nova_t type: pointer to internal state that needs to be passed
 *   around.
 *
 * - nova_data(), nova_set_data() functions for associating device specific data
 *   with the nova_t.
 *
 * - common primitive types: milliseconds_t, cmd_id_t.
 *
 * - data persisted on non-volatile memory between power cycles (user settings
 *   and usage counters).
 *
 * - the over-the-air BLE protocol used to communicate with the App.
 *
 * Important:
 *
 * When struct values are sent over the air, the values should be encoded in
 * big-endian byte order.
 * Some structs contain empty 'pad' fields: these are to ensure byte values
 * align correctly and the compiler doesn't reorder the memory structure.
 */

#include <stdint.h>


// ----------------------------------------------------------------------------
// nova_t


/**
 * Represents a Nova device.
 *
 * Typically implementations should allocate one of these at startup and
 * pass the pointer around to all nova related functions.
 *
 * The full struct definition is in nova-internal.h. This is only needed
 * when allocating the data.
 *
 * The struct contains internal state for the Nova device.
 */
typedef struct nova_t nova_t;


// ----------------------------------------------------------------------------
// User data

/**
 * Additional implementation specific data can be associated with nova_t.
 *
 * This data is not used by the core Nova code - use it for your own
 * purposes.
 *
 * To set the data see nova_data_set().
 */
void* nova_data(nova_t *nova);

/**
 * See nova_data().
 */
void nova_data_set(nova_t *nova, void *new_data);


// ----------------------------------------------------------------------------
// Common types

typedef uint16_t milliseconds_t;
typedef uint16_t cmd_id_t;


// ----------------------------------------------------------------------------
// Persistent data and settings

/**
 * Represents settings for a flash of light.
 *
 * Warm/cool brightness and timeout.
 *
 * Stored locally for device triggered flashes (see flash_defaults_t),
 * and also passed by custom app (see app_command_body_t).
 */
typedef struct flash_settings_t
{
  milliseconds_t timeout;
  uint8_t warm; // 0-255 (off-full)
  uint8_t cool; // 0-255 (off-full)
} flash_settings_t;

/**
 * Default flash settings to use when user triggers a flash
 * from the button on the device.
 *
 * Preflash is used before taking the photo to illuminate the scene and
 * help the camera focus.
 *
 * When the camera is ready, the regular flash burst will occur.
 */
typedef struct flash_defaults_t
{
  flash_settings_t regular;
  flash_settings_t preflash;
} flash_defaults_t;

/**
 * Internal counters (stats) used to track device usage.
 *
 * When events occur, the counters are incremented and persisted
 * in flash memory. The app may query the counters via BLE.
 *
 * If adding new counters, add to the end of the struct.
 * Do not remove or rearrange existing fields as it will corrupt
 * stored memory when the firmware is upgraded.
 */
typedef struct counters_t
{
  /** How many times device has started. */
  uint32_t boot;

  /** How many time a BLE connection has been made via Nova app characteristic. */
  uint32_t app_connect;

  /** How many time a BLE connection has been made via HID profile. */
  uint32_t hid_connect;

  /** How many times the flash has been triggered via the button while paired to Nova app. */
  uint32_t flash_button_app;

  /** How many times the flash has been triggered via the button while paired to native HID profile. */
  uint32_t flash_button_native;

  /** How many times the flash has been triggered via the button while disconnected. */
  uint32_t flash_button_disconnected;

  /** How many times the flash has been triggered via the a BLE message from Nova app. */
  uint32_t flash_remote_app;

} counters_t;


// ----------------------------------------------------------------------------
// BLE App communication protocol

/**
 * Command sent/received to/from App over Nova BLE characteristic.
 *
 * The command consists of an id, type and optional body.
 *
 * For each command, the remote end will respond with a command of type=ACK
 * with the same id. The sender can use this to acknowledge the receiver has
 * processed the command.
 */
typedef struct app_command_t
{
  /** Type of command. This must be the a value from app_command_type below. */
  uint8_t type;

  /** Additional padding. Leave empty. Used to help byte alignment. */
  uint8_t __pad;

  /** Numeric id of command. This is used to tie the request to ack. */
  cmd_id_t id;

  /** Optional body of command containing additional args for certain types. */
  union app_command_body_u
  {
    /** Populated if type=FLASH: contains brightness/timeout settings. */
    flash_settings_t flash_settings;

    /** Populated if type=TRIGGER: contains whether button is pressed or released. */
    struct flash_trigger_t
    {
      /** 0 = pressed down, 1 = released */
      uint8_t is_pressed;
    } trigger;

  } body;

} app_command_t;

/**
 * Type of command. The value of app_command_t.type.
 */
typedef enum
{
  /**
   * ACK: Whenever the Nova or remote phone receives a non-ACK command it
   * will respond with an ACK.
   *
   * The id of the ACK matches the id of the original request.
   */
  NOVA_CMD_ACK      = 0,

  /**
   * PING: No-op command. Can be used to test connectivity (check ACK is returned).
   */
  NOVA_CMD_PING     = 1,

  /**
   * FLASH: Sent from app to Nova device. Initiate a flash of light.
   *
   * The command must also contain data in command.body.flash_settings
   * to pass the brightness and timeout.
   */
  NOVA_CMD_FLASH    = 2,

  /**
   * OFF: Sent from app to Nova device. Turn off lights.
   */
  NOVA_CMD_OFF      = 3,

  /**
   * TRIGGER: Sent from Nova device to app to indicate the user has
   * triggered a flash by pressing the button.
   *
   * The device will actually send two trigger commands:
   * 1. When the button is pressed-down
   * 2. When the button is released
   *
   * The command must also contain data in command.body.trigger to indicate
   * if the button is being pressed or released.
   */
  NOVA_CMD_TRIGGER  = 4

} app_command_type;
