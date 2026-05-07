#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

static int finalize_box(lua_State *L) {
  int *value = (int *)lua_touserdata(L, 1);
  printf("__gc value=%d top=%d\n", *value, lua_gettop(L));
  return 0;
}

int main(void) {
  lua_State *L = luaL_newstate();
  int *value = (int *)lua_newuserdatauv(L, sizeof(int), 0);

  *value = 77;
  lua_newtable(L);
  lua_pushcfunction(L, finalize_box);
  lua_setfield(L, -2, "__gc");
  lua_setmetatable(L, -2);
  lua_pop(L, 1);

  printf("before_gc top=%d\n", lua_gettop(L));
  lua_gc(L, LUA_GCCOLLECT);
  printf("after_gc top=%d\n", lua_gettop(L));
  lua_gc(L, LUA_GCCOLLECT);

  lua_close(L);
  return 0;
}
