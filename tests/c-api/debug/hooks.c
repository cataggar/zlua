#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

static int hook_events = 0;
static int count_events = 0;

static void hook(lua_State *L, lua_Debug *ar) {
  lua_getinfo(L, "Slr", ar);
  if (ar->event == LUA_HOOKCOUNT) {
    count_events++;
  } else if (hook_events < 8) {
    printf("hook event=%d line=%d what=%s transfer=%d/%d\n",
           ar->event, ar->currentline, ar->what, ar->ftransfer, ar->ntransfer);
    hook_events++;
  }
}

static int cadd(lua_State *L) {
  lua_pushinteger(L, lua_tointeger(L, 1) + lua_tointeger(L, 2));
  return 1;
}

int main(void) {
  lua_State *L = luaL_newstate();
  int status;

  lua_pushcfunction(L, cadd);
  lua_setglobal(L, "cadd");

  lua_sethook(L, hook, LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE | LUA_MASKCOUNT, 2);
  printf("hook_set=%d mask=%d count=%d\n", lua_gethook(L) == hook, lua_gethookmask(L), lua_gethookcount(L));
  status = luaL_loadbufferx(L,
      "local x = 0\n"
      "for i = 1, 3 do\n"
      "  x = x + cadd(i, 1)\n"
      "end\n"
      "return x\n",
      66, "=dbg-hooks", "t");
  printf("load=%d\n", status);
  status = lua_pcall(L, 0, 1, 0);
  printf("call=%d result=%lld count_events=%d\n", status, (long long)lua_tointeger(L, -1), count_events > 0);
  lua_sethook(L, NULL, 0, 0);
  printf("hook_clear=%d mask=%d count=%d\n", lua_gethook(L) == NULL, lua_gethookmask(L), lua_gethookcount(L));

  lua_close(L);
  return 0;
}
