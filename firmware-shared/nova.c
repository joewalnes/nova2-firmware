// (c) 2015, Joe Walnes, Sneaky Squid

/**
 * Shared implementation of Nova device firmware.
 *
 * This is provides the core logic of the firmware, but does not
 * include any device/platform/processor specific code.
 *
 * This core logic can be shared across Nova device implementations
 * and simulations.
 *
 * Alternatively, it can be used as the canonical reference of how
 * Nova is expected to behave.
 *
 * To integrate into a new system:
 *
 * - Provide implementations for all functions in nova-device.h
 *   which allows the code below to interact with hardware.
 *
 * - Create a main() program which allocates a nova_t type and
 *   and calls nova_on_?????() functions (see nova-api.h) when
 *   the user interacts with device. The platform specific code
 *   is also responsible for setting up the BLE radio stack and
 *   listening to events.
 */

// TODO: Read battery level and charger status
// TODO: Figure out battery indicator
// TODO: When should device go to sleep/wakeup

#include "nova.h"
#include "nova-api.h"
#include "nova-device.h"
#include "nova-internal.h"

// Forward declarations: see below.
void flash_start(nova_t *nova, flash_settings_t *flash_settings);
void flash_end(nova_t *nova);
void update_status_indicator(nova_t *nova);


// ----------------------------------------------------------------------------
// STARTUP

/**
 * Called at device startup. Can also be called again to
 * effectively reset in memory state.
 */
void nova_on_reset(nova_t *nova)
{
  // Restore flash defaults from non-volatile memory.
  nova_load_flash_defaults(nova, &nova->flash_defaults);

  // If no flash defaults have been set, use something sensible.
  if (nova->flash_defaults.regular.timeout == 0) {
    nova->flash_defaults.regular.timeout = 5000;
    nova->flash_defaults.regular.warm = 127;
    nova->flash_defaults.regular.cool = 127;
  }
  if (nova->flash_defaults.preflash.timeout == 0) {
    nova->flash_defaults.preflash.timeout = 10000;
    nova->flash_defaults.preflash.warm = 63;
    nova->flash_defaults.preflash.cool = 63;
  }

  // Restore usage counters from non-volatile memory.
  nova_load_counters(nova, &nova->counters);

  // Increment and save boot counter.
  nova->counters.boot++;
  nova_save_counters(nova, &nova->counters);

  // Ensure lights are off, timers are reset, etc.
  flash_end(nova);

  // Reset internal state.
  nova->ble_app_connected = false;
  nova->ble_hid_connected = false;
  nova->outbound_command_id = 0;
  nova->command_id_for_trigger_ack = 0;

  // Reset status LED.
  update_status_indicator(nova);
}


// ----------------------------------------------------------------------------
// BLE subscription events

/**
 * Called when App subscribes to Nova BLE characteristic.
 */
void nova_on_connect_app(nova_t *nova)
{
  // Update internal state.
  nova->ble_app_connected = true;

  // Update status LED.
  update_status_indicator(nova);

  // Increment and save counter.
  nova->counters.app_connect++;
  nova_save_counters(nova, &nova->counters);
}

/**
 * Called when App UNsubscribes to Nova BLE characteristic.
 */
void nova_on_disconnect_app(nova_t *nova)
{
  // Update internal state.
  nova->ble_app_connected = false;

  // Update status LED.
  update_status_indicator(nova);

  // If both HID and Nova App are disconnected, abort flash.
  if (!nova->ble_hid_connected) {
    flash_end(nova);
  }
}

/**
 * Called when phone subscribes to HID characteristic.
 */
void nova_on_connect_hid(nova_t *nova)
{
  // Update internal state.
  nova->ble_hid_connected = true;

  // Update status LED.
  update_status_indicator(nova);

  // Increment and save counter.
  nova->counters.hid_connect++;
  nova_save_counters(nova, &nova->counters);
}

/**
 * Called when phone UNsubscribes to HID characteristic.
 */
void nova_on_disconnect_hid(nova_t *nova)
{
  // Update internal state.
  nova->ble_hid_connected = false;

  // Update status LED.
  update_status_indicator(nova);

  // If both HID and Nova App are disconnected, abort flash.
  if (!nova->ble_app_connected) {
    flash_end(nova);
  }
}


// ----------------------------------------------------------------------------
// BUTTON HANDLING


/**
 * Called when user begins pressing down button.
 */
void nova_on_button_pressdown(nova_t *nova)
{
  // Turn lights on with pre-flash warm/cool settings.
  flash_start(nova, &nova->flash_defaults.preflash);

  // If paired to custom app, send TRIGGER PRESS command.
  if (nova->ble_app_connected) {

    app_command_t cmd;
    cmd.header.id = ++(nova->outbound_command_id);
    cmd.header.type = NOVA_CMD_TRIGGER;
    cmd.body.trigger.is_pressed = true;
    nova_send_app_command(nova, &cmd);

    // Increment counter.
    nova->counters.flash_button_app++;
  }

  else if (nova->ble_hid_connected) {
    // Increment counter.
    nova->counters.flash_button_native++;
  }

  else {
    // Increment counter.
    nova->counters.flash_button_disconnected++;
  }

  // Save counter.
  nova_save_counters(nova, &nova->counters);
}


