#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

static int describe(lua_State *L) {
  lua_pushvalue(L, lua_upvalueindex(1));
  lua_pushvalue(L, 1);
  lua_pushvalue(L, lua_upvalueindex(2));
  return 3;
}

static void call_top(lua_State *L, const char *label) {
  int status;
  lua_pushvalue(L, -1);
  lua_pushinteger(L, 7);
  status = lua_pcall(L, 1, 3, 0);
  printf("%s_status=%d values=%lld,%lld,%s\n", label, status, (long long)lua_tointeger(L, -3), (long long)lua_tointeger(L, -2), lua_tostring(L, -1));
  lua_pop(L, 3);
}

int main(void) {
  lua_State *L = luaL_newstate();
  const char *name;
  void *id_before;
  void *id_after;
  int status;

  lua_pushinteger(L, 10);
  lua_pushstring(L, "tag");
  lua_pushcclosure(L, describe, 2);
  printf("closure_top=%d type=%s isc=%d\n", lua_gettop(L), lua_typename(L, lua_type(L, -1)), lua_iscfunction(L, -1));

  name = lua_getupvalue(L, -1, 1);
  printf("get_c_upvalue name_empty=%d value=%lld top=%d\n", name != NULL && name[0] == '\0', (long long)lua_tointeger(L, -1), lua_gettop(L));
  lua_pop(L, 1);

  id_before = lua_upvalueid(L, -1, 1);
  lua_pushinteger(L, 99);
  name = lua_setupvalue(L, -2, 1);
  id_after = lua_upvalueid(L, -1, 1);
  printf("setup_c_upvalue name_empty=%d same_id=%d\n", name != NULL && name[0] == '\0', id_before == id_after);
  call_top(L, "cclosure");
  lua_settop(L, 0);

  status = luaL_loadstring(L, "local function make(v) local x=v; return function() return x end end; return make(1), make(2)");
  status = (status == LUA_OK) ? lua_pcall(L, 0, 2, 0) : status;
  printf("load_lua_closures=%d top=%d\n", status, lua_gettop(L));
  printf("lua_ids_before=%d\n", lua_upvalueid(L, 1, 1) == lua_upvalueid(L, 2, 1));
  lua_upvaluejoin(L, 1, 1, 2, 1);
  printf("lua_ids_after=%d\n", lua_upvalueid(L, 1, 1) == lua_upvalueid(L, 2, 1));
  lua_pushvalue(L, 1);
  status = lua_pcall(L, 0, 1, 0);
  printf("joined_call=%d value=%lld\n", status, (long long)lua_tointeger(L, -1));

  lua_close(L);
  return 0;
}
