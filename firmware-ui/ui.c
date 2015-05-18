// (c) 2015, Joe Walnes, Sneaky Squid

/**
 * See ui.h
 *
 * This is a primitive NCURSES based UI.
 *
 * All the NCURSES based code is in this single file. So it should be
 * easy to replace it with another GUI mechanism if needed.
 *
 * See screenshot.png if you want to see how it looks.
 */

#include "ui.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <ncurses.h>

#include <nova-internal.h>

#define boolstr(x) x ? "yes" : "no"

#define LOG_ITEMS 47
#define LOG_MSG_LEN 100

static nova_t *nova;
static fake_nova_device_t *device;

static WINDOW *window_hardware;
static WINDOW *window_timer;
static WINDOW *window_counters;
static WINDOW *window_state;
static WINDOW *window_help;
static WINDOW *window_log;

static char log_buffer[LOG_ITEMS][LOG_MSG_LEN];

#define STYLE_NORMAL 1
#define STYLE_FRAME 2
#define STYLE_TITLE 3
#define STYLE_WARM 4
#define STYLE_COOL 5
#define STYLE_CONNECTED 6
#define STYLE_TIMER 7

#include <stdlib.h>

void ui_init(nova_t *nova_val, fake_nova_device_t *device_val)
{
  nova = nova_val;
  device = device_val;

  for (int i = 0; i < LOG_ITEMS; i++) {
    log_buffer[i][0] = 0;
  }

  initscr();
  noecho();
  curs_set(FALSE);
  cbreak();
  start_color();

  init_pair(STYLE_NORMAL, COLOR_WHITE, COLOR_BLACK);
  init_pair(STYLE_FRAME, COLOR_MAGENTA, COLOR_BLACK);
  init_pair(STYLE_TITLE, COLOR_YELLOW, COLOR_BLACK);
  init_pair(STYLE_WARM, COLOR_YELLOW, COLOR_YELLOW);
  init_pair(STYLE_COOL, COLOR_CYAN, COLOR_CYAN);
  init_pair(STYLE_CONNECTED, COLOR_GREEN, COLOR_GREEN);
  init_pair(STYLE_TIMER, COLOR_RED, COLOR_RED);

  window_hardware = newwin(5, 60, 1, 1);
  window_timer = newwin(3, 60, 7, 1);
  window_counters = newwin(9, 60, 11, 1);
  window_state = newwin(19, 60, 21, 1);
  window_help = newwin(9, 60, 41, 1);
  window_log = newwin(LOG_ITEMS + 2, 100, 1, 64);
}

void ui_finish()
{
  delwin(window_hardware);
  delwin(window_timer);
  delwin(window_counters);
  delwin(window_state);
  delwin(window_log);
  delwin(window_help);
  endwin();
}

void ui_log(const char *msg, ...)
{
  // move everything along in the log items
  memcpy(log_buffer[1], log_buffer[0], sizeof(char[LOG_MSG_LEN]) * (LOG_ITEMS - 1));

  // format from var-args
  va_list vargs;
  va_start(vargs, msg);
  char formatted[LOG_MSG_LEN];
  vsprintf(formatted, msg, vargs);
  va_end(vargs);

  // set front of array
  strncpy(log_buffer[0], formatted, sizeof(char[LOG_MSG_LEN]));
}

ui_action ui_get_action(int timeout)
{
  timeout(timeout);
  int c = getch();
  switch (c) {
    case 'q':
    case 'Q':
      return UI_ACTION_QUIT;
    case 'a':
    case 'A':
      return UI_ACTION_TOGGLE_APP;
    case 'h':
    case 'H':
      return UI_ACTION_TOGGLE_HID;
    case 'r':
    case 'R':
      return UI_ACTION_RESET;
    case 'p':
    case 'P':
      return UI_ACTION_APP_PING;
    case '1':
      return UI_ACTION_APP_FLASH;
    case '2':
      return UI_ACTION_APP_OFF;
    case '4':
      return UI_ACTION_TRIGGER_PRESSDOWN;
    case '5':
      return UI_ACTION_TRIGGER_RELEASE;
    default:
      return UI_ACTION_NO_OP;
  }
}

void render_hardware(WINDOW *win)
{
  mvwprintw(win, 1, 2, "connected     : [  ]");
  if (device->connected_lit) {
    wattron(win, COLOR_PAIR(STYLE_CONNECTED));
    mvwprintw(win, 1, 19, "##");
    wattroff(win, COLOR_PAIR(STYLE_CONNECTED));
  }
  mvwprintw(win, 2, 2, "warm intensity: [                               ] %u", device->lights_warm_pwm);
  wattron(win, COLOR_PAIR(STYLE_WARM));
  for (int i = 0; i < device->lights_warm_pwm / 8; i++) {
    mvwprintw(win, 2, 19 + i, "#");
  }
  wattroff(win, COLOR_PAIR(STYLE_WARM));
  mvwprintw(win, 3, 2, "cool intensity: [                               ] %u", device->lights_cool_pwm);
  wattron(win, COLOR_PAIR(STYLE_COOL));
  for (int i = 0; i < device->lights_cool_pwm / 8; i++) {
    mvwprintw(win, 3, 19 + i, "#");
  }
  wattroff(win, COLOR_PAIR(STYLE_COOL));
}

