#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

static int cont(lua_State *L, int status, lua_KContext ctx) {
  printf("cont_from_lua status=%d ctx=%lld top=%d arg=%s yieldable=%d\n",
         status, (long long)ctx, lua_gettop(L), lua_tostring(L, 1), lua_isyieldable(L));
  lua_pushstring(L, "c-done");
  lua_pushvalue(L, 1);
  return 2;
}

static int yielding_c(lua_State *L) {
  printf("called_from_lua top=%d arg=%s yieldable=%d\n", lua_gettop(L), lua_tostring(L, 1), lua_isyieldable(L));
  lua_pushstring(L, "c-yield");
  return lua_yieldk(L, 1, 77, cont);
}

int main(void) {
  lua_State *L = luaL_newstate();
  lua_State *T;
  int status;
  int nres = -1;

  lua_pushcfunction(L, yielding_c);
  lua_setglobal(L, "yielding_c");

  T = lua_newthread(L);
  status = luaL_loadstring(T, "return yielding_c('from-lua')");
  printf("load_status=%d top=%d\n", status, lua_gettop(T));

  status = lua_resume(T, L, 0, &nres);
  printf("first_status=%d nres=%d top=%d value=%s status=%d\n",
         status, nres, lua_gettop(T), lua_tostring(T, 1), lua_status(T));

  lua_settop(T, 0);
  lua_pushstring(T, "resume-lua");
  status = lua_resume(T, L, 1, &nres);
  printf("second_status=%d nres=%d top=%d status=%d values=%s,%s\n",
         status, nres, lua_gettop(T), lua_status(T), lua_tostring(T, 1), lua_tostring(T, 2));

  lua_close(L);
  return 0;
}
