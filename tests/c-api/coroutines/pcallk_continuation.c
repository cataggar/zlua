#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

static int pcall_cont(lua_State *L, int status, lua_KContext ctx) {
  printf("pcall_cont status=%d ctx=%lld top=%d arg=%s yieldable=%d\n",
         status, (long long)ctx, lua_gettop(L), lua_tostring(L, 1), lua_isyieldable(L));
  lua_pushstring(L, "pcallk-done");
  lua_pushvalue(L, 1);
  return 2;
}

static int inner(lua_State *L) {
  lua_pushstring(L, "pcallk-yield");
  return lua_yield(L, 1);
}

static int outer(lua_State *L) {
  lua_pushcfunction(L, inner);
  return lua_pcallk(L, 0, 1, 0, 456, pcall_cont);
}

int main(void) {
  lua_State *L = luaL_newstate();
  lua_State *T = lua_newthread(L);
  int status;
  int nres = -1;

  lua_pushcfunction(T, outer);
  status = lua_resume(T, L, 0, &nres);
  printf("first_status=%d nres=%d top=%d value=%s status=%d\n",
         status, nres, lua_gettop(T), lua_tostring(T, 1), lua_status(T));

  lua_settop(T, 0);
  lua_pushstring(T, "resume-pcallk");
  status = lua_resume(T, L, 1, &nres);
  printf("second_status=%d nres=%d top=%d status=%d values=%s,%s\n",
         status, nres, lua_gettop(T), lua_status(T), lua_tostring(T, 1), lua_tostring(T, 2));

  lua_close(L);
  return 0;
}
