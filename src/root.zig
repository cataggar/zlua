pub const version = "0.0.0";
pub const lua_target_version = "Lua 5.5";

pub const frontend = @import("frontend.zig");
pub const compile = @import("compile.zig");
pub const errors = @import("errors.zig");
pub const runtime = @import("runtime.zig");
pub const stdlib = @import("stdlib.zig");
pub const testing = @import("testing.zig");

test {
    _ = frontend;
    _ = compile;
    _ = errors;
    _ = runtime;
    _ = stdlib;
    _ = testing;
}