/**
 * Called when user releases button to finish the press.
 *
 * Before calling this, apply sensible debounce protection to prevent
 * short (<10 milliseconds) presses.
 */
void nova_on_button_release(nova_t *nova)
{
  // If paired to custom app...
  if (nova->ble_app_connected) {

    // Switch from preflash to regular flash brightness.
    flash_start(nova, &nova->flash_defaults.regular);

    // Tell app to take photo.
    app_command_t cmd;
    cmd.header.id = ++(nova->outbound_command_id);
    cmd.header.type = NOVA_CMD_TRIGGER;
    cmd.body.trigger.is_pressed = false;
    nova_send_app_command(nova, &cmd);

    // Prepare ACK handler (nova_on_app_command() below)
    // so it knows the app has taken the photo.
    nova->command_id_for_trigger_ack = cmd.header.id;
  }

  // If paired to native os...
  else if (nova->ble_hid_connected) {

    // Switch from preflash to flash brightness.
    flash_start(nova, &nova->flash_defaults.regular);

    // Trigger native camera by sending media keys over HID.
    nova_send_hid_key(nova, 0x20); // multimedia key volume up
    nova_send_hid_key(nova, 0x00); // multimedia key release
  }

  // If not paired...
  else {
    // End flash immediately.
    flash_end(nova);
  }
}


// ----------------------------------------------------------------------------
// APP BLE COMMAND HANDLING

/**
 * Called when Nova BLE characteristic receives a command from the App.
 */
void nova_on_app_command(nova_t *nova, app_command_t *cmd)
{
  // Prepare "ACK" response (but don't send it yet).
  app_command_t ack;
  ack.header.id = cmd->header.id;
  ack.header.type = NOVA_CMD_ACK;

  // Receive "PING" command...
  if (cmd->header.type == NOVA_CMD_PING) {
    // Just respond with "ACK".
    nova_send_app_command(nova, &ack);
  }

  // Receive "FLASH" command...
  else if (cmd->header.type == NOVA_CMD_FLASH) {
    // Start the flash.
    flash_start(nova, &cmd->body.flash_settings);

    // Increment and save counter.
    nova->counters.flash_remote_app++;
    nova_save_counters(nova, &nova->counters);

    // Respond with "ACK".
    nova_send_app_command(nova, &ack);
  }

  // Receive "OFF" command...
  else if (cmd->header.type == NOVA_CMD_OFF) {
    // End flash,
    flash_end(nova);

    // Respond with "ACK".
    nova_send_app_command(nova, &ack);
  }

  // Receive "ACK" response from request previously sent to app...
  else if (cmd->header.type == NOVA_CMD_ACK) {

    // Response from trigger: app has completed photo so end_flash().
    if (nova->command_id_for_trigger_ack == cmd->header.id) {
      flash_end(nova);
      nova->command_id_for_trigger_ack = 0;
    }

    // Note: Don't send an ACK response here, otherwise we'll be
    // ACKing the ACK and get caught in an infinite loop.
  }
}


// ----------------------------------------------------------------------------
// TIMER COMPLETION

/**
 * Called sometime after nova_timer_schedule() to indicate flash has timed out.
 */
void nova_on_timer_complete(nova_t *nova)
{
  // Just turn it off.
  flash_end(nova);
}


// ----------------------------------------------------------------------------
// QUERY


void* nova_data(nova_t *nova)
{
  return nova->data;
}

void nova_data_set(nova_t *nova, void *new_data)
{
  nova->data = new_data;
}

bool nova_is_ble_app_connected(nova_t *nova)
{
  return nova->ble_app_connected;
}

bool nova_is_ble_hid_connected(nova_t *nova)
{
  return nova->ble_hid_connected;
}


// ----------------------------------------------------------------------------
// HELPER FUNCTIONS


/**
 * Common code to start a flash.
 */
void flash_start(nova_t *nova, flash_settings_t *flash_settings)
{
  // Activate device lights.
  nova_set_lights(nova, flash_settings->warm, flash_settings->cool);
  nova->is_lit = (flash_settings->cool > 0 && flash_settings->warm > 0);

  // Ensure status light does not interfere with flash light.
  update_status_indicator(nova);

  // Schedule end_flash() (see below) to run after elapsed time
  // to shutdown light.
  if (nova->is_lit) {
    nova_timer_schedule(nova, flash_settings->timeout);
  }
}

/**
 * Common code to end a flash.
 */
void flash_end(nova_t *nova)
{
  // Abort any timer that may still be running.
  nova_timer_clear(nova);

  // Deactivate device lights.
  nova_set_lights(nova, 0, 0);
  nova->is_lit = false;

  // Re-enable status indicator, if needed.
  update_status_indicator(nova);
}

/**
 * Common code to activate/deactivate status LEDs.
 */
void update_status_indicator(nova_t *nova)
{
  // Show status as connected if either HID BLE or Nova App BLE is connected,
  // but disable LED while the main lights are on to prevent color from
  // interfering with photo.
  nova_set_status_indicator(nova,
      (nova->ble_app_connected || nova->ble_hid_connected) && !nova->is_lit);
}
