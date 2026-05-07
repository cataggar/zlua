#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

static int close_box(lua_State *L) {
  int *value = (int *)lua_touserdata(L, 1);
  printf("__close value=%d err=%s top=%d\n", *value, lua_typename(L, lua_type(L, 2)), lua_gettop(L));
  return 0;
}

static void push_closable(lua_State *L, int value) {
  int *slot = (int *)lua_newuserdatauv(L, sizeof(int), 0);
  *slot = value;
  lua_newtable(L);
  lua_pushcfunction(L, close_box);
  lua_setfield(L, -2, "__close");
  lua_setmetatable(L, -2);
}

int main(void) {
  lua_State *L = luaL_newstate();

  push_closable(L, 12);
  lua_toclose(L, -1);
  printf("before_closeslot top=%d\n", lua_gettop(L));
  lua_closeslot(L, -1);
  printf("after_closeslot top=%d type=%s\n", lua_gettop(L), lua_typename(L, lua_type(L, -1)));
  lua_pop(L, 1);

  push_closable(L, 34);
  lua_toclose(L, -1);
  printf("before_pop top=%d\n", lua_gettop(L));
  lua_pop(L, 1);
  printf("after_pop top=%d\n", lua_gettop(L));

  lua_close(L);
  return 0;
}
