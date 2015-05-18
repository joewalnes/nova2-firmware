# (c) 2015, Joe Walnes, Sneaky Squid

# This Makefile validates nova.c can compile correctly.
# It discards the resulting lib because it's useless
# without a hardware platform, but it's enough to verify
# the code is valid.

# To run (on Linux, OSX or other POSIXy platform): 
#   make

# TODO: Add an equivalent for Windows.

check: nova.c
	$(CC) -c -o /dev/null $^
.PHONY: check
