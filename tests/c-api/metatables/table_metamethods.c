#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

int main(void) {
  lua_State *L = luaL_newstate();

  lua_newtable(L);          /* target */
  lua_newtable(L);          /* metatable */
  lua_newtable(L);          /* __index table */
  lua_pushstring(L, "fallback");
  lua_setfield(L, -2, "missing");
  lua_setfield(L, -2, "__index");

  lua_newtable(L);          /* __newindex table */
  lua_pushvalue(L, -1);
  lua_setglobal(L, "newindex_target");
  lua_setfield(L, -2, "__newindex");
  lua_setmetatable(L, -2);

  printf("has_metatable=%d top=%d\n", lua_getmetatable(L, 1), lua_gettop(L));
  lua_pop(L, 1);

  lua_getfield(L, 1, "missing");
  printf("index=%s top=%d\n", lua_tostring(L, -1), lua_gettop(L));
  lua_pop(L, 1);

  printf("metafield_type=%s top=%d\n", lua_typename(L, luaL_getmetafield(L, 1, "__index")), lua_gettop(L));
  lua_pop(L, 1);

  lua_newtable(L);
  lua_pushstring(L, "namedtable");
  lua_setfield(L, -2, "__name");
  lua_setmetatable(L, 1);
  luaL_tolstring(L, 1, NULL);
  printf("tolstring_prefix=%.10s top=%d\n", lua_tostring(L, -1), lua_gettop(L));
  lua_pop(L, 1);

  lua_pushstring(L, "written");
  lua_setfield(L, 1, "targeted");
  lua_getglobal(L, "newindex_target");
  lua_getfield(L, -1, "targeted");
  printf("newindex=%s\n", lua_tostring(L, -1));
  lua_pop(L, 2);

  lua_getfield(L, 1, "targeted");
  printf("target_raw=%s\n", lua_typename(L, lua_type(L, -1)));
  lua_pop(L, 1);

  lua_pushstring(L, "direct");
  lua_rawseti(L, 1, 1);
  lua_geti(L, 1, 1);
  printf("raw_bypass=%s len=%llu\n", lua_tostring(L, -1), (unsigned long long)lua_rawlen(L, 1));

  lua_close(L);
  return 0;
}