void render_timer(WINDOW* win)
{
  if (device->flash_timer.active) {
    // flash_timer.scheduled
    mvwprintw(win, 1, 2, "flash timer   : [                    ] %ums",
        device->flash_timer.remaining);
    wattron(win, COLOR_PAIR(STYLE_TIMER));
    for (int i = 0; i < 20.0 * ((float)device->flash_timer.remaining / (float)device->flash_timer.timeout); i++) {
      mvwprintw(win, 1, 19 + i, "#");
    }
    wattroff(win, COLOR_PAIR(STYLE_TIMER));
  }
  else {
    mvwprintw(win, 1, 2, "flash timer   : inactive");
  }
}

void render_counters(WINDOW *win)
{
  int line = 1;
  mvwprintw(win, line++, 2, "boot ...................... = %lu", nova->counters.boot);
  mvwprintw(win, line++, 2, "app_connect ............... = %lu", nova->counters.app_connect);
  mvwprintw(win, line++, 2, "hid_connect ............... = %lu", nova->counters.hid_connect);
  mvwprintw(win, line++, 2, "flash_button_app .......... = %lu", nova->counters.flash_button_app);
  mvwprintw(win, line++, 2, "flash_button_native ....... = %lu", nova->counters.flash_button_native);
  mvwprintw(win, line++, 2, "flash_button_disconnected . = %lu", nova->counters.flash_button_disconnected);
  mvwprintw(win, line++, 2, "flash_remote_app .......... = %lu", nova->counters.flash_remote_app);
}

void render_state(WINDOW *win)
{
  int line = 1;
  mvwprintw(win, line++, 2, "ble_app_connected ......... = %s", boolstr(nova->ble_app_connected));
  mvwprintw(win, line++, 2, "ble_hid_connected ......... = %s", boolstr(nova->ble_hid_connected));
  mvwprintw(win, line++, 2, "is_lit .................... = %s", boolstr(nova->is_lit));
  mvwprintw(win, line++, 2, "flash_defaults {");
  mvwprintw(win, line++, 2, "  regular {");
  mvwprintw(win, line++, 2, "    timeout ............... = %lu", nova->flash_defaults.regular.timeout);
  mvwprintw(win, line++, 2, "    warm .................. = %lu", nova->flash_defaults.regular.warm);
  mvwprintw(win, line++, 2, "    cool .................. = %lu", nova->flash_defaults.regular.cool);
  mvwprintw(win, line++, 2, "  }");
  mvwprintw(win, line++, 2, "  preflash {");
  mvwprintw(win, line++, 2, "    timeout ............... = %lu", nova->flash_defaults.preflash.timeout);
  mvwprintw(win, line++, 2, "    warm .................. = %lu", nova->flash_defaults.preflash.warm);
  mvwprintw(win, line++, 2, "    cool .................. = %lu", nova->flash_defaults.preflash.cool);
  mvwprintw(win, line++, 2, "  }");
  mvwprintw(win, line++, 2, "}");
  mvwprintw(win, line++, 2, "outbound_command_id ....... = %lu", nova->outbound_command_id);
  mvwprintw(win, line++, 2, "command_id_for_trigger_ack  = %lu", nova->command_id_for_trigger_ack);
}

void render_help(WINDOW* win)
{
  int line = 1;
  mvwprintw(win, line++, 2, "R     : reset (power on)");
  mvwprintw(win, line++, 2, "A     : toggle BLE App connectivity");
  mvwprintw(win, line++, 2, "H     : toggle BLE HID connectivity");
  mvwprintw(win, line++, 2, "P     : simulate PING from App");
  mvwprintw(win, line++, 2, "1, 2  : simulate FLASH, OFF from App");
  mvwprintw(win, line++, 2, "4, 5  : simulate trigger button PRESS, RELEASE");
  mvwprintw(win, line++, 2, "Q     : quit");
}

void render_log(WINDOW* win)
{
  for (int i = 0; i < LOG_ITEMS; i++) {
    mvwprintw(win, i + 1, 2, log_buffer[LOG_ITEMS - i - 1]);
  }
}

void ui_refresh()
{
  #define render(win, render_func, title) {\
      wclear(win); \
      wattron(win, COLOR_PAIR(STYLE_FRAME)); \
      box(win, 0, 0); \
      wattroff(win, COLOR_PAIR(STYLE_FRAME)); \
      wattron(win, COLOR_PAIR(STYLE_TITLE)); \
      mvwprintw(win, 0, 1, " %s ", title); \
      wattroff(win, COLOR_PAIR(STYLE_TITLE)); \
      wattron(win, COLOR_PAIR(STYLE_NORMAL)); \
      render_func(win); \
      wattroff(win, COLOR_PAIR(STYLE_NORMAL)); \
      wnoutrefresh(win); \
    }

  render(window_hardware, render_hardware, "HARDWARE");
  render(window_timer, render_timer, "TIMER");
  render(window_counters, render_counters, "COUNTERS");
  render(window_state, render_state, "INTERNAL STATE");
  render(window_help, render_help, "HELP");
  render(window_log, render_log, "DEBUG LOG");

  doupdate();
}
