// (c) 2015, Joe Walnes, Sneaky Squid

#pragma once

/**
 * Save and load a struct to disk.
 */

#include <stddef.h>

void file_save(const char *filename, const void *data, size_t len);
void file_load(const char *filename, void *data, size_t len);
