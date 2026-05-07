const std = @import("std");
const compile = @import("../compile.zig");
const types = @import("types.zig");
const value_mod = @import("value.zig");

const bytecode = compile.bytecode;
const proto_mod = compile.proto;

const RuntimeErrorPayload = types.RuntimeErrorPayload;
const Value = types.Value;
const ProtectedCallResult = types.ProtectedCallResult;
const ProtectedCallContext = types.ProtectedCallContext;
const ProtectedContinuationKind = types.ProtectedContinuationKind;
const ProtectedContinuation = types.ProtectedContinuation;
const CallOneContinuationResult = types.CallOneContinuationResult;
const CallOneContinuation = types.CallOneContinuation;
const Closure = types.Closure;
const Thread = types.Thread;
const CallFrame = types.CallFrame;

const freeProtectedResult = value_mod.freeProtectedResult;
const argValue = value_mod.argValue;
const truthy = value_mod.truthy;

pub fn callOneResult(comptime State: type, self: *State, thread: *Thread, callable: Value, args: []const Value) anyerror!Value {
    return callOneResultMaybeContinuation(State, self, thread, callable, args, null);
}

pub fn callOneResultWithContinuation(comptime State: type, self: *State, thread: *Thread, callable: Value, args: []const Value, result: CallOneContinuationResult) anyerror!Value {
    return callOneResultMaybeContinuation(State, self, thread, callable, args, result);
}

pub fn callOneMetamethodWithContinuation(comptime State: type, self: *State, thread: *Thread, name: []const u8, callable: Value, args: []const Value, result: CallOneContinuationResult) anyerror!Value {
    const previous_name = thread.next_call_name;
    const previous_namewhat = thread.next_call_namewhat;
    thread.next_call_name = metamethodDebugName(name);
    thread.next_call_namewhat = "metamethod";
    defer {
        thread.next_call_name = previous_name;
        thread.next_call_namewhat = previous_namewhat;
    }
    return callOneResultWithContinuation(State, self, thread, callable, args, result);
}

pub fn callOneMetamethod(comptime State: type, self: *State, thread: *Thread, name: []const u8, callable: Value, args: []const Value) anyerror!Value {
    const previous_name = thread.next_call_name;
    const previous_namewhat = thread.next_call_namewhat;
    thread.next_call_name = metamethodDebugName(name);
    thread.next_call_namewhat = "metamethod";
    defer {
        thread.next_call_name = previous_name;
        thread.next_call_namewhat = previous_namewhat;
    }
    return callOneResult(State, self, thread, callable, args);
}

pub fn metamethodDebugName(name: []const u8) []const u8 {
    return if (std.mem.startsWith(u8, name, "__")) name[2..] else name;
}

pub fn callOneResultMaybeContinuation(comptime State: type, self: *State, thread: *Thread, callable: Value, args: []const Value, continuation_result: ?CallOneContinuationResult) anyerror!Value {
    const frame_count = thread.frames.items.len;
    const frame = thread.frames.items[frame_count - 1];
    const relative_base: bytecode.Register = frame.proto.max_registers;
    const base = frame.base + @as(usize, relative_base);
    try thread.ensureStack(self.allocator, base + 1 + args.len, self.stackValueLimit());
    thread.stack.items[base] = callable;
    for (args, 0..) |arg, index| thread.stack.items[base + 1 + index] = arg;

    self.invokeValue(thread, .{ .base = relative_base, .arg_count = @intCast(args.len), .return_count = 1 }, 0) catch |err| switch (err) {
        error.CoroutineYield => {
            if (continuation_result) |result| try pushCallOneContinuation(State, self, thread, frame_count, result);
            return err;
        },
        else => return err,
    };
    self.runThreadUntil(thread, frame_count) catch |err| switch (err) {
        error.CoroutineYield => {
            if (continuation_result) |result| try pushCallOneContinuation(State, self, thread, frame_count, result);
            return err;
        },
        else => return err,
    };
    return thread.stack.items[base];
}

pub fn pushCallOneContinuation(comptime State: type, self: *State, thread: *Thread, frame_count: usize, result: CallOneContinuationResult) !void {
    try thread.call_one_continuations.append(self.allocator, .{ .frame_count = frame_count, .result = result });
}

pub fn readyCallOneContinuationIndex(thread: *Thread) ?usize {
    for (thread.call_one_continuations.items, 0..) |continuation, index| {
        if (continuation.frame_count == thread.frames.items.len) return index;
    }
    return null;
}

