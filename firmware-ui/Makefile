# (c) 2015, Joe Walnes, Sneaky Squid

# Should work on Linux and OSX. The program uses ncurses library so it's
# unlikely to ever work on Windows.

# Build commands:
#   make             -- Compiles and runs program.
#   make build       -- Compiles program. Run with ./firmware-ui
#   make clean       -- Clean up built files (and data)

SHARED_DIR=../firmware-shared

run: firmware-ui
	./firmware-ui
.PHONY: run

build: firmware-ui
.PHONY: run

firmware-ui: $(wildcard *.c) $(wildcard util/*.c) $(wildcard $(SHARED_DIR)/*.c)
	$(CC) -I $(SHARED_DIR) -lncurses -o $@ $^

clean:
	rm -f firmware-ui $(wildcard *.data)
.PHONY: clean
