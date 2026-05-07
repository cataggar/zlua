#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

static int cont(lua_State *L, int status, lua_KContext ctx) {
  printf("cont_status=%d ctx=%lld top=%d arg=%s yieldable=%d\n",
         status, (long long)ctx, lua_gettop(L), lua_tostring(L, 1), lua_isyieldable(L));
  lua_pushstring(L, "continued");
  lua_pushvalue(L, 1);
  return 2;
}

static int yielder(lua_State *L) {
  printf("start_top=%d yieldable=%d\n", lua_gettop(L), lua_isyieldable(L));
  lua_pushstring(L, "yielded");
  return lua_yieldk(L, 1, 123, cont);
}

int main(void) {
  lua_State *L = luaL_newstate();
  lua_State *T = lua_newthread(L);
  int nres = -1;
  int status;

  lua_pushcfunction(T, yielder);
  status = lua_resume(T, L, 0, &nres);
  printf("first_status=%d nres=%d top=%d status=%d value=%s\n",
         status, nres, lua_gettop(T), lua_status(T), lua_tostring(T, 1));

  lua_settop(T, 0);
  lua_pushstring(T, "resume-arg");
  status = lua_resume(T, L, 1, &nres);
  printf("second_status=%d nres=%d top=%d status=%d values=%s,%s\n",
         status, nres, lua_gettop(T), lua_status(T), lua_tostring(T, 1), lua_tostring(T, 2));

  lua_close(L);
  return 0;
}
