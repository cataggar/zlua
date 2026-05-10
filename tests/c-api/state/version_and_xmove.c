#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

int main(void) {
  lua_State *L = luaL_newstate();
  lua_State *T;

  luaL_checkversion(L);
  printf("ident_nonempty=%d version_match=%d null_match=%d\n",
         lua_ident[0] != '\0', lua_version(L) == LUA_VERSION_NUM,
         lua_version(NULL) == lua_version(L));

  T = lua_newthread(L);
  lua_pushstring(L, "main-value");
  lua_pushinteger(L, 55);
  lua_xmove(L, T, 2);
  printf("xmove_to_thread main_top=%d thread_top=%d values=%s,%lld\n",
         lua_gettop(L), lua_gettop(T), lua_tostring(T, 1),
         (long long)lua_tointeger(T, 2));

  lua_pushstring(T, "thread-value");
  lua_xmove(T, L, 1);
  printf("xmove_to_main main_top=%d thread_top=%d value=%s thread_is_top=%d\n",
         lua_gettop(L), lua_gettop(T), lua_tostring(L, -1),
         lua_tothread(L, 1) == T);

  lua_xmove(L, T, 0);
  printf("xmove_zero main_top=%d thread_top=%d\n", lua_gettop(L), lua_gettop(T));

  lua_close(L);
  return 0;
}
