const std = @import("std");
const frontend = @import("frontend.zig");

pub const resolver = @import("compile/resolver.zig");
pub const bytecode = @import("compile/bytecode.zig");
pub const proto = @import("compile/proto.zig");
pub const compiler = @import("compile/compiler.zig");
pub const disasm = @import("compile/disasm.zig");

pub const Proto = proto.Proto;

pub fn compile(allocator: std.mem.Allocator, tree: *const frontend.ast.Ast) !Proto {
    return compiler.compile(allocator, tree);
}

test {
    _ = resolver;
    _ = bytecode;
    _ = proto;
    _ = compiler;
    _ = disasm;
}
