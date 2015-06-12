// (c) 2015, Joe Walnes, Sneaky Squid

#include <stdio.h>
#include <stdlib.h>

#include <nova-api.h>

#include "ui.h"
#include "util/basictimer.h"

/**
 * This is a standalone program that embeds the Nova shared firmware code
 * but wires it up to a fake device (in memory, instead of real hardware)
 * and provides a user interface for viewing and interacting with it.
 *
 * Use it to manually interact with the shared firmware code and see
 * how it responds.
 *
 * See README for more details.
 */

// TODO: Allow UI to change (and save) flash_defaults
// TODO: Simulate App ACKing trigger

int main(int argc, char **argv)
{
  // Setup fake Nova device. See fake-nova-device.h.
  // Usage counters saved in file "counters.data".
  fake_nova_device_t *device = fake_nova_device_init("counters.data");
  nova_t* nova = device->nova;

  // For simulating commands from the App.
  cmd_id_t id = 0;
  app_command_t cmd;

  // Setup UI.
  ui_init(nova, device);

  // Reset Nova firmware.
  ui_log("-> nova_on_reset()");
  nova_on_reset(nova);

  // Main loop...
  for(;;) {

    // Run timer callbacks if its time has expired.
    basic_timer_tick(&device->flash_timer);

    // Paint UI.
    ui_refresh();

    // Await action from user interface.
    // If timer is active, only wait a short while so the UI can be regularly
    // repainted to show timer countdown progress.
    // If timer is not active, give it more time so we don't repaint too often.
    int key_timeout = device->flash_timer.active ? 100 : 1000;
    ui_action action = ui_get_action(key_timeout);

    // Handle user action.
    switch (action) {

      case UI_ACTION_QUIT:
        goto quit;

      case UI_ACTION_RESET:
        ui_log("-> nova_on_reset()");
        nova_on_reset(nova);
        break;

      case UI_ACTION_TOGGLE_APP:
        // Toggle APP connectivity.
        if (!nova_is_ble_app_connected(nova)) {
          ui_log("-> nova_on_connect_app()");
          nova_on_connect_app(nova);
        } else {
          ui_log("-> nova_on_disconnect_app()");
          nova_on_disconnect_app(nova);
        }
        break;

      case UI_ACTION_TOGGLE_HID:
        // Toggle HID connectivity.
        if (!nova_is_ble_hid_connected(nova)) {
          ui_log("-> nova_on_connect_hid()");
          nova_on_connect_hid(nova);
        } else {
          ui_log("-> nova_on_disconnect_hid()");
          nova_on_disconnect_hid(nova);
        }
        break;

      case UI_ACTION_APP_PING:
        // Simulate PING from App.
        if (nova_is_ble_app_connected(nova)) {
          cmd.header.type = NOVA_CMD_PING;
          cmd.header.id = ++id;
          ui_log("-> nova_on_app_command({type=PING, id=%u})", cmd.header.id);
          nova_on_app_command(nova, &cmd);
        }
        break;

      case UI_ACTION_APP_FLASH:
        // Simulate FLASH from App.
        if (nova_is_ble_app_connected(nova)) {
          cmd.header.type = NOVA_CMD_FLASH;
          cmd.header.id = ++id;
          cmd.body.flash_settings.timeout = 5000;
          cmd.body.flash_settings.warm = 255;
          cmd.body.flash_settings.cool = 127;
          ui_log("-> nova_on_app_command({type=FLASH, id=%u, flash_settings={timeout=%u, warm=%u, cool=%u}})",
              cmd.header.id, cmd.body.flash_settings.timeout, cmd.body.flash_settings.warm, cmd.body.flash_settings.cool);
          nova_on_app_command(nova, &cmd);
        }
        break;

      case UI_ACTION_APP_OFF:
        // Simulate OFF from app.
        if (nova_is_ble_app_connected(nova)) {
          cmd.header.type = NOVA_CMD_OFF;
          cmd.header.id = ++id;
          ui_log("-> nova_on_app_command({type=OFF, id=%u})", cmd.header.id);
          nova_on_app_command(nova, &cmd);
        }
        break;

      case UI_ACTION_TRIGGER_PRESSDOWN:
        // Simulate user pressing down on trigger button.
        ui_log("-> nova_on_button_pressdown()");
        nova_on_button_pressdown(nova);
        break;

      case UI_ACTION_TRIGGER_RELEASE:
        // Simulate user releasing trigger button.
        ui_log("-> nova_on_button_release()");
        nova_on_button_release(nova);
        break;

      case UI_ACTION_NO_OP:
        // Nothing happened in alloted time. Try again.
        break;

    }
  }

quit:
  // Cleanup.
  ui_finish();
  fake_nova_device_free(device);
  return 0;
}
