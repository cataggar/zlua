#include <stdio.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"

static int answer(lua_State *L) {
  lua_pushinteger(L, 42);
  return 1;
}

static int open_mod(lua_State *L) {
  lua_newtable(L);
  lua_pushstring(L, lua_tostring(L, 1));
  lua_setfield(L, -2, "name");
  lua_pushcfunction(L, answer);
  lua_setfield(L, -2, "answer");
  return 1;
}

static const luaL_Reg funcs[] = {
  {"answer", answer},
  {"flag", NULL},
  {NULL, NULL}
};

int main(void) {
  lua_State *L = luaL_newstate();
  luaL_Buffer b;
  char *slot;
  int existed;

  luaL_buffinit(L, &b);
  luaL_addstring(&b, "hello");
  luaL_addchar(&b, ' ');
  lua_pushstring(L, "world");
  luaL_addvalue(&b);
  slot = luaL_prepbuffsize(&b, 3);
  memcpy(slot, "!!!", 3);
  luaL_addsize(&b, 3);
  luaL_pushresult(&b);
  printf("buffer=%s top=%d\n", lua_tostring(L, -1), lua_gettop(L));
  lua_pop(L, 1);

  printf("gsub=%s\n", luaL_gsub(L, "a-b-a", "a", "xy"));
  lua_pop(L, 1);

  lua_newtable(L);
  luaL_setfuncs(L, funcs, 0);
  lua_getfield(L, -1, "answer");
  lua_call(L, 0, 1);
  lua_getfield(L, -2, "flag");
  printf("setfuncs answer=%lld flag=%s\n", (long long)lua_tointeger(L, -2), lua_typename(L, lua_type(L, -1)));
  lua_pop(L, 3);

  existed = luaL_getsubtable(L, LUA_REGISTRYINDEX, "subtable-fixture");
  printf("subtable_first=%d type=%s\n", existed, lua_typename(L, lua_type(L, -1)));
  lua_pop(L, 1);
  existed = luaL_getsubtable(L, LUA_REGISTRYINDEX, "subtable-fixture");
  printf("subtable_second=%d type=%s\n", existed, lua_typename(L, lua_type(L, -1)));
  lua_pop(L, 1);

  luaL_requiref(L, "fixture.mod", open_mod, 1);
  lua_getfield(L, -1, "name");
  lua_getglobal(L, "fixture.mod");
  printf("require name=%s same=%d top=%d\n", lua_tostring(L, -2), lua_rawequal(L, -3, -1), lua_gettop(L));

  lua_close(L);
  return 0;
}
