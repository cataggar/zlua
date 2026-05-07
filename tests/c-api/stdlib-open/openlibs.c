#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

static void print_global(lua_State *L, const char *name) {
  lua_getglobal(L, name);
  printf("%s=%s\n", name, lua_typename(L, lua_type(L, -1)));
  lua_pop(L, 1);
}

int main(void) {
  lua_State *L = luaL_newstate();
  int status;

  luaopen_math(L);
  printf("math_ret=%s top=%d\n", lua_typename(L, lua_type(L, -1)), lua_gettop(L));
  lua_pop(L, 1);
  print_global(L, "math");

  luaopen_package(L);
  lua_getfield(L, -1, "loaded");
  lua_getfield(L, -2, "preload");
  printf("package_ret=%s loaded=%s preload=%s\n", lua_typename(L, lua_type(L, -3)), lua_typename(L, lua_type(L, -2)), lua_typename(L, lua_type(L, -1)));
  lua_pop(L, 3);

  luaL_openselectedlibs(L, LUA_GLIBK | LUA_STRLIBK | LUA_TABLIBK, LUA_UTF8LIBK);
  print_global(L, "_G");
  print_global(L, "string");
  print_global(L, "table");
  print_global(L, "utf8");

  luaL_getsubtable(L, LUA_REGISTRYINDEX, LUA_PRELOAD_TABLE);
  lua_getfield(L, -1, "utf8");
  printf("preload_utf8=%s\n", lua_typename(L, lua_type(L, -1)));
  lua_pop(L, 2);

  status = luaL_loadstring(L, "return type(print), string.upper('ok'), table.concat({'a','b'}, ',')");
  status = (status == LUA_OK) ? lua_pcall(L, 0, 3, 0) : status;
  printf("call=%d values=%s,%s,%s\n", status, lua_tostring(L, 1), lua_tostring(L, 2), lua_tostring(L, 3));

  lua_close(L);
  return 0;
}
