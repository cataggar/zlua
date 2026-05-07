const std = @import("std");

pub const lua_State = opaque {};
const lua_Debug = opaque {};
const luaL_Buffer = opaque {};
const luaL_Reg = opaque {};

const lua_Number = f64;
const lua_Integer = c_longlong;
const lua_Unsigned = c_ulonglong;
const lua_KContext = isize;
const lua_CFunction = ?*const fn (?*lua_State) callconv(.c) c_int;
const lua_KFunction = ?*const fn (?*lua_State, c_int, lua_KContext) callconv(.c) c_int;
const lua_Reader = ?*const fn (?*lua_State, ?*anyopaque, *usize) callconv(.c) ?[*:0]const u8;
const lua_Writer = ?*const fn (?*lua_State, ?*const anyopaque, usize, ?*anyopaque) callconv(.c) c_int;
const lua_Alloc = ?*const fn (?*anyopaque, ?*anyopaque, usize, usize) callconv(.c) ?*anyopaque;
const lua_WarnFunction = ?*const fn (?*anyopaque, ?[*:0]const u8, c_int) callconv(.c) void;
const lua_Hook = ?*const fn (?*lua_State, ?*lua_Debug) callconv(.c) void;
const VaList = std.builtin.VaList;

pub export const lua_ident: [18:0]u8 = "zlua C API phase 0".*;

fn zstr(comptime value: [:0]const u8) [*:0]const u8 {
    return value.ptr;
}

pub export fn lua_newstate(_: lua_Alloc, _: ?*anyopaque, _: c_uint) callconv(.c) ?*lua_State {
    return null;
}

pub export fn lua_close(_: ?*lua_State) callconv(.c) void {}

pub export fn lua_newthread(_: ?*lua_State) callconv(.c) ?*lua_State {
    return null;
}

