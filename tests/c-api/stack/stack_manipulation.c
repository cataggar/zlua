#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

static void print_stack(lua_State *L, const char *label) {
  int i;
  printf("%s top=%d", label, lua_gettop(L));
  for (i = 1; i <= lua_gettop(L); i++) {
    printf(" %s", lua_typename(L, lua_type(L, i)));
  }
  printf("\n");
}

int main(void) {
  lua_State *L = luaL_newstate();
  int isnum = 0;

  printf("initial top=%d\n", lua_gettop(L));
  printf("checkstack=%d\n", lua_checkstack(L, 10));

  lua_pushnil(L);
  lua_pushboolean(L, 1);
  lua_pushinteger(L, 42);
  print_stack(L, "after_push");
  printf("abs_last=%d\n", lua_absindex(L, -1));
  printf("integer=%lld isnum=%d isinteger=%d\n", (long long)lua_tointegerx(L, -1, &isnum), isnum, lua_isinteger(L, -1));

  lua_pushvalue(L, 2);
  lua_copy(L, 3, 1);
  lua_rotate(L, 2, 1);
  print_stack(L, "after_copy_rotate");
  printf("values=%lld,%d,%lld,%d\n",
      (long long)lua_tointeger(L, 1), lua_toboolean(L, 2),
      (long long)lua_tointeger(L, 3), lua_toboolean(L, 4));

  lua_settop(L, 6);
  print_stack(L, "after_grow");
  lua_settop(L, -3);
  print_stack(L, "after_shrink");

  lua_rotate(L, 2, -1);
  print_stack(L, "after_rotate_left");
  printf("values2=%lld,%d,%lld,%d\n",
      (long long)lua_tointeger(L, 1), lua_toboolean(L, 2),
      (long long)lua_tointeger(L, 3), lua_toboolean(L, 4));

  lua_pop(L, 2);
  print_stack(L, "after_pop");
  lua_settop(L, 0);
  print_stack(L, "after_clear");

  lua_pushstring(L, "main");
  lua_State *T = lua_newthread(L);
  lua_pushstring(L, "thread");
  lua_xmove(L, T, 1);
  printf("xmove main_top=%d thread_top=%d thread_value=%s\n", lua_gettop(L), lua_gettop(T), lua_tostring(T, -1));

  lua_close(L);
  return 0;
}
