#include <stdio.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"

static int meta_label(lua_State *L) {
  lua_getfield(L, 1, "label");
  lua_pushfstring(L, "meta:%s", lua_tostring(L, -1));
  return 1;
}

int main(void) {
  lua_State *L = luaL_newstate();
  size_t len = 0;
  int called;
  int type;
  const char *text;

  lua_newtable(L);
  lua_pushstring(L, "target");
  lua_setfield(L, -2, "label");
  lua_newtable(L);
  lua_pushstring(L, "fixture-object");
  lua_setfield(L, -2, "__name");
  lua_pushcfunction(L, meta_label);
  lua_setfield(L, -2, "__tostring");
  lua_pushcfunction(L, meta_label);
  lua_setfield(L, -2, "describe");
  lua_setmetatable(L, -2);

  type = luaL_getmetafield(L, 1, "__name");
  printf("metafield_name type=%s value=%s top=%d\n",
         lua_typename(L, type), lua_tostring(L, -1), lua_gettop(L));
  lua_pop(L, 1);

  type = luaL_getmetafield(L, 1, "missing");
  printf("metafield_missing type=%s top=%d\n", lua_typename(L, type), lua_gettop(L));

  called = luaL_callmeta(L, 1, "describe");
  printf("callmeta_hit=%d value=%s top=%d\n", called, lua_tostring(L, -1), lua_gettop(L));
  lua_pop(L, 1);

  called = luaL_callmeta(L, 1, "missing");
  printf("callmeta_miss=%d top=%d\n", called, lua_gettop(L));

  text = luaL_tolstring(L, 1, &len);
  printf("tolstring_meta=%s len=%zu top=%d\n", text, len, lua_gettop(L));
  lua_pop(L, 1);

  lua_pushboolean(L, 1);
  text = luaL_tolstring(L, -1, &len);
  printf("tolstring_bool=%s len=%zu top=%d\n", text, len, lua_gettop(L));
  lua_pop(L, 2);

  luaL_traceback(L, L, "trace-msg", 0);
  text = lua_tostring(L, -1);
  printf("traceback_msg=%d traceback_label=%d top=%d\n",
         strstr(text, "trace-msg") == text,
         strstr(text, "stack traceback:") != NULL, lua_gettop(L));
  lua_pop(L, 1);

  luaL_traceback(L, L, NULL, 0);
  text = lua_tostring(L, -1);
  printf("traceback_nomsg=%d top=%d\n", strstr(text, "stack traceback:") == text, lua_gettop(L));

  lua_close(L);
  return 0;
}
