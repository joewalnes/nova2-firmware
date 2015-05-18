// (c) 2015, Joe Walnes, Sneaky Squid

#pragma once

/**
 * Creates a console based NCURSES user interface.
 *
 * The UI:
 * - renders the state of nova_t and fake_nova_device_t
 * - displays log messages
 * - waits for user actions and returns them to program
 */

#include "fake-nova-device.h"

#include <nova.h>

/**
 * When user interaction occurs, what did they do?
 *
 * Returned from ui_get_action().
 */
typedef enum
{
  UI_ACTION_NO_OP,
  UI_ACTION_QUIT,
  UI_ACTION_RESET,
  UI_ACTION_TOGGLE_APP,
  UI_ACTION_TOGGLE_HID,
  UI_ACTION_APP_PING,
  UI_ACTION_APP_FLASH,
  UI_ACTION_APP_OFF,
  UI_ACTION_TRIGGER_PRESSDOWN,
  UI_ACTION_TRIGGER_RELEASE
} ui_action;

/**
 * Initialize UI. Call once at start.
 */
void ui_init(nova_t *nova, fake_nova_device_t *device);

/**
 * Call before quitting app to restore terminal.
 */
void ui_finish();

/**
 * Refresh all data on UI screen.
 *
 * Call this regularly.
 */
void ui_refresh();

/**
 * Append a log message to the UI screen.
 *
 * Uses printf() style var-arg formatters.
 */
void ui_log(const char *msg, ...);

/**
 * Wait for a user action (see ui_action above).
 *
 * Will wait at most timeout milliseconds.
 */
ui_action ui_get_action(int timeout);
