pub const version = "0.0.0";
pub const lua_target_version = "Lua 5.5";

pub const testing = @import("testing.zig");

test {
    _ = testing;
}
