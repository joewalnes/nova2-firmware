// (c) 2015, Joe Walnes, Sneaky Squid

#pragma once

/**
 * Internal state used in nova.c.
 *
 * Generally you shouldn't need to access any of these fields, but they're
 * listed here so code can read them for debug reasons.
 */

#include <stdbool.h>

#include "nova.h"

struct nova_t
{
  /**
   * Usage counters. Loaded at startup and saved after each modification.
   */
  counters_t counters;

  /**
   * Default flash settings for when user uses the button to trigger a flash.
   *
   * This data can be updated externally
   */
  flash_defaults_t flash_defaults;

  /**
   * Is device connected to Nova App characteristic?
   */
  bool ble_app_connected;

  /**
   * Is device connected to phone HID characteristic?
   */
  bool ble_hid_connected;

  /**
   * Are main lights currently lit?
   */
  bool is_lit;

  /**
   * id incremented each time a command is sent to the app.
   */
  cmd_id_t outbound_command_id;

  /**
   * If non-zero, it means we're waiting for an ack to a TRIGGER cmd to
   * confirm the phone completed the photo.
   */
  cmd_id_t command_id_for_trigger_ack;

  /**
   * Arbitrary data that can be associated with nova_t instance.
   * See nova_data()/nova_data_set() in nova.h.
   */
  void *data;

};
