#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

int main(void) {
  lua_State *L = luaL_newstate();
  int count = lua_gc(L, LUA_GCCOUNT);
  int bytes = lua_gc(L, LUA_GCCOUNTB);

  printf("count_nonnegative=%d\n", count >= 0);
  printf("bytes_range=%d\n", bytes >= 0 && bytes < 1024);
  printf("isrunning=%d\n", lua_gc(L, LUA_GCISRUNNING));
  printf("stop=%d\n", lua_gc(L, LUA_GCSTOP));
  printf("isrunning_after_stop=%d\n", lua_gc(L, LUA_GCISRUNNING));
  printf("step=%d\n", lua_gc(L, LUA_GCSTEP, (size_t)0));
  printf("restart=%d\n", lua_gc(L, LUA_GCRESTART));
  printf("isrunning_after_restart=%d\n", lua_gc(L, LUA_GCISRUNNING));
  printf("gen_old=%d\n", lua_gc(L, LUA_GCGEN));
  printf("inc_old=%d\n", lua_gc(L, LUA_GCINC));
  printf("gen_old2=%d\n", lua_gc(L, LUA_GCGEN));
  printf("pause_old=%d\n", lua_gc(L, LUA_GCPARAM, LUA_GCPPAUSE, 300));
  printf("pause_new=%d\n", lua_gc(L, LUA_GCPARAM, LUA_GCPPAUSE, -1));
  printf("pause_restore=%d\n", lua_gc(L, LUA_GCPARAM, LUA_GCPPAUSE, 250));
  printf("invalid=%d\n", lua_gc(L, 999));

  lua_gc(L, LUA_GCCOLLECT);
  lua_close(L);
  return 0;
}
