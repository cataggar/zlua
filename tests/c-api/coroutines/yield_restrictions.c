#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

static int yield_now(lua_State *L) {
  return lua_yield(L, 0);
}

static int protected_inner(lua_State *L) {
  int status;
  lua_pushcfunction(L, yield_now);
  status = lua_pcall(L, 0, 0, 0);
  printf("inner_pcall_status=%d msg=%.32s\n", status, lua_tostring(L, -1));
  lua_pop(L, 1);
  lua_pushstring(L, "outer-ok");
  return 1;
}

int main(void) {
  lua_State *L = luaL_newstate();
  lua_State *T;
  int status;
  int nres = -1;

  lua_pushcfunction(L, yield_now);
  status = lua_pcall(L, 0, 0, 0);
  printf("main_pcall_status=%d msg=%.32s\n", status, lua_tostring(L, -1));
  lua_pop(L, 1);

  T = lua_newthread(L);
  lua_pushcfunction(T, protected_inner);
  status = lua_resume(T, L, 0, &nres);
  printf("resume_status=%d nres=%d top=%d value=%s\n", status, nres, lua_gettop(T), lua_tostring(T, 1));

  lua_close(L);
  return 0;
}
