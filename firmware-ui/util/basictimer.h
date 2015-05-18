// (c) 2015, Joe Walnes, Sneaky Squid

#pragma once

/**
 * A very basic mechanism for scheduling a callback to run after elapsed
 * milliseconds.
 *
 * This is not particulary precise, but good enough for humans.
 *
 * Usage:
 *
 *   // Step 1: Create a basic_timer_t. Keep it around for as long as any
 *   //         timers are running.
 *   basic_timer_t my_timer;
 *
 *   // Step 2: Define your callback. This will be called when your timer
 *   //         expires.
 *   void some_callback(basic_timer *timer, void *data)
 *   {
 *     printf("this is called later\n");
 *   }
 *
 *   // Step 3: Schedule your callback to be called a number of milliseconds
 *   //         from now. The final arg (NULL) is arbitrary data you can pass
 *   //         to the callback.
 *   void somewhere_else() {
 *     basic_timer_schedule(my_timer, 2000, some_callback, NULL);
 *   }
 *
 *   // Step 4: In your main loop, regularly call basic_timer_tick(), which
 *   //         will check if your timer has expired and trigger the callback
 *   //         if necessary.
 *   int main() {
 *     for(;;) {
 *       // do some work
 *       basic_timer_tick(my_timer); // non-blocking
 *     }
 *   }
 */

#include <stdbool.h>
#include <stdint.h>

struct basic_timer_t;

/**
 * Timer callback function, triggered when timer expires.
 *
 * The data param is an arbitrary piece of data that can be passed in when
 * the timer is scheduled.
 */
typedef void (*basic_timer_callback)(struct basic_timer_t *timer, void *data);

/**
 * Instance of timer.
 *
 * All times are in milliseconds. Absolute times are milliseconds since epoch.
 */
typedef struct basic_timer_t
{
  /** Is the timer active? That is, something is scheduled to run in the future. */
  bool active;

  /** What time does the timer expire? Absolute. */
  uint64_t expires;

  /** How long was the original timeout? Relative to time when it was scheduled. */
  uint64_t timeout;

  /** How long remaining. Relative to expires. Updated everytime basic_timer_tick() is called. */
  uint64_t remaining;

  /** Function to invoke when timer expires. */
  basic_timer_callback callback;

  /** Arbitrary user data to pass to callback function. */
  void *data;

} basic_timer_t;

/**
 * Schedule a callback to be run in the future.
 *
 * Timeout is in milliseconds.
 *
 * If data is provided, it will be passed to callback. Use NULL if not needed.
 */
void basic_timer_schedule(basic_timer_t *timer, uint64_t timeout, basic_timer_callback callback, void *data);

/**
 * If a timer was previously scheduled, unschedule it.
 *
 * There's no harm in calling this if nothing is scheduled - it's a no-op.
 */
void basic_timer_clear(basic_timer_t *timer);

/**
 * Call this regularly in your main run loop - it will check if the timer needs to be fired
 * and do so if necessary.
 */
void basic_timer_tick(basic_timer_t *timer);
