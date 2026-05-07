#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

static int entry(lua_State *L) {
  printf("entry_yieldable=%d top=%d\n", lua_isyieldable(L), lua_gettop(L));
  lua_pushinteger(L, lua_tointeger(L, 1) * 2);
  lua_pushstring(L, "done");
  return 2;
}

int main(void) {
  lua_State *L = luaL_newstate();
  lua_State *T = lua_newthread(L);
  int nres = -1;
  int status;

  printf("main_top=%d thread_type=%s tothread=%d status=%d yieldable_outside=%d\n",
         lua_gettop(L), lua_typename(L, lua_type(L, -1)), lua_tothread(L, -1) == T,
         lua_status(T), lua_isyieldable(T));

  lua_pushcfunction(T, entry);
  lua_pushinteger(T, 21);
  status = lua_resume(T, L, 1, &nres);
  printf("resume_status=%d nres=%d top=%d status=%d values=%lld,%s\n",
         status, nres, lua_gettop(T), lua_status(T), (long long)lua_tointeger(T, 1), lua_tostring(T, 2));

  status = lua_closethread(T, L);
  printf("close_status=%d top=%d status=%d\n", status, lua_gettop(T), lua_status(T));

  lua_close(L);
  return 0;
}
