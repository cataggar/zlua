#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"

typedef struct Counts {
  int freed;
} Counts;

static void *free_external(void *ud, void *ptr, size_t osize, size_t nsize) {
  Counts *counts = (Counts *)ud;
  printf("free_external osize=%zu nsize=%zu text=%s\n", osize, nsize, (char *)ptr);
  counts->freed++;
  free(ptr);
  return NULL;
}

int main(void) {
  lua_State *L = luaL_newstate();
  Counts counts = {0};
  char *text = (char *)malloc(7);
  size_t len;

  memcpy(text, "extern", 7);
  printf("same_ptr=%d\n", lua_pushexternalstring(L, text, 6, free_external, &counts) == text);
  printf("value=%s len=%zu rawlen=%llu\n", lua_tolstring(L, -1, &len), len, (unsigned long long)lua_rawlen(L, -1));
  lua_pop(L, 1);
  lua_gc(L, LUA_GCCOLLECT);
  printf("freed_after_gc=%d\n", counts.freed);
  lua_close(L);
  printf("freed_after_close=%d\n", counts.freed);
  return 0;
}
