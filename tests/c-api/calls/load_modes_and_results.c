#include <stdio.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"

typedef struct DumpBuffer {
  char data[1024];
  size_t len;
} DumpBuffer;

static int writer(lua_State *L, const void *p, size_t sz, void *ud) {
  DumpBuffer *buffer = (DumpBuffer *)ud;
  (void)L;
  if (sz == 0) return 0;
  if (buffer->len + sz > sizeof(buffer->data)) return 1;
  memcpy(buffer->data + buffer->len, p, sz);
  buffer->len += sz;
  return 0;
}

static int failer(lua_State *L) {
  return luaL_error(L, "c failure %d", 17);
}

static int handler(lua_State *L) {
  lua_pushfstring(L, "handled:%s", lua_tostring(L, 1));
  return 1;
}

int main(void) {
  lua_State *L = luaL_newstate();
  DumpBuffer buffer = {{0}, 0};
  int status;
  int msgh;

  status = luaL_loadbufferx(L, "return 1", strlen("return 1"), "=text-as-binary", "b");
  printf("text_as_binary status=%d type=%s top=%d\n", status, lua_typename(L, lua_type(L, -1)), lua_gettop(L));
  lua_settop(L, 0);

  status = luaL_loadstring(L, "return 99");
  printf("dump_load status=%d type=%s\n", status, lua_typename(L, lua_type(L, -1)));
  printf("dump_status=%d\n", lua_dump(L, writer, &buffer, 0));
  lua_pop(L, 1);

  status = luaL_loadbufferx(L, buffer.data, buffer.len, "=binary-as-text", "t");
  printf("binary_as_text status=%d type=%s top=%d\n", status, lua_typename(L, lua_type(L, -1)), lua_gettop(L));
  lua_settop(L, 0);

  status = luaL_loadbufferx(L, buffer.data, buffer.len, "=binary-default", NULL);
  printf("binary_default_load status=%d type=%s top=%d\n", status, lua_typename(L, lua_type(L, -1)), lua_gettop(L));
  status = lua_pcall(L, 0, 1, 0);
  printf("binary_default_call status=%d value=%lld top=%d\n", status, (long long)lua_tointeger(L, -1), lua_gettop(L));
  lua_settop(L, 0);

  status = luaL_loadstring(L, "return 'only-one'");
  status = (status == LUA_OK) ? lua_pcall(L, 0, 3, 0) : status;
  printf("pcall_padding status=%d top=%d values=%s,%s,%s\n", status, lua_gettop(L),
         lua_tostring(L, 1), lua_typename(L, lua_type(L, 2)), lua_typename(L, lua_type(L, 3)));
  lua_settop(L, 0);

  lua_pushcfunction(L, handler);
  msgh = lua_gettop(L);
  lua_pushcfunction(L, failer);
  status = lua_pcall(L, 0, 1, msgh);
  printf("c_error_handler status=%d top=%d msg_prefix=%.8s\n", status, lua_gettop(L), lua_tostring(L, -1));
  lua_settop(L, 0);

  lua_close(L);
  return 0;
}
