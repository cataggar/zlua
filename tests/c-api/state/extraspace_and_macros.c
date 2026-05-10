#include <stdio.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

static char version_release_is_zero[(LUA_VERSION_RELEASE_N == 0) ? 1 : -1];
static char numtypes_is_nine[(LUA_NUMTYPES == 9) ? 1 : -1];
static char registry_last_is_mainthread[(LUA_RIDX_LAST == LUA_RIDX_MAINTHREAD) ? 1 : -1];
static char upvalueindex_below_registry[(lua_upvalueindex(1) == LUA_REGISTRYINDEX - 1) ? 1 : -1];
static char hook_mask_call_matches[(LUA_MASKCALL == (1 << LUA_HOOKCALL)) ? 1 : -1];
static char hook_mask_count_matches[(LUA_MASKCOUNT == (1 << LUA_HOOKCOUNT)) ? 1 : -1];
static char gc_param_count_matches[(LUA_GCPN == 6) ? 1 : -1];
static char coroutine_mask_after_package[(LUA_COLIBK == (LUA_LOADLIBK << 1)) ? 1 : -1];
static char utf8_mask_after_table[(LUA_UTF8LIBK == (LUA_TABLIBK << 1)) ? 1 : -1];

int main(void) {
  lua_State *L = luaL_newstate();
  lua_State *T;
  unsigned char *main_extra = (unsigned char *)lua_getextraspace(L);
  unsigned char *thread_extra;
  size_t i;
  int initially_zero = 1;
  int copied = 1;

  for (i = 0; i < LUA_EXTRASPACE; i++) {
    if (main_extra[i] != 0) initially_zero = 0;
    main_extra[i] = (unsigned char)(0x30 + i);
  }

  T = lua_newthread(L);
  thread_extra = (unsigned char *)lua_getextraspace(T);
  for (i = 0; i < LUA_EXTRASPACE; i++) {
    if (thread_extra[i] != (unsigned char)(0x30 + i)) copied = 0;
  }

  thread_extra[0] = 0x7f;
  printf("extraspace size_positive=%d initially_zero=%d copied=%d distinct=%d parent_unchanged=%d\n",
         LUA_EXTRASPACE > 0, initially_zero, copied, main_extra != thread_extra,
         main_extra[0] == 0x30);

  lua_rawgeti(L, LUA_REGISTRYINDEX, LUA_RIDX_MAINTHREAD);
  printf("mainthread_equal=%d type=%s top=%d\n",
         lua_tothread(L, -1) == L, lua_typename(L, lua_type(L, -1)), lua_gettop(L));
  lua_pop(L, 1);

  printf("macros multret=%d minstack=%d errfile=%d filehandle=%s versuffix=%s\n",
         LUA_MULTRET, LUA_MINSTACK, LUA_ERRFILE, LUA_FILEHANDLE, LUA_VERSUFFIX);

  (void)version_release_is_zero;
  (void)numtypes_is_nine;
  (void)registry_last_is_mainthread;
  (void)upvalueindex_below_registry;
  (void)hook_mask_call_matches;
  (void)hook_mask_count_matches;
  (void)gc_param_count_matches;
  (void)coroutine_mask_after_package;
  (void)utf8_mask_after_table;

  lua_close(L);
  return 0;
}
