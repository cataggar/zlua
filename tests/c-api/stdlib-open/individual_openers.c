#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

static void check_open(lua_State *L, const char *name, lua_CFunction openf, const char *field) {
  int nres = openf(L);
  const char *ret_type = lua_typename(L, lua_type(L, -1));
  const char *field_type;
  const char *global_type;

  lua_getfield(L, -1, field);
  field_type = lua_typename(L, lua_type(L, -1));
  lua_pop(L, 1);

  lua_getglobal(L, name);
  global_type = lua_typename(L, lua_type(L, -1));
  lua_pop(L, 1);

  printf("%s nres=%d ret=%s %s=%s global=%s top=%d\n",
         name, nres, ret_type, field, field_type, global_type, lua_gettop(L));
  lua_pop(L, 1);
}

int main(void) {
  lua_State *L = luaL_newstate();

  check_open(L, "coroutine", luaopen_coroutine, "resume");
  check_open(L, "debug", luaopen_debug, "traceback");
  check_open(L, "io", luaopen_io, "write");
  check_open(L, "os", luaopen_os, "time");

  lua_close(L);
  return 0;
}
