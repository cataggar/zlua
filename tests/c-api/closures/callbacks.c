#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

static int add(lua_State *L) {
  int count = lua_gettop(L);
  lua_Integer sum = 0;
  int i;
  for (i = 1; i <= count; i++) sum += lua_tointeger(L, i);
  lua_pushinteger(L, sum);
  lua_pushinteger(L, count);
  return 2;
}

static int call_lua(lua_State *L) {
  int status;
  lua_getglobal(L, "triple");
  lua_pushvalue(L, 1);
  status = lua_pcall(L, 1, 1, 0);
  if (status != LUA_OK) return lua_error(L);
  return 1;
}

int main(void) {
  lua_State *L = luaL_newstate();
  int status;

  lua_pushcfunction(L, add);
  printf("iscfunction=%d tocfunction=%d\n", lua_iscfunction(L, -1), lua_tocfunction(L, -1) == add);
  lua_setglobal(L, "add");

  status = luaL_loadstring(L, "return add(4, 5, 6)");
  printf("load_add=%d\n", status);
  status = lua_pcall(L, 0, LUA_MULTRET, 0);
  printf("lua_calls_c=%d top=%d sum=%lld count=%lld\n", status, lua_gettop(L), (long long)lua_tointeger(L, 1), (long long)lua_tointeger(L, 2));
  lua_settop(L, 0);

  status = luaL_loadstring(L, "function triple(x) return x * 3 end");
  status = (status == LUA_OK) ? lua_pcall(L, 0, 0, 0) : status;
  printf("define_triple=%d\n", status);

  lua_pushcfunction(L, call_lua);
  lua_pushinteger(L, 7);
  status = lua_pcall(L, 1, 1, 0);
  printf("c_calls_lua=%d top=%d result=%lld\n", status, lua_gettop(L), (long long)lua_tointeger(L, -1));

  lua_close(L);
  return 0;
}
