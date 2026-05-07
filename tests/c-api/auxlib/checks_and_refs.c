#include <stdio.h>
#include <string.h>
#include <errno.h>

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

static int fail_type(lua_State *L) {
  return luaL_typeerror(L, 1, "table");
}

int main(void) {
  lua_State *L = luaL_newstate();
  int r1, r2, r3;
  char *slot;
  luaL_Buffer b;

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

  luaL_checkstack(L, 2, "fixture");
  luaL_where(L, 1);
  printf("where_len=%zu\n", strlen(lua_tostring(L, -1)));
  lua_pop(L, 1);

  lua_pushcfunction(L, fail_type);
  lua_pushinteger(L, 1);
  int status = lua_pcall(L, 1, 1, 0);
  printf("typeerror_status=%d contains=%d\n", status, strstr(lua_tostring(L, -1), "table expected, got number") != NULL);
  lua_settop(L, 0);

  luaL_buffinitsize(L, &b, 4);
  slot = luaL_prepbuffsize(&b, 4);
  memcpy(slot, "size", 4);
  luaL_pushresultsize(&b, 4);
  printf("resultsize=%s top=%d\n", lua_tostring(L, -1), lua_gettop(L));
  lua_pop(L, 1);

  printf("makeseed_nonzero=%d\n", luaL_makeseed(L) != 0);
  lua_pushstring(L, "abcd");
  printf("len=%lld\n", (long long)luaL_len(L, -1));
  lua_pop(L, 1);

  errno = 0;
  int file_returns = luaL_fileresult(L, 1, NULL);
  printf("fileresult_ok=%d returns=%d top=%d\n", lua_toboolean(L, -1), file_returns, lua_gettop(L));
  lua_pop(L, 1);
  errno = 0;
  int exec_returns = luaL_execresult(L, 0);
  printf("execresult_ok_returns=%d top=%d\n", exec_returns, lua_gettop(L));
  printf("execresult=%s,%s,%lld\n", lua_toboolean(L, -3) ? "true" : "fail", lua_tostring(L, -2), (long long)lua_tointeger(L, -1));
  lua_pop(L, 3);

  lua_close(L);
  return 0;
}
