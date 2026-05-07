const std = @import("std");
const compile = @import("../compile.zig");
const types = @import("types.zig");
const value_mod = @import("value.zig");

const bytecode = compile.bytecode;
const proto_mod = compile.proto;

const RuntimeError = types.RuntimeError;
const Value = types.Value;
const ProtectedCallResult = types.ProtectedCallResult;
const CoroutineResumeResult = types.CoroutineResumeResult;
const CClosureResumeContext = types.CClosureResumeContext;
const Closure = types.Closure;
const CClosure = types.CClosure;
const Upvalue = types.Upvalue;
const Thread = types.Thread;
const ThreadStatus = types.ThreadStatus;

const argValue = value_mod.argValue;
const toInteger = value_mod.toInteger;

fn isNativeCallable(value: Value) bool {
    return switch (value) {
        .native_print,
        .native_tostring,
        .native_getmetatable,
        .native_setmetatable,
        .native_rawequal,
        .native_rawget,
        .native_rawset,
        .native_rawlen,
        .native_next,
        .native_pairs,
        .native_ipairs,
        .native_ipairs_iter,
        .native_table_create,
        .native_select,
        .native_assert,
        .native_error,
        .native_pcall,
        .native_xpcall,
        .native_collectgarbage,
        .native_debug_traceback,
        .native_coroutine_create,
        .native_coroutine_resume,
        .native_coroutine_yield,
        .native_coroutine_status,
        .native_coroutine_running,
        .native_coroutine_isyieldable,
        .native_coroutine_close,
        .native_coroutine_wrap,
        .native,
        => true,
        else => false,
    };
}

fn functionLike(value: Value) bool {
    return switch (value) {
        .closure, .c_closure, .coroutine_wrapper, .gmatch_iterator => true,
        else => isNativeCallable(value),
    };
}

fn freeCoroutineResumeResult(allocator: std.mem.Allocator, result: CoroutineResumeResult) void {
    switch (result) {
        .success => |values| allocator.free(values),
        .failure => {},
    }
}

fn threadStatusName(status: ThreadStatus) []const u8 {
    return switch (status) {
        .suspended => "suspended",
        .running => "running",
        .normal => "normal",
        .dead => "dead",
    };
}

fn resumeChainDepth(thread: ?*Thread) usize {
    var depth: usize = 0;
    var current = thread;
    while (current) |active| : (current = active.resume_parent) depth += 1;
    return depth;
}

pub fn newCoroutine(comptime State: type, self: *State, entry: Value) !*Thread {
    return newCoroutineThread(State, self, entry);
}

pub fn resumeThread(comptime State: type, self: *State, target: *Thread, args: []const Value) !ProtectedCallResult {
    const result = try resumeCoroutine(State, self, target, args);
    return switch (result) {
        .success => |values| .{ .success = values },
        .failure => |value| .{ .failure = value },
    };
}

pub fn closeThread(comptime State: type, self: *State, target: *Thread) !?Value {
    return closeCoroutine(State, self, target, null);
}

pub fn threadWasYielded(comptime State: type, _: *State, target: *Thread) bool {
    return target.status == .suspended and target.started;
}

pub fn resumeCClosureDispatch(comptime State: type, self: *State, thread: *Thread, args: []const Value) !void {
    const dispatch = self.c_closure_resume_dispatch orelse return;
    var context = CClosureResumeContext{
        .state = self,
        .thread = thread,
        .args = args,
        .user_data = self.c_closure_user_data,
    };
    defer context.deinit();

    dispatch(&context) catch |err| switch (err) {
        error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => return err,
        error.CoroutineYield, error.CoroutineClose => return err,
        error.LuaError => return self.failValue(context.error_value orelse .{ .string = try self.intern("C callback raised an error") }),
        error.OutOfMemory => return err,
        else => return self.fail(@errorName(err)),
    };

    const actual_count = try self.resolveReturnCount(thread.yield_result_count, context.returns.items.len);
    try thread.ensureStack(self.allocator, thread.yield_result_base + actual_count, self.stackValueLimit());
    for (0..actual_count) |index| {
        thread.stack.items[thread.yield_result_base + index] = if (index < context.returns.items.len) context.returns.items[index] else .nil;
    }
    thread.last_result_base = thread.yield_result_base;
    thread.last_result_count = actual_count;
}

