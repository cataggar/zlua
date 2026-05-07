#include <stdio.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"

typedef struct DumpBuffer {
  char data[512];
  size_t len;
  int calls;
} DumpBuffer;

static int writer(lua_State *L, const void *p, size_t sz, void *ud) {
  DumpBuffer *buffer = (DumpBuffer *)ud;
  (void)L;
  if (sz == 0) return 0;
  if (buffer->len + sz > sizeof(buffer->data)) return 1;
  memcpy(buffer->data + buffer->len, p, sz);
  buffer->len += sz;
  buffer->calls++;
  return 0;
}

int main(void) {
  lua_State *L = luaL_newstate();
  DumpBuffer buffer = {{0}, 0, 0};
  char number[LUA_N2SBUFFSZ];
  int status;
  unsigned len;
  size_t consumed;

  status = luaL_loadstring(L, "return 41 + 1");
  printf("load_status=%d type=%s top=%d\n", status, lua_typename(L, lua_type(L, -1)), lua_gettop(L));
  status = lua_dump(L, writer, &buffer, 0);
  printf("dump_status=%d calls_positive=%d size_positive=%d top=%d sig=%d\n", status, buffer.calls > 0, buffer.len > 0, lua_gettop(L), buffer.data[0] == LUA_SIGNATURE[0]);

  status = luaL_loadbufferx(L, buffer.data, buffer.len, "=dumped", "b");
  printf("reload_status=%d type=%s top=%d\n", status, lua_typename(L, lua_type(L, -1)), lua_gettop(L));
  status = lua_pcall(L, 0, 1, 0);
  printf("reload_call=%d value=%lld\n", status, (long long)lua_tointeger(L, -1));
  lua_settop(L, 0);

  lua_pushinteger(L, -123);
  len = lua_numbertocstring(L, -1, number);
  printf("int_string=%s len=%u\n", number, len);
  lua_pushnumber(L, 12.0);
  len = lua_numbertocstring(L, -1, number);
  printf("num_string=%s len=%u\n", number, len);
  lua_pushstring(L, "not-number");
  printf("non_number_len=%u\n", lua_numbertocstring(L, -1, number));
  lua_settop(L, 0);

  consumed = lua_stringtonumber(L, "  42 ");
  printf("stringtonumber_int consumed=%zu type=%s value=%lld top=%d\n", consumed, lua_typename(L, lua_type(L, -1)), (long long)lua_tointeger(L, -1), lua_gettop(L));
  consumed = lua_stringtonumber(L, "3.5");
  printf("stringtonumber_num consumed=%zu value=%.1f top=%d\n", consumed, lua_tonumber(L, -1), lua_gettop(L));
  consumed = lua_stringtonumber(L, "  0x10 ");
  printf("stringtonumber_hexint consumed=%zu type=%s value=%lld top=%d\n", consumed, lua_typename(L, lua_type(L, -1)), (long long)lua_tointeger(L, -1), lua_gettop(L));
  consumed = lua_stringtonumber(L, "0x1.8p1");
  printf("stringtonumber_hexnum consumed=%zu value=%.1f top=%d\n", consumed, lua_tonumber(L, -1), lua_gettop(L));
  consumed = lua_stringtonumber(L, "12x");
  printf("stringtonumber_bad consumed=%zu top=%d\n", consumed, lua_gettop(L));
  consumed = lua_stringtonumber(L, "nan");
  printf("stringtonumber_nan consumed=%zu top=%d\n", consumed, lua_gettop(L));

  lua_close(L);
  return 0;
}
