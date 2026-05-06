const std = @import("std");
const errors = @import("errors.zig");
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

pub fn compileWithDiagnostic(allocator: std.mem.Allocator, tree: *const frontend.ast.Ast, error_diagnostic: *?errors.Diagnostic) !Proto {
    return compiler.compile(allocator, tree) catch |err| {
        if (error_diagnostic.* == null) error_diagnostic.* = .{ .compile = compileDiagnostic(err) };
        return err;
    };
}

fn compileDiagnostic(err: anyerror) errors.CompileError {
    return switch (err) {
        error.TooManyReturns => .{ .too_many_returns = .{ .start = .{}, .end = .{} } },
        error.RegisterOverflow => .{ .register_overflow = .{ .line = 1 } },
        error.JumpOutOfRange => .{ .jump_out_of_range = .{ .line = 1 } },
        else => .{ .invalid_ast = .{ .line = 1 } },
    };
}

test {
    _ = resolver;
    _ = bytecode;
    _ = proto;
    _ = compiler;
    _ = disasm;
}
