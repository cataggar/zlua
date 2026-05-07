#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

static char version_major_is_5[(LUA_VERSION_MAJOR_N == 5) ? 1 : -1];
static char version_minor_is_5[(LUA_VERSION_MINOR_N == 5) ? 1 : -1];
static char registry_globals_is_2[(LUA_RIDX_GLOBALS == 2) ? 1 : -1];
static char registry_mainthread_is_3[(LUA_RIDX_MAINTHREAD == 3) ? 1 : -1];

int main(void) {
  lua_State *L = NULL;
  luaL_Buffer B;
  luaL_Reg R = { NULL, NULL };
  (void)L;
  (void)B;
  (void)R;
  (void)version_major_is_5;
  (void)version_minor_is_5;
  (void)registry_globals_is_2;
  (void)registry_mainthread_is_3;
  return 0;
}
