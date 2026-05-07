#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"

struct ReaderData {
  const char *chunks[3];
  int index;
};

static const char *reader(lua_State *L, void *ud, size_t *size) {
  (void)L;
  struct ReaderData *data = (struct ReaderData *)ud;
  const char *chunk = data->chunks[data->index++];
  if (chunk == NULL) {
    *size = 0;
    return NULL;
  }
  *size = strlen(chunk);
  return chunk;
}

static int handler(lua_State *L) {
  lua_pushfstring(L, "handled:%s", lua_tostring(L, 1));
  return 1;
}

int main(void) {
  lua_State *L = luaL_newstate();
  int status;

  status = luaL_loadstring(L, "return 12, 'ok'");
  printf("loadstring_status=%d type=%s top=%d\n", status, lua_typename(L, lua_type(L, -1)), lua_gettop(L));
  status = lua_pcall(L, 0, LUA_MULTRET, 0);
  printf("pcall_status=%d top=%d a=%lld b=%s\n", status, lua_gettop(L), (long long)lua_tointeger(L, 1), lua_tostring(L, 2));
  lua_settop(L, 0);

  status = luaL_loadbufferx(L, "return ...", strlen("return ..."), "=buffer", "t");
  printf("buffer_status=%d\n", status);
  lua_pushinteger(L, 7);
  lua_pushstring(L, "arg");
  status = lua_pcall(L, 2, LUA_MULTRET, 0);
  printf("args_status=%d top=%d first=%lld second=%s\n", status, lua_gettop(L), (long long)lua_tointeger(L, 1), lua_tostring(L, 2));
  lua_settop(L, 0);

  struct ReaderData data = {{"return ", "3 + 4", NULL}, 0};
  status = lua_load(L, reader, &data, "=reader", "t");
  printf("reader_status=%d type=%s\n", status, lua_typename(L, lua_type(L, -1)));
  status = lua_pcall(L, 0, 1, 0);
  printf("reader_call=%d value=%lld\n", status, (long long)lua_tointeger(L, -1));
  lua_settop(L, 0);

  lua_pushcfunction(L, handler);
  int msgh = lua_gettop(L);
  status = luaL_loadstring(L, "return missing_global + 1");
  printf("runtime_load_status=%d\n", status);
  status = lua_pcall(L, 0, 1, msgh);
  printf("runtime_error_status=%d top=%d msg_prefix=%.8s\n", status, lua_gettop(L), lua_tostring(L, -1));
  lua_settop(L, 0);

  status = luaL_loadstring(L, "return ");
  printf("syntax_status=%d type=%s top=%d\n", status, lua_typename(L, lua_type(L, -1)), lua_gettop(L));
  lua_settop(L, 0);

  const char *path = ".zig-cache/c-api-loadfile-fixture.lua";
  FILE *file = fopen(path, "wb");
  fputs("return 'file', 55", file);
  fclose(file);
  status = luaL_loadfilex(L, path, "t");
  printf("file_status=%d type=%s\n", status, lua_typename(L, lua_type(L, -1)));
  status = lua_pcall(L, 0, LUA_MULTRET, 0);
  printf("file_call=%d top=%d first=%s second=%lld\n", status, lua_gettop(L), lua_tostring(L, 1), (long long)lua_tointeger(L, 2));
  remove(path);

  lua_close(L);
  return 0;
}
