#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

static int inspect(lua_State *L) {
  lua_Debug ar;
  const char *name;

  printf("self_stack=%d\n", lua_getstack(L, 0, &ar));
  lua_getinfo(L, "nSltur", &ar);
  printf("self event=%d what=%s line=%d src=%s nups=%u nparams=%u vararg=%d extra=%u tail=%d trans=%d/%d\n",
         ar.event, ar.what, ar.currentline, ar.short_src, (unsigned)ar.nups,
         (unsigned)ar.nparams, ar.isvararg, (unsigned)ar.extraargs,
         ar.istailcall, ar.ftransfer, ar.ntransfer);

  printf("caller_stack=%d\n", lua_getstack(L, 1, &ar));
  lua_getinfo(L, "nSltur", &ar);
  printf("caller what=%s line=%d src=%s nups=%u nparams=%u vararg=%d extra=%u tail=%d trans=%d/%d\n",
         ar.what, ar.currentline, ar.short_src, (unsigned)ar.nups,
         (unsigned)ar.nparams, ar.isvararg, (unsigned)ar.extraargs,
         ar.istailcall, ar.ftransfer, ar.ntransfer);

  name = lua_getlocal(L, &ar, 1);
  printf("local1=%s value=%lld\n", name ? name : "NULL", (long long)lua_tointeger(L, -1));
  lua_pop(L, 1);
  lua_pushinteger(L, 99);
  name = lua_setlocal(L, &ar, 1);
  printf("setlocal=%s\n", name ? name : "NULL");
  return 0;
}

int main(void) {
  lua_State *L = luaL_newstate();
  lua_Debug ar;
  int status;

  lua_pushcfunction(L, inspect);
  lua_setglobal(L, "inspect");

  status = luaL_loadbufferx(L,
      "local function target(a, ...)\n"
      "  local x = a + 1\n"
      "  inspect()\n"
      "  return x\n"
      "end\n"
      "return target(10, 20, 30)\n",
      111, "=dbg-info", "t");
  printf("load=%d\n", status);
  status = lua_pcall(L, 0, 1, 0);
  printf("call=%d top=%d result=%lld\n", status, lua_gettop(L), (long long)lua_tointeger(L, -1));
  lua_settop(L, 0);

  status = luaL_loadstring(L, "local function f(a,b) local z = a + b return z end return f");
  status = (status == LUA_OK) ? lua_pcall(L, 0, 1, 0) : status;
  printf("function_load=%d\n", status);
  lua_getinfo(L, ">Su", &ar);
  printf("function_info what=%s src=%s nparams=%u vararg=%d top=%d\n",
         ar.what, ar.short_src, (unsigned)ar.nparams, ar.isvararg, lua_gettop(L));
  lua_close(L);
  return 0;
}