pub fn completeReadyCallOneContinuation(comptime State: type, self: *State, thread: *Thread) !bool {
    const index = readyCallOneContinuationIndex(thread) orelse return false;
    const continuation = thread.call_one_continuations.orderedRemove(index);
    const value = if (thread.last_result_count == 0) Value.nil else thread.stack.items[thread.last_result_base];
    switch (continuation.result) {
        .value => |dest| thread.stack.items[dest] = value,
        .truthy => |dest| thread.stack.items[dest] = .{ .boolean = truthy(value) },
        .inverted_truthy => |dest| thread.stack.items[dest] = .{ .boolean = !truthy(value) },
        .branch_truthy => |branch| {
            thread.last_result_count = 0;
            thread.last_transfer_count = 0;
            try self.jumpIfBranchResult(thread, truthy(value), branch.jump_if_truthy, branch.offset);
        },
        .branch_inverted_truthy => |branch| {
            thread.last_result_count = 0;
            thread.last_transfer_count = 0;
            try self.jumpIfBranchResult(thread, !truthy(value), branch.jump_if_truthy, branch.offset);
        },
        .discard => {},
    }
    return true;
}

pub fn protectedCall(comptime State: type, self: *State, thread: *Thread, callable: Value, args: []const Value) anyerror!ProtectedCallResult {
    const context = protectedCallContextWithErrors(State, self, thread);
    return runProtectedCall(State, self, thread, context, callable, args);
}

pub fn protectedCallContext(comptime State: type, _: *State, thread: *Thread) ProtectedCallContext {
    const frame_count = thread.frames.items.len;
    const frame = thread.frames.items[frame_count - 1];
    const relative_base: bytecode.Register = frame.proto.max_registers;
    return .{
        .frame_count = frame_count,
        .relative_base = relative_base,
        .absolute_base = frame.base + @as(usize, relative_base),
        .stack_len = thread.stack.items.len,
        .last_result_base = thread.last_result_base,
        .last_result_count = thread.last_result_count,
        .last_error = undefined,
    };
}

pub fn protectedCallContextWithErrors(comptime State: type, self: *State, thread: *Thread) ProtectedCallContext {
    var context = protectedCallContext(State, self, thread);
    context.last_error = self.last_error;
    return context;
}

pub fn runProtectedCall(comptime State: type, self: *State, thread: *Thread, context: ProtectedCallContext, callable: Value, args: []const Value) anyerror!ProtectedCallResult {
    try thread.ensureStack(self.allocator, context.absolute_base + 1 + args.len, self.stackValueLimit());
    thread.stack.items[context.absolute_base] = callable;
    for (args, 0..) |arg, index| thread.stack.items[context.absolute_base + 1 + index] = arg;

    self.last_error = null;
    self.last_error_in_close = false;
    self.invokeValue(thread, .{ .base = context.relative_base, .arg_count = @intCast(args.len), .return_count = bytecode.multret_count }, 0) catch |err| switch (err) {
        error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode, error.OutOfMemory => {
            if (thread.frames.items.len < context.frame_count) return err;
            if (err == error.OutOfMemory) {
                if (self.last_error == null) self.last_error = .{ .diagnostic = "not enough memory" };
            }
            const error_value = self.currentErrorValue();
            const failure = try self.restoreProtectedCall(thread, context, error_value);
            return .{ .failure = failure };
        },
        else => return err,
    };
    self.runThreadUntil(thread, context.frame_count) catch |err| switch (err) {
        error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode, error.OutOfMemory => {
            if (thread.frames.items.len < context.frame_count) return err;
            if (err == error.OutOfMemory) {
                if (self.last_error == null) self.last_error = .{ .diagnostic = "not enough memory" };
            }
            const error_value = self.currentErrorValue();
            const failure = try self.restoreProtectedCall(thread, context, error_value);
            return .{ .failure = failure };
        },
        else => return err,
    };

    const values = try self.allocator.alloc(Value, thread.last_result_count);
    for (values, 0..) |*value, index| value.* = thread.stack.items[thread.last_result_base + index];
    _ = try self.restoreProtectedCall(thread, context, .nil);
    return .{ .success = values };
}

pub fn pushProtectedContinuation(comptime State: type, self: *State, thread: *Thread, context: ProtectedCallContext, base: bytecode.Register, return_count: u16, kind: ProtectedContinuationKind, handler: Value, handler_depth: usize) !void {
    try thread.protected_continuations.append(self.allocator, .{
        .context = context,
        .base = base,
        .return_count = return_count,
        .kind = kind,
        .handler = handler,
        .handler_depth = handler_depth,
    });
}

pub fn readyProtectedContinuationIndex(thread: *Thread) ?usize {
    for (thread.protected_continuations.items, 0..) |continuation, index| {
        if (continuation.context.frame_count == thread.frames.items.len) return index;
    }
    return null;
}

pub fn errorProtectedContinuationIndex(thread: *Thread) ?usize {
    var best_index: ?usize = null;
    var best_frame_count: usize = 0;
    for (thread.protected_continuations.items, 0..) |continuation, index| {
        const frame_count = continuation.context.frame_count;
        if (frame_count > thread.frames.items.len) continue;
        if (best_index == null or frame_count > best_frame_count) {
            best_index = index;
            best_frame_count = frame_count;
        }
    }
    return best_index;
}

