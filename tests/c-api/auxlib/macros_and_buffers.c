#include <stdio.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"

static int answer(lua_State *L) {
  lua_pushinteger(L, 123);
  return 1;
}

static int optional(lua_State *L) {
  lua_Integer value = luaL_opt(L, luaL_checkinteger, 1, 77);
  lua_pushinteger(L, value);
  return 1;
}

static int expect_positive(lua_State *L) {
  lua_Integer value = luaL_checkinteger(L, 1);
  luaL_argcheck(L, value > 0, 1, "positive expected");
  lua_pushinteger(L, value);
  return 1;
}

static const luaL_Reg funcs[] = {
  {"answer", answer},
  {NULL, NULL}
};

static void call_one(lua_State *L, int nargs) {
  int status = lua_pcall(L, nargs, 1, 0);
  if (status == LUA_OK) {
    printf("call status=%d type=%s value=%s top=%d\n", status, lua_typename(L, lua_type(L, -1)), lua_tostring(L, -1), lua_gettop(L));
  } else {
    printf("call status=%d type=%s contains=%d top=%d\n", status, lua_typename(L, lua_type(L, -1)), strstr(lua_tostring(L, -1), "positive expected") != NULL, lua_gettop(L));
  }
  lua_settop(L, 0);
}

int main(void) {
  lua_State *L = luaL_newstate();
  luaL_Buffer b;
  char *slot;

  luaL_newlib(L, funcs);
  lua_getfield(L, -1, "answer");
  lua_call(L, 0, 1);
  printf("newlib answer=%lld top=%d\n", (long long)lua_tointeger(L, -1), lua_gettop(L));
  lua_settop(L, 0);

  lua_pushcfunction(L, optional);
  lua_pushnil(L);
  call_one(L, 1);

  lua_pushcfunction(L, optional);
  lua_pushinteger(L, 5);
  call_one(L, 1);

  lua_pushcfunction(L, expect_positive);
  lua_pushinteger(L, -1);
  call_one(L, 1);

  luaL_buffinit(L, &b);
  luaL_addstring(&b, "abcdef");
  printf("bufflen1=%zu addr_nonnull=%d top=%d\n", luaL_bufflen(&b), luaL_buffaddr(&b) != NULL, lua_gettop(L));
  luaL_buffsub(&b, 2);
  luaL_addchar(&b, 'Z');
  slot = luaL_prepbuffer(&b);
  memcpy(slot, "12", 2);
  luaL_addsize(&b, 2);
  printf("bufflen2=%zu\n", luaL_bufflen(&b));
  luaL_pushresult(&b);
  printf("buffer_result=%s top=%d\n", lua_tostring(L, -1), lua_gettop(L));
  lua_pop(L, 1);

  luaL_pushfail(L);
  printf("pushfail_type=%s bool=%d\n", lua_typename(L, lua_type(L, -1)), lua_toboolean(L, -1));

  lua_close(L);
  return 0;
}
