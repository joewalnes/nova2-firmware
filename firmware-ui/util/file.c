// (c) 2015, Joe Walnes, Sneaky Squid

#include "file.h"

#include <stdio.h>

void file_save(const char *filename, const void *data, size_t len)
{
  FILE *file = fopen(filename, "wb");
  if (file) {
    fwrite(data, len, 1, file);
    fclose(file);
  }
}

void file_load(const char *filename, void *data, size_t len)
{
  FILE *file = fopen(filename, "rb");
  if (file) {
    fread(data, len, 1, file);
    fclose(file);
  }
}
