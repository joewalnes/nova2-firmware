// (c) 2015, Joe Walnes, Sneaky Squid

/**
 * Provides implementations of all Nova device functions (nova-device.h).
 *
 * This 'fake' implementation does not use real hardware and instead
 * just stores everything in memory in struct fake_device_t.
 *
 * It also sends calls to the UI to make it easy to see what's going on.
 */

#include "fake-nova-device.h"

#include <stdlib.h>

#include <nova-device.h>
#include <nova-api.h>
#include <nova-internal.h>

#include "util/basictimer.h"
#include "util/file.h"
#include "ui.h"

fake_nova_device_t *fake_nova_device_init(const char *counters_filename)
{
  fake_nova_device_t *device = malloc(sizeof(fake_nova_device_t));
  device->flash_timer.active = false;
  device->counters_filename = counters_filename;

  device->nova = malloc(sizeof(nova_t));
  device->nova->data = device;

  return device;
}

void fake_nova_device_free(fake_nova_device_t *device)
{
  free(device->nova);
  free(device);
}

void nova_load_counters(nova_t *nova, counters_t *counters)
{
  ui_log("   nova_load_counters()");
  fake_nova_device_t *device = (fake_nova_device_t*)nova_data(nova);
  file_load(device->counters_filename, counters, sizeof(counters_t));
}

void nova_save_counters(nova_t *nova, counters_t *counters)
{
  ui_log("   nova_save_counters()");
  fake_nova_device_t *device = (fake_nova_device_t*)nova_data(nova);
  file_save(device->counters_filename, counters, sizeof(counters_t));
}

void nova_load_flash_defaults(nova_t *nova, flash_defaults_t *flash_defaults)
{
  ui_log("   nova_load_flash_defaults()");
}

void nova_send_app_command(nova_t *nova, app_command_t *cmd)
{
  switch (cmd->type) {
    case NOVA_CMD_TRIGGER:
      ui_log("   nova_send_app_command({type=TRIGGER, id=%u, is_pressed=%i})",
          cmd->id, cmd->body.trigger.is_pressed);
      break;
    case NOVA_CMD_ACK:
      ui_log("   nova_send_app_command({type=ACK, id=%u})", cmd->id);
      break;
    default:
      ui_log("   nova_send_app_command(UNEXPECTED!)", cmd->id);
  }
}

void nova_send_hid_key(nova_t *nova, char key_code)
{
  ui_log("   nova_send_hid_key(code=%#04x)", key_code);
}

void nova_set_status_indicator(nova_t *nova, bool lit)
{
  ui_log("   nova_set_status_indicator(lit=%i)", lit);
  fake_nova_device_t *device = (fake_nova_device_t*)nova_data(nova);
  device->connected_lit = lit;
}

void nova_set_lights(nova_t *nova, uint8_t warm_pwm, uint8_t cool_pwm)
{
  ui_log("   nova_set_status_indicator(warm=%u, cool=%u)", warm_pwm, cool_pwm);
  fake_nova_device_t *device = (fake_nova_device_t*)nova_data(nova);
  device->lights_warm_pwm = warm_pwm;
  device->lights_cool_pwm = cool_pwm;
}

void on_timer_complete(basic_timer_t *timer, void *data)
{
  nova_on_timer_complete((nova_t*) data);
}

void nova_timer_schedule(nova_t *nova, milliseconds_t timeout)
{
  ui_log("   nova_timer_schedule(timeout=%u)", timeout);
  fake_nova_device_t *device = (fake_nova_device_t*)nova_data(nova);
  basic_timer_schedule(&device->flash_timer, timeout, on_timer_complete, nova);
}

void nova_timer_clear(nova_t *nova)
{
  ui_log("   nova_timer_clear()");
  fake_nova_device_t *device = (fake_nova_device_t*)nova_data(nova);
  basic_timer_clear(&device->flash_timer);
}
