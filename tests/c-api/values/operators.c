#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

int main(void) {
  lua_State *L = luaL_newstate();

  lua_pushinteger(L, 7);
  lua_pushinteger(L, 3);
  lua_arith(L, LUA_OPADD);
  printf("add=%lld\n", (long long)lua_tointeger(L, -1));
  lua_pop(L, 1);

  lua_pushinteger(L, 7);
  lua_pushinteger(L, 3);
  lua_arith(L, LUA_OPIDIV);
  printf("idiv=%lld\n", (long long)lua_tointeger(L, -1));
  lua_pop(L, 1);

  lua_pushinteger(L, 7);
  lua_pushinteger(L, 3);
  lua_arith(L, LUA_OPMOD);
  printf("mod=%lld\n", (long long)lua_tointeger(L, -1));
  lua_pop(L, 1);

  lua_pushinteger(L, 6);
  lua_pushinteger(L, 3);
  lua_arith(L, LUA_OPBAND);
  printf("band=%lld\n", (long long)lua_tointeger(L, -1));
  lua_pop(L, 1);

  lua_pushnumber(L, 7.5);
  lua_pushinteger(L, 2);
  lua_arith(L, LUA_OPDIV);
  printf("div=%.2f\n", lua_tonumber(L, -1));
  lua_pop(L, 1);

  lua_pushstring(L, "a");
  lua_pushinteger(L, 12);
  lua_concat(L, 2);
  printf("concat=%s rawlen=%llu\n", lua_tostring(L, -1), (unsigned long long)lua_rawlen(L, -1));
  lua_pop(L, 1);

  lua_pushinteger(L, 4);
  lua_pushnumber(L, 4.0);
  printf("eq=%d le=%d lt=%d raw=%d\n",
      lua_compare(L, -2, -1, LUA_OPEQ), lua_compare(L, -2, -1, LUA_OPLE),
      lua_compare(L, -2, -1, LUA_OPLT), lua_rawequal(L, -2, -1));
  lua_pop(L, 2);

  lua_pushstring(L, "abc");
  lua_len(L, -1);
  printf("len_string=%lld\n", (long long)lua_tointeger(L, -1));
  lua_pop(L, 2);

  lua_newtable(L);
  lua_pushboolean(L, 1);
  lua_rawseti(L, -2, 1);
  lua_pushboolean(L, 1);
  lua_rawseti(L, -2, 2);
  lua_len(L, -1);
  printf("len_table=%lld\n", (long long)lua_tointeger(L, -1));

  lua_close(L);
  return 0;
}