pub fn coroutineCreate(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void {
    const entry = argValue(self, thread, op, 0);
    if (!functionLike(entry)) return self.failArgumentType("coroutine.create", 1, "function", entry);
    try self.returnValues(thread, op.base, op.return_count, &.{.{ .thread = try newCoroutineThread(State, self, entry) }});
}

pub fn coroutineResume(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void {
    const target = try self.expectThread(argValue(self, thread, op, 0));
    const args = try self.collectArgs(thread, op, 1);
    defer self.allocator.free(args);

    const result = try resumeCoroutine(State, self, target, args);
    defer freeCoroutineResumeResult(self.allocator, result);
    try returnCoroutineResumeResult(State, self, thread, op.base, op.return_count, result);
}

pub fn coroutineYield(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void {
    if (thread.is_main) return self.fail("attempt to yield from outside a coroutine");
    if (thread.closing) return self.fail("attempt to yield from a __close metamethod");
    if (thread.native_call_depth > 1) return self.fail("attempt to yield across a native-call boundary");

    thread.yield_values.clearRetainingCapacity();
    for (0..op.arg_count) |index| {
        try thread.yield_values.append(self.allocator, argValue(self, thread, op, @intCast(index)));
    }
    const frame = thread.frames.items[thread.frames.items.len - 1];
    thread.yield_result_base = frame.base + op.base;
    thread.yield_result_count = op.return_count;
    if (thread.hook_return and !thread.hook_running) thread.pending_yield_hook_return = true;
    thread.status = .suspended;
    return error.CoroutineYield;
}

pub fn coroutineStatus(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void {
    const target = try self.expectThread(argValue(self, thread, op, 0));
    try self.returnValues(thread, op.base, op.return_count, &.{.{ .string = try self.intern(threadStatusName(target.status)) }});
}

pub fn coroutineRunning(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void {
    try self.returnValues(thread, op.base, op.return_count, &.{ .{ .thread = thread }, .{ .boolean = thread.is_main } });
}

pub fn coroutineIsYieldable(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void {
    const target = if (op.arg_count == 0) thread else try self.expectThread(argValue(self, thread, op, 0));
    const yieldable = if (target == thread)
        !thread.is_main and thread.status == .running and thread.native_call_depth <= 1 and !thread.closing
    else
        !target.is_main and target.status != .dead and !target.closing;
    try self.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = yieldable }});
}

pub fn coroutineClose(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void {
    const target = if (op.arg_count == 0) thread else try self.expectThread(argValue(self, thread, op, 0));
    if (target.status == .normal) return self.fail("cannot close a normal coroutine");
    if (target.is_main) return self.fail("cannot close main coroutine");
    if (target.closing) {
        try self.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = true }});
        return;
    }
    if (target.status == .dead) {
        if (target.close_error_value) |error_value| {
            target.close_error_value = null;
            try self.returnValues(thread, op.base, op.return_count, &.{ .{ .boolean = false }, error_value });
        } else {
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = true }});
        }
        return;
    }
    if (target.status == .running and target != thread) return self.fail("cannot close a running coroutine");

    const closes_self = target == thread and target.status == .running;
    if (try closeCoroutine(State, self, target, null)) |error_value| {
        if (closes_self) return self.throwValue(error_value);
        try self.returnValues(thread, op.base, op.return_count, &.{ .{ .boolean = false }, error_value });
        return;
    }
    if (closes_self) return error.CoroutineClose;
    try self.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = true }});
}

