Nova Shared Firmware
====================

Shared implementation of Nova device firmware.

This is provides the core logic of the firmware, but does not
include any device/platform/processor specific code.

This core logic can be shared across Nova device implementations
and simulations.

Alternatively, it can be used as the canonical reference of how
Nova is expected to behave.

To integrate into a new system:

- Provide implementations for all functions in nova-device.h
  which allows the code below to interact with hardware.

- Create a main() program which allocates a nova_t type and
  and calls nova_on_?????() functions (see nova-api.h) when
  the user interacts with device. The platform specific code
  is also responsible for setting up the BLE radio stack and
  listening to events.






----

*(c) 2015, Joe Walnes, Sneaky Squid*
