// (c) 2015, Joe Walnes, Sneaky Squid

/**
 * See basictimer.h for usage.
 */

#include "basictimer.h"

#include <stddef.h>

uint64_t millis_now();

void basic_timer_schedule(basic_timer_t *timer, uint64_t timeout, basic_timer_callback callback, void *data)
{
  timer->active = true;
  timer->callback = callback;
  timer->data = data;
  timer->expires = millis_now() + (uint64_t)timeout;
  timer->timeout = timeout;
  timer->remaining = timeout;
}

void basic_timer_clear(basic_timer_t *timer)
{
  timer->active = false;
  timer->callback = NULL;
  timer->data = NULL;
  timer->expires = 0;
  timer->timeout = 0;
  timer->remaining = 0;
}

void basic_timer_tick(basic_timer_t *timer)
{
  if (timer->active) {
    uint64_t now = millis_now();
    if (now >= timer->expires) {
      timer->callback(timer, timer->data);
      basic_timer_clear(timer);
    } else {
      timer->remaining = (timer->expires - now);
    }
  }
}

// ---- Platform specific time functions ----

#ifdef __MACH__ // Mac OS X

  #include <sys/time.h>

  uint64_t millis_now()
  {
    struct timeval time;
    gettimeofday(&time, NULL);
    return (time.tv_sec * 1000) + (time.tv_usec / 1000);
  }

#elif _WIN32 // Windows

  #include "windows.h"

  uint64_t millis_now()
  {
    SYSTEMTIME time;
    GetSystemTime(&time);
    return (time.wSeconds * 1000) + time.wMilliseconds;
  }

#else // Linux

  #include <time.h>

  uint64_t millis_now()
  {
    struct timespec time;
    clock_gettime(CLOCK_REALTIME, &time);
    return (time.tv_sec * 1000) + round(time.tv_nsec / 1000000);
  }

#endif
