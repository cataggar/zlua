#include <stdio.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"

static int checked(lua_State *L) {
  size_t len;
  const char *opts[] = {"alpha", "beta", "gamma", NULL};
  const char *s = luaL_checklstring(L, 1, &len);
  lua_Number n = luaL_checknumber(L, 2);
  lua_Integer i = luaL_checkinteger(L, 3);
  const char *fallback = luaL_optlstring(L, 4, "fallback", NULL);
  lua_Number on = luaL_optnumber(L, 5, 12.5);
  lua_Integer oi = luaL_optinteger(L, 6, 77);
  int opt = luaL_checkoption(L, 7, "beta", opts);
  luaL_checkany(L, 1);
  luaL_checktype(L, 8, LUA_TTABLE);
  lua_pushfstring(L, "%s:%d:%.1f:%d:%s:%.1f:%d:%d", s, (int)len, (double)n, (int)i, fallback, (double)on, (int)oi, opt);
  return 1;
}

static void print_call(lua_State *L, int nargs) {
  int status = lua_pcall(L, nargs, 1, 0);
  printf("status=%d result=%s\n", status, lua_tostring(L, -1));
  lua_settop(L, 0);
}

int main(void) {
  lua_State *L = luaL_newstate();
  int r1, r2, r3;

  lua_pushcfunction(L, checked);
  lua_pushstring(L, "hello");
  lua_pushnumber(L, 4.5);
  lua_pushinteger(L, 9);
  lua_pushnil(L);
  lua_pushnil(L);
  lua_pushnil(L);
  lua_pushstring(L, "gamma");
  lua_newtable(L);
  print_call(L, 8);

  lua_newtable(L);
  lua_pushstring(L, "first");
  r1 = luaL_ref(L, -2);
  lua_pushstring(L, "second");
  r2 = luaL_ref(L, -2);
  luaL_unref(L, -1, r1);
  lua_pushstring(L, "third");
  r3 = luaL_ref(L, -2);
  lua_rawgeti(L, -1, r2);
  lua_rawgeti(L, -2, r3);
  printf("refs=%d,%d,%d values=%s,%s top=%d\n", r1, r2, r3, lua_tostring(L, -2), lua_tostring(L, -1), lua_gettop(L));
  lua_pop(L, 3);

  lua_pushnil(L);
  printf("nilref=%d top=%d\n", luaL_ref(L, LUA_REGISTRYINDEX), lua_gettop(L));

  lua_close(L);
  return 0;
}
