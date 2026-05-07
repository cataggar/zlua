#include <stdio.h>
#include <stdlib.h>

#include "lua.h"
#include "lauxlib.h"

static int panicf(lua_State *L) {
  printf("panic:%s\n", lua_tostring(L, -1));
  lua_close(L);
  exit(23);
}

static int boom(lua_State *L) {
  lua_pushstring(L, "unprotected boom");
  return lua_error(L);
}

int main(void) {
  lua_State *L = luaL_newstate();
  lua_atpanic(L, panicf);
  lua_pushcfunction(L, boom);
  lua_call(L, 0, 0);
  return 0;
}
