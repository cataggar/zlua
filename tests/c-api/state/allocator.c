#include <stdio.h>
#include <stdlib.h>

#include "lua.h"
#include "lauxlib.h"

typedef struct Counts {
  int alloc_seen;
  int free_seen;
  int resize_seen;
} Counts;

static void *counting_alloc(void *ud, void *ptr, size_t osize, size_t nsize) {
  Counts *counts = (Counts *)ud;
  (void)osize;
  if (nsize == 0) {
    counts->free_seen = counts->free_seen || ptr != NULL;
    free(ptr);
    return NULL;
  }
  if (ptr == NULL) {
    counts->alloc_seen = 1;
    return malloc(nsize);
  }
  counts->resize_seen = 1;
  return realloc(ptr, nsize);
}

int main(void) {
  Counts counts = {0, 0, 0};
  lua_State *L = lua_newstate(counting_alloc, &counts, 0);
  void *ud = NULL;
  lua_Alloc allocf = lua_getallocf(L, &ud);

  printf("state=%d\n", L != NULL);
  printf("alloc_seen=%d\n", counts.alloc_seen);
  printf("allocf_same=%d\n", allocf == counting_alloc);
  printf("ud_same=%d\n", ud == &counts);
  printf("checkstack=%d\n", lua_checkstack(L, 32));

  lua_close(L);
  printf("free_seen=%d\n", counts.free_seen);
  return 0;
}
