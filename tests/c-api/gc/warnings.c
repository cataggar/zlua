#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

typedef struct WarnState {
  int calls;
} WarnState;

static void custom_warn(void *ud, const char *msg, int tocont) {
  WarnState *state = (WarnState *)ud;
  state->calls++;
  printf("warn%d:%s:%d\n", state->calls, msg, tocont);
}

int main(void) {
  lua_State *L = luaL_newstate();
  WarnState state = {0};

  lua_setwarnf(L, custom_warn, &state);
  lua_warning(L, "first", 0);
  lua_warning(L, "part", 1);
  lua_warning(L, "end", 0);
  lua_setwarnf(L, NULL, NULL);
  lua_warning(L, "ignored", 0);
  printf("calls=%d\n", state.calls);

  lua_close(L);
  return 0;
}
