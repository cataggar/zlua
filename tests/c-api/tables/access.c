#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

static void print_top(lua_State *L, const char *label) {
  printf("%s top=%d type=%s\n", label, lua_gettop(L), lua_typename(L, lua_type(L, -1)));
}

int main(void) {
  lua_State *L = luaL_newstate();
  int key;

  lua_createtable(L, 3, 2);
  print_top(L, "created");

  lua_pushinteger(L, 10);
  lua_rawseti(L, -2, 1);
  lua_pushinteger(L, 20);
  lua_rawseti(L, -2, 2);
  lua_pushinteger(L, 30);
  lua_rawseti(L, -2, 3);
  lua_pushstring(L, "field-value");
  lua_setfield(L, -2, "field");
  lua_pushinteger(L, 99);
  lua_rawsetp(L, -2, &key);
  lua_pushstring(L, "via_settable");
  lua_pushinteger(L, 44);
  lua_settable(L, -3);
  lua_pushinteger(L, 40);
  lua_rawseti(L, -2, 4);
  lua_pushinteger(L, 50);
  lua_seti(L, -2, 5);

  printf("len=%llu\n", (unsigned long long)lua_rawlen(L, -1));
  lua_getfield(L, -1, "field");
  printf("field=%s top=%d\n", lua_tostring(L, -1), lua_gettop(L));
  lua_pop(L, 1);

  lua_geti(L, -1, 2);
  printf("geti=%lld top=%d\n", (long long)lua_tointeger(L, -1), lua_gettop(L));
  lua_pop(L, 1);

  lua_rawgetp(L, -1, &key);
  printf("rawgetp=%lld\n", (long long)lua_tointeger(L, -1));
  lua_pop(L, 1);

  lua_pushstring(L, "via_settable");
  lua_rawget(L, -2);
  printf("rawget=%lld\n", (long long)lua_tointeger(L, -1));
  lua_pop(L, 1);

  lua_geti(L, -1, 5);
  printf("seti=%lld\n", (long long)lua_tointeger(L, -1));
  lua_pop(L, 1);

  lua_pushinteger(L, 2);
  lua_gettable(L, -2);
  printf("gettable=%lld top=%d\n", (long long)lua_tointeger(L, -1), lua_gettop(L));
  lua_pop(L, 1);

  lua_newtable(L);
  lua_pushinteger(L, 11);
  lua_rawseti(L, -2, 1);
  lua_pushinteger(L, 22);
  lua_rawseti(L, -2, 2);
  lua_pushnil(L);
  while (lua_next(L, -2) != 0) {
    printf("next=%lld:%lld\n", (long long)lua_tointeger(L, -2), (long long)lua_tointeger(L, -1));
    lua_pop(L, 1);
  }
  printf("after_next top=%d\n", lua_gettop(L));
  lua_pop(L, 1);

  lua_pushvalue(L, -1);
  lua_setglobal(L, "stored");
  lua_getglobal(L, "stored");
  printf("global_type=%s equal=%d\n", lua_typename(L, lua_type(L, -1)), lua_rawequal(L, -1, -2));

  lua_close(L);
  return 0;
}