pub export fn lua_closethread(_: ?*lua_State, _: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn lua_atpanic(_: ?*lua_State, panicf: lua_CFunction) callconv(.c) lua_CFunction {
    return panicf;
}

pub export fn lua_version(_: ?*lua_State) callconv(.c) lua_Number {
    return 505;
}

pub export fn lua_absindex(_: ?*lua_State, idx: c_int) callconv(.c) c_int {
    return idx;
}

pub export fn lua_gettop(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn lua_settop(_: ?*lua_State, _: c_int) callconv(.c) void {}
pub export fn lua_pushvalue(_: ?*lua_State, _: c_int) callconv(.c) void {}
pub export fn lua_rotate(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) void {}
pub export fn lua_copy(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) void {}

pub export fn lua_checkstack(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_xmove(_: ?*lua_State, _: ?*lua_State, _: c_int) callconv(.c) void {}

pub export fn lua_isnumber(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_isstring(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_iscfunction(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_isinteger(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_isuserdata(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_type(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return -1;
}

pub export fn lua_typename(_: ?*lua_State, tp: c_int) callconv(.c) [*:0]const u8 {
    return switch (tp) {
        -1 => zstr("no value"),
        0 => zstr("nil"),
        1 => zstr("boolean"),
        2 => zstr("userdata"),
        3 => zstr("number"),
        4 => zstr("string"),
        5 => zstr("table"),
        6 => zstr("function"),
        7 => zstr("userdata"),
        8 => zstr("thread"),
        else => zstr("invalid"),
    };
}

pub export fn lua_tonumberx(_: ?*lua_State, _: c_int, isnum: ?*c_int) callconv(.c) lua_Number {
    if (isnum) |ptr| ptr.* = 0;
    return 0;
}

pub export fn lua_tointegerx(_: ?*lua_State, _: c_int, isnum: ?*c_int) callconv(.c) lua_Integer {
    if (isnum) |ptr| ptr.* = 0;
    return 0;
}

pub export fn lua_toboolean(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_tolstring(_: ?*lua_State, _: c_int, len: ?*usize) callconv(.c) ?[*:0]const u8 {
    if (len) |ptr| ptr.* = 0;
    return null;
}

pub export fn lua_rawlen(_: ?*lua_State, _: c_int) callconv(.c) lua_Unsigned {
    return 0;
}

pub export fn lua_tocfunction(_: ?*lua_State, _: c_int) callconv(.c) lua_CFunction {
    return null;
}

pub export fn lua_touserdata(_: ?*lua_State, _: c_int) callconv(.c) ?*anyopaque {
    return null;
}

pub export fn lua_tothread(_: ?*lua_State, _: c_int) callconv(.c) ?*lua_State {
    return null;
}

pub export fn lua_topointer(_: ?*lua_State, _: c_int) callconv(.c) ?*const anyopaque {
    return null;
}

pub export fn lua_arith(_: ?*lua_State, _: c_int) callconv(.c) void {}

pub export fn lua_rawequal(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_compare(_: ?*lua_State, _: c_int, _: c_int, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_pushnil(_: ?*lua_State) callconv(.c) void {}
pub export fn lua_pushnumber(_: ?*lua_State, _: lua_Number) callconv(.c) void {}
pub export fn lua_pushinteger(_: ?*lua_State, _: lua_Integer) callconv(.c) void {}

pub export fn lua_pushlstring(_: ?*lua_State, s: ?[*]const u8, _: usize) callconv(.c) ?[*:0]const u8 {
    return @ptrCast(s);
}

pub export fn lua_pushexternalstring(_: ?*lua_State, s: ?[*]const u8, _: usize, _: lua_Alloc, _: ?*anyopaque) callconv(.c) ?[*:0]const u8 {
    return @ptrCast(s);
}

pub export fn lua_pushstring(_: ?*lua_State, s: ?[*:0]const u8) callconv(.c) ?[*:0]const u8 {
    return s;
}

pub export fn lua_pushvfstring(_: ?*lua_State, fmt: ?[*:0]const u8, _: VaList) callconv(.c) ?[*:0]const u8 {
    return fmt;
}

pub export fn lua_pushfstring(_: ?*lua_State, fmt: ?[*:0]const u8, ...) callconv(.c) ?[*:0]const u8 {
    return fmt;
}

pub export fn lua_pushcclosure(_: ?*lua_State, _: lua_CFunction, _: c_int) callconv(.c) void {}
pub export fn lua_pushboolean(_: ?*lua_State, _: c_int) callconv(.c) void {}
pub export fn lua_pushlightuserdata(_: ?*lua_State, _: ?*anyopaque) callconv(.c) void {}

pub export fn lua_pushthread(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn lua_getglobal(_: ?*lua_State, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn lua_gettable(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_getfield(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn lua_geti(_: ?*lua_State, _: c_int, _: lua_Integer) callconv(.c) c_int {
    return 0;
}

pub export fn lua_rawget(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_rawgeti(_: ?*lua_State, _: c_int, _: lua_Integer) callconv(.c) c_int {
    return 0;
}

pub export fn lua_rawgetp(_: ?*lua_State, _: c_int, _: ?*const anyopaque) callconv(.c) c_int {
    return 0;
}

pub export fn lua_createtable(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) void {}

pub export fn lua_newuserdatauv(_: ?*lua_State, _: usize, _: c_int) callconv(.c) ?*anyopaque {
    return null;
}

pub export fn lua_getmetatable(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_getiuservalue(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_setglobal(_: ?*lua_State, _: ?[*:0]const u8) callconv(.c) void {}
pub export fn lua_settable(_: ?*lua_State, _: c_int) callconv(.c) void {}
pub export fn lua_setfield(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) void {}
pub export fn lua_seti(_: ?*lua_State, _: c_int, _: lua_Integer) callconv(.c) void {}
pub export fn lua_rawset(_: ?*lua_State, _: c_int) callconv(.c) void {}
pub export fn lua_rawseti(_: ?*lua_State, _: c_int, _: lua_Integer) callconv(.c) void {}
pub export fn lua_rawsetp(_: ?*lua_State, _: c_int, _: ?*const anyopaque) callconv(.c) void {}

pub export fn lua_setmetatable(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_setiuservalue(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_callk(_: ?*lua_State, _: c_int, _: c_int, _: lua_KContext, _: lua_KFunction) callconv(.c) void {}

pub export fn lua_pcallk(_: ?*lua_State, _: c_int, _: c_int, _: c_int, _: lua_KContext, _: lua_KFunction) callconv(.c) c_int {
    return 0;
}

pub export fn lua_load(_: ?*lua_State, _: lua_Reader, _: ?*anyopaque, _: ?[*:0]const u8, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn lua_dump(_: ?*lua_State, _: lua_Writer, _: ?*anyopaque, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_yieldk(_: ?*lua_State, _: c_int, _: lua_KContext, _: lua_KFunction) callconv(.c) c_int {
    return 0;
}

pub export fn lua_resume(_: ?*lua_State, _: ?*lua_State, _: c_int, nres: ?*c_int) callconv(.c) c_int {
    if (nres) |ptr| ptr.* = 0;
    return 0;
}

pub export fn lua_status(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn lua_isyieldable(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn lua_setwarnf(_: ?*lua_State, _: lua_WarnFunction, _: ?*anyopaque) callconv(.c) void {}
pub export fn lua_warning(_: ?*lua_State, _: ?[*:0]const u8, _: c_int) callconv(.c) void {}

pub export fn lua_gc(_: ?*lua_State, _: c_int, ...) callconv(.c) c_int {
    return 0;
}

pub export fn lua_error(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn lua_next(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_concat(_: ?*lua_State, _: c_int) callconv(.c) void {}
pub export fn lua_len(_: ?*lua_State, _: c_int) callconv(.c) void {}

pub export fn lua_numbertocstring(_: ?*lua_State, _: c_int, buff: ?[*]u8) callconv(.c) c_uint {
    if (buff) |ptr| ptr[0] = 0;
    return 0;
}

pub export fn lua_stringtonumber(_: ?*lua_State, _: ?[*:0]const u8) callconv(.c) usize {
    return 0;
}

pub export fn lua_getallocf(_: ?*lua_State, ud: ?*?*anyopaque) callconv(.c) lua_Alloc {
    if (ud) |ptr| ptr.* = null;
    return null;
}

pub export fn lua_setallocf(_: ?*lua_State, _: lua_Alloc, _: ?*anyopaque) callconv(.c) void {}
pub export fn lua_toclose(_: ?*lua_State, _: c_int) callconv(.c) void {}
pub export fn lua_closeslot(_: ?*lua_State, _: c_int) callconv(.c) void {}

pub export fn lua_getstack(_: ?*lua_State, _: c_int, _: ?*lua_Debug) callconv(.c) c_int {
    return 0;
}

pub export fn lua_getinfo(_: ?*lua_State, _: ?[*:0]const u8, _: ?*lua_Debug) callconv(.c) c_int {
    return 0;
}

pub export fn lua_getlocal(_: ?*lua_State, _: ?*const lua_Debug, _: c_int) callconv(.c) ?[*:0]const u8 {
    return null;
}

pub export fn lua_setlocal(_: ?*lua_State, _: ?*const lua_Debug, _: c_int) callconv(.c) ?[*:0]const u8 {
    return null;
}

pub export fn lua_getupvalue(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) ?[*:0]const u8 {
    return null;
}

pub export fn lua_setupvalue(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) ?[*:0]const u8 {
    return null;
}

pub export fn lua_upvalueid(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) ?*anyopaque {
    return null;
}

pub export fn lua_upvaluejoin(_: ?*lua_State, _: c_int, _: c_int, _: c_int, _: c_int) callconv(.c) void {}
pub export fn lua_sethook(_: ?*lua_State, _: lua_Hook, _: c_int, _: c_int) callconv(.c) void {}

pub export fn lua_gethook(_: ?*lua_State) callconv(.c) lua_Hook {
    return null;
}

pub export fn lua_gethookmask(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn lua_gethookcount(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_checkversion_(_: ?*lua_State, _: lua_Number, _: usize) callconv(.c) void {}

pub export fn luaL_getmetafield(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_callmeta(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_tolstring(_: ?*lua_State, _: c_int, len: ?*usize) callconv(.c) ?[*:0]const u8 {
    if (len) |ptr| ptr.* = 0;
    return null;
}

pub export fn luaL_argerror(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_typeerror(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_checklstring(_: ?*lua_State, _: c_int, len: ?*usize) callconv(.c) ?[*:0]const u8 {
    if (len) |ptr| ptr.* = 0;
    return null;
}

pub export fn luaL_optlstring(_: ?*lua_State, _: c_int, def: ?[*:0]const u8, len: ?*usize) callconv(.c) ?[*:0]const u8 {
    if (len) |ptr| ptr.* = 0;
    return def;
}

pub export fn luaL_checknumber(_: ?*lua_State, _: c_int) callconv(.c) lua_Number {
    return 0;
}

pub export fn luaL_optnumber(_: ?*lua_State, _: c_int, def: lua_Number) callconv(.c) lua_Number {
    return def;
}

pub export fn luaL_checkinteger(_: ?*lua_State, _: c_int) callconv(.c) lua_Integer {
    return 0;
}

pub export fn luaL_optinteger(_: ?*lua_State, _: c_int, def: lua_Integer) callconv(.c) lua_Integer {
    return def;
}

pub export fn luaL_checkstack(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) void {}
pub export fn luaL_checktype(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) void {}
pub export fn luaL_checkany(_: ?*lua_State, _: c_int) callconv(.c) void {}

pub export fn luaL_newmetatable(_: ?*lua_State, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_setmetatable(_: ?*lua_State, _: ?[*:0]const u8) callconv(.c) void {}

pub export fn luaL_testudata(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) ?*anyopaque {
    return null;
}

pub export fn luaL_checkudata(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) ?*anyopaque {
    return null;
}

pub export fn luaL_where(_: ?*lua_State, _: c_int) callconv(.c) void {}

pub export fn luaL_error(_: ?*lua_State, _: ?[*:0]const u8, ...) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_checkoption(_: ?*lua_State, _: c_int, _: ?[*:0]const u8, _: [*]const ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_fileresult(_: ?*lua_State, stat: c_int, _: ?[*:0]const u8) callconv(.c) c_int {
    return stat;
}

pub export fn luaL_execresult(_: ?*lua_State, stat: c_int) callconv(.c) c_int {
    return stat;
}

pub export fn luaL_alloc(_: ?*anyopaque, _: ?*anyopaque, _: usize, _: usize) callconv(.c) ?*anyopaque {
    return null;
}

pub export fn luaL_ref(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return -2;
}

pub export fn luaL_unref(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) void {}

pub export fn luaL_loadfilex(_: ?*lua_State, _: ?[*:0]const u8, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_loadbufferx(_: ?*lua_State, _: ?[*]const u8, _: usize, _: ?[*:0]const u8, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_loadstring(_: ?*lua_State, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_newstate() callconv(.c) ?*lua_State {
    return null;
}

pub export fn luaL_makeseed(_: ?*lua_State) callconv(.c) c_uint {
    return 0;
}

pub export fn luaL_len(_: ?*lua_State, _: c_int) callconv(.c) lua_Integer {
    return 0;
}

pub export fn luaL_addgsub(_: ?*luaL_Buffer, _: ?[*:0]const u8, _: ?[*:0]const u8, _: ?[*:0]const u8) callconv(.c) void {}

pub export fn luaL_gsub(_: ?*lua_State, s: ?[*:0]const u8, _: ?[*:0]const u8, _: ?[*:0]const u8) callconv(.c) ?[*:0]const u8 {
    return s;
}

pub export fn luaL_setfuncs(_: ?*lua_State, _: ?*const luaL_Reg, _: c_int) callconv(.c) void {}

pub export fn luaL_getsubtable(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_traceback(_: ?*lua_State, _: ?*lua_State, _: ?[*:0]const u8, _: c_int) callconv(.c) void {}
pub export fn luaL_requiref(_: ?*lua_State, _: ?[*:0]const u8, _: lua_CFunction, _: c_int) callconv(.c) void {}
pub export fn luaL_buffinit(_: ?*lua_State, _: ?*luaL_Buffer) callconv(.c) void {}

pub export fn luaL_prepbuffsize(_: ?*luaL_Buffer, _: usize) callconv(.c) ?[*]u8 {
    return null;
}

pub export fn luaL_addlstring(_: ?*luaL_Buffer, _: ?[*]const u8, _: usize) callconv(.c) void {}
pub export fn luaL_addstring(_: ?*luaL_Buffer, _: ?[*:0]const u8) callconv(.c) void {}
pub export fn luaL_addvalue(_: ?*luaL_Buffer) callconv(.c) void {}
pub export fn luaL_pushresult(_: ?*luaL_Buffer) callconv(.c) void {}
pub export fn luaL_pushresultsize(_: ?*luaL_Buffer, _: usize) callconv(.c) void {}

pub export fn luaL_buffinitsize(_: ?*lua_State, _: ?*luaL_Buffer, _: usize) callconv(.c) ?[*]u8 {
    return null;
}

pub export fn luaopen_base(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_package(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_coroutine(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_debug(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_io(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_math(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_os(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_string(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_table(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_utf8(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_openselectedlibs(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) void {}
