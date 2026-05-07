#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

static void print_type(lua_State *L, int idx) {
  printf("%s\n", lua_typename(L, lua_type(L, idx)));
}

int main(void) {
  lua_State *L = luaL_newstate();
  void *ud = NULL;
  lua_Alloc allocf;

  printf("version=%.0f\n", (double)lua_version(L));
  allocf = lua_getallocf(L, &ud);
  luaL_checkversion(L);
  printf("allocf=%d ud=%d\n", allocf != NULL, ud == NULL);

  lua_rawgeti(L, LUA_REGISTRYINDEX, LUA_RIDX_GLOBALS);
  printf("globals=");
  print_type(L, -1);
  lua_pop(L, 1);

  lua_rawgeti(L, LUA_REGISTRYINDEX, LUA_RIDX_MAINTHREAD);
  printf("mainthread=");
  print_type(L, -1);
  printf("tothread=%d\n", lua_tothread(L, -1) != NULL);
  lua_pop(L, 1);

  lua_rawgeti(L, LUA_REGISTRYINDEX, 1);
  printf("reserved=");
  print_type(L, -1);
  lua_pop(L, 1);

  lua_pushglobaltable(L);
  printf("pushglobal=");
  print_type(L, -1);
  lua_pop(L, 1);

  printf("pushthread_main=%d\n", lua_pushthread(L));
  printf("pushthread_type=");
  print_type(L, -1);

  lua_close(L);
  return 0;
}
