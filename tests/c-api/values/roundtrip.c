#include <stdio.h>
#include <string.h>
#include <stdarg.h>

#include "lua.h"
#include "lauxlib.h"

static void print_type(lua_State *L, int idx) {
  printf("%s", lua_typename(L, lua_type(L, idx)));
}

static const char *push_vformat(lua_State *L, const char *fmt, ...) {
  const char *result;
  va_list args;
  va_start(args, fmt);
  result = lua_pushvfstring(L, fmt, args);
  va_end(args);
  return result;
}

int main(void) {
  lua_State *L = luaL_newstate();
  int isnum = 0;
  size_t len = 0;
  int marker = 123;
  const char embedded[] = {'a', '\0', 'b'};

  lua_pushnil(L);
  lua_pushboolean(L, 1);
  lua_pushinteger(L, 42);
  lua_pushnumber(L, 3.5);
  lua_pushlstring(L, embedded, sizeof(embedded));
  lua_pushstring(L, "17");
  lua_pushlightuserdata(L, &marker);

  printf("top=%d\n", lua_gettop(L));
  printf("types=");
  for (int i = 1; i <= lua_gettop(L); i++) {
    if (i > 1) printf(",");
    print_type(L, i);
  }
  printf("\n");

  printf("integer=%lld number=%.1f stringnum=%.1f isnum=%d\n",
      (long long)lua_tointeger(L, 3), lua_tonumber(L, 4),
      lua_tonumberx(L, 6, &isnum), isnum);
  printf("isnumber=%d,%d,%d\n", lua_isnumber(L, 3), lua_isnumber(L, 6), lua_isnumber(L, 7));

  const char *s = lua_tolstring(L, 5, &len);
  printf("embedded_len=%zu bytes=%d,%d,%d rawlen=%llu\n",
      len, (unsigned char)s[0], (unsigned char)s[1], (unsigned char)s[2],
      (unsigned long long)lua_rawlen(L, 5));

  s = lua_tolstring(L, 3, &len);
  printf("number_to_string=%s len=%zu type=", s, len);
  print_type(L, 3);
  printf("\n");

  printf("userdata=%d isuserdata=%d topointer=%d\n",
      lua_touserdata(L, 7) == &marker, lua_isuserdata(L, 7),
      lua_topointer(L, 7) == &marker);

  lua_settop(L, 0);
  lua_pushstring(L, NULL);
  printf("push_null=");
  print_type(L, -1);
  printf("\n");

  lua_pushfstring(L, "%s:%d:%I:%U:%s", "fmt", 5, (lua_Integer)1234567890123LL, (unsigned long)0x24, NULL);
  printf("fstring=%s\n", lua_tostring(L, -1));

  push_vformat(L, "%s:%d", "vfmt", 6);
  printf("vfstring=%s\n", lua_tostring(L, -1));

  lua_close(L);
  return 0;
}