pub fn completeReadyProtectedContinuation(comptime State: type, self: *State, thread: *Thread) !bool {
    const index = readyProtectedContinuationIndex(thread) orelse return false;
    const continuation = thread.protected_continuations.items[index];
    const values = try self.copyStackSlice(thread, thread.last_result_base, thread.last_result_count);
    defer self.allocator.free(values);
    _ = try self.restoreProtectedCall(thread, continuation.context, .nil);
    _ = thread.protected_continuations.orderedRemove(index);
    try returnProtectedContinuationSuccess(State, self, thread, continuation, values);
    return true;
}

pub fn completeProtectedContinuationError(comptime State: type, self: *State, thread: *Thread, error_value: Value) !bool {
    const index = errorProtectedContinuationIndex(thread) orelse return false;
    const continuation = thread.protected_continuations.items[index];
    const failure = try self.restoreProtectedCall(thread, continuation.context, error_value);
    _ = thread.protected_continuations.orderedRemove(index);
    try returnProtectedContinuationFailure(State, self, thread, continuation, failure);
    return true;
}

pub fn returnProtectedContinuationSuccess(comptime State: type, self: *State, thread: *Thread, continuation: ProtectedContinuation, values: []Value) !void {
    switch (continuation.kind) {
        .pcall, .xpcall => try returnProtectedResult(State, self, thread, continuation.base, continuation.return_count, .{ .success = values }),
        .xpcall_handler => {
            const handled = if (values.len == 0) Value.nil else values[0];
            try self.returnValues(thread, continuation.base, continuation.return_count, &.{ .{ .boolean = false }, handled });
        },
    }
}

pub fn returnProtectedContinuationFailure(comptime State: type, self: *State, thread: *Thread, continuation: ProtectedContinuation, failure: Value) !void {
    switch (continuation.kind) {
        .pcall => try returnProtectedResult(State, self, thread, continuation.base, continuation.return_count, .{ .failure = failure }),
        .xpcall => try self.returnXpcallFailure(thread, continuation.base, continuation.return_count, continuation.handler, failure),
        .xpcall_handler => try self.returnXpcallFailureFromDepth(thread, continuation.base, continuation.return_count, continuation.handler, failure, continuation.handler_depth + 1),
    }
}

pub fn returnProtectedResult(comptime State: type, self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, result: ProtectedCallResult) !void {
    switch (result) {
        .success => |values| {
            var returns = std.ArrayList(Value).empty;
            defer returns.deinit(self.allocator);
            try returns.append(self.allocator, .{ .boolean = true });
            try returns.appendSlice(self.allocator, values);
            try self.returnValues(thread, base, return_count, returns.items);
        },
        .failure => |error_value| try self.returnValues(thread, base, return_count, &.{ .{ .boolean = false }, error_value }),
    }
}

pub fn collectArgs(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call, first: u16) ![]Value {
    if (op.arg_count <= first) return self.allocator.alloc(Value, 0);
    const args = try self.allocator.alloc(Value, op.arg_count - first);
    for (args, 0..) |*arg, index| arg.* = argValue(self, thread, op, first + @as(u16, @intCast(index)));
    return args;
}

pub fn resolveReturnCount(comptime State: type, self: *State, count: u16, available: usize) !usize {
    _ = self;
    return if (count == bytecode.multret_count) available else count;
}

pub fn prepareClosureFrame(comptime State: type, self: *State, thread: *Thread, closure: *Closure, source_base: usize, frame_base: usize, arg_count: usize, return_start: usize, return_count: u16) !CallFrame {
    const register_count = @max(closure.proto.max_registers, 1);
    const param_count = @as(usize, closure.proto.param_count);
    const copied = @min(arg_count, param_count);
    const varargs = try self.captureVarargs(thread, source_base + 1 + param_count, if (closure.proto.is_vararg and arg_count > param_count) arg_count - param_count else 0);
    errdefer if (varargs.len != 0) self.allocator.free(varargs);
    try thread.ensureStack(self.allocator, frame_base + register_count, self.stackValueLimit());

    for (0..copied) |index| thread.stack.items[frame_base + index] = thread.stack.items[source_base + 1 + index];
    for (copied..register_count) |index| thread.stack.items[frame_base + index] = .nil;

    if (closure.proto.named_vararg) {
        thread.stack.items[frame_base + param_count] = try self.namedVarargTable(varargs);
    }

    return .{
        .closure = closure,
        .proto = closure.proto,
        .base = frame_base,
        .pc = 0,
        .return_start = return_start,
        .return_count = return_count,
        .varargs = varargs,
        .owns_varargs = varargs.len != 0,
    };
}
