// (c) 2015, Joe Walnes, Sneaky Squid

#pragma once

#include <stdbool.h>
#include <nova.h>
#include "util/basictimer.h"

/**
 * Provides implementations of all Nova device functions (nova-device.h).
 *
 * This 'fake' implementation does not use real hardware and instead
 * just stores everything in memory in struct fake_device_t.
 *
 * See fake-nova-device.c for the actual implementations.
 *
 * It also sends calls to the UI to make it easy to see what's going on.
 */
typedef struct fake_nova_device_t
{
  /** Associated nova_t. */
  nova_t *nova;

  /** Current PWM setting of cool lights (0-255). */
  uint8_t lights_cool_pwm;

  /** Current PWM setting of warm lights (0-255). */
  uint8_t lights_warm_pwm;

  /** Whether connectivity indicator is lit. */
  bool connected_lit;

  /** Timer used for deactivating flash. */
  basic_timer_t flash_timer;

  /** Path to store usage counters data. */
  const char *counters_filename;

} fake_nova_device_t;

/**
 * Create a new fake_nova_device_t.
 *
 * This also comes with a nova_t instance which can be accessed via the nova
 * pointer in the result.
 *
 * counters_filename is a path to save usage counters data in between runs.
 */
fake_nova_device_t *fake_nova_device_init(const char *counters_filename);

/**
 * Free up fake_nova_device_t and embedded nova_t.
 */
void fake_nova_device_free(fake_nova_device_t *device);
