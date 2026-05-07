#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

static int raise_string(lua_State *L) {
  lua_pushstring(L, "callback boom");
  return lua_error(L);
}

static int raise_formatted(lua_State *L) {
  return luaL_error(L, "formatted %d", 42);
}

int main(void) {
  lua_State *L = luaL_newstate();
  int status;

  lua_pushcfunction(L, raise_string);
  status = lua_pcall(L, 0, 1, 0);
  printf("string_status=%d top=%d msg=%s\n", status, lua_gettop(L), lua_tostring(L, -1));
  lua_settop(L, 0);

  lua_pushcfunction(L, raise_formatted);
  status = lua_pcall(L, 0, 1, 0);
  printf("formatted_status=%d top=%d msg=%s\n", status, lua_gettop(L), lua_tostring(L, -1));

  lua_close(L);
  return 0;
}
