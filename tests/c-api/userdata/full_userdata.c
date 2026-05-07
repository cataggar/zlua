#include <stdio.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"

typedef struct Box {
  int value;
  char label[8];
} Box;

int main(void) {
  lua_State *L = luaL_newstate();
  Box *box = (Box *)lua_newuserdatauv(L, sizeof(Box), 2);
  int created;
  int created_again;
  void *checked;

  box->value = 42;
  strcpy(box->label, "box");

  printf("new top=%d type=%s isud=%d rawlen=%llu sameptr=%d\n",
      lua_gettop(L), lua_typename(L, lua_type(L, -1)), lua_isuserdata(L, -1),
      (unsigned long long)lua_rawlen(L, -1), lua_touserdata(L, -1) == box);

  lua_pushstring(L, "first");
  printf("setuv1=%d\n", lua_setiuservalue(L, -2, 1));
  lua_pushinteger(L, 99);
  printf("setuv2=%d\n", lua_setiuservalue(L, -2, 2));
  lua_pushboolean(L, 1);
  printf("setuv3=%d\n", lua_setiuservalue(L, -2, 3));

  printf("getuv1_type=%s ret=%d ", lua_typename(L, lua_getiuservalue(L, 1, 1)), lua_type(L, -1));
  printf("value=%s\n", lua_tostring(L, -1));
  lua_pop(L, 1);
  printf("getuv2_type=%s value=%lld\n", lua_typename(L, lua_getiuservalue(L, 1, 2)), (long long)lua_tointeger(L, -1));
  lua_pop(L, 1);
  printf("getuv3_type=%s top=%d\n", lua_typename(L, lua_getiuservalue(L, 1, 3)), lua_gettop(L));
  lua_pop(L, 1);

  created = luaL_newmetatable(L, "BoxMT");
  printf("newmt=%d top=%d\n", created, lua_gettop(L));
  lua_getfield(L, -1, "__name");
  printf("mt_name=%s\n", lua_tostring(L, -1));
  lua_pop(L, 1);

  created_again = luaL_newmetatable(L, "BoxMT");
  printf("newmt_again=%d equal=%d top=%d\n", created_again, lua_rawequal(L, -1, -2), lua_gettop(L));
  lua_pop(L, 2);
  luaL_setmetatable(L, "BoxMT");

  checked = luaL_testudata(L, 1, "BoxMT");
  printf("testudata=%d checkudata=%d label=%s value=%d\n",
      checked == box, luaL_checkudata(L, 1, "BoxMT") == box, box->label, box->value);
  printf("wrongmt=%d light_isud=%d\n", luaL_testudata(L, 1, "OtherMT") == NULL, lua_isuserdata(L, 99));

  lua_close(L);
  return 0;
}