pub fn coroutineWrap(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void {
    if (argValue(self, thread, op, 0) == .gmatch_iterator) {
        try self.returnValues(thread, op.base, op.return_count, &.{argValue(self, thread, op, 0)});
        return;
    }
    const entry = argValue(self, thread, op, 0);
    if (!functionLike(entry)) return self.failArgumentType("coroutine.wrap", 1, "function", entry);
    try self.returnValues(thread, op.base, op.return_count, &.{.{ .coroutine_wrapper = try newCoroutineThread(State, self, entry) }});
}

pub fn callCoroutineWrapper(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call, target: *Thread) !void {
    const args = try self.collectArgs(thread, op, 0);
    defer self.allocator.free(args);
    try callCoroutineWrapperWithArgs(State, self, thread, op.base, op.return_count, target, args);
}

pub fn callCoroutineWrapperWithArgs(comptime State: type, self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, target: *Thread, args: []const Value) !void {
    const result = try resumeCoroutine(State, self, target, args);
    defer freeCoroutineResumeResult(self.allocator, result);
    switch (result) {
        .success => |values| try self.returnValues(thread, base, return_count, values),
        .failure => |error_value| return self.throwValue(error_value),
    }
}

pub fn newCoroutineThread(comptime State: type, self: *State, entry: Value) !*Thread {
    const thread = try self.allocator.create(Thread);
    errdefer self.allocator.destroy(thread);
    thread.* = Thread.initCoroutine(entry);
    errdefer thread.deinit(self.allocator);
    try self.thread_allocations.append(self.allocator, thread);
    self.noteAllocation(@sizeOf(Thread));
    return thread;
}

pub fn closeCoroutine(comptime State: type, self: *State, target: *Thread, error_value: ?Value) !?Value {
    if (self.coroutine_close_depth >= self.callFrameLimit()) return .{ .string = try self.intern("C stack overflow") };
    self.coroutine_close_depth += 1;
    defer self.coroutine_close_depth -= 1;

    const previous_thread = self.current_thread;
    const previous_parent = target.resume_parent;
    const previous_status = target.status;
    self.current_thread = target;
    target.resume_parent = previous_thread;
    target.status = .running;
    target.closing = true;
    defer {
        target.closing = false;
        target.status = .dead;
        target.resume_parent = previous_parent;
        self.current_thread = previous_thread;
    }

    self.closeFramesTo(target, 0, error_value) catch |err| switch (err) {
        error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => return self.currentErrorValue(),
        else => {
            target.status = previous_status;
            return err;
        },
    };
    target.close_error_value = null;
    return null;
}

pub fn resumeCoroutine(comptime State: type, self: *State, target: *Thread, args: []const Value) !CoroutineResumeResult {
    if (target.is_main) return .{ .failure = .{ .string = try self.intern("cannot resume main coroutine") } };
    if (target.status == .dead) return .{ .failure = .{ .string = try self.intern("cannot resume dead coroutine") } };
    if (target.status != .suspended) return .{ .failure = .{ .string = try self.intern("cannot resume non-suspended coroutine") } };

    const parent = self.current_thread;
    if (parent == target) return .{ .failure = .{ .string = try self.intern("cannot resume running coroutine") } };
    if (resumeChainDepth(parent) >= self.callFrameLimit()) return .{ .failure = .{ .string = try self.intern("C stack overflow") } };

    if (parent) |parent_thread| {
        if (parent_thread.status == .running) parent_thread.status = .normal;
    }
    const previous_thread = self.current_thread;
    const previous_parent = target.resume_parent;
    self.current_thread = target;
    target.resume_parent = parent;
    target.status = .running;
    defer {
        self.current_thread = previous_thread;
        target.resume_parent = previous_parent;
        if (parent) |parent_thread| {
            if (parent_thread.status == .normal) parent_thread.status = .running;
        }
    }

    if (!target.started) {
        try startCoroutine(State, self, target, args);
    } else if (target.pending_c_continuation) {
        target.pending_c_continuation = false;
        try resumeCClosureDispatch(State, self, target, args);
    } else {
        try setCoroutineResumeValues(State, self, target, args);
    }

    while (true) {
        self.runThreadUntil(target, 0) catch |err| switch (err) {
            error.CoroutineYield => return .{ .success = try copyValues(State, self, target.yield_values.items) },
            error.CoroutineClose => return .{ .success = try copyValues(State, self, &.{}) },
            error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => {
                const error_value = self.currentErrorValue();
                const completed = self.completeProtectedContinuationError(target, error_value) catch |continuation_err| switch (continuation_err) {
                    error.CoroutineYield => return .{ .success = try copyValues(State, self, target.yield_values.items) },
                    else => return continuation_err,
                };
                if (completed) continue;
                var final_error = error_value;
                target.error_traceback = try self.snapshotCoroutineErrorTraceback(target);
                if (try closeCoroutine(State, self, target, final_error)) |close_error_value| final_error = close_error_value;
                target.close_error_value = final_error;
                target.status = .dead;
                return .{ .failure = final_error };
            },
            else => return err,
        };
        break;
    }

    target.status = .dead;
    target.close_error_value = null;
    target.error_traceback = null;
    if (target.entry == .native and target.entry.native == .dofile and target.last_result_count >= 2) {
        const values = target.stack.items[target.last_result_base .. target.last_result_base + target.last_result_count];
        if (values[0] == .native and values[0].native == .dofile and values[1] == .string) {
            return .{ .success = try copyValues(State, self, values[2..]) };
        }
    }
    return .{ .success = try copyStackSlice(State, self, target, target.last_result_base, target.last_result_count) };
}

pub fn startCoroutine(comptime State: type, self: *State, target: *Thread, args: []const Value) !void {
    const closure, const arg_count = switch (target.entry) {
        .closure => |closure| blk: {
            try target.ensureStack(self.allocator, 1 + args.len, self.stackValueLimit());
            target.stack.items[0] = .{ .closure = closure };
            for (args, 0..) |arg, index| target.stack.items[1 + index] = arg;
            break :blk .{ closure, args.len };
        },
        else => blk: {
            const trampoline = try callableEntryClosure(State, self);
            try target.ensureStack(self.allocator, 2 + args.len, self.stackValueLimit());
            target.stack.items[0] = .{ .closure = trampoline };
            target.stack.items[1] = target.entry;
            for (args, 0..) |arg, index| target.stack.items[2 + index] = arg;
            break :blk .{ trampoline, 1 + args.len };
        },
    };
    var frame = try self.prepareClosureFrame(target, closure, 0, 0, arg_count, 0, bytecode.multret_count);
    errdefer frame.deinit(self.allocator);
    try target.frames.append(self.allocator, frame);
    target.started = true;
    if (target.hook_call and !target.hook_running) try self.callHook(target, "call");
}

pub fn callableEntryClosure(comptime State: type, self: *State) !*Closure {
    const proto = try self.allocator.create(proto_mod.Proto);
    errdefer self.allocator.destroy(proto);
    proto.* = proto_mod.Proto.init(self.allocator);
    errdefer proto.deinit();
    proto.max_registers = 2;
    proto.param_count = 1;
    proto.is_vararg = true;
    proto.source_name = "=(coroutine entry)";
    _ = try proto.emit(.{ .vararg = .{ .dest = 1, .count = bytecode.multret_count } }, 0);
    _ = try proto.emit(.{ .call = .{ .base = 0, .arg_count = bytecode.multret_count, .return_count = bytecode.multret_count } }, 0);
    _ = try proto.emit(.{ .ret = .{ .first = 0, .count = bytecode.multret_count } }, 0);
    try self.proto_allocations.append(self.allocator, proto);

    const upvalues = try self.allocator.alloc(*Upvalue, 0);
    errdefer self.allocator.free(upvalues);
    const closure = try self.allocator.create(Closure);
    closure.* = .{ .proto = proto, .upvalues = upvalues };
    errdefer self.destroyClosure(closure);
    try self.closure_allocations.append(self.allocator, closure);
    self.noteAllocation(@sizeOf(Closure));
    return closure;
}

pub fn setCoroutineResumeValues(comptime State: type, self: *State, target: *Thread, args: []const Value) !void {
    const actual_count = try self.resolveReturnCount(target.yield_result_count, args.len);
    try target.ensureStack(self.allocator, target.yield_result_base + actual_count, self.stackValueLimit());
    for (0..actual_count) |index| {
        target.stack.items[target.yield_result_base + index] = if (index < args.len) args[index] else .nil;
    }
    target.last_result_base = target.yield_result_base;
    target.last_result_count = actual_count;
}

pub fn returnCoroutineResumeResult(comptime State: type, self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, result: CoroutineResumeResult) !void {
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

pub fn copyValues(comptime State: type, self: *State, values: []const Value) ![]Value {
    const copied = try self.allocator.alloc(Value, values.len);
    @memcpy(copied, values);
    return copied;
}

pub fn copyStackSlice(comptime State: type, self: *State, thread: *Thread, base: usize, count: usize) ![]Value {
    const values = try self.allocator.alloc(Value, count);
    for (values, 0..) |*value, index| value.* = thread.stack.items[base + index];
    return values;
}
