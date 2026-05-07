const std = @import("std");
const compile = @import("compile.zig");
const chunk_mod = @import("runtime/chunk.zig");
const errors = @import("errors.zig");
const frontend = @import("frontend.zig");
const host = @import("runtime/host.zig");
const process = @import("testing/process.zig");
const stdlib = @import("stdlib.zig");
const types = @import("runtime/types.zig");
const value_mod = @import("runtime/value.zig");

const bytecode = compile.bytecode;
const proto_mod = compile.proto;

pub const RuntimeError = types.RuntimeError;

const default_max_stack_values: usize = 65536;
const default_max_call_frames: usize = 256;
const max_error_handler_depth: usize = 200;
const max_metamethod_depth: usize = 15;
pub const binary_chunk_signature = chunk_mod.binary_chunk_signature;
pub const binary_chunk_payload_magic = chunk_mod.binary_chunk_payload_magic;

pub const Value = types.Value;
pub const NativeFn = types.NativeFn;
pub const UserdataFinalizer = types.UserdataFinalizer;
pub const UserdataDeinit = types.UserdataDeinit;
pub const ProtectedCallResult = types.ProtectedCallResult;
pub const ApiCallbackDispatchFn = types.ApiCallbackDispatchFn;
pub const CClosureDispatchFn = types.CClosureDispatchFn;
pub const CClosureResumeDispatchFn = types.CClosureResumeDispatchFn;
pub const CDebugHookDispatchFn = types.CDebugHookDispatchFn;
pub const DebugHookEvent = types.DebugHookEvent;
pub const CDebugHookContext = types.CDebugHookContext;
pub const CClosureContext = types.CClosureContext;
pub const CClosureResumeContext = types.CClosureResumeContext;
pub const ApiCallbackContext = types.ApiCallbackContext;
pub const RuntimeErrorPayload = types.RuntimeErrorPayload;
const ProtectedCallContext = types.ProtectedCallContext;
const ProtectedContinuationKind = types.ProtectedContinuationKind;
const ProtectedContinuation = types.ProtectedContinuation;
const GenericForContinuation = types.GenericForContinuation;
const BranchContinuation = types.BranchContinuation;
const TailCallContinuation = types.TailCallContinuation;
const CallOneContinuationResult = types.CallOneContinuationResult;
const CallOneContinuation = types.CallOneContinuation;
const BinaryChunkReader = chunk_mod.BinaryChunkReader(State);

pub const appendBinaryChunkHeader = chunk_mod.appendBinaryChunkHeader;
pub const dumpClosureBinary = chunk_mod.dumpClosureBinary;

const CoroutineResumeResult = types.CoroutineResumeResult;
pub const Closure = types.Closure;
pub const CClosure = types.CClosure;
pub const CUpvalue = types.CUpvalue;
pub const Upvalue = types.Upvalue;
const TableEntry = types.TableEntry;
const TableEntryIndex = types.TableEntryIndex;
pub const Table = types.Table;
pub const Userdata = types.Userdata;
pub const Thread = types.Thread;
const ThreadStatus = types.ThreadStatus;
const CallFrame = types.CallFrame;
const StringAllocation = types.StringAllocation;
const PointerAllocationIndex = types.PointerAllocationIndex;
pub const GcMode = types.GcMode;
pub const GcParam = types.GcParam;
const GcParams = types.GcParams;
const WeakMode = types.WeakMode;
const RuntimeAllocationStats = types.RuntimeAllocationStats;

pub const StdlibMode = stdlib.LibrarySelection;
pub const MemoryFile = host.MemoryFile;
pub const MemoryFilesystem = host.MemoryFilesystem;
pub const FilesystemCapability = host.FilesystemCapability;
pub const ClockCapability = host.ClockCapability;
pub const ProcessCapability = host.ProcessCapability;

pub const StateOptions = struct {
    stdlib: StdlibMode = .full,
    io: ?std.Io = null,
    stdout: ?*std.Io.Writer = null,
    stderr: ?*std.Io.Writer = null,
    filesystem: FilesystemCapability = .disabled,
    environment: ?*const std.process.Environ.Map = null,
    clock: ClockCapability = .system,
    process: ProcessCapability = .disabled,
    stdin: []const u8 = "",
    max_memory: ?usize = null,
    max_stack_values: ?usize = null,
    max_call_frames: ?usize = null,
    max_instructions: ?u64 = null,
    debug_errors: bool = false,
    trace_vm: bool = false,
};

pub const ExecuteOptions = struct {
    collect_after_instruction: bool = false,
    state: StateOptions = .{},
};

pub const State = struct {
    allocator: std.mem.Allocator,
    globals: std.StringHashMap(Value),
    global_table: ?*Table = null,
    strings: std.StringHashMap([]const u8),
    string_allocations: std.ArrayList(StringAllocation) = .empty,
    string_allocation_index: PointerAllocationIndex,
    table_allocations: std.ArrayList(*Table) = .empty,
    table_allocation_index: PointerAllocationIndex,
    table_metatable_head: ?*Table = null,
    table_metatable_count: usize = 0,
    userdata_allocations: std.ArrayList(*Userdata) = .empty,
    closure_allocations: std.ArrayList(*Closure) = .empty,
    c_closure_allocations: std.ArrayList(*CClosure) = .empty,
    upvalue_allocations: std.ArrayList(*Upvalue) = .empty,
    c_upvalue_allocations: std.ArrayList(*CUpvalue) = .empty,
    thread_allocations: std.ArrayList(*Thread) = .empty,
    proto_allocations: std.ArrayList(*proto_mod.Proto) = .empty,
    source_allocations: std.ArrayList([]const u8) = .empty,
    api_roots: std.ArrayList(Value) = .empty,
    stdout: std.ArrayList(u8) = .empty,
    stderr: std.ArrayList(u8) = .empty,
    options: StateOptions,
    stdin_pos: usize = 0,
    last_error: ?RuntimeErrorPayload = null,
    last_error_in_close: bool = false,
    traceback_error_in_close: bool = false,
    current_thread: ?*Thread = null,
    api_callback_dispatch: ?ApiCallbackDispatchFn = null,
    api_callback_user_data: ?*anyopaque = null,
    c_closure_dispatch: ?CClosureDispatchFn = null,
    c_closure_resume_dispatch: ?CClosureResumeDispatchFn = null,
    c_debug_hook_dispatch: ?CDebugHookDispatchFn = null,
    c_closure_user_data: ?*anyopaque = null,
    coroutine_close_depth: usize = 0,
    string_metatable: ?*Table = null,
    number_metatable: ?*Table = null,
    boolean_metatable: ?*Table = null,
    nil_metatable: ?*Table = null,
    is_collecting: bool = false,
    collect_after_instruction: bool = false,
    gc_running: bool = true,
    gc_mode: GcMode = .generational,
    gc_params: GcParams = .{},
    gc_next_total: usize = 0,
    gc_known_total: usize = 0,
    mark_all_stack_registers: bool = false,
    conservative_gc_depth: usize = 0,
    random_state: [4]u64 = .{ 0x123456789abcdef0, 0xff, 0xfedcba9876543210, 0 },
    instruction_count: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) !State {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: StateOptions) !State {
        var state = State{
            .allocator = allocator,
            .globals = std.StringHashMap(Value).init(allocator),
            .strings = std.StringHashMap([]const u8).init(allocator),
            .string_allocation_index = PointerAllocationIndex.init(allocator),
            .table_allocation_index = PointerAllocationIndex.init(allocator),
            .options = options,
        };
        errdefer state.deinit();
        try stdlib.openLibraries(&state, options.stdlib);
        if (!options.stdlib.isEmpty()) try stdlib.installGlobalTable(&state);
        state.resetAutoGcThreshold();
        return state;
    }

    fn stackValueLimit(self: *const State) usize {
        return if (self.options.max_stack_values) |limit| @min(limit, default_max_stack_values) else default_max_stack_values;
    }

    fn callFrameLimit(self: *const State) usize {
        return if (self.options.max_call_frames) |limit| @min(limit, default_max_call_frames) else default_max_call_frames;
    }

    pub fn fileMetatable(state: *State) !*Table {
        const value = try state.newTableWithHints(0, 3);
        try state.setTableRaw(value.table, .{ .string = try state.intern("__name") }, .{ .string = try state.intern("FILE*") });
        try state.setTableRaw(value.table, .{ .string = try state.intern("__close") }, .{ .native = .io_file_close });
        try state.setTableRaw(value.table, .{ .string = try state.intern("__gc") }, .{ .native = .io_file_close });
        return value.table;
    }

    pub fn deinit(self: *State) void {
        self.stdout.deinit(self.allocator);
        self.stderr.deinit(self.allocator);
        self.globals.deinit();
        self.strings.deinit();
        self.string_allocation_index.deinit();
        self.table_allocation_index.deinit();
        for (self.thread_allocations.items) |thread| self.destroyThread(thread);
        for (self.closure_allocations.items) |closure| self.destroyClosure(closure);
        for (self.c_closure_allocations.items) |closure| self.destroyCClosure(closure);
        for (self.upvalue_allocations.items) |upvalue| self.allocator.destroy(upvalue);
        for (self.c_upvalue_allocations.items) |upvalue| self.allocator.destroy(upvalue);
        for (self.userdata_allocations.items) |userdata| self.destroyUserdata(userdata);
        for (self.table_allocations.items) |table| self.destroyTable(table);
        for (self.proto_allocations.items) |proto| {
            proto.deinit();
            self.allocator.destroy(proto);
        }
        for (self.source_allocations.items) |source| self.allocator.free(source);
        for (self.string_allocations.items) |allocation| self.allocator.free(allocation.bytes);
        self.api_roots.deinit(self.allocator);
        self.source_allocations.deinit(self.allocator);
        self.proto_allocations.deinit(self.allocator);
        self.thread_allocations.deinit(self.allocator);
        self.upvalue_allocations.deinit(self.allocator);
        self.c_upvalue_allocations.deinit(self.allocator);
        self.closure_allocations.deinit(self.allocator);
        self.c_closure_allocations.deinit(self.allocator);
        self.userdata_allocations.deinit(self.allocator);
        self.table_allocations.deinit(self.allocator);
        self.string_allocations.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn execute(self: *State, proto: *const proto_mod.Proto) !void {
        try self.executeClosure(try self.newRootClosure(proto));
    }

    pub fn callLoadedClosure(self: *State, closure: *Closure, args: []const Value) ![]Value {
        var thread = Thread.initRoot(self.allocator, closure, self.stackValueLimit()) catch |err| switch (err) {
            error.StackOverflow => return self.fail("stack overflow"),
            else => return err,
        };
        defer thread.deinit(self.allocator);
        try self.setRootThreadArgs(&thread, args);
        thread.frames.items[0].return_count = bytecode.multret_count;
        const previous_thread = self.current_thread;
        self.current_thread = &thread;
        defer self.current_thread = previous_thread;
        self.runThreadUntil(&thread, 0) catch |err| {
            if (err == error.StackOverflow and self.last_error == null) self.last_error = .{ .diagnostic = "stack overflow" };
            if (self.options.debug_errors and isRuntimeError(err)) self.appendUnhandledErrorDebugDump(&thread, err) catch {};
            self.closeFramesTo(&thread, 0, self.currentErrorValue()) catch |close_err| return close_err;
            thread.status = .dead;
            return err;
        };
        thread.status = .dead;
        return self.copyStackSlice(&thread, thread.last_result_base, thread.last_result_count);
    }

    pub fn protectedCallLoadedClosure(self: *State, closure: *Closure, args: []const Value) !ProtectedCallResult {
        var thread = Thread.initRoot(self.allocator, closure, self.stackValueLimit()) catch |err| switch (err) {
            error.StackOverflow => return .{ .failure = .{ .string = try self.intern("stack overflow") } },
            else => return err,
        };
        defer thread.deinit(self.allocator);
        try self.setRootThreadArgs(&thread, args);
        thread.frames.items[0].return_count = bytecode.multret_count;
        const previous_thread = self.current_thread;
        self.current_thread = &thread;
        defer self.current_thread = previous_thread;

        self.last_error = null;
        self.last_error_in_close = false;
        self.runThreadUntil(&thread, 0) catch |err| switch (err) {
            error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => {
                if (err == error.StackOverflow and self.last_error == null) self.last_error = .{ .diagnostic = "stack overflow" };
                if (self.options.debug_errors) self.appendUnhandledErrorDebugDump(&thread, err) catch {};
                var failure = self.currentErrorValue();
                self.closeFramesTo(&thread, 0, failure) catch |close_err| switch (close_err) {
                    error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => failure = self.currentErrorValue(),
                    else => return close_err,
                };
                thread.status = .dead;
                return .{ .failure = failure };
            },
            else => return err,
        };
        thread.status = .dead;
        return .{ .success = try self.copyStackSlice(&thread, thread.last_result_base, thread.last_result_count) };
    }

    pub fn executeSourceChunk(self: *State, source: []const u8) !void {
        const loaded = try self.loadSourceAsClosure(source);
        try self.executeClosure(loaded.closure);
    }

    pub fn executeSourceChunkNamed(self: *State, source: []const u8, source_name: []const u8) !void {
        const loaded = try self.loadSourceAsClosureNamed(source, source_name);
        try self.executeClosure(loaded.closure);
    }

    fn executeClosure(self: *State, closure: *Closure) !void {
        var thread = Thread.initRoot(self.allocator, closure, self.stackValueLimit()) catch |err| switch (err) {
            error.StackOverflow => return self.fail("stack overflow"),
            else => return err,
        };
        defer thread.deinit(self.allocator);
        const previous_thread = self.current_thread;
        self.current_thread = &thread;
        defer self.current_thread = previous_thread;
        self.runThreadUntil(&thread, 0) catch |err| {
            if (err == error.StackOverflow and self.last_error == null) self.last_error = .{ .diagnostic = "stack overflow" };
            if (self.options.debug_errors and isRuntimeError(err)) self.appendUnhandledErrorDebugDump(&thread, err) catch {};
            self.closeFramesTo(&thread, 0, self.currentErrorValue()) catch |close_err| return close_err;
            thread.status = .dead;
            return err;
        };
        thread.status = .dead;
    }

    fn runThreadUntil(self: *State, thread: *Thread, target_frame_count: usize) anyerror!void {
        while (thread.frames.items.len > target_frame_count) {
            if (thread.pending_unwind_error != null and thread.frames.items.len == thread.pending_unwind_resume_frame_count) {
                const error_value = thread.pending_unwind_error.?;
                const target = thread.pending_unwind_target_frame_count;
                thread.pending_unwind_error = null;
                try self.closeFramesTo(thread, target, error_value);
                return self.throwValue(error_value);
            }
            if (try self.completeReadyCallOneContinuation(thread)) continue;
            if (try self.completeReadyProtectedContinuation(thread)) continue;
            if (try self.completeReadyTailCallContinuation(thread)) continue;
            if (try self.completeReadyGenericForContinuation(thread)) continue;
            if (thread.pending_yield_hook_return) {
                thread.pending_yield_hook_return = false;
                try self.callHook(thread, "return");
                continue;
            }
            var frame = &thread.frames.items[thread.frames.items.len - 1];
            const proto = frame.proto;
            if (frame.pc >= proto.instructions.items.len) {
                try self.returnFromFrame(thread, 0, 0);
                continue;
            }
            const pc = frame.pc;
            const instruction = proto.instructions.items[pc];
            if (plainFastLoopCanStart(instruction) and self.runPlainFastLoop(thread, target_frame_count)) continue;
            frame.pc += 1;
            try self.checkExecutionLimits(thread);
            if (self.options.trace_vm) try self.traceInstruction(frame.*, pc, instruction);
            try self.callLineHook(thread);
            try self.callCountHook(thread);

            frame = &thread.frames.items[thread.frames.items.len - 1];
            const base = frame.base;
            const stack = thread.stack.items;

            switch (instruction) {
                .load_nil => |dest| stack[base + dest] = .nil,
                .load_bool => |op| stack[base + op.dest] = .{ .boolean = op.value },
                .load_const => |op| stack[base + op.dest] = try self.closureConstant(frame.closure, op.constant),
                .move => |op| stack[base + op.dest] = stack[base + op.source],
                .get_global => |op| stack[base + op.register] = self.getGlobalValue(constantString(proto, op.name)),
                .set_global => |op| try self.setGlobal(constantString(proto, op.name), stack[base + op.register]),
                .declare_global => |op| try self.declareGlobal(thread, constantString(proto, op.name), op.table, op.value),
                .add => |op| {
                    const lhs = stack[base + op.left];
                    const rhs = stack[base + op.right];
                    if (rawNumericBinaryOpFast(lhs, rhs, .add)) |value| {
                        stack[base + op.dest] = value;
                    } else {
                        try self.binaryOpToRegister(thread, op, .add);
                    }
                },
                .sub => |op| {
                    const lhs = stack[base + op.left];
                    const rhs = stack[base + op.right];
                    if (rawNumericBinaryOpFast(lhs, rhs, .sub)) |value| {
                        stack[base + op.dest] = value;
                    } else {
                        try self.binaryOpToRegister(thread, op, .sub);
                    }
                },
                .mul => |op| {
                    const lhs = stack[base + op.left];
                    const rhs = stack[base + op.right];
                    if (rawNumericBinaryOpFast(lhs, rhs, .mul)) |value| {
                        stack[base + op.dest] = value;
                    } else {
                        try self.binaryOpToRegister(thread, op, .mul);
                    }
                },
                .div => |op| {
                    const lhs = stack[base + op.left];
                    const rhs = stack[base + op.right];
                    if (rawNumericBinaryOpFast(lhs, rhs, .div)) |value| {
                        stack[base + op.dest] = value;
                    } else {
                        try self.binaryOpToRegister(thread, op, .div);
                    }
                },
                .idiv => |op| {
                    const lhs = stack[base + op.left];
                    const rhs = stack[base + op.right];
                    if (rawNumericBinaryOpFast(lhs, rhs, .idiv)) |value| {
                        stack[base + op.dest] = value;
                    } else {
                        try self.binaryOpToRegister(thread, op, .idiv);
                    }
                },
                .mod => |op| {
                    const lhs = stack[base + op.left];
                    const rhs = stack[base + op.right];
                    if (rawNumericBinaryOpFast(lhs, rhs, .mod)) |value| {
                        stack[base + op.dest] = value;
                    } else {
                        try self.binaryOpToRegister(thread, op, .mod);
                    }
                },
                .pow => |op| try self.binaryOpToRegister(thread, op, .pow),
                .band => |op| {
                    const lhs = stack[base + op.left];
                    const rhs = stack[base + op.right];
                    if (rawIntegerBitwiseOpFast(lhs, rhs, .band)) |value| {
                        stack[base + op.dest] = value;
                    } else {
                        try self.binaryOpToRegister(thread, op, .band);
                    }
                },
                .bor => |op| {
                    const lhs = stack[base + op.left];
                    const rhs = stack[base + op.right];
                    if (rawIntegerBitwiseOpFast(lhs, rhs, .bor)) |value| {
                        stack[base + op.dest] = value;
                    } else {
                        try self.binaryOpToRegister(thread, op, .bor);
                    }
                },
                .bxor => |op| {
                    const lhs = stack[base + op.left];
                    const rhs = stack[base + op.right];
                    if (rawIntegerBitwiseOpFast(lhs, rhs, .bxor)) |value| {
                        stack[base + op.dest] = value;
                    } else {
                        try self.binaryOpToRegister(thread, op, .bxor);
                    }
                },
                .shl => |op| {
                    const lhs = stack[base + op.left];
                    const rhs = stack[base + op.right];
                    if (rawIntegerBitwiseOpFast(lhs, rhs, .shl)) |value| {
                        stack[base + op.dest] = value;
                    } else {
                        try self.binaryOpToRegister(thread, op, .shl);
                    }
                },
                .shr => |op| {
                    const lhs = stack[base + op.left];
                    const rhs = stack[base + op.right];
                    if (rawIntegerBitwiseOpFast(lhs, rhs, .shr)) |value| {
                        stack[base + op.dest] = value;
                    } else {
                        try self.binaryOpToRegister(thread, op, .shr);
                    }
                },
                .unm => |op| try self.unaryOpToRegister(thread, op, .unm),
                .bnot => |op| try self.unaryOpToRegister(thread, op, .bnot),
                .concat => |op| try self.binaryOpToRegister(thread, op, .concat),
                .eq => |op| {
                    const lhs = stack[base + op.left];
                    const rhs = stack[base + op.right];
                    if (lhs != .table or rhs != .table) {
                        stack[base + op.dest] = .{ .boolean = valuesEqual(lhs, rhs) };
                    } else {
                        try self.equalValuesToRegister(thread, op);
                    }
                },
                .lt => |op| {
                    const lhs = stack[base + op.left];
                    const rhs = stack[base + op.right];
                    if (rawCompare(lhs, rhs, .lt)) |result| {
                        stack[base + op.dest] = .{ .boolean = result };
                    } else {
                        try self.compareValuesToRegister(thread, op, .lt);
                    }
                },
                .le => |op| {
                    const lhs = stack[base + op.left];
                    const rhs = stack[base + op.right];
                    if (rawCompare(lhs, rhs, .le)) |result| {
                        stack[base + op.dest] = .{ .boolean = result };
                    } else {
                        try self.compareValuesToRegister(thread, op, .le);
                    }
                },
                .not => |op| stack[base + op.dest] = .{ .boolean = !truthy(stack[base + op.source]) },
                .len => |op| try self.lengthToRegister(thread, op),
                .new_table => |op| stack[base + op.dest] = try self.newTableWithHints(op.array_hint, op.hash_hint),
                .set_list => |op| try self.setList(thread, op),
                .get_table => |op| {
                    const table_value = stack[base + op.table];
                    const key_value = stack[base + op.key];
                    if (fastTableRawGet(table_value, key_value)) |value| {
                        stack[base + op.dest] = value;
                    } else {
                        try self.getTableToRegister(thread, op.dest, table_value, key_value);
                    }
                },
                .set_table => |op| {
                    const table_value = stack[base + op.table];
                    const key_value = stack[base + op.key];
                    const value = stack[base + op.value];
                    if (!try self.fastTableArraySet(table_value, key_value, value)) {
                        if (key_value != .string or !try self.fastTableKnownKeySet(table_value, key_value, value)) {
                            try self.setTableFromThreadContinuable(thread, table_value, key_value, value);
                        }
                    }
                },
                .set_array => |op| {
                    const table_value = stack[base + op.table];
                    const value = stack[base + op.value];
                    if (table_value == .table and op.index != 0) {
                        try self.setTableArrayRawIndex(table_value.table, op.index, value);
                    } else {
                        try self.setTableFromThreadContinuable(thread, table_value, .{ .integer = @intCast(op.index) }, value);
                    }
                },
                .get_field => |op| {
                    const table_value = stack[base + op.table];
                    const key = Value{ .string = constantString(proto, op.name) };
                    if (fastTableRawGet(table_value, key)) |value| {
                        stack[base + op.dest] = value;
                    } else {
                        try self.getTableToRegister(thread, op.dest, table_value, key);
                    }
                },
                .set_field => |op| {
                    const table_value = stack[base + op.table];
                    const key = Value{ .string = constantString(proto, op.name) };
                    const value = stack[base + op.value];
                    if (!try self.fastTableKnownKeySet(table_value, key, value)) {
                        try self.setTableFromThreadContinuable(thread, table_value, key, value);
                    }
                },
                .jmp => |offset| try self.jumpThreadMaybeFast(thread, offset, true),
                .compare_branch => |op| {
                    const lhs = stack[base + op.left];
                    const rhs = stack[base + op.right];
                    if (rawCompareBranchResult(lhs, rhs, op.op)) |result| {
                        if (result == op.jump_if_truthy) try self.jumpThreadMaybeFast(thread, op.offset, true);
                    } else {
                        try self.compareBranch(thread, op);
                    }
                },
                .test_op => |op| if (truthy(stack[base + op.register]) == op.jump_if_truthy) {
                    try self.jumpThreadMaybeFast(thread, op.offset, true);
                },
                .test_set => |op| {
                    const value = stack[base + op.source];
                    stack[base + op.dest] = value;
                    if (truthy(value) == op.jump_if_truthy) {
                        try self.jumpThreadMaybeFast(thread, op.offset, true);
                    }
                },
                .call => |op| try self.callValue(thread, op),
                .tail_call => |op| try self.tailCallValue(thread, op),
                .ret => |op| try self.returnFromFrame(thread, op.first, op.count),
                .vararg => |op| try self.loadVarargs(thread, op),
                .for_prep => |op| try self.forPrep(thread, op),
                .for_loop => |op| try self.forLoop(thread, op),
                .tfor_prep => |op| if (!(try self.advanceGenericFor(thread, op, true))) try self.jumpThread(thread, op.offset, false),
                .tfor_call => |op| _ = try self.advanceGenericFor(thread, op, false),
                .tfor_loop => |op| try self.jumpThread(thread, op.offset, false),
                .closure => |op| stack[base + op.dest] = try self.newClosure(thread, proto.children.items[op.proto]),
                .get_upvalue => |op| stack[base + op.register] = self.readUpvalue(thread, op.upvalue),
                .set_upvalue => |op| self.writeUpvalue(thread, op.upvalue, stack[base + op.register]),
                .close => |register| if (thread.open_upvalues != null) self.closeUpvalues(thread, base + register),
                .check_close => |register| try self.checkToBeClosedRegister(thread, register),
                .close_tbc => |register| try self.closeToBeClosedRegister(thread, register, null),
            }

            if (!instructionPreservesLastResult(instruction)) {
                thread.last_result_count = 0;
                thread.last_transfer_count = 0;
            }

            if (self.gc_running and (self.collect_after_instruction or self.shouldRunAutoGc())) try self.collectGarbageConservatively(thread);
        }
    }

    fn runPlainFastLoop(self: *State, thread: *Thread, target_frame_count: usize) bool {
        if (thread.frames.items.len <= target_frame_count) return false;
        if (self.options.max_instructions != null or self.options.max_memory != null or self.options.trace_vm) return false;
        if (self.collect_after_instruction) return false;
        if (thread.hook != .nil and (thread.hook_line or thread.hook_count != 0 or thread.hook_running)) return false;
        if (self.gc_running and self.shouldRunAutoGc()) return false;

        const frame_index = thread.frames.items.len - 1;
        var frame = &thread.frames.items[frame_index];
        if (frame.proto.has_to_close_locals) return false;
        const proto = frame.proto;
        const instructions = proto.instructions.items;
        const base = frame.base;
        var pc = frame.pc;
        var stack = thread.stack.items;
        var executed = false;

        fast_loop: while (pc < instructions.len) {
            switch (instructions[pc]) {
                .load_nil => |dest| {
                    stack[base + dest] = .nil;
                    pc += 1;
                },
                .load_bool => |op| {
                    stack[base + op.dest] = .{ .boolean = op.value };
                    pc += 1;
                },
                .load_const => |op| {
                    const constants = frame.closure.constants orelse break :fast_loop;
                    stack[base + op.dest] = constants[op.constant] orelse break :fast_loop;
                    pc += 1;
                },
                .move => |op| {
                    stack[base + op.dest] = stack[base + op.source];
                    pc += 1;
                },
                .add => |op| {
                    const value = rawNumericBinaryOpFast(stack[base + op.left], stack[base + op.right], .add) orelse break :fast_loop;
                    stack[base + op.dest] = value;
                    pc += 1;
                },
                .sub => |op| {
                    const value = rawNumericBinaryOpFast(stack[base + op.left], stack[base + op.right], .sub) orelse break :fast_loop;
                    stack[base + op.dest] = value;
                    pc += 1;
                },
                .mul => |op| {
                    const value = rawNumericBinaryOpFast(stack[base + op.left], stack[base + op.right], .mul) orelse break :fast_loop;
                    stack[base + op.dest] = value;
                    pc += 1;
                },
                .div => |op| {
                    const value = rawNumericBinaryOpFast(stack[base + op.left], stack[base + op.right], .div) orelse break :fast_loop;
                    stack[base + op.dest] = value;
                    pc += 1;
                },
                .idiv => |op| {
                    const value = rawNumericBinaryOpFast(stack[base + op.left], stack[base + op.right], .idiv) orelse break :fast_loop;
                    stack[base + op.dest] = value;
                    pc += 1;
                },
                .mod => |op| {
                    const value = rawNumericBinaryOpFast(stack[base + op.left], stack[base + op.right], .mod) orelse break :fast_loop;
                    stack[base + op.dest] = value;
                    pc += 1;
                },
                .band => |op| {
                    const value = rawIntegerBitwiseOpFast(stack[base + op.left], stack[base + op.right], .band) orelse break :fast_loop;
                    stack[base + op.dest] = value;
                    pc += 1;
                },
                .bor => |op| {
                    const value = rawIntegerBitwiseOpFast(stack[base + op.left], stack[base + op.right], .bor) orelse break :fast_loop;
                    stack[base + op.dest] = value;
                    pc += 1;
                },
                .bxor => |op| {
                    const value = rawIntegerBitwiseOpFast(stack[base + op.left], stack[base + op.right], .bxor) orelse break :fast_loop;
                    stack[base + op.dest] = value;
                    pc += 1;
                },
                .shl => |op| {
                    const value = rawIntegerBitwiseOpFast(stack[base + op.left], stack[base + op.right], .shl) orelse break :fast_loop;
                    stack[base + op.dest] = value;
                    pc += 1;
                },
                .shr => |op| {
                    const value = rawIntegerBitwiseOpFast(stack[base + op.left], stack[base + op.right], .shr) orelse break :fast_loop;
                    stack[base + op.dest] = value;
                    pc += 1;
                },
                .eq => |op| {
                    const lhs = stack[base + op.left];
                    const rhs = stack[base + op.right];
                    if (lhs == .table and rhs == .table and !valuesEqual(lhs, rhs)) break :fast_loop;
                    stack[base + op.dest] = .{ .boolean = valuesEqual(lhs, rhs) };
                    pc += 1;
                },
                .lt => |op| {
                    const result = rawCompare(stack[base + op.left], stack[base + op.right], .lt) orelse break :fast_loop;
                    stack[base + op.dest] = .{ .boolean = result };
                    pc += 1;
                },
                .le => |op| {
                    const result = rawCompare(stack[base + op.left], stack[base + op.right], .le) orelse break :fast_loop;
                    stack[base + op.dest] = .{ .boolean = result };
                    pc += 1;
                },
                .not => |op| {
                    stack[base + op.dest] = .{ .boolean = !truthy(stack[base + op.source]) };
                    pc += 1;
                },
                .len => |op| {
                    const value = fastLengthNoMetamethod(stack[base + op.source]) orelse break :fast_loop;
                    stack[base + op.dest] = value;
                    pc += 1;
                },
                .get_table => |op| {
                    const value = fastTableRawGet(stack[base + op.table], stack[base + op.key]) orelse break :fast_loop;
                    stack[base + op.dest] = value;
                    pc += 1;
                },
                .get_field => |op| {
                    const key = Value{ .string = constantString(proto, op.name) };
                    const value = fastTableRawGet(stack[base + op.table], key) orelse break :fast_loop;
                    stack[base + op.dest] = value;
                    pc += 1;
                },
                .set_table => |op| {
                    if (!self.fastTableArraySetExistingNoAlloc(stack[base + op.table], stack[base + op.key], stack[base + op.value]) and
                        !self.fastTableKnownKeySetExistingNoAlloc(stack[base + op.table], stack[base + op.key], stack[base + op.value])) break :fast_loop;
                    pc += 1;
                },
                .set_field => |op| {
                    const key = Value{ .string = constantString(proto, op.name) };
                    if (!self.fastTableKnownKeySetExistingNoAlloc(stack[base + op.table], key, stack[base + op.value])) break :fast_loop;
                    pc += 1;
                },
                .compare_branch => |op| {
                    const result = rawCompareBranchResult(stack[base + op.left], stack[base + op.right], op.op) orelse break :fast_loop;
                    pc += 1;
                    if (result == op.jump_if_truthy) {
                        const source_pc = pc;
                        pc = jumpTarget(source_pc, op.offset);
                        if (pc < source_pc) frame.last_hook_line = null;
                    }
                },
                .jmp => |offset| {
                    pc += 1;
                    const source_pc = pc;
                    pc = jumpTarget(source_pc, offset);
                    if (pc < source_pc) frame.last_hook_line = null;
                },
                .test_op => |op| {
                    pc += 1;
                    if (truthy(stack[base + op.register]) == op.jump_if_truthy) {
                        const source_pc = pc;
                        pc = jumpTarget(source_pc, op.offset);
                        if (pc < source_pc) frame.last_hook_line = null;
                    }
                },
                .test_set => |op| {
                    const value = stack[base + op.source];
                    stack[base + op.dest] = value;
                    pc += 1;
                    if (truthy(value) == op.jump_if_truthy) {
                        const source_pc = pc;
                        pc = jumpTarget(source_pc, op.offset);
                        if (pc < source_pc) frame.last_hook_line = null;
                    }
                },
                .for_loop => |op| {
                    const absolute_base = base + op.base;
                    const current = stack[absolute_base];
                    const limit = stack[absolute_base + 1];
                    const step = stack[absolute_base + 2];
                    if (current != .integer or limit != .integer or step != .integer) break :fast_loop;
                    const next = current.integer +% step.integer;
                    stack[absolute_base] = .{ .integer = next };
                    pc += 1;
                    const wrapped = (step.integer > 0 and next < current.integer) or (step.integer < 0 and next > current.integer);
                    if (!wrapped and forLoopContinuesInteger(next, limit.integer, step.integer)) {
                        const source_pc = pc;
                        pc = jumpTarget(source_pc, op.offset);
                        if (pc < source_pc) frame.last_hook_line = null;
                    }
                },
                .close => |register| {
                    _ = register;
                    if (thread.open_upvalues != null) break :fast_loop;
                    pc += 1;
                },
                else => break :fast_loop,
            }
            executed = true;
        }

        if (!executed) return false;
        frame = &thread.frames.items[frame_index];
        frame.pc = pc;
        thread.last_result_count = 0;
        thread.last_transfer_count = 0;
        return true;
    }

    fn checkExecutionLimits(self: *State, thread: *Thread) !void {
        if (self.options.max_instructions) |max_instructions| {
            if (self.instruction_count >= max_instructions) return self.failRuntimeDetail(thread, "instruction limit exceeded");
            self.instruction_count += 1;
        }

        if (self.options.max_memory) |max_memory| {
            if (self.refreshAllocationTotal() <= max_memory) return;
            if (self.gc_running and !self.is_collecting) try self.collectGarbageConservatively(thread);
            if (self.refreshAllocationTotal() > max_memory) return self.failRuntimeDetail(thread, "memory limit exceeded");
        }
    }

    fn noteAllocation(self: *State, bytes: usize) void {
        self.gc_known_total = self.gc_known_total +| bytes;
    }

    fn noteAllocationFreed(self: *State, bytes: usize) void {
        self.gc_known_total = if (bytes > self.gc_known_total) 0 else self.gc_known_total - bytes;
    }

    fn refreshAllocationTotal(self: *State) usize {
        const total = self.allocationStats().total();
        self.gc_known_total = total;
        return total;
    }

    fn currentAllocationTotal(self: *State) usize {
        return self.gc_known_total;
    }

    fn tableCapacityBytes(table: *const Table) usize {
        return table.array.capacity * @sizeOf(Value) + table.entries.capacity * @sizeOf(TableEntry);
    }

    fn tableGcBytes(table: *const Table) usize {
        if (!table.counts_for_gc_count) return 0;
        return @sizeOf(Table) + tableCapacityBytes(table);
    }

    fn noteTableCapacityDelta(self: *State, table: *const Table, old_capacity_bytes: usize) void {
        if (!table.counts_for_gc_count) return;
        const new_capacity_bytes = tableCapacityBytes(table);
        if (new_capacity_bytes > old_capacity_bytes) self.noteAllocation(new_capacity_bytes - old_capacity_bytes);
    }

    fn setTableRaw(self: *State, table: *Table, key: Value, value: Value) !void {
        const old_capacity_bytes = tableCapacityBytes(table);
        try table.set(self.allocator, key, value);
        self.noteTableCapacityDelta(table, old_capacity_bytes);
    }

    fn fastTableArraySet(self: *State, table_value: Value, key_value: Value, value: Value) !bool {
        if (table_value != .table) return false;
        const index = arrayIndex(key_value) orelse return false;
        if (index > std.math.maxInt(u32)) return false;
        return self.fastTableArraySetIndex(table_value, @intCast(index), value);
    }

    fn fastTableArraySetExistingNoAlloc(self: *State, table_value: Value, key_value: Value, value: Value) bool {
        if (self.is_collecting) return false;
        if (table_value != .table) return false;
        const index = arrayIndex(key_value) orelse return false;
        const table = table_value.table;
        if (index <= table.array.items.len) {
            const slot = &table.array.items[index - 1];
            if (slot.* == .nil and table.metatable != null) return false;
            slot.* = value;
            return true;
        }
        if (table.metatable != null or value == .nil) return false;
        if (index == table.array.items.len + 1 and index <= table.array.capacity) {
            table.array.appendAssumeCapacity(value);
            table.removeHashKey(key_value);
            return true;
        }
        return false;
    }

    fn fastTableKnownKeySetExistingNoAlloc(self: *State, table_value: Value, key: Value, value: Value) bool {
        if (self.is_collecting) return false;
        if (table_value != .table or key != .string) return false;
        const table = table_value.table;
        const index = table.entry_index.get(key) orelse return false;
        const slot = &table.entries.items[index].value;
        if (slot.* == .nil and table.metatable != null) return false;
        slot.* = value;
        return true;
    }

    fn fastTableArraySetIndex(self: *State, table_value: Value, index_u32: u32, value: Value) !bool {
        if (table_value != .table or index_u32 == 0) return false;
        const index: usize = index_u32;
        const key_value = Value{ .integer = @intCast(index_u32) };
        const table = table_value.table;
        if (index <= table.array.items.len) {
            const slot = &table.array.items[index - 1];
            if (slot.* != .nil or table.metatable == null) {
                slot.* = value;
                self.writeTableBarrier(table, key_value, value);
                return true;
            }
            return false;
        }
        if (table.metatable != null or value == .nil) return false;
        if (index == table.array.items.len + 1) {
            const old_capacity_bytes = tableCapacityBytes(table);
            try table.array.append(self.allocator, value);
            table.removeHashKey(key_value);
            self.noteTableCapacityDelta(table, old_capacity_bytes);
            self.writeTableBarrier(table, key_value, value);
            return true;
        }
        if (index > table.array.capacity) return false;

        const old_capacity_bytes = tableCapacityBytes(table);
        const old_len = table.array.items.len;
        try table.array.resize(self.allocator, index);
        @memset(table.array.items[old_len..], .nil);
        table.array.items[index - 1] = value;
        table.removeHashKey(key_value);
        self.noteTableCapacityDelta(table, old_capacity_bytes);
        self.writeTableBarrier(table, key_value, value);
        return true;
    }

    fn setTableArrayRawIndex(self: *State, table: *Table, index_u32: u32, value: Value) !void {
        const index: usize = index_u32;
        const key = Value{ .integer = @intCast(index_u32) };
        if (index <= table.array.items.len) {
            table.array.items[index - 1] = value;
            self.writeTableBarrier(table, key, value);
            return;
        }
        if (value == .nil) return;
        if (index == table.array.items.len + 1) {
            const old_capacity_bytes = tableCapacityBytes(table);
            try table.array.append(self.allocator, value);
            self.noteTableCapacityDelta(table, old_capacity_bytes);
            self.writeTableBarrier(table, key, value);
            return;
        }
        if (index <= table.array.capacity) {
            const old_capacity_bytes = tableCapacityBytes(table);
            const old_len = table.array.items.len;
            try table.array.resize(self.allocator, index);
            @memset(table.array.items[old_len..], .nil);
            table.array.items[index - 1] = value;
            self.noteTableCapacityDelta(table, old_capacity_bytes);
            self.writeTableBarrier(table, key, value);
            return;
        }
        try self.setTableRaw(table, key, value);
        self.writeTableBarrier(table, key, value);
    }

    fn fastTableKnownKeySet(self: *State, table_value: Value, key: Value, value: Value) !bool {
        if (table_value != .table) return false;
        const table = table_value.table;
        if (table.setExistingNonNil(key, value)) {
            self.writeTableBarrier(table, key, value);
            return true;
        }
        if (table.metatable != null) return false;
        if (value == .nil) return true;
        try self.setTableRaw(table, key, value);
        self.writeTableBarrier(table, key, value);
        return true;
    }

    fn traceInstruction(self: *State, frame: CallFrame, pc: usize, instruction: bytecode.Instruction) !void {
        const line = if (pc < frame.proto.line_info.items.len) frame.proto.line_info.items[pc].line else 0;
        try appendFmt(self.allocator, &self.stderr, "[trace-vm] {s}:{d} pc={d} op={s}\n", .{ frame.proto.source_name, line, pc, @tagName(instruction) });
    }

    fn get(_: *State, thread: *Thread, register: bytecode.Register) Value {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        return thread.stack.items[frame.base + register];
    }

    fn declareGlobal(self: *State, thread: *Thread, name: []const u8, table_register: bytecode.Register, value_register: bytecode.Register) !void {
        const table_value = self.get(thread, table_register);
        if (table_value != .table) return self.failRuntimeDetail(thread, "attempt to index a nil value");
        const key = Value{ .string = try self.intern(name) };
        if (table_value.table.get(key) != .nil) {
            const message = try std.fmt.allocPrint(self.allocator, "global '{s}' already defined", .{name});
            defer self.allocator.free(message);
            return self.fail(try self.intern(message));
        }
        try self.setTable(table_value, key, self.get(thread, value_register));
    }

    fn set(_: *State, thread: *Thread, register: bytecode.Register, value: Value) void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        thread.stack.items[frame.base + register] = value;
    }

    fn absoluteRegister(_: *State, thread: *Thread, register: bytecode.Register) usize {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        return frame.base + @as(usize, register);
    }

    fn setGlobal(self: *State, name: []const u8, value: Value) !void {
        const key = if (self.globals.contains(name)) name else try self.intern(name);
        try self.globals.put(key, value);
        if (self.global_table) |table| {
            try self.setTableRaw(table, .{ .string = key }, value);
            self.writeTableBarrier(table, .{ .string = key }, value);
        }
        self.markValue(value);
    }

    fn getGlobalValue(self: *State, name: []const u8) Value {
        if (self.global_table) |table| return table.get(.{ .string = name });
        return self.globals.get(name) orelse .nil;
    }

    pub fn getGlobal(self: *State, name: []const u8) Value {
        return self.getGlobalValue(name);
    }

    pub fn currentLine(self: *State, thread: *Thread, level: i64) ?usize {
        _ = self;
        if (level < 1) return null;
        const depth: usize = @intCast(level);
        if (depth > thread.frames.items.len) return null;
        const frame = thread.frames.items[thread.frames.items.len - depth];
        if (frame.proto.line_info.items.len == 0) return null;
        const pc = if (frame.pc == 0) @as(usize, 0) else frame.pc - 1;
        return frame.proto.line_info.items[@min(pc, frame.proto.line_info.items.len - 1)].line;
    }

    pub fn currentExtraArgs(self: *State, thread: *Thread, level: i64) ?usize {
        _ = self;
        if (level < 1) return null;
        const depth: usize = @intCast(level);
        if (depth > thread.frames.items.len) return null;
        const frame = thread.frames.items[thread.frames.items.len - depth];
        return frame.varargs.len;
    }

    pub fn currentWhat(self: *State, thread: *Thread, level: i64) []const u8 {
        _ = self;
        if (level == 2 and thread.protected_close_depth != 0) return "C";
        if (level >= 1) {
            const depth: usize = @intCast(level);
            if (depth <= thread.frames.items.len) {
                const frame = thread.frames.items[thread.frames.items.len - depth];
                if (frame.proto.defined_line == 0) return "main";
            }
        }
        return "Lua";
    }

    pub fn currentFunctionName(self: *State, thread: *Thread, level: i64) ?[]const u8 {
        _ = self;
        if (level == 2 and thread.protected_close_depth != 0) return "pcall";
        if (level == 2 and thread.hook_running) if (thread.hook_return_name) |name| return name;
        if (level < 1) return null;
        const depth: usize = @intCast(level);
        if (depth > thread.frames.items.len) return null;
        const frame = thread.frames.items[thread.frames.items.len - depth];
        const pc = if (frame.pc == 0) 0 else frame.pc - 1;
        for (frame.proto.locals.items) |local| {
            if (!std.mem.eql(u8, local.name, "name")) continue;
            if (pc < local.start_pc or (local.end_pc != 0 and pc > local.end_pc)) continue;
            const value = thread.stack.items[frame.base + local.register];
            if (value == .string) return value.string;
        }
        return frame.debug_name_override orelse frame.proto.debug_name;
    }

    pub fn currentFunctionNameWhat(self: *State, thread: *Thread, level: i64) ?[]const u8 {
        _ = self;
        if (level < 1) return null;
        const depth: usize = @intCast(level);
        if (depth > thread.frames.items.len) return null;
        const frame = thread.frames.items[thread.frames.items.len - depth];
        return frame.debug_namewhat_override;
    }

    pub fn setThreadHook(self: *State, target: *Thread, hook: Value, mask: []const u8, count: u32) void {
        _ = self;
        target.hook = hook;
        target.hook_call = false;
        target.hook_line = false;
        target.hook_return = false;
        target.hook_count = 0;
        target.hook_count_remaining = 0;
        target.pending_yield_hook_return = false;
        if (hook == .nil) return;
        target.hook_call = std.mem.indexOfScalar(u8, mask, 'c') != null;
        target.hook_line = std.mem.indexOfScalar(u8, mask, 'l') != null;
        target.hook_return = std.mem.indexOfScalar(u8, mask, 'r') != null;
        target.hook_count = count;
        target.hook_count_remaining = hookDispatchInterval(count);
        if (target.hook_line and target.frames.items.len != 0) {
            const frame_index = target.frames.items.len - 1;
            target.frames.items[frame_index].last_hook_line = lineForFrame(target.frames.items[frame_index]);
        }
    }

    pub fn threadHookMask(self: *State, thread: *Thread) ![]const u8 {
        var bytes: [3]u8 = undefined;
        var len: usize = 0;
        if (thread.hook_call) {
            bytes[len] = 'c';
            len += 1;
        }
        if (thread.hook_return) {
            bytes[len] = 'r';
            len += 1;
        }
        if (thread.hook_line) {
            bytes[len] = 'l';
            len += 1;
        }
        return self.intern(bytes[0..len]);
    }

    fn callHook(self: *State, thread: *Thread, event: []const u8) !void {
        if (self.c_debug_hook_dispatch) |dispatch| {
            var context = CDebugHookContext{
                .state = self,
                .thread = thread,
                .event = debugHookEvent(event),
                .currentline = if (std.mem.eql(u8, event, "line")) lineForFrame(thread.frames.items[thread.frames.items.len - 1]) else null,
                .ftransfer = thread.hook_transfer_index_base,
                .ntransfer = thread.hook_transfer_count,
                .user_data = self.c_closure_user_data,
            };
            return dispatch(&context);
        }
        const args = [_]Value{.{ .string = try self.intern(event) }};
        try self.callHookWithArgs(thread, &args);
    }

    fn callReturnHook(self: *State, thread: *Thread, name: ?[]const u8) !void {
        const previous = thread.hook_return_name;
        thread.hook_return_name = name;
        defer thread.hook_return_name = previous;
        try self.callHook(thread, "return");
    }

    fn callHookWithArgs(self: *State, thread: *Thread, args: []const Value) !void {
        if (thread.hook == .nil or thread.hook_running) return;
        thread.hook_running = true;
        defer thread.hook_running = false;
        self.conservative_gc_depth += 1;
        defer self.conservative_gc_depth -= 1;
        const previous_result_base = thread.last_result_base;
        const previous_result_count = thread.last_result_count;
        defer {
            thread.last_result_base = previous_result_base;
            thread.last_result_count = previous_result_count;
        }
        _ = try self.callOneResult(thread, thread.hook, args);
    }

    fn callLineHook(self: *State, thread: *Thread) !void {
        if (!thread.hook_line or thread.hook == .nil or thread.hook_running) return;
        if (thread.frames.items.len == 0) return;
        const frame_index = thread.frames.items.len - 1;
        const line = lineForFrame(thread.frames.items[frame_index]) orelse return;
        if (thread.frames.items[frame_index].last_hook_line == line) return;
        thread.frames.items[frame_index].last_hook_line = line;
        const line_value = if (thread.frames.items[frame_index].closure.stripped_debug) Value.nil else Value{ .integer = @intCast(line) };
        const args = [_]Value{ .{ .string = try self.intern("line") }, line_value };
        try self.callHookWithArgs(thread, &args);
    }

    fn callCountHook(self: *State, thread: *Thread) !void {
        if (thread.hook_count == 0 or thread.hook == .nil or thread.hook_running) return;
        if (thread.hook_count_remaining > 1) {
            thread.hook_count_remaining -= 1;
            return;
        }
        thread.hook_count_remaining = hookDispatchInterval(thread.hook_count);
        try self.callHook(thread, "count");
    }

    fn hookDispatchInterval(count: u32) u32 {
        return if (count == 0) 0 else count * 2;
    }

    pub fn putGlobal(self: *State, name: []const u8, value: Value) !void {
        try self.setGlobal(name, value);
    }

    pub fn rootValue(self: *State, value: Value) !usize {
        for (self.api_roots.items, 0..) |root, index| {
            if (root == .nil) {
                self.api_roots.items[index] = value;
                self.markValue(value);
                return index;
            }
        }
        try self.api_roots.append(self.allocator, value);
        self.markValue(value);
        return self.api_roots.items.len - 1;
    }

    pub fn unrootValue(self: *State, index: usize) void {
        if (index < self.api_roots.items.len) self.api_roots.items[index] = .nil;
    }

    pub fn rootedValue(self: *State, index: usize) Value {
        if (index >= self.api_roots.items.len) return .nil;
        return self.api_roots.items[index];
    }

    pub fn activeRootCount(self: State) usize {
        var count: usize = 0;
        for (self.api_roots.items) |root| {
            if (root != .nil) count += 1;
        }
        return count;
    }

    pub fn setApiCallbackDispatch(self: *State, dispatch: ApiCallbackDispatchFn, user_data: *anyopaque) void {
        self.api_callback_dispatch = dispatch;
        self.api_callback_user_data = user_data;
    }

    pub fn setCClosureDispatch(self: *State, dispatch: CClosureDispatchFn, user_data: *anyopaque) void {
        self.c_closure_dispatch = dispatch;
        self.c_closure_user_data = user_data;
    }

    pub fn setCClosureResumeDispatch(self: *State, dispatch: CClosureResumeDispatchFn) void {
        self.c_closure_resume_dispatch = dispatch;
    }

    pub fn setCDebugHookDispatch(self: *State, dispatch: CDebugHookDispatchFn) void {
        self.c_debug_hook_dispatch = dispatch;
    }

    pub fn newCClosure(self: *State, function_id: usize, upvalue_values: []const Value) !*CClosure {
        var upvalues: []*CUpvalue = if (upvalue_values.len == 0)
            &.{}
        else
            try self.allocator.alloc(*CUpvalue, upvalue_values.len);
        errdefer if (upvalues.len != 0) self.allocator.free(upvalues);

        for (upvalue_values, 0..) |value, index| {
            const upvalue = try self.allocator.create(CUpvalue);
            errdefer self.allocator.destroy(upvalue);
            upvalue.* = .{ .value = value };
            try self.c_upvalue_allocations.append(self.allocator, upvalue);
            self.noteAllocation(@sizeOf(CUpvalue));
            upvalues[index] = upvalue;
        }

        const closure = try self.allocator.create(CClosure);
        closure.* = .{ .function_id = function_id, .upvalues = upvalues };
        errdefer self.destroyCClosure(closure);
        try self.c_closure_allocations.append(self.allocator, closure);
        self.noteAllocation(@sizeOf(CClosure));
        return closure;
    }

    pub fn newCoroutine(self: *State, entry: Value) !*Thread {
        return self.newCoroutineThread(entry);
    }

    pub fn resumeThread(self: *State, target: *Thread, args: []const Value) !ProtectedCallResult {
        const result = try self.resumeCoroutine(target, args);
        return switch (result) {
            .success => |values| .{ .success = values },
            .failure => |value| .{ .failure = value },
        };
    }

    pub fn closeThread(self: *State, target: *Thread) !?Value {
        return self.closeCoroutine(target, null);
    }

    pub fn threadWasYielded(_: *State, target: *Thread) bool {
        return target.status == .suspended and target.started;
    }

    pub fn callCClosureDispatch(self: *State, thread: *Thread, op: bytecode.Call, closure: *CClosure) !void {
        const dispatch = self.c_closure_dispatch orelse return self.fail("C closure dispatcher unavailable");
        var context = CClosureContext{
            .state = self,
            .thread = thread,
            .op = op,
            .closure = closure,
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

        try self.returnValues(thread, op.base, op.return_count, context.returns.items);
    }

    fn resumeCClosureDispatch(self: *State, thread: *Thread, args: []const Value) !void {
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

    pub fn callApiCallbackDispatch(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const dispatch = self.api_callback_dispatch orelse return self.fail("host callback dispatcher unavailable");
        const id_value = argValue(self, thread, op, 0);
        const id_integer = toInteger(id_value) orelse return self.failArgumentType("__zlua_api_callback", 1, "integer", id_value);
        if (id_integer <= 0) return self.failArgumentMessage("__zlua_api_callback", 1, "out of range");
        const callback_id = std.math.cast(usize, id_integer) orelse return self.failArgumentMessage("__zlua_api_callback", 1, "out of range");

        var context = ApiCallbackContext{
            .state = self,
            .thread = thread,
            .op = op,
            .callback_id = callback_id,
            .user_data = self.api_callback_user_data,
        };
        defer context.deinit();

        dispatch(&context) catch |err| switch (err) {
            error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => return err,
            error.LuaError => return self.failValue(context.error_value orelse .{ .string = try self.intern("host callback raised an error") }),
            error.OutOfMemory => return err,
            else => return self.fail(@errorName(err)),
        };

        try self.returnValues(thread, op.base, op.return_count, context.returns.items);
    }

    pub fn readFileAlloc(self: *State, path: []const u8) ![]const u8 {
        switch (self.options.filesystem) {
            .disabled => return self.fail("filesystem access disabled"),
            .memory => |files| {
                for (files) |file| {
                    if (std.mem.eql(u8, file.path, path)) return self.allocator.dupe(u8, file.contents);
                }
                return self.fail("cannot open file");
            },
            .memory_rw => |filesystem| return filesystem.readFileAlloc(self.allocator, path) catch return self.fail("cannot open file"),
            .host_cwd => {
                const io = self.options.io orelse return self.fail("filesystem I/O unavailable");
                return std.Io.Dir.cwd().readFileAlloc(io, path, self.allocator, .limited(1024 * 1024)) catch return self.fail("cannot open file");
            },
        }
    }

    pub fn writeStdout(self: *State, bytes: []const u8) !void {
        try self.stdout.appendSlice(self.allocator, bytes);
        if (self.options.stdout) |writer| try writer.writeAll(bytes);
    }

    pub fn writeStderr(self: *State, bytes: []const u8) !void {
        try self.stderr.appendSlice(self.allocator, bytes);
        if (self.options.stderr) |writer| try writer.writeAll(bytes);
    }

    pub fn flushStdout(self: *State) !void {
        if (self.options.stdout) |writer| try writer.flush();
    }

    pub fn flushStderr(self: *State) !void {
        if (self.options.stderr) |writer| try writer.flush();
    }

    pub fn writeFile(self: *State, path: []const u8, data: []const u8) !void {
        switch (self.options.filesystem) {
            .disabled, .memory => return self.fail("filesystem write access disabled"),
            .memory_rw => |filesystem| filesystem.writeFile(path, data) catch return self.fail("cannot write file"),
            .host_cwd => {
                const io = self.options.io orelse return self.fail("filesystem I/O unavailable");
                std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = data }) catch return self.fail("cannot write file");
            },
        }
    }

    pub fn removeFile(self: *State, path: []const u8) !void {
        switch (self.options.filesystem) {
            .disabled, .memory => return self.fail("filesystem write access disabled"),
            .memory_rw => |filesystem| filesystem.removeFile(path) catch return self.fail("cannot remove file"),
            .host_cwd => {
                const io = self.options.io orelse return self.fail("filesystem I/O unavailable");
                std.Io.Dir.cwd().deleteFile(io, path) catch return self.fail("cannot remove file");
            },
        }
    }

    pub fn renameFile(self: *State, old_path: []const u8, new_path: []const u8) !void {
        switch (self.options.filesystem) {
            .disabled, .memory => return self.fail("filesystem write access disabled"),
            .memory_rw => |filesystem| filesystem.renameFile(old_path, new_path) catch return self.fail("cannot rename file"),
            .host_cwd => {
                const io = self.options.io orelse return self.fail("filesystem I/O unavailable");
                std.Io.Dir.cwd().rename(old_path, std.Io.Dir.cwd(), new_path, io) catch return self.fail("cannot rename file");
            },
        }
    }

    pub fn getenv(self: *State, name: []const u8) ?[]const u8 {
        const environment = self.options.environment orelse return null;
        return environment.get(name);
    }

    pub fn currentTime(self: *State) !i64 {
        return switch (self.options.clock) {
            .disabled => self.fail("clock access disabled"),
            .fixed => |value| value,
            .system => {
                const io = self.options.io orelse return self.fail("clock I/O unavailable");
                return @intCast(@divTrunc(std.Io.Clock.real.now(io).nanoseconds, std.time.ns_per_s));
            },
        };
    }

    pub fn processEnabled(self: *State) bool {
        return self.options.process == .enabled;
    }

    pub fn readStdin(self: *State, spec: []const u8) !Value {
        const input = self.options.stdin;
        if (std.mem.eql(u8, spec, "*a") or std.mem.eql(u8, spec, "a")) {
            const remaining = input[self.stdin_pos..];
            self.stdin_pos = input.len;
            return .{ .string = try self.intern(remaining) };
        }
        if (std.mem.eql(u8, spec, "*l") or std.mem.eql(u8, spec, "l")) {
            if (self.stdin_pos >= input.len) return .nil;
            const start = self.stdin_pos;
            while (self.stdin_pos < input.len and input[self.stdin_pos] != '\n') self.stdin_pos += 1;
            const line = input[start..self.stdin_pos];
            if (self.stdin_pos < input.len and input[self.stdin_pos] == '\n') self.stdin_pos += 1;
            return .{ .string = try self.intern(line) };
        }
        return self.fail("unsupported read option");
    }

    pub fn loadSourceAsClosure(self: *State, source: []const u8) !Value {
        return self.loadSourceAsClosureNamed(source, null);
    }

    pub fn loadSourceAsClosureNamed(self: *State, source: []const u8, source_name: ?[]const u8) !Value {
        return self.loadSourceAsClosureNamedEnv(source, source_name, self.defaultEnvironment());
    }

    pub fn loadSourceAsClosureNamedEnv(self: *State, source: []const u8, source_name: ?[]const u8, environment: Value) !Value {
        var diagnostic: ?errors.Diagnostic = null;
        var tree = frontend.parseWithDiagnostic(self.allocator, source, &diagnostic) catch return self.failLoadDiagnostic(source_name, source, diagnostic, "cannot load source");
        defer tree.deinit();

        compile.resolver.resolveWithDiagnostic(self.allocator, &tree, &diagnostic) catch return self.failLoadDiagnostic(source_name, source, diagnostic, "cannot resolve source");
        const proto = try self.allocator.create(proto_mod.Proto);
        errdefer self.allocator.destroy(proto);
        proto.* = compile.compileWithDiagnostic(self.allocator, &tree, &diagnostic) catch return self.failLoadDiagnostic(source_name, source, diagnostic, "cannot compile source");
        if (source_name) |name| try setProtoSourceName(proto, name);
        errdefer proto.deinit();
        try self.proto_allocations.append(self.allocator, proto);
        errdefer _ = self.proto_allocations.pop();
        return .{ .closure = try self.newRootClosureWithEnv(proto, environment) };
    }

    pub fn loadBinaryDump(self: *State, source: []const u8, environment: Value) !Value {
        var header = std.ArrayList(u8).empty;
        defer header.deinit(self.allocator);
        try appendBinaryChunkHeader(self.allocator, &header);

        if (source.len < header.items.len) return self.fail("truncated binary chunk");
        if (!std.mem.eql(u8, source[0..header.items.len], header.items)) return self.fail("bad binary chunk");

        var pos = header.items.len;
        if (source.len < pos + binary_chunk_payload_magic.len) return self.fail("truncated binary chunk");
        if (!std.mem.eql(u8, source[pos .. pos + binary_chunk_payload_magic.len], binary_chunk_payload_magic)) return self.fail("unsupported PUC Lua binary chunk");
        pos += binary_chunk_payload_magic.len;

        var reader = BinaryChunkReader{ .state = self, .source = source, .pos = pos };
        const stripped_debug = try reader.readBool();
        const proto = try reader.readProto(null);
        errdefer {
            proto.deinit();
            self.allocator.destroy(proto);
        }
        if (reader.pos != source.len) return self.fail("bad binary chunk");
        try self.proto_allocations.append(self.allocator, proto);
        return self.newDumpedClosure(proto, environment, stripped_debug);
    }

    pub fn loadFileAsClosure(self: *State, path: []const u8) !Value {
        return self.loadFileAsClosureNamed(path, null);
    }

    pub fn loadFileAsClosureNamed(self: *State, path: []const u8, source_name: ?[]const u8) !Value {
        const source = try self.readFileAlloc(path);
        errdefer self.allocator.free(source);
        const allocated_source_name = if (source_name == null) try std.fmt.allocPrint(self.allocator, "@{s}", .{path}) else null;
        defer if (allocated_source_name) |name| self.allocator.free(name);
        const closure = try self.loadSourceAsClosureNamed(source, source_name orelse allocated_source_name.?);
        try self.source_allocations.append(self.allocator, source);
        return closure;
    }

    fn setRootThreadArgs(self: *State, thread: *Thread, args: []const Value) !void {
        const proto = thread.frames.items[0].proto;
        const param_count = @min(args.len, proto.param_count);
        for (args[0..param_count], 0..) |arg, index| thread.stack.items[index] = arg;

        if (!proto.is_vararg or args.len <= proto.param_count) return;
        const owned_args = try self.allocator.dupe(Value, args[proto.param_count..]);
        thread.frames.items[0].varargs = owned_args;
        thread.frames.items[0].owns_varargs = true;
    }

    pub fn callCollect(self: *State, thread: *Thread, callable: Value, args: []const Value) anyerror![]Value {
        const frame_count = thread.frames.items.len;
        const frame = thread.frames.items[frame_count - 1];
        const relative_base: bytecode.Register = frame.proto.max_registers;
        const base = frame.base + @as(usize, relative_base);
        try thread.ensureStack(self.allocator, base + 1 + args.len, self.stackValueLimit());
        thread.stack.items[base] = callable;
        for (args, 0..) |arg, index| thread.stack.items[base + 1 + index] = arg;

        try self.invokeValue(thread, .{ .base = relative_base, .arg_count = @intCast(args.len), .return_count = bytecode.multret_count }, 0);
        try self.runThreadUntil(thread, frame_count);
        return self.copyStackSlice(thread, thread.last_result_base, thread.last_result_count);
    }

    fn loadConstant(self: *State, constant: bytecode.Constant) !Value {
        return switch (constant) {
            .nil => .nil,
            .boolean => |value| .{ .boolean = value },
            .integer => |lexeme| try parseIntegerLiteral(lexeme),
            .number => |lexeme| .{ .number = try parseLuaNumber(lexeme) },
            .string => |lexeme| .{ .string = try self.decodeStringLiteral(lexeme) },
        };
    }

    fn closureConstant(self: *State, closure: *Closure, index: bytecode.ConstantIndex) !Value {
        if (closure.constants == null) closure.constants = try self.allocateConstantCache(closure.proto);
        const constants = closure.constants.?;
        if (constants[index] == null) constants[index] = try self.loadConstant(closure.proto.constants.items[index]);
        return constants[index].?;
    }

    fn allocateConstantCache(self: *State, proto: *const proto_mod.Proto) ![]?Value {
        const constants = try self.allocator.alloc(?Value, proto.constants.items.len);
        errdefer self.allocator.free(constants);
        @memset(constants, null);
        self.noteAllocation(constants.len * @sizeOf(?Value));
        return constants;
    }

    pub fn intern(self: *State, bytes: []const u8) ![]const u8 {
        if (self.strings.get(bytes)) |interned| return interned;
        const interned = try self.allocateString(bytes);
        try self.strings.put(interned, interned);
        return interned;
    }

    pub fn allocateString(self: *State, bytes: []const u8) ![]const u8 {
        const allocated = try self.allocator.dupe(u8, bytes);
        errdefer self.allocator.free(allocated);
        try self.string_allocations.append(self.allocator, .{ .bytes = allocated });
        errdefer _ = self.string_allocations.pop();
        if (allocated.len != 0) try self.string_allocation_index.put(@intFromPtr(allocated.ptr), self.string_allocations.items.len - 1);
        self.noteAllocation(@sizeOf(StringAllocation) + allocated.len);
        return allocated;
    }

    fn decodeStringLiteral(self: *State, lexeme: []const u8) ![]const u8 {
        if (lexeme.len < 2) return lexeme;
        if (lexeme[0] == '\'' or lexeme[0] == '"') return self.decodeShortString(lexeme);
        if (lexeme[0] == '[') return self.decodeLongString(lexeme);
        return lexeme;
    }

    fn decodeShortString(self: *State, lexeme: []const u8) ![]const u8 {
        var out = std.ArrayList(u8).empty;
        errdefer out.deinit(self.allocator);

        var index: usize = 1;
        while (index + 1 < lexeme.len) {
            const byte = lexeme[index];
            index += 1;
            if (byte != '\\') {
                try out.append(self.allocator, byte);
                continue;
            }
            if (index >= lexeme.len - 1) return self.fail("unfinished string escape");
            const escaped = lexeme[index];
            index += 1;
            switch (escaped) {
                'a' => try out.append(self.allocator, 0x07),
                'b' => try out.append(self.allocator, 0x08),
                'f' => try out.append(self.allocator, 0x0c),
                'n' => try out.append(self.allocator, '\n'),
                'r' => try out.append(self.allocator, '\r'),
                't' => try out.append(self.allocator, '\t'),
                'v' => try out.append(self.allocator, 0x0b),
                '\\', '"', '\'' => try out.append(self.allocator, escaped),
                'x' => {
                    if (index + 1 >= lexeme.len) return self.fail("invalid hexadecimal escape");
                    const value = hexValue(lexeme[index]) * 16 + hexValue(lexeme[index + 1]);
                    index += 2;
                    try out.append(self.allocator, @intCast(value));
                },
                '0'...'9' => {
                    var value: u32 = escaped - '0';
                    var count: usize = 1;
                    while (count < 3 and index < lexeme.len - 1 and std.ascii.isDigit(lexeme[index])) : (count += 1) {
                        value = value * 10 + lexeme[index] - '0';
                        index += 1;
                    }
                    try out.append(self.allocator, @intCast(value));
                },
                'z' => while (index < lexeme.len - 1 and std.ascii.isWhitespace(lexeme[index])) : (index += 1) {},
                'u' => {
                    if (index >= lexeme.len - 1 or lexeme[index] != '{') return self.fail("invalid unicode escape");
                    index += 1;
                    var value: u32 = 0;
                    var count: usize = 0;
                    while (index < lexeme.len - 1 and lexeme[index] != '}') : (index += 1) {
                        value = appendUnicodeEscapeDigit(value, hexValue(lexeme[index]));
                        count += 1;
                    }
                    if (count == 0 or index >= lexeme.len - 1 or lexeme[index] != '}' or value > max_lua_utf8_codepoint) return self.fail("invalid unicode escape");
                    index += 1;
                    var encoded: [6]u8 = undefined;
                    const len = encodeLuaUtf8(value, &encoded) orelse return self.fail("invalid unicode escape");
                    try out.appendSlice(self.allocator, encoded[0..len]);
                },
                '\n' => {
                    if (index < lexeme.len - 1 and lexeme[index] == '\r') index += 1;
                    try out.append(self.allocator, '\n');
                },
                '\r' => {
                    if (index < lexeme.len - 1 and lexeme[index] == '\n') index += 1;
                    try out.append(self.allocator, '\n');
                },
                else => return self.fail("invalid string escape"),
            }
        }

        const bytes = try self.intern(out.items);
        out.deinit(self.allocator);
        return bytes;
    }

    fn decodeLongString(self: *State, lexeme: []const u8) ![]const u8 {
        var level: usize = 0;
        while (1 + level < lexeme.len and lexeme[1 + level] == '=') level += 1;
        const content_start = level + 2;
        const content_end = lexeme.len - level - 2;
        var content = lexeme[content_start..content_end];
        if (std.mem.startsWith(u8, content, "\r\n") or std.mem.startsWith(u8, content, "\n\r")) {
            content = content[2..];
        } else if (std.mem.startsWith(u8, content, "\n") or std.mem.startsWith(u8, content, "\r")) {
            content = content[1..];
        }
        if (std.mem.indexOfScalar(u8, content, '\r')) |_| {
            const normalized = try self.normalizeLongStringLineEnds(content);
            defer self.allocator.free(normalized);
            return self.intern(normalized);
        }
        return self.intern(content);
    }

    fn normalizeLongStringLineEnds(self: *State, content: []const u8) ![]const u8 {
        var out = std.ArrayList(u8).empty;
        errdefer out.deinit(self.allocator);
        var index: usize = 0;
        while (index < content.len) {
            const byte = content[index];
            if (byte == '\r') {
                try out.append(self.allocator, '\n');
                index += if (index + 1 < content.len and content[index + 1] == '\n') 2 else 1;
            } else if (byte == '\n' and index + 1 < content.len and content[index + 1] == '\r') {
                try out.append(self.allocator, '\n');
                index += 2;
            } else {
                try out.append(self.allocator, byte);
                index += 1;
            }
        }
        return out.toOwnedSlice(self.allocator);
    }

    pub fn newTableWithHints(self: *State, array_hint: u32, hash_hint: u32) !Value {
        const table = try self.allocator.create(Table);
        errdefer self.allocator.destroy(table);
        table.* = try Table.init(self.allocator, array_hint, hash_hint);
        errdefer table.deinit(self.allocator);
        try self.table_allocations.append(self.allocator, table);
        errdefer _ = self.table_allocations.pop();
        try self.table_allocation_index.put(@intFromPtr(table), self.table_allocations.items.len - 1);
        self.noteAllocation(tableGcBytes(table));
        return .{ .table = table };
    }

    pub fn newUserdata(self: *State, ptr: *anyopaque, type_id: usize, type_name: []const u8, finalizer: ?UserdataFinalizer, finalizer_data: ?*const anyopaque, deinit_fn: ?UserdataDeinit) !Value {
        const userdata = try self.allocator.create(Userdata);
        errdefer self.allocator.destroy(userdata);
        userdata.* = .{
            .ptr = ptr,
            .type_id = type_id,
            .type_name = type_name,
            .finalizer = finalizer,
            .finalizer_data = finalizer_data,
            .deinit_fn = deinit_fn,
        };
        try self.userdata_allocations.append(self.allocator, userdata);
        self.noteAllocation(@sizeOf(Userdata));
        return .{ .userdata = userdata };
    }

    fn newRootClosure(self: *State, proto: *const proto_mod.Proto) !*Closure {
        return self.newRootClosureWithEnv(proto, self.defaultEnvironment());
    }

    fn newRootClosureWithEnv(self: *State, proto: *const proto_mod.Proto, environment: Value) !*Closure {
        var upvalues: []*Upvalue = if (proto.upvalues.items.len == 0)
            &.{}
        else
            try self.allocator.alloc(*Upvalue, proto.upvalues.items.len);
        errdefer if (upvalues.len != 0) self.allocator.free(upvalues);

        for (proto.upvalues.items, 0..) |desc, index| {
            const upvalue = try self.allocator.create(Upvalue);
            errdefer self.allocator.destroy(upvalue);
            upvalue.* = .{
                .owner = undefined,
                .stack_index = 0,
                .closed = if (std.mem.eql(u8, desc.name, "_ENV")) environment else .nil,
                .is_open = false,
            };
            try self.upvalue_allocations.append(self.allocator, upvalue);
            self.noteAllocation(@sizeOf(Upvalue));
            upvalues[index] = upvalue;
        }

        const closure = try self.allocator.create(Closure);
        errdefer self.allocator.destroy(closure);
        closure.* = .{ .proto = proto, .upvalues = upvalues };
        try self.closure_allocations.append(self.allocator, closure);
        self.noteAllocation(@sizeOf(Closure));
        return closure;
    }

    fn defaultEnvironment(self: *State) Value {
        return if (self.global_table) |table| .{ .table = table } else self.getGlobalValue("_G");
    }

    fn newDumpedClosure(self: *State, proto: *const proto_mod.Proto, environment: Value, stripped_debug: bool) !Value {
        var upvalues: []*Upvalue = if (proto.upvalues.items.len == 0)
            &.{}
        else
            try self.allocator.alloc(*Upvalue, proto.upvalues.items.len);
        errdefer if (upvalues.len != 0) self.allocator.free(upvalues);

        for (proto.upvalues.items, 0..) |desc, index| {
            const upvalue = try self.allocator.create(Upvalue);
            errdefer self.allocator.destroy(upvalue);
            upvalue.* = .{
                .owner = undefined,
                .stack_index = 0,
                .closed = if (std.mem.eql(u8, desc.name, "_ENV")) environment else .nil,
                .is_open = false,
            };
            try self.upvalue_allocations.append(self.allocator, upvalue);
            self.noteAllocation(@sizeOf(Upvalue));
            upvalues[index] = upvalue;
        }

        const closure = try self.allocator.create(Closure);
        closure.* = .{ .proto = proto, .upvalues = upvalues, .stripped_debug = stripped_debug };
        errdefer self.destroyClosure(closure);
        try self.closure_allocations.append(self.allocator, closure);
        self.noteAllocation(@sizeOf(Closure));
        return .{ .closure = closure };
    }

    fn newClosure(self: *State, thread: *Thread, proto: *const proto_mod.Proto) !Value {
        const parent = thread.frames.items[thread.frames.items.len - 1];
        const upvalues = try self.allocator.alloc(*Upvalue, proto.upvalues.items.len);
        errdefer self.allocator.free(upvalues);
        for (proto.upvalues.items, 0..) |desc, index| {
            upvalues[index] = if (desc.in_stack)
                try self.captureUpvalue(thread, parent.base + desc.index)
            else
                parent.closure.upvalues[desc.index];
        }

        const closure = try self.allocator.create(Closure);
        closure.* = .{ .proto = proto, .upvalues = upvalues, .stripped_debug = parent.closure.stripped_debug };
        errdefer self.destroyClosure(closure);
        try self.closure_allocations.append(self.allocator, closure);
        self.noteAllocation(@sizeOf(Closure));
        return .{ .closure = closure };
    }

    fn captureUpvalue(self: *State, thread: *Thread, stack_index: usize) !*Upvalue {
        var current = thread.open_upvalues;
        while (current) |upvalue| : (current = upvalue.next) {
            if (upvalue.is_open and upvalue.stack_index == stack_index) return upvalue;
        }

        const upvalue = try self.allocator.create(Upvalue);
        errdefer self.allocator.destroy(upvalue);
        upvalue.* = .{ .owner = thread, .stack_index = stack_index, .next = thread.open_upvalues };
        try self.upvalue_allocations.append(self.allocator, upvalue);
        self.noteAllocation(@sizeOf(Upvalue));
        thread.open_upvalues = upvalue;
        return upvalue;
    }

    fn readUpvalue(self: *State, thread: *Thread, index: bytecode.UpvalueIndex) Value {
        _ = self;
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const upvalue = frame.closure.upvalues[index];
        return if (upvalue.is_open) upvalue.owner.stack.items[upvalue.stack_index] else upvalue.closed;
    }

    fn writeUpvalue(self: *State, thread: *Thread, index: bytecode.UpvalueIndex, value: Value) void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const upvalue = frame.closure.upvalues[index];
        if (upvalue.is_open) {
            upvalue.owner.stack.items[upvalue.stack_index] = value;
        } else {
            upvalue.closed = value;
            self.writeBarrier(upvalue.marked, value);
        }
    }

    fn closeUpvalues(self: *State, thread: *Thread, first_stack_index: usize) void {
        _ = self;
        var previous: ?*Upvalue = null;
        var current = thread.open_upvalues;
        while (current) |upvalue| {
            const next = upvalue.next;
            if (upvalue.is_open and upvalue.stack_index >= first_stack_index) {
                upvalue.closed = thread.stack.items[upvalue.stack_index];
                upvalue.is_open = false;
                upvalue.next = null;
                if (previous) |prev| {
                    prev.next = next;
                } else {
                    thread.open_upvalues = next;
                }
            } else {
                previous = upvalue;
            }
            current = next;
        }
    }

    fn checkToBeClosedRegister(self: *State, thread: *Thread, register: bytecode.Register) !void {
        const value = self.get(thread, register);
        if (value == .nil) return;
        if (value == .boolean and !value.boolean) return;
        if ((try self.getMetamethod(value, "__close")) == null) {
            const frame = thread.frames.items[thread.frames.items.len - 1];
            thread.stack.items[frame.base + register] = .nil;
            if (self.toBeClosedLocalName(thread, register)) |name| {
                const message = try std.fmt.allocPrint(self.allocator, "variable '{s}' got a non-closable value", .{name});
                defer self.allocator.free(message);
                return self.fail(try self.intern(message));
            }
            return self.fail("variable got a non-closable value");
        }
    }

    fn toBeClosedLocalName(self: *State, thread: *Thread, register: bytecode.Register) ?[]const u8 {
        _ = self;
        const frame = thread.frames.items[thread.frames.items.len - 1];
        for (frame.proto.locals.items) |local| {
            if (!local.to_close or local.register != register) continue;
            if (!localActiveAt(local, frame.pc)) continue;
            return local.name;
        }
        return null;
    }

    fn closeToBeClosedRegister(self: *State, thread: *Thread, register: bytecode.Register, error_value: ?Value) anyerror!void {
        const frame_count = thread.frames.items.len;
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const absolute_register = frame.base + register;
        const value = thread.stack.items[absolute_register];
        if (value == .nil) return;
        if (value == .boolean and !value.boolean) return;
        const metamethod = (try self.getMetamethod(value, "__close")) orelse {
            thread.stack.items[absolute_register] = .nil;
            return self.fail("metamethod 'close'");
        };
        const previous_call_name = thread.next_call_name;
        thread.next_call_name = "close";
        defer thread.next_call_name = previous_call_name;
        _ = (if (error_value) |err_value|
            self.callOneResult(thread, metamethod, &.{ value, err_value })
        else
            self.callOneResult(thread, metamethod, &.{value})) catch |err| {
            if (err == error.CoroutineYield and error_value != null) {
                thread.pending_unwind_error = error_value.?;
                thread.pending_unwind_resume_frame_count = frame_count;
                thread.pending_unwind_target_frame_count = if (frame_count == 0) 0 else frame_count - 1;
            }
            if (isRuntimeError(err)) {
                var close_err = err;
                self.closeFramesTo(thread, frame_count, self.currentErrorValue()) catch |unwind_err| {
                    close_err = unwind_err;
                    if (!isRuntimeError(unwind_err)) return unwind_err;
                };
                thread.stack.items[absolute_register] = .nil;
                self.last_error_in_close = true;
                return close_err;
            }
            thread.stack.items[absolute_register] = .nil;
            return err;
        };
        thread.stack.items[absolute_register] = .nil;
    }

    fn jumpThread(self: *State, thread: *Thread, offset: bytecode.JumpOffset, auto_gc: bool) !void {
        const frame_index = thread.frames.items.len - 1;
        const frame = &thread.frames.items[frame_index];
        const source_pc = frame.pc;
        const target_pc = jumpTarget(source_pc, offset);
        if (frame.proto.has_to_close_locals) try self.closeToBeClosedExitingPc(thread, frame_index, source_pc, target_pc, null);
        thread.frames.items[frame_index].pc = target_pc;
        if (target_pc < source_pc) {
            thread.frames.items[frame_index].last_hook_line = null;
            if (auto_gc and self.gc_running and self.shouldRunAutoGc()) try self.collectGarbageConservatively(thread);
        }
    }

    fn jumpThreadMaybeFast(self: *State, thread: *Thread, offset: bytecode.JumpOffset, auto_gc: bool) !void {
        const frame = &thread.frames.items[thread.frames.items.len - 1];
        if (frame.proto.has_to_close_locals) return self.jumpThread(thread, offset, auto_gc);

        const source_pc = frame.pc;
        const target_pc = jumpTarget(source_pc, offset);
        frame.pc = target_pc;
        if (target_pc < source_pc) {
            frame.last_hook_line = null;
            if (auto_gc and self.gc_running and self.shouldRunAutoGc()) try self.collectGarbageConservatively(thread);
        }
    }

    fn forPrep(self: *State, thread: *Thread, op: bytecode.ForLoop) !void {
        const initial = self.get(thread, op.base);
        const limit = self.get(thread, op.base + 1);
        const step = self.get(thread, op.base + 2);
        if (toInteger(initial)) |initial_integer| {
            if (toInteger(step)) |step_integer| {
                if (step_integer == 0) return self.failRuntimeDetail(thread, "'for' step is zero");
                const limit_integer = toInteger(limit) orelse blk: {
                    const limit_number = toNumberMaybe(limit) orelse return self.failForTypeError(thread, .limit, limit);
                    break :blk integerForLimit(limit_number, step_integer) orelse {
                        self.set(thread, op.base, .{ .integer = initial_integer });
                        self.set(thread, op.base + 1, .{ .integer = initial_integer });
                        self.set(thread, op.base + 2, .{ .integer = step_integer });
                        try self.jumpThread(thread, op.offset, false);
                        return;
                    };
                };
                self.set(thread, op.base, .{ .integer = initial_integer });
                self.set(thread, op.base + 1, .{ .integer = limit_integer });
                self.set(thread, op.base + 2, .{ .integer = step_integer });
                if (!forLoopContinuesInteger(initial_integer, limit_integer, step_integer)) try self.jumpThread(thread, op.offset, false);
                return;
            }
        }

        const initial_number = toNumberMaybe(initial) orelse return self.failForTypeError(thread, .initial, initial);
        const limit_number = toNumberMaybe(limit) orelse return self.failForTypeError(thread, .limit, limit);
        const step_number = toNumberMaybe(step) orelse return self.failForTypeError(thread, .step, step);
        if (step_number == 0) return self.failRuntimeDetail(thread, "'for' step is zero");
        self.set(thread, op.base, .{ .number = initial_number });
        self.set(thread, op.base + 1, .{ .number = limit_number });
        self.set(thread, op.base + 2, .{ .number = step_number });
        if (!forLoopContinuesNumber(initial_number, limit_number, step_number)) try self.jumpThread(thread, op.offset, false);
    }

    fn forLoop(self: *State, thread: *Thread, op: bytecode.ForLoop) !void {
        const frame = &thread.frames.items[thread.frames.items.len - 1];
        const absolute_base = frame.base + op.base;
        const stack = thread.stack.items;
        const current = stack[absolute_base];
        const limit = stack[absolute_base + 1];
        const step = stack[absolute_base + 2];
        if (current == .integer and limit == .integer and step == .integer) {
            const next = current.integer +% step.integer;
            stack[absolute_base] = .{ .integer = next };
            const wrapped = (step.integer > 0 and next < current.integer) or (step.integer < 0 and next > current.integer);
            if (!wrapped and forLoopContinuesInteger(next, limit.integer, step.integer)) {
                if (frame.proto.has_to_close_locals) {
                    try self.jumpThread(thread, op.offset, false);
                } else {
                    const source_pc = frame.pc;
                    const target_pc = jumpTarget(source_pc, op.offset);
                    frame.pc = target_pc;
                    if (target_pc < source_pc) frame.last_hook_line = null;
                }
            }
            return;
        }

        const next = (try toNumber(current)) + (try toNumber(step));
        stack[absolute_base] = .{ .number = next };
        if (forLoopContinuesNumber(next, try toNumber(limit), try toNumber(step))) {
            if (frame.proto.has_to_close_locals) {
                try self.jumpThread(thread, op.offset, false);
            } else {
                const source_pc = frame.pc;
                const target_pc = jumpTarget(source_pc, op.offset);
                frame.pc = target_pc;
                if (target_pc < source_pc) frame.last_hook_line = null;
            }
        }
    }

    fn closeToBeClosedExitingPc(self: *State, thread: *Thread, frame_index: usize, source_pc: usize, target_pc: usize, error_value: ?Value) !void {
        const frame = thread.frames.items[frame_index];
        var pending_error = error_value;
        var close_failed = false;

        var index = frame.proto.locals.items.len;
        while (index > 0) {
            index -= 1;
            const local = frame.proto.locals.items[index];
            if (!local.to_close) continue;
            if (!localActiveAt(local, source_pc) or localActiveAt(local, target_pc)) continue;
            const value = thread.stack.items[frame.base + local.register];
            if (value != .nil and !(value == .boolean and !value.boolean) and (try self.getMetamethod(value, "__close")) == null) continue;

            self.closeToBeClosedRegister(thread, local.register, pending_error) catch |err| {
                if (isRuntimeError(err)) {
                    self.discardFramesTo(thread, frame_index + 1);
                    pending_error = self.currentErrorValue();
                    close_failed = true;
                } else return err;
            };
        }

        if (close_failed) return self.throwValue(pending_error.?);
    }

    fn closeActiveToBeClosedInTopFrame(self: *State, thread: *Thread, error_value: ?Value) !void {
        const frame_index = thread.frames.items.len - 1;
        const frame = thread.frames.items[frame_index];
        const pc = frame.pc;
        var pending_error = error_value;
        var close_failed = false;

        var index = frame.proto.locals.items.len;
        while (index > 0) {
            index -= 1;
            const local = frame.proto.locals.items[index];
            if (!local.to_close or !localActiveAt(local, pc)) continue;

            self.closeToBeClosedRegister(thread, local.register, pending_error) catch |err| {
                if (isRuntimeError(err)) {
                    self.discardFramesTo(thread, frame_index + 1);
                    pending_error = self.currentErrorValue();
                    close_failed = true;
                } else return err;
            };
        }

        if (close_failed) return self.throwValue(pending_error.?);
    }

    fn closeFramesTo(self: *State, thread: *Thread, frame_count: usize, error_value: ?Value) !void {
        var pending_error = error_value;
        var close_failed = false;
        while (thread.frames.items.len > frame_count) {
            self.closeActiveToBeClosedInTopFrame(thread, pending_error) catch |err| {
                pending_error = self.currentErrorValue();
                close_failed = close_failed or isRuntimeError(err);
                if (!isRuntimeError(err)) return err;
            };
            const frame = thread.frames.items[thread.frames.items.len - 1];
            self.closeUpvalues(thread, frame.base);
            thread.frames.items[thread.frames.items.len - 1].deinit(self.allocator);
            thread.frames.items.len -= 1;
        }
        if (close_failed) return self.throwValue(pending_error.?);
    }

    fn discardFramesTo(self: *State, thread: *Thread, frame_count: usize) void {
        while (thread.frames.items.len > frame_count) {
            const frame = thread.frames.items[thread.frames.items.len - 1];
            self.closeUpvalues(thread, frame.base);
            thread.frames.items[thread.frames.items.len - 1].deinit(self.allocator);
            thread.frames.items.len -= 1;
        }
    }

    fn getTable(self: *State, table_value: Value, key_value: Value) !Value {
        return self.getTableDepth(null, table_value, key_value, 0);
    }

    pub fn getTableValue(self: *State, table_value: Value, key_value: Value) !Value {
        return self.getTable(table_value, key_value);
    }

    pub fn getTableFromThread(self: *State, thread: *Thread, table_value: Value, key_value: Value) !Value {
        return self.getTableDepth(thread, table_value, key_value, 0);
    }

    fn getTableToRegister(self: *State, thread: *Thread, dest: bytecode.Register, table_value: Value, key_value: Value) !void {
        const value = try self.getTableDepthContinuable(thread, self.absoluteRegister(thread, dest), table_value, key_value, 0);
        self.set(thread, dest, value);
    }

    fn getTableDepthContinuable(self: *State, thread: *Thread, dest: usize, table_value: Value, key_value: Value, depth: usize) !Value {
        if (depth > max_metamethod_depth) return self.fail("'__index' chain too long");
        const key = try self.readableTableKey(key_value) orelse return .nil;

        if (table_value == .table) {
            const value = table_value.table.get(key);
            if (value != .nil) return value;
        }

        const metamethod = try self.getMetamethod(table_value, "__index") orelse {
            if (table_value == .table) return .nil;
            return self.failIndexTypeError(thread, table_value);
        };

        return switch (metamethod) {
            .table => self.getTableDepthContinuable(thread, dest, metamethod, key, depth + 1),
            else => if (functionLike(metamethod))
                try self.callOneMetamethodWithContinuation(thread, "__index", metamethod, &.{ table_value, key }, .{ .value = dest })
            else
                self.failRuntimeDetail(thread, indexErrorMessage(metamethod)),
        };
    }

    fn getTableDepth(self: *State, thread: ?*Thread, table_value: Value, key_value: Value, depth: usize) !Value {
        if (depth > max_metamethod_depth) return self.fail("'__index' chain too long");
        const key = try self.readableTableKey(key_value) orelse return .nil;

        if (table_value == .table) {
            const value = table_value.table.get(key);
            if (value != .nil) return value;
        }

        const metamethod = try self.getMetamethod(table_value, "__index") orelse {
            if (table_value == .table) return .nil;
            return self.failIndexTypeError(thread, table_value);
        };

        return switch (metamethod) {
            .table => self.getTableDepth(thread, metamethod, key, depth + 1),
            else => if (!functionLike(metamethod))
                self.failRuntimeDetail(thread, indexErrorMessage(metamethod))
            else if (thread) |active_thread|
                try self.callOneMetamethod(active_thread, "__index", metamethod, &.{ table_value, key })
            else
                self.fail(callErrorMessage(metamethod)),
        };
    }

    fn rawGet(self: *State, table_value: Value, key_value: Value) !Value {
        const table = switch (table_value) {
            .table => |table| table,
            else => return self.fail(indexErrorMessage(table_value)),
        };
        const key = try self.readableTableKey(key_value) orelse return .nil;
        return table.get(key);
    }

    fn setTable(self: *State, table_value: Value, key_value: Value, value: Value) !void {
        try self.setTableDepth(null, table_value, key_value, value, 0);
    }

    pub fn setTableValue(self: *State, table_value: Value, key_value: Value, value: Value) !void {
        try self.setTable(table_value, key_value, value);
    }

    pub fn setTableFromThread(self: *State, thread: *Thread, table_value: Value, key_value: Value, value: Value) !void {
        try self.setTableDepth(thread, table_value, key_value, value, 0);
    }

    fn setTableFromThreadContinuable(self: *State, thread: *Thread, table_value: Value, key_value: Value, value: Value) !void {
        try self.setTableDepthContinuable(thread, table_value, key_value, value, 0);
    }

    fn setTableDepthContinuable(self: *State, thread: *Thread, table_value: Value, key_value: Value, value: Value, depth: usize) !void {
        if (depth > max_metamethod_depth) return self.fail("'__newindex' chain too long");
        const key = try self.writableTableKey(key_value);

        if (table_value == .table) {
            const table = table_value.table;
            if (table.setExistingNonNil(key, value)) {
                self.writeTableBarrier(table, key, value);
                return;
            }
        }

        const metamethod = try self.getMetamethod(table_value, "__newindex") orelse {
            if (table_value == .table) {
                try self.setTableRaw(table_value.table, key, value);
                self.writeTableBarrier(table_value.table, key, value);
                return;
            }
            return self.failNewIndexTypeError(thread, table_value);
        };

        switch (metamethod) {
            .table => try self.setTableDepthContinuable(thread, metamethod, key, value, depth + 1),
            else => if (functionLike(metamethod)) {
                _ = try self.callOneMetamethodWithContinuation(thread, "__newindex", metamethod, &.{ table_value, key, value }, .discard);
            } else {
                return self.failRuntimeDetail(thread, indexErrorMessage(metamethod));
            },
        }
    }

    fn setTableDepth(self: *State, thread: ?*Thread, table_value: Value, key_value: Value, value: Value, depth: usize) !void {
        if (depth > max_metamethod_depth) return self.fail("'__newindex' chain too long");
        const key = try self.writableTableKey(key_value);

        if (table_value == .table) {
            const table = table_value.table;
            if (table.setExistingNonNil(key, value)) {
                self.writeTableBarrier(table, key, value);
                return;
            }
        }

        const metamethod = try self.getMetamethod(table_value, "__newindex") orelse {
            if (table_value == .table) {
                try self.setTableRaw(table_value.table, key, value);
                self.writeTableBarrier(table_value.table, key, value);
                return;
            }
            return self.failNewIndexTypeError(thread, table_value);
        };

        switch (metamethod) {
            .table => try self.setTableDepth(thread, metamethod, key, value, depth + 1),
            else => if (!functionLike(metamethod)) {
                return self.failRuntimeDetail(thread, indexErrorMessage(metamethod));
            } else if (thread) |active_thread| {
                _ = try self.callOneMetamethod(active_thread, "__newindex", metamethod, &.{ table_value, key, value });
            } else {
                return self.fail(callErrorMessage(metamethod));
            },
        }
    }

    fn readableTableKey(self: *State, value: Value) !?Value {
        _ = self;
        return switch (value) {
            .nil => null,
            .number => |number| if (std.math.isNan(number)) null else if (floatToInteger(number)) |integer| .{ .integer = integer } else value,
            else => value,
        };
    }

    fn writableTableKey(self: *State, value: Value) !Value {
        return switch (value) {
            .nil => self.fail("table index is nil"),
            .number => |number| if (std.math.isNan(number)) self.fail("table index is NaN") else if (floatToInteger(number)) |integer| .{ .integer = integer } else value,
            else => value,
        };
    }

    pub fn lengthOf(self: *State, thread: *Thread, value: Value) !Value {
        return switch (value) {
            .string => |string| .{ .integer = @intCast(string.len) },
            .table => |table| if ((try self.getMetamethod(value, "__len"))) |metamethod|
                try self.callOneMetamethod(thread, "__len", metamethod, &.{ value, value })
            else
                .{ .integer = table.len() },
            else => if ((try self.getMetamethod(value, "__len"))) |metamethod|
                try self.callOneMetamethod(thread, "__len", metamethod, &.{ value, value })
            else
                self.fail("attempt to get length of a non-string value"),
        };
    }

    fn concatValues(self: *State, lhs: Value, rhs: Value) !Value {
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.allocator);
        try appendLuaString(self.allocator, &out, lhs);
        try appendLuaString(self.allocator, &out, rhs);
        return .{ .string = try self.allocateString(out.items) };
    }

    fn callValue(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const resolved = try self.resolveCall(thread, op);
        const callee = self.get(thread, resolved.base);
        if (callee == .closure) {
            const call_name = thread.next_call_name;
            const call_namewhat = thread.next_call_namewhat;
            thread.next_call_name = null;
            thread.next_call_namewhat = null;
            try self.callClosure(thread, resolved, callee.closure, call_name, call_namewhat);
            return;
        }
        try self.invokeValue(thread, resolved, 0);
    }

    fn invokeValue(self: *State, thread: *Thread, resolved: bytecode.Call, depth: usize) anyerror!void {
        if (depth > max_metamethod_depth) return self.fail("'__call' chain too long");
        const callee = self.get(thread, resolved.base);
        if (callee == .coroutine_wrapper) {
            try self.callCoroutineWrapper(thread, resolved, callee.coroutine_wrapper);
            return;
        }

        const entering_native = isYieldBlockingNative(callee);
        if (entering_native) thread.native_call_depth += 1;
        defer {
            if (entering_native) thread.native_call_depth -= 1;
        }
        const call_name = thread.next_call_name;
        const call_namewhat = thread.next_call_namewhat;
        thread.next_call_name = null;
        thread.next_call_namewhat = null;
        const hook_native = isNativeCallable(callee) and !thread.hook_running;
        if (hook_native and thread.hook_call) {
            const previous_hook_func = thread.hook_level2_func;
            const previous_transfer_index_base = thread.hook_transfer_index_base;
            const previous_transfer_stack_base = thread.hook_transfer_stack_base;
            const previous_transfer_count = thread.hook_transfer_count;
            const previous_transfer_values = thread.hook_transfer_values;
            thread.hook_level2_func = callee;
            thread.hook_transfer_index_base = 1;
            thread.hook_transfer_stack_base = thread.frames.items[thread.frames.items.len - 1].base + resolved.base + 1;
            thread.hook_transfer_count = resolved.arg_count;
            thread.hook_transfer_values = &.{};
            defer {
                thread.hook_level2_func = previous_hook_func;
                thread.hook_transfer_index_base = previous_transfer_index_base;
                thread.hook_transfer_stack_base = previous_transfer_stack_base;
                thread.hook_transfer_count = previous_transfer_count;
                thread.hook_transfer_values = previous_transfer_values;
            }
            try self.callHook(thread, "call");
        }
        switch (callee) {
            .closure => |closure| try self.callClosure(thread, resolved, closure, call_name, call_namewhat),
            .c_closure => |closure| try self.callCClosureDispatch(thread, resolved, closure),
            .native_print => {
                for (0..resolved.arg_count) |index| {
                    if (index != 0) try self.writeStdout("\t");
                    const text = try self.valueToString(thread, self.get(thread, resolved.base + 1 + @as(bytecode.Register, @intCast(index))));
                    try self.writeStdout(text);
                }
                try self.writeStdout("\n");
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{});
            },
            .native_tostring => {
                if (resolved.arg_count == 0) return self.failArgumentMessage("tostring", 1, "value expected");
                const value = self.get(thread, resolved.base + 1);
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{.{ .string = try self.valueToString(thread, value) }});
            },
            .native_getmetatable => try self.returnValues(thread, resolved.base, resolved.return_count, &.{try self.getMetatableValue(argValue(self, thread, resolved, 0))}),
            .native_setmetatable => {
                const table_value = argValue(self, thread, resolved, 0);
                if (table_value != .table) return self.failArgumentType("setmetatable", 1, "table", table_value);
                try self.setMetatableValue(table_value, argValue(self, thread, resolved, 1));
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{table_value});
            },
            .native_rawequal => try self.returnValues(thread, resolved.base, resolved.return_count, &.{.{ .boolean = valuesEqual(argValue(self, thread, resolved, 0), argValue(self, thread, resolved, 1)) }}),
            .native_rawget => try self.returnValues(thread, resolved.base, resolved.return_count, &.{try self.rawGet(argValue(self, thread, resolved, 0), argValue(self, thread, resolved, 1))}),
            .native_rawset => {
                const table = argValue(self, thread, resolved, 0);
                try self.rawSet(table, argValue(self, thread, resolved, 1), argValue(self, thread, resolved, 2));
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{table});
            },
            .native_rawlen => try self.returnValues(thread, resolved.base, resolved.return_count, &.{try self.rawLen(argValue(self, thread, resolved, 0))}),
            .native_next => {
                const values = try self.nextValues(argValue(self, thread, resolved, 0), argValue(self, thread, resolved, 1));
                try self.returnValues(thread, resolved.base, resolved.return_count, &values);
            },
            .native_pairs => {
                const table_value = argValue(self, thread, resolved, 0);
                if (table_value != .table) return self.failArgumentType("pairs", 1, "table", table_value);
                if (try self.getMetamethod(table_value, "__pairs")) |metamethod| {
                    self.set(thread, resolved.base, metamethod);
                    self.set(thread, resolved.base + 1, table_value);
                    thread.native_call_depth -= 1;
                    defer thread.native_call_depth += 1;
                    try self.invokeValue(thread, .{ .base = resolved.base, .arg_count = 1, .return_count = resolved.return_count }, 0);
                    return;
                }
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{ .native_next, table_value, .nil });
            },
            .native_ipairs => {
                const table_value = argValue(self, thread, resolved, 0);
                if (table_value != .table) return self.failArgumentType("ipairs", 1, "table", table_value);
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{ .native_ipairs_iter, table_value, .{ .integer = 0 } });
            },
            .native_ipairs_iter => {
                const values = try self.ipairsIterValues(thread, argValue(self, thread, resolved, 0), argValue(self, thread, resolved, 1));
                try self.returnValues(thread, resolved.base, resolved.return_count, &values);
            },
            .native_table_create => {
                const array_hint = try self.tableCreateHint(argValue(self, thread, resolved, 0), 1);
                const hash_hint = if (resolved.arg_count >= 2) try self.tableCreateHint(argValue(self, thread, resolved, 1), 2) else 0;
                if (hash_hint == std.math.maxInt(i32)) return self.fail("table overflow");
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{try self.newTableWithHints(array_hint, hash_hint)});
            },
            .native_select => try self.selectValues(thread, resolved),
            .native_assert => try self.assertValues(thread, resolved),
            .native_error => try self.errorValue(thread, resolved),
            .native_pcall => try self.pcallValues(thread, resolved),
            .native_xpcall => try self.xpcallValues(thread, resolved),
            .native_collectgarbage => try self.collectGarbageValue(thread, resolved),
            .native_debug_traceback => try self.tracebackValue(thread, resolved),
            .native_coroutine_create => try self.coroutineCreate(thread, resolved),
            .native_coroutine_resume => try self.coroutineResume(thread, resolved),
            .native_coroutine_yield => try self.coroutineYield(thread, resolved),
            .native_coroutine_status => try self.coroutineStatus(thread, resolved),
            .native_coroutine_running => try self.coroutineRunning(thread, resolved),
            .native_coroutine_isyieldable => try self.coroutineIsYieldable(thread, resolved),
            .native_coroutine_close => try self.coroutineClose(thread, resolved),
            .native_coroutine_wrap => try self.coroutineWrap(thread, resolved),
            .gmatch_iterator => |state_table| {
                if (state_table.get(.{ .string = "__zlua_lines_iterator" }) != .nil) {
                    const values = try stdlib.io.linesNext(self, .{ .table = state_table });
                    try self.returnValues(thread, resolved.base, resolved.return_count, values);
                } else {
                    const values = try stdlib.string.gmatchNext(self, .{ .table = state_table });
                    try self.returnValues(thread, resolved.base, resolved.return_count, values[0..2]);
                }
            },
            .native => |native| try self.callNative(native, thread, resolved),
            else => {
                const metamethod = try self.getMetamethod(callee, "__call") orelse return self.failCallTypeError(thread, callee, call_name, call_namewhat);
                try self.prependCallArgument(thread, resolved, metamethod, callee);
                try self.invokeValue(thread, .{ .base = resolved.base, .arg_count = resolved.arg_count + 1, .return_count = resolved.return_count }, depth + 1);
            },
        }
        if (hook_native and thread.hook_return) {
            const previous_hook_func = thread.hook_level2_func;
            const previous_transfer_index_base = thread.hook_transfer_index_base;
            const previous_transfer_stack_base = thread.hook_transfer_stack_base;
            const previous_transfer_count = thread.hook_transfer_count;
            const previous_transfer_values = thread.hook_transfer_values;
            thread.hook_level2_func = callee;
            thread.hook_transfer_index_base = 2;
            thread.hook_transfer_stack_base = thread.last_transfer_base;
            thread.hook_transfer_count = thread.last_transfer_count;
            thread.hook_transfer_values = &.{};
            defer {
                thread.hook_level2_func = previous_hook_func;
                thread.hook_transfer_index_base = previous_transfer_index_base;
                thread.hook_transfer_stack_base = previous_transfer_stack_base;
                thread.hook_transfer_count = previous_transfer_count;
                thread.hook_transfer_values = previous_transfer_values;
            }
            try self.callReturnHook(thread, call_name orelse nativeHookName(callee));
        }
    }

    fn prependCallArgument(self: *State, thread: *Thread, resolved: bytecode.Call, metamethod: Value, receiver: Value) !void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const base = frame.base + resolved.base;
        try thread.ensureStack(self.allocator, base + 2 + resolved.arg_count, self.stackValueLimit());
        var index: usize = resolved.arg_count;
        while (index > 0) {
            index -= 1;
            thread.stack.items[base + 2 + index] = thread.stack.items[base + 1 + index];
        }
        thread.stack.items[base] = metamethod;
        thread.stack.items[base + 1] = receiver;
    }

    pub fn callOneResult(self: *State, thread: *Thread, callable: Value, args: []const Value) anyerror!Value {
        return self.callOneResultMaybeContinuation(thread, callable, args, null);
    }

    fn callOneResultWithContinuation(self: *State, thread: *Thread, callable: Value, args: []const Value, result: CallOneContinuationResult) anyerror!Value {
        return self.callOneResultMaybeContinuation(thread, callable, args, result);
    }

    fn callOneMetamethodWithContinuation(self: *State, thread: *Thread, name: []const u8, callable: Value, args: []const Value, result: CallOneContinuationResult) anyerror!Value {
        const previous_name = thread.next_call_name;
        const previous_namewhat = thread.next_call_namewhat;
        thread.next_call_name = metamethodDebugName(name);
        thread.next_call_namewhat = "metamethod";
        defer {
            thread.next_call_name = previous_name;
            thread.next_call_namewhat = previous_namewhat;
        }
        return self.callOneResultWithContinuation(thread, callable, args, result);
    }

    fn callOneMetamethod(self: *State, thread: *Thread, name: []const u8, callable: Value, args: []const Value) anyerror!Value {
        const previous_name = thread.next_call_name;
        const previous_namewhat = thread.next_call_namewhat;
        thread.next_call_name = metamethodDebugName(name);
        thread.next_call_namewhat = "metamethod";
        defer {
            thread.next_call_name = previous_name;
            thread.next_call_namewhat = previous_namewhat;
        }
        return self.callOneResult(thread, callable, args);
    }

    fn metamethodDebugName(name: []const u8) []const u8 {
        return if (std.mem.startsWith(u8, name, "__")) name[2..] else name;
    }

    fn callOneResultMaybeContinuation(self: *State, thread: *Thread, callable: Value, args: []const Value, continuation_result: ?CallOneContinuationResult) anyerror!Value {
        const frame_count = thread.frames.items.len;
        const frame = thread.frames.items[frame_count - 1];
        const relative_base: bytecode.Register = frame.proto.max_registers;
        const base = frame.base + @as(usize, relative_base);
        try thread.ensureStack(self.allocator, base + 1 + args.len, self.stackValueLimit());
        thread.stack.items[base] = callable;
        for (args, 0..) |arg, index| thread.stack.items[base + 1 + index] = arg;

        self.invokeValue(thread, .{ .base = relative_base, .arg_count = @intCast(args.len), .return_count = 1 }, 0) catch |err| switch (err) {
            error.CoroutineYield => {
                if (continuation_result) |result| try self.pushCallOneContinuation(thread, frame_count, result);
                return err;
            },
            else => return err,
        };
        self.runThreadUntil(thread, frame_count) catch |err| switch (err) {
            error.CoroutineYield => {
                if (continuation_result) |result| try self.pushCallOneContinuation(thread, frame_count, result);
                return err;
            },
            else => return err,
        };
        return thread.stack.items[base];
    }

    fn pushCallOneContinuation(self: *State, thread: *Thread, frame_count: usize, result: CallOneContinuationResult) !void {
        try thread.call_one_continuations.append(self.allocator, .{ .frame_count = frame_count, .result = result });
    }

    fn readyCallOneContinuationIndex(thread: *Thread) ?usize {
        for (thread.call_one_continuations.items, 0..) |continuation, index| {
            if (continuation.frame_count == thread.frames.items.len) return index;
        }
        return null;
    }

    fn completeReadyCallOneContinuation(self: *State, thread: *Thread) !bool {
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

    pub fn protectedCall(self: *State, thread: *Thread, callable: Value, args: []const Value) anyerror!ProtectedCallResult {
        const context = self.protectedCallContextWithErrors(thread);
        return self.runProtectedCall(thread, context, callable, args);
    }

    fn protectedCallContext(_: *State, thread: *Thread) ProtectedCallContext {
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

    fn protectedCallContextWithErrors(self: *State, thread: *Thread) ProtectedCallContext {
        var context = self.protectedCallContext(thread);
        context.last_error = self.last_error;
        return context;
    }

    fn runProtectedCall(self: *State, thread: *Thread, context: ProtectedCallContext, callable: Value, args: []const Value) anyerror!ProtectedCallResult {
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

    fn restoreProtectedCall(
        self: *State,
        thread: *Thread,
        context: ProtectedCallContext,
        error_value: Value,
    ) !Value {
        var failure = error_value;
        thread.protected_close_depth += 1;
        defer thread.protected_close_depth -= 1;
        self.closeFramesTo(thread, context.frame_count, error_value) catch |err| switch (err) {
            error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => failure = self.currentErrorValue(),
            else => return err,
        };
        thread.stack.items.len = context.stack_len;
        thread.last_result_base = context.last_result_base;
        thread.last_result_count = context.last_result_count;
        self.last_error = context.last_error;
        return failure;
    }

    fn pushProtectedContinuation(self: *State, thread: *Thread, context: ProtectedCallContext, base: bytecode.Register, return_count: u16, kind: ProtectedContinuationKind, handler: Value, handler_depth: usize) !void {
        try thread.protected_continuations.append(self.allocator, .{
            .context = context,
            .base = base,
            .return_count = return_count,
            .kind = kind,
            .handler = handler,
            .handler_depth = handler_depth,
        });
    }

    fn readyProtectedContinuationIndex(thread: *Thread) ?usize {
        for (thread.protected_continuations.items, 0..) |continuation, index| {
            if (continuation.context.frame_count == thread.frames.items.len) return index;
        }
        return null;
    }

    fn errorProtectedContinuationIndex(thread: *Thread) ?usize {
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

    fn completeReadyProtectedContinuation(self: *State, thread: *Thread) !bool {
        const index = readyProtectedContinuationIndex(thread) orelse return false;
        const continuation = thread.protected_continuations.items[index];
        const values = try self.copyStackSlice(thread, thread.last_result_base, thread.last_result_count);
        defer self.allocator.free(values);
        _ = try self.restoreProtectedCall(thread, continuation.context, .nil);
        _ = thread.protected_continuations.orderedRemove(index);
        try self.returnProtectedContinuationSuccess(thread, continuation, values);
        return true;
    }

    fn completeProtectedContinuationError(self: *State, thread: *Thread, error_value: Value) !bool {
        const index = errorProtectedContinuationIndex(thread) orelse return false;
        const continuation = thread.protected_continuations.items[index];
        const failure = try self.restoreProtectedCall(thread, continuation.context, error_value);
        _ = thread.protected_continuations.orderedRemove(index);
        try self.returnProtectedContinuationFailure(thread, continuation, failure);
        return true;
    }

    fn returnProtectedContinuationSuccess(self: *State, thread: *Thread, continuation: ProtectedContinuation, values: []Value) !void {
        switch (continuation.kind) {
            .pcall, .xpcall => try self.returnProtectedResult(thread, continuation.base, continuation.return_count, .{ .success = values }),
            .xpcall_handler => {
                const handled = if (values.len == 0) Value.nil else values[0];
                try self.returnValues(thread, continuation.base, continuation.return_count, &.{ .{ .boolean = false }, handled });
            },
        }
    }

    fn returnProtectedContinuationFailure(self: *State, thread: *Thread, continuation: ProtectedContinuation, failure: Value) !void {
        switch (continuation.kind) {
            .pcall => try self.returnProtectedResult(thread, continuation.base, continuation.return_count, .{ .failure = failure }),
            .xpcall => try self.returnXpcallFailure(thread, continuation.base, continuation.return_count, continuation.handler, failure),
            .xpcall_handler => try self.returnXpcallFailureFromDepth(thread, continuation.base, continuation.return_count, continuation.handler, failure, continuation.handler_depth + 1),
        }
    }

    pub fn valueToString(self: *State, thread: *Thread, value: Value) anyerror![]const u8 {
        if (isFileValue(value)) {
            if (isClosedFileValue(value)) return self.intern("file (closed)");
            var file_name = std.ArrayList(u8).empty;
            defer file_name.deinit(self.allocator);
            try appendFmt(self.allocator, &file_name, "file (0x{x})", .{@intFromPtr(value.table)});
            return self.intern(file_name.items);
        }

        if (try self.getMetamethod(value, "__tostring")) |metamethod| {
            const result = try self.callOneResult(thread, metamethod, &.{value});
            return switch (result) {
                .string => |string| string,
                else => self.fail("'__tostring' must return a string"),
            };
        }

        if (try self.getMetamethod(value, "__name")) |name| {
            if (name == .string) {
                var named = std.ArrayList(u8).empty;
                defer named.deinit(self.allocator);
                try appendNamedValue(self.allocator, &named, name.string, value);
                return self.intern(named.items);
            }
        }

        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.allocator);
        try appendValue(self.allocator, &out, value);
        return self.intern(out.items);
    }

    fn getMetatableValue(self: *State, value: Value) !Value {
        const metatable = switch (value) {
            .table => |table| table.metatable orelse return .nil,
            .userdata => |userdata| userdata.metatable orelse return .nil,
            .string => self.string_metatable orelse return .nil,
            .integer, .number => self.number_metatable orelse return .nil,
            .boolean => self.boolean_metatable orelse return .nil,
            .nil => self.nil_metatable orelse return .nil,
            else => return .nil,
        };
        const locked = metatable.get(.{ .string = "__metatable" });
        if (locked != .nil) return locked;
        return .{ .table = metatable };
    }

    fn setMetatableValue(self: *State, table_value: Value, metatable_value: Value) !void {
        const table = try self.expectTable(table_value);
        if (table.metatable) |metatable| {
            if (metatable.get(.{ .string = "__metatable" }) != .nil) return self.fail("cannot change a protected metatable");
        }
        const metatable = switch (metatable_value) {
            .nil => null,
            .table => |metatable| metatable,
            else => return self.fail("nil or table expected"),
        };
        self.setTableMetatableRaw(table, metatable);
        if (table.metatable) |active_metatable| self.writeBarrier(table.marked, .{ .table = active_metatable });
    }

    pub fn setDebugMetatableValue(self: *State, value: Value, metatable_value: Value) !void {
        const metatable = switch (metatable_value) {
            .nil => null,
            .table => |metatable| metatable,
            else => return self.fail("nil or table expected"),
        };
        switch (value) {
            .table => |table| {
                self.setTableMetatableRaw(table, metatable);
                if (metatable) |mt| self.writeBarrier(table.marked, .{ .table = mt });
            },
            .userdata => |userdata| {
                userdata.metatable = metatable;
                if (metatable) |mt| self.writeBarrier(userdata.marked, .{ .table = mt });
            },
            .string => self.string_metatable = metatable,
            .integer, .number => self.number_metatable = metatable,
            .boolean => self.boolean_metatable = metatable,
            .nil => self.nil_metatable = metatable,
            else => return self.fail("cannot set metatable for this value"),
        }
    }

    fn getMetamethod(self: *State, value: Value, name: []const u8) !?Value {
        const metatable = switch (value) {
            .table => |table| table.metatable orelse return null,
            .userdata => |userdata| userdata.metatable orelse return null,
            .string => self.string_metatable orelse return null,
            .integer, .number => self.number_metatable orelse return null,
            .boolean => self.boolean_metatable orelse return null,
            .nil => self.nil_metatable orelse return null,
            else => return null,
        };
        const metamethod = metatable.get(.{ .string = name });
        return if (metamethod == .nil) null else metamethod;
    }

    pub fn setTableMetatableRaw(self: *State, table: *Table, metatable: ?*Table) void {
        const old_has_metatable = table.metatable != null;
        table.metatable = metatable;
        self.noteTableMetatableChanged(table, old_has_metatable);
    }

    fn noteTableMetatableChanged(self: *State, table: *Table, old_has_metatable: bool) void {
        if (!self.isTrackedTable(table)) return;
        const new_has_metatable = table.metatable != null;
        if (old_has_metatable == new_has_metatable) return;
        if (new_has_metatable) {
            table.metatable_prev = null;
            table.metatable_next = self.table_metatable_head;
            if (self.table_metatable_head) |head| head.metatable_prev = table;
            self.table_metatable_head = table;
            self.table_metatable_count += 1;
        } else {
            self.unlinkTableMetatable(table);
            self.table_metatable_count -= 1;
        }
    }

    fn unlinkTableMetatable(self: *State, table: *Table) void {
        if (table.metatable_prev) |prev| {
            prev.metatable_next = table.metatable_next;
        } else if (self.table_metatable_head == table) {
            self.table_metatable_head = table.metatable_next;
        }
        if (table.metatable_next) |next| next.metatable_prev = table.metatable_prev;
        table.metatable_prev = null;
        table.metatable_next = null;
    }

    pub fn luaTypeNameForError(self: *State, value: Value) []const u8 {
        if (isFileValue(value)) return "FILE*";
        if (self.getMetamethod(value, "__name") catch null) |name| {
            if (name == .string) return name.string;
        }
        return luaTypeName(value);
    }

    fn getEitherMetamethod(self: *State, lhs: Value, rhs: Value, name: []const u8) !?Value {
        if (try self.getMetamethod(lhs, name)) |metamethod| return metamethod;
        return self.getMetamethod(rhs, name);
    }

    fn binaryOpToRegister(self: *State, thread: *Thread, op: bytecode.Binary, kind: BinaryOp) !void {
        const lhs = self.get(thread, op.left);
        const rhs = self.get(thread, op.right);
        if (kind == .concat and luaStringLike(lhs) and luaStringLike(rhs)) {
            self.set(thread, op.dest, try self.concatValues(lhs, rhs));
            return;
        }
        const raw = rawBinaryOp(lhs, rhs, kind) catch |err| switch (err) {
            error.RuntimeError => if ((kind == .idiv or kind == .mod) and (toInteger(rhs) orelse 1) == 0) return self.failRuntimeDetail(thread, if (kind == .mod) "attempt to perform 'n%0'" else "attempt to divide by zero") else return err,
        };
        if (raw) |value| {
            self.set(thread, op.dest, value);
            return;
        }

        const metamethod_name = binaryMetamethod(kind);
        const metamethod = (try self.getEitherMetamethod(lhs, rhs, metamethod_name)) orelse {
            if (bitwiseIntegerError(lhs, rhs, kind)) |message| return self.failRuntimeDetail(thread, message);
            return self.failBinaryTypeError(thread, lhs, rhs, kind);
        };
        const result = try self.callOneMetamethodWithContinuation(thread, metamethod_name, metamethod, &.{ lhs, rhs }, .{ .value = self.absoluteRegister(thread, op.dest) });
        self.set(thread, op.dest, result);
    }

    fn unaryOpToRegister(self: *State, thread: *Thread, op: bytecode.Unary, kind: UnaryMetamethodOp) !void {
        const value = self.get(thread, op.source);
        if (rawUnaryOp(value, kind)) |result| {
            self.set(thread, op.dest, result);
            return;
        }
        if (kind == .bnot) {
            if (bitwiseValueError(value)) |message| return self.failRuntimeDetail(thread, message);
        }
        const metamethod = (try self.getMetamethod(value, unaryMetamethod(kind))) orelse return self.failUnaryTypeError(thread, value, kind);
        const result = try self.callOneMetamethodWithContinuation(thread, unaryMetamethod(kind), metamethod, &.{ value, value }, .{ .value = self.absoluteRegister(thread, op.dest) });
        self.set(thread, op.dest, result);
    }

    fn equalValuesToRegister(self: *State, thread: *Thread, op: bytecode.Binary) !void {
        const lhs = self.get(thread, op.left);
        const rhs = self.get(thread, op.right);
        if (valuesEqual(lhs, rhs)) {
            self.set(thread, op.dest, .{ .boolean = true });
            return;
        }
        if (lhs != .table or rhs != .table) {
            self.set(thread, op.dest, .{ .boolean = false });
            return;
        }
        const metamethod = (try self.getEitherMetamethod(lhs, rhs, "__eq")) orelse {
            self.set(thread, op.dest, .{ .boolean = false });
            return;
        };
        const result = try self.callOneMetamethodWithContinuation(thread, "__eq", metamethod, &.{ lhs, rhs }, .{ .truthy = self.absoluteRegister(thread, op.dest) });
        self.set(thread, op.dest, .{ .boolean = truthy(result) });
    }

    fn compareValuesToRegister(self: *State, thread: *Thread, op: bytecode.Binary, kind: CompareOp) !void {
        const lhs = self.get(thread, op.left);
        const rhs = self.get(thread, op.right);
        if (rawCompare(lhs, rhs, kind)) |result| {
            self.set(thread, op.dest, .{ .boolean = result });
            return;
        }
        switch (kind) {
            .lt => {
                const metamethod = (try self.getEitherMetamethod(lhs, rhs, "__lt")) orelse return self.failCompareTypeError(thread, lhs, rhs);
                const result = try self.callOneMetamethodWithContinuation(thread, "__lt", metamethod, &.{ lhs, rhs }, .{ .truthy = self.absoluteRegister(thread, op.dest) });
                self.set(thread, op.dest, .{ .boolean = truthy(result) });
            },
            .le => {
                if (try self.getEitherMetamethod(lhs, rhs, "__le")) |metamethod| {
                    const result = try self.callOneMetamethodWithContinuation(thread, "__le", metamethod, &.{ lhs, rhs }, .{ .truthy = self.absoluteRegister(thread, op.dest) });
                    self.set(thread, op.dest, .{ .boolean = truthy(result) });
                    return;
                }
                const lt = (try self.getEitherMetamethod(lhs, rhs, "__lt")) orelse return self.failCompareTypeError(thread, lhs, rhs);
                const result = try self.callOneMetamethodWithContinuation(thread, "__lt", lt, &.{ rhs, lhs }, .{ .inverted_truthy = self.absoluteRegister(thread, op.dest) });
                self.set(thread, op.dest, .{ .boolean = !truthy(result) });
            },
        }
    }

    fn compareBranch(self: *State, thread: *Thread, op: bytecode.CompareBranch) !void {
        const lhs = self.get(thread, op.left);
        const rhs = self.get(thread, op.right);
        switch (op.op) {
            .eq => {
                if (valuesEqual(lhs, rhs)) return self.jumpIfBranchResult(thread, true, op.jump_if_truthy, op.offset);
                if (lhs != .table or rhs != .table) return self.jumpIfBranchResult(thread, false, op.jump_if_truthy, op.offset);
                const metamethod = (try self.getEitherMetamethod(lhs, rhs, "__eq")) orelse return self.jumpIfBranchResult(thread, false, op.jump_if_truthy, op.offset);
                const continuation: BranchContinuation = .{ .jump_if_truthy = op.jump_if_truthy, .offset = op.offset };
                const result = try self.callOneMetamethodWithContinuation(thread, "__eq", metamethod, &.{ lhs, rhs }, .{ .branch_truthy = continuation });
                try self.jumpIfBranchResult(thread, truthy(result), op.jump_if_truthy, op.offset);
            },
            .lt => try self.compareBranchOrder(thread, lhs, rhs, .lt, "__lt", op.jump_if_truthy, op.offset),
            .le => {
                if (rawCompare(lhs, rhs, .le)) |result| return self.jumpIfBranchResult(thread, result, op.jump_if_truthy, op.offset);
                if (try self.getEitherMetamethod(lhs, rhs, "__le")) |metamethod| {
                    const continuation: BranchContinuation = .{ .jump_if_truthy = op.jump_if_truthy, .offset = op.offset };
                    const result = try self.callOneMetamethodWithContinuation(thread, "__le", metamethod, &.{ lhs, rhs }, .{ .branch_truthy = continuation });
                    return self.jumpIfBranchResult(thread, truthy(result), op.jump_if_truthy, op.offset);
                }
                const lt = (try self.getEitherMetamethod(lhs, rhs, "__lt")) orelse return self.failCompareTypeError(thread, lhs, rhs);
                const continuation: BranchContinuation = .{ .jump_if_truthy = op.jump_if_truthy, .offset = op.offset };
                const result = try self.callOneMetamethodWithContinuation(thread, "__lt", lt, &.{ rhs, lhs }, .{ .branch_inverted_truthy = continuation });
                try self.jumpIfBranchResult(thread, !truthy(result), op.jump_if_truthy, op.offset);
            },
        }
    }

    fn compareBranchOrder(self: *State, thread: *Thread, lhs: Value, rhs: Value, kind: CompareOp, metamethod_name: []const u8, jump_if_truthy: bool, offset: bytecode.JumpOffset) !void {
        if (rawCompare(lhs, rhs, kind)) |result| return self.jumpIfBranchResult(thread, result, jump_if_truthy, offset);
        const metamethod = (try self.getEitherMetamethod(lhs, rhs, metamethod_name)) orelse return self.failCompareTypeError(thread, lhs, rhs);
        const continuation: BranchContinuation = .{ .jump_if_truthy = jump_if_truthy, .offset = offset };
        const result = try self.callOneMetamethodWithContinuation(thread, metamethod_name, metamethod, &.{ lhs, rhs }, .{ .branch_truthy = continuation });
        try self.jumpIfBranchResult(thread, truthy(result), jump_if_truthy, offset);
    }

    fn jumpIfBranchResult(self: *State, thread: *Thread, result: bool, jump_if_truthy: bool, offset: bytecode.JumpOffset) !void {
        if (result == jump_if_truthy) try self.jumpThreadMaybeFast(thread, offset, true);
    }

    fn lengthToRegister(self: *State, thread: *Thread, op: bytecode.Unary) !void {
        const value = self.get(thread, op.source);
        switch (value) {
            .string => |string| self.set(thread, op.dest, .{ .integer = @intCast(string.len) }),
            .table => |table| if ((try self.getMetamethod(value, "__len"))) |metamethod| {
                const result = try self.callOneMetamethodWithContinuation(thread, "__len", metamethod, &.{ value, value }, .{ .value = self.absoluteRegister(thread, op.dest) });
                self.set(thread, op.dest, result);
            } else {
                self.set(thread, op.dest, .{ .integer = table.len() });
            },
            else => if ((try self.getMetamethod(value, "__len"))) |metamethod| {
                const result = try self.callOneMetamethodWithContinuation(thread, "__len", metamethod, &.{ value, value }, .{ .value = self.absoluteRegister(thread, op.dest) });
                self.set(thread, op.dest, result);
            } else {
                return self.failLengthTypeError(thread, value);
            },
        }
    }

    fn rawLen(self: *State, value: Value) !Value {
        return switch (value) {
            .string => |string| .{ .integer = @intCast(string.len) },
            .table => |table| if (isFileValue(value)) self.fail("table or string expected") else .{ .integer = table.len() },
            else => self.fail("table or string expected"),
        };
    }

    fn binaryOp(self: *State, thread: *Thread, lhs: Value, rhs: Value, op: BinaryOp) !Value {
        if (op == .concat and luaStringLike(lhs) and luaStringLike(rhs)) return self.concatValues(lhs, rhs);
        const raw = rawBinaryOp(lhs, rhs, op) catch |err| switch (err) {
            error.RuntimeError => if ((op == .idiv or op == .mod) and (toInteger(rhs) orelse 1) == 0) return self.failRuntimeDetail(thread, if (op == .mod) "attempt to perform 'n%0'" else "attempt to divide by zero") else return err,
        };
        if (raw) |value| return value;
        const metamethod_name = binaryMetamethod(op);
        const metamethod = (try self.getEitherMetamethod(lhs, rhs, metamethod_name)) orelse {
            if (bitwiseIntegerError(lhs, rhs, op)) |message| return self.failRuntimeDetail(thread, message);
            return self.failBinaryTypeError(thread, lhs, rhs, op);
        };
        return self.callOneMetamethod(thread, metamethod_name, metamethod, &.{ lhs, rhs });
    }

    fn unaryOp(self: *State, thread: *Thread, value: Value, op: UnaryMetamethodOp) !Value {
        if (rawUnaryOp(value, op)) |result| return result;
        if (op == .bnot) {
            if (bitwiseValueError(value)) |message| return self.failRuntimeDetail(thread, message);
        }
        const metamethod_name = unaryMetamethod(op);
        const metamethod = (try self.getMetamethod(value, metamethod_name)) orelse return self.failUnaryTypeError(thread, value, op);
        return self.callOneMetamethod(thread, metamethod_name, metamethod, &.{ value, value });
    }

    fn equalValues(self: *State, thread: *Thread, lhs: Value, rhs: Value) !bool {
        if (valuesEqual(lhs, rhs)) return true;
        if (lhs != .table or rhs != .table) return false;
        const metamethod = (try self.getEitherMetamethod(lhs, rhs, "__eq")) orelse return false;
        return truthy(try self.callOneMetamethod(thread, "__eq", metamethod, &.{ lhs, rhs }));
    }

    pub fn compareValues(self: *State, thread: *Thread, lhs: Value, rhs: Value, op: CompareOp) !bool {
        if (rawCompare(lhs, rhs, op)) |result| return result;
        switch (op) {
            .lt => {
                const metamethod = (try self.getEitherMetamethod(lhs, rhs, "__lt")) orelse return self.failCompareTypeError(thread, lhs, rhs);
                return truthy(try self.callOneMetamethod(thread, "__lt", metamethod, &.{ lhs, rhs }));
            },
            .le => {
                if (try self.getEitherMetamethod(lhs, rhs, "__le")) |metamethod| {
                    return truthy(try self.callOneMetamethod(thread, "__le", metamethod, &.{ lhs, rhs }));
                }
                const lt = (try self.getEitherMetamethod(lhs, rhs, "__lt")) orelse return self.failCompareTypeError(thread, lhs, rhs);
                return !truthy(try self.callOneMetamethod(thread, "__lt", lt, &.{ rhs, lhs }));
            },
        }
    }

    fn callClosure(self: *State, thread: *Thread, op: bytecode.Call, closure: *Closure, debug_name_override: ?[]const u8, debug_namewhat_override: ?[]const u8) !void {
        if (thread.frames.items.len >= self.callFrameLimit()) return self.fail("stack overflow");

        const caller = thread.frames.items[thread.frames.items.len - 1];
        const base = caller.base + op.base;
        var frame = try self.prepareClosureFrame(thread, closure, base, base, @intCast(op.arg_count), base, op.return_count);
        frame.debug_name_override = debug_name_override;
        frame.debug_namewhat_override = debug_namewhat_override;
        errdefer frame.deinit(self.allocator);
        try thread.frames.append(self.allocator, frame);
        if (thread.hook_call and !thread.hook_running) try self.callHook(thread, "call");
    }

    fn tailCallValue(self: *State, thread: *Thread, op: bytecode.Call) anyerror!void {
        var resolved = try self.resolveCall(thread, op);
        var depth: usize = 0;
        while (true) {
            const callee = self.get(thread, resolved.base);
            switch (callee) {
                .closure => break,
                .coroutine_wrapper => break,
                else => if (isNativeCallable(callee)) break,
            }

            if (depth > max_metamethod_depth) return self.fail("'__call' chain too long");
            const metamethod = try self.getMetamethod(callee, "__call") orelse break;
            try self.prependCallArgument(thread, resolved, metamethod, callee);
            resolved.arg_count += 1;
            depth += 1;
        }

        const callee = self.get(thread, resolved.base);
        switch (callee) {
            .closure => |closure| {
                try self.closeActiveToBeClosedInTopFrame(thread, null);
                const frame = thread.frames.items[thread.frames.items.len - 1];
                self.closeUpvalues(thread, frame.base);
                const new_frame = try self.prepareClosureFrame(thread, closure, frame.base + resolved.base, frame.base, @intCast(resolved.arg_count), frame.return_start, frame.return_count);
                var tail_frame = new_frame;
                tail_frame.is_tail_call = true;
                thread.frames.items[thread.frames.items.len - 1].deinit(self.allocator);
                thread.frames.items[thread.frames.items.len - 1] = tail_frame;
                if (thread.hook_call and !thread.hook_running) {
                    const previous_transfer_index_base = thread.hook_transfer_index_base;
                    const previous_transfer_stack_base = thread.hook_transfer_stack_base;
                    const previous_transfer_count = thread.hook_transfer_count;
                    const previous_transfer_values = thread.hook_transfer_values;
                    thread.hook_transfer_index_base = 1;
                    thread.hook_transfer_stack_base = new_frame.base;
                    thread.hook_transfer_count = closure.proto.param_count;
                    thread.hook_transfer_values = &.{};
                    defer {
                        thread.hook_transfer_index_base = previous_transfer_index_base;
                        thread.hook_transfer_stack_base = previous_transfer_stack_base;
                        thread.hook_transfer_count = previous_transfer_count;
                        thread.hook_transfer_values = previous_transfer_values;
                    }
                    try self.callHook(thread, "tail call");
                }
            },
            else => {
                const frame = thread.frames.items[thread.frames.items.len - 1];
                const frame_count = thread.frames.items.len;
                self.callValue(thread, .{ .base = resolved.base, .arg_count = resolved.arg_count, .return_count = frame.return_count }) catch |err| switch (err) {
                    error.CoroutineYield => {
                        try self.pushTailCallContinuation(thread, frame_count, resolved.base, frame.return_count);
                        return err;
                    },
                    else => return err,
                };
                try self.runThreadUntil(thread, frame_count);
                try self.returnFromFrame(thread, resolved.base, frame.return_count);
            },
        }
    }

    fn returnFromFrame(self: *State, thread: *Thread, first: bytecode.Register, count: u16) !void {
        const frame_index = thread.frames.items.len - 1;
        var frame = &thread.frames.items[frame_index];
        if (frame.pending_returns == null and !frame.proto.has_to_close_locals and (!thread.hook_return or thread.hook_running)) {
            const source_start = frame.base + first;
            const source_count = try self.resolveResultCount(thread, source_start, count);
            self.closeUpvalues(thread, frame.base);
            if (thread.frames.items.len == 1) {
                thread.last_result_base = source_start;
                thread.last_result_count = source_count;
                frame.deinit(self.allocator);
                thread.frames.items.len = 0;
                return;
            }

            const return_start = frame.return_start;
            const return_count = try self.resolveReturnCount(frame.return_count, source_count);
            frame.deinit(self.allocator);
            thread.frames.items.len -= 1;

            try thread.ensureStack(self.allocator, return_start + return_count, self.stackValueLimit());
            const copied = @min(return_count, source_count);
            for (0..copied) |index| thread.stack.items[return_start + index] = thread.stack.items[source_start + index];
            for (copied..return_count) |index| thread.stack.items[return_start + index] = .nil;
            thread.last_result_base = return_start;
            thread.last_result_count = return_count;
            return;
        }

        const preserved = frame.pending_returns orelse blk: {
            const source_start = frame.base + first;
            const source_count = try self.resolveResultCount(thread, source_start, count);
            const values = try self.allocator.alloc(Value, source_count);
            for (values, 0..) |*value, index| value.* = thread.stack.items[source_start + index];
            frame.pending_returns = values;
            break :blk values;
        };
        try self.closeActiveToBeClosedInTopFrame(thread, null);
        frame = &thread.frames.items[frame_index];
        if (thread.hook_return and !thread.hook_running) {
            const previous_transfer_index_base = thread.hook_transfer_index_base;
            const previous_transfer_stack_base = thread.hook_transfer_stack_base;
            const previous_transfer_count = thread.hook_transfer_count;
            const previous_transfer_values = thread.hook_transfer_values;
            thread.hook_transfer_index_base = @as(i64, @intCast(first)) + 1;
            thread.hook_transfer_stack_base = frame.base + first;
            thread.hook_transfer_count = preserved.len;
            thread.hook_transfer_values = preserved;
            defer {
                thread.hook_transfer_index_base = previous_transfer_index_base;
                thread.hook_transfer_stack_base = previous_transfer_stack_base;
                thread.hook_transfer_count = previous_transfer_count;
                thread.hook_transfer_values = previous_transfer_values;
            }
            try self.callReturnHook(thread, frame.debug_name_override orelse frame.proto.debug_name);
        }
        frame = &thread.frames.items[frame_index];
        frame.pending_returns = null;
        self.closeUpvalues(thread, frame.base);
        if (thread.frames.items.len == 1) {
            const result_start = frame.base + first;
            try thread.ensureStack(self.allocator, result_start + preserved.len, self.stackValueLimit());
            for (preserved, 0..) |value, index| thread.stack.items[result_start + index] = value;
            thread.last_result_base = result_start;
            thread.last_result_count = preserved.len;
            self.allocator.free(preserved);
            frame.deinit(self.allocator);
            thread.frames.items.len = 0;
            return;
        }

        const return_start = frame.return_start;
        const return_count = try self.resolveReturnCount(frame.return_count, preserved.len);
        frame.deinit(self.allocator);
        thread.frames.items.len -= 1;

        try thread.ensureStack(self.allocator, return_start + return_count, self.stackValueLimit());
        const copied = @min(return_count, preserved.len);
        for (preserved[0..copied], 0..) |value, index| thread.stack.items[return_start + index] = value;
        for (copied..return_count) |index| thread.stack.items[return_start + index] = .nil;
        self.allocator.free(preserved);
        thread.last_result_base = return_start;
        thread.last_result_count = return_count;
    }

    pub fn returnValues(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, values: []const Value) !void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const actual_count = try self.resolveReturnCount(return_count, values.len);
        const absolute_base = frame.base + base;
        const stored_count = @max(actual_count, values.len);
        try thread.ensureStack(self.allocator, absolute_base + stored_count, self.stackValueLimit());
        for (0..stored_count) |index| {
            thread.stack.items[absolute_base + index] = if (index < values.len) values[index] else .nil;
        }
        thread.last_result_base = absolute_base;
        thread.last_result_count = actual_count;
        thread.last_transfer_base = absolute_base;
        thread.last_transfer_count = values.len;
    }

    fn prepareClosureFrame(self: *State, thread: *Thread, closure: *Closure, source_base: usize, frame_base: usize, arg_count: usize, return_start: usize, return_count: u16) !CallFrame {
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

    fn captureVarargs(self: *State, thread: *Thread, source_start: usize, count: usize) ![]const Value {
        if (count == 0) return &.{};
        const values = try self.allocator.alloc(Value, count);
        for (0..count) |index| values[index] = thread.stack.items[source_start + index];
        return values;
    }

    fn namedVarargTable(self: *State, varargs: []const Value) !Value {
        const table_value = try self.newTableWithHints(@intCast(varargs.len), 1);
        const table = table_value.table;
        self.noteAllocationFreed(tableGcBytes(table));
        table.counts_for_gc_count = false;
        try self.setTableRaw(table, .{ .string = try self.intern("n") }, .{ .integer = @intCast(varargs.len) });
        for (varargs, 0..) |value, index| {
            try self.setTableRaw(table, .{ .integer = @intCast(index + 1) }, value);
        }
        return table_value;
    }

    fn resolveCall(self: *State, thread: *Thread, op: bytecode.Call) !bytecode.Call {
        if (op.arg_count != bytecode.multret_count) return op;
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const expected_base = frame.base + op.base + 1;
        if (thread.last_result_base < expected_base) return self.fail("invalid multiple-return call state");
        const end = thread.last_result_base + thread.last_result_count;
        const count = if (end <= expected_base) 0 else end - expected_base;
        return .{ .base = op.base, .arg_count = @intCast(count), .return_count = op.return_count };
    }

    fn resolveResultCount(self: *State, thread: *Thread, source_start: usize, count: u16) !usize {
        if (count != bytecode.multret_count) return count;
        if (thread.last_result_base < source_start) return self.fail("invalid multiple-return result state");
        const end = thread.last_result_base + thread.last_result_count;
        return if (end <= source_start) 0 else end - source_start;
    }

    fn resolveReturnCount(self: *State, count: u16, available: usize) !usize {
        _ = self;
        return if (count == bytecode.multret_count) available else count;
    }

    fn loadVarargs(self: *State, thread: *Thread, op: bytecode.Vararg) !void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        if (frame.proto.named_vararg) return self.loadNamedVarargs(thread, frame, op);
        const actual_count = try self.resolveReturnCount(op.count, frame.varargs.len);
        const dest = frame.base + op.dest;
        try thread.ensureStack(self.allocator, dest + actual_count, self.stackValueLimit());
        const copied = @min(actual_count, frame.varargs.len);
        for (0..copied) |index| thread.stack.items[dest + index] = frame.varargs[index];
        for (copied..actual_count) |index| thread.stack.items[dest + index] = .nil;
        thread.last_result_base = dest;
        thread.last_result_count = actual_count;
    }

    fn loadNamedVarargs(self: *State, thread: *Thread, frame: CallFrame, op: bytecode.Vararg) !void {
        const table_value = thread.stack.items[frame.base + frame.proto.param_count];
        const table = try self.expectTable(table_value);
        const count = try self.namedVarargCount(table);
        const actual_count = try self.resolveReturnCount(op.count, count);
        const dest = frame.base + op.dest;
        try thread.ensureStack(self.allocator, dest + actual_count, self.stackValueLimit());
        const copied = @min(actual_count, count);
        for (0..copied) |index| thread.stack.items[dest + index] = table.get(.{ .integer = @intCast(index + 1) });
        for (copied..actual_count) |index| thread.stack.items[dest + index] = .nil;
        thread.last_result_base = dest;
        thread.last_result_count = actual_count;
    }

    fn namedVarargCount(self: *State, table: *Table) !usize {
        const n_value = table.get(.{ .string = try self.intern("n") });
        if (n_value != .integer or n_value.integer < 0 or n_value.integer >= bytecode.multret_count) {
            return self.fail("vararg table has no proper 'n'");
        }
        return @intCast(n_value.integer);
    }

    fn setList(self: *State, thread: *Thread, op: bytecode.SetList) !void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const source_start = frame.base + op.first;
        const count: usize = if (op.count == bytecode.multret_count) try self.resolveResultCount(thread, source_start, bytecode.multret_count) else op.count;
        const table_value = self.get(thread, op.table);
        if (try self.fastSetListRaw(thread, table_value, source_start, count, op.start_index)) return;
        for (0..count) |index| {
            const array_index = @as(usize, op.start_index) + index;
            try self.setTable(table_value, .{ .integer = @intCast(array_index) }, thread.stack.items[source_start + index]);
        }
    }

    fn fastSetListRaw(self: *State, thread: *Thread, table_value: Value, source_start: usize, count: usize, start_index_u32: u32) !bool {
        if (table_value != .table or start_index_u32 == 0) return false;
        const table = table_value.table;
        if (table.metatable != null) return false;

        const start_index: usize = start_index_u32;
        var grow_to = table.array.items.len;
        for (0..count) |offset| {
            if (offset > std.math.maxInt(usize) - start_index) return self.fail("table overflow");
            const array_index = start_index + offset;
            if (array_index > std.math.maxInt(i64)) return false;
            if (thread.stack.items[source_start + offset] != .nil and array_index > grow_to) grow_to = array_index;
        }

        if (grow_to > table.array.items.len and start_index > table.array.items.len + 1 and grow_to > table.array.capacity) return false;
        if (grow_to > table.array.items.len) {
            const old_capacity_bytes = tableCapacityBytes(table);
            const old_len = table.array.items.len;
            try table.array.resize(self.allocator, grow_to);
            @memset(table.array.items[old_len..], .nil);
            self.noteTableCapacityDelta(table, old_capacity_bytes);
        }

        for (0..count) |offset| {
            const array_index = start_index + offset;
            if (array_index > table.array.items.len) continue;
            const value = thread.stack.items[source_start + offset];
            table.array.items[array_index - 1] = value;
            const key = Value{ .integer = @intCast(array_index) };
            if (value != .nil) table.removeHashKey(key);
            self.writeTableBarrier(table, key, value);
        }
        return true;
    }

    fn selectValues(self: *State, thread: *Thread, op: bytecode.Call) !void {
        if (op.arg_count == 0) return self.failArgumentMessage("select", 1, "value expected");
        const first = argValue(self, thread, op, 0);
        if (first == .string and std.mem.eql(u8, first.string, "#")) {
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .integer = @intCast(op.arg_count - 1) }});
            return;
        }

        var index = toInteger(first) orelse return self.failArgumentType("select", 1, "number", first);
        const count: i64 = @intCast(op.arg_count - 1);
        if (index < 0) index = count + index + 1;
        if (index < 1 or index > count + 1) return self.failArgumentMessage("select", 1, "index out of range");

        var values = std.ArrayList(Value).empty;
        defer values.deinit(self.allocator);
        var arg_index: usize = @intCast(index);
        const last_arg: usize = @intCast(count);
        while (arg_index <= last_arg) : (arg_index += 1) {
            try values.append(self.allocator, argValue(self, thread, op, @intCast(arg_index)));
        }
        try self.returnValues(thread, op.base, op.return_count, values.items);
    }

    fn assertValues(self: *State, thread: *Thread, op: bytecode.Call) !void {
        if (op.arg_count == 0) return self.failArgumentMessage("assert", 1, "value expected");

        const condition = argValue(self, thread, op, 0);
        if (!truthy(condition)) {
            if (op.arg_count >= 2) return self.throwValue(try self.errorObjectValue(argValue(self, thread, op, 1)));
            return self.throwStringWithLocation(thread, "assertion failed!", 1);
        }

        const values = try self.allocator.alloc(Value, op.arg_count);
        defer self.allocator.free(values);
        for (values, 0..) |*value, index| value.* = argValue(self, thread, op, @intCast(index));
        try self.returnValues(thread, op.base, op.return_count, values);
    }

    fn errorValue(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const raw_value = argValue(self, thread, op, 0);
        const value = try self.errorObjectValue(raw_value);
        const level = if (op.arg_count >= 2) toInteger(argValue(self, thread, op, 1)) orelse 1 else 1;
        if (level <= 0 or value != .string or raw_value == .nil) return self.throwValue(value);

        const level_index = std.math.cast(usize, level) orelse return self.throwValue(value);
        return self.throwStringWithLocation(thread, value.string, level_index);
    }

    fn throwStringWithLocation(self: *State, thread: *Thread, message_text: []const u8, level: usize) !void {
        const line = self.lineForErrorLevel(thread, level) orelse return self.throwValue(.{ .string = try self.intern(message_text) });
        const source = self.sourceForErrorLevel(thread, level) orelse "zlua";
        const message = try std.fmt.allocPrint(self.allocator, "{s}:{d}: {s}", .{ source, line, message_text });
        defer self.allocator.free(message);
        return self.throwValue(.{ .string = try self.intern(message) });
    }

    fn errorObjectValue(self: *State, value: Value) !Value {
        if (value == .nil) return .{ .string = try self.intern("<no error object>") };
        return value;
    }

    fn pcallValues(self: *State, thread: *Thread, op: bytecode.Call) !void {
        if (op.arg_count == 0) return self.failArgumentMessage("pcall", 1, "value expected");
        const args = try self.collectArgs(thread, op, 1);
        defer self.allocator.free(args);

        const context = self.protectedCallContextWithErrors(thread);
        const previous_traceback_native_name = thread.traceback_native_name;
        thread.traceback_native_name = "pcall";
        defer thread.traceback_native_name = previous_traceback_native_name;
        const result = self.runProtectedCall(thread, context, argValue(self, thread, op, 0), args) catch |err| switch (err) {
            error.CoroutineYield => {
                try self.pushProtectedContinuation(thread, context, op.base, op.return_count, .pcall, .nil, 0);
                return err;
            },
            else => return err,
        };
        defer freeProtectedResult(self.allocator, result);
        try self.returnProtectedResult(thread, op.base, op.return_count, result);
    }

    fn xpcallValues(self: *State, thread: *Thread, op: bytecode.Call) !void {
        if (op.arg_count < 2) return self.failArgumentMessage("xpcall", 2, "value expected");
        const handler = argValue(self, thread, op, 1);
        const args = try self.collectArgs(thread, op, 2);
        defer self.allocator.free(args);

        const context = self.protectedCallContextWithErrors(thread);
        const result = self.runProtectedCall(thread, context, argValue(self, thread, op, 0), args) catch |err| switch (err) {
            error.CoroutineYield => {
                try self.pushProtectedContinuation(thread, context, op.base, op.return_count, .xpcall, handler, 0);
                return err;
            },
            else => return err,
        };
        defer freeProtectedResult(self.allocator, result);
        switch (result) {
            .success => try self.returnProtectedResult(thread, op.base, op.return_count, result),
            .failure => |error_value| try self.returnXpcallFailure(thread, op.base, op.return_count, handler, error_value),
        }
    }

    fn returnXpcallFailure(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, handler: Value, error_value: Value) !void {
        try self.returnXpcallFailureFromDepth(thread, base, return_count, handler, error_value, 0);
    }

    fn returnXpcallFailureFromDepth(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, handler: Value, error_value: Value, initial_depth: usize) !void {
        var current_error = error_value;
        var depth = initial_depth;
        while (true) : (depth += 1) {
            const handler_error = if (depth >= max_error_handler_depth)
                Value{ .string = try self.intern("C stack overflow") }
            else
                current_error;
            const context = self.protectedCallContextWithErrors(thread);
            const previous_traceback_close = self.traceback_error_in_close;
            self.traceback_error_in_close = self.last_error_in_close;
            const handler_result = self.runProtectedCall(thread, context, handler, &.{handler_error}) catch |err| switch (err) {
                error.CoroutineYield => {
                    try self.pushProtectedContinuation(thread, context, base, return_count, .xpcall_handler, handler, depth);
                    return err;
                },
                else => {
                    self.traceback_error_in_close = previous_traceback_close;
                    return err;
                },
            };
            self.traceback_error_in_close = previous_traceback_close;
            switch (handler_result) {
                .success => |values| {
                    defer self.allocator.free(values);
                    const handled = if (values.len == 0) Value.nil else values[0];
                    try self.returnValues(thread, base, return_count, &.{ .{ .boolean = false }, handled });
                    return;
                },
                .failure => |failure| {
                    if (depth >= max_error_handler_depth) {
                        try self.returnValues(thread, base, return_count, &.{ .{ .boolean = false }, .{ .string = try self.intern("error in error handling") } });
                        return;
                    }
                    current_error = failure;
                },
            }
        }
    }

    fn tracebackValue(self: *State, thread: *Thread, op: bytecode.Call) !void {
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.allocator);

        const message = argValue(self, thread, op, 0);
        if (message == .thread) {
            const target = message.thread;
            const level_value = if (op.arg_count >= 3) argValue(self, thread, op, 2) else Value.nil;
            const has_coroutine_level = level_value != .nil;
            if (!has_coroutine_level and target.close_error_value != null) if (target.error_traceback) |traceback| {
                try self.returnValues(thread, op.base, op.return_count, &.{.{ .string = traceback }});
                return;
            };
            const coroutine_level = if (has_coroutine_level) toInteger(level_value) orelse 1 else 0;
            const has_yield_trace = !has_coroutine_level and (target.frames.items.len != 0 or (target.status != .dead and target.yield_values.items.len != 0));
            try out.appendSlice(self.allocator, "stack traceback:");
            if (has_yield_trace) try out.appendSlice(self.allocator, "\n\t'yield'");
            const skip = if (coroutine_level <= 1) @as(usize, 0) else @as(usize, @intCast(coroutine_level - 1));
            var remaining = if (skip >= target.frames.items.len) @as(usize, 0) else target.frames.items.len - skip;
            if (remaining == 0 and target.status != .dead and target.yield_values.items.len != 0 and !has_coroutine_level) {
                try out.appendSlice(self.allocator, "\n\t@db.lua: in function <");
            }
            while (remaining > 0) {
                remaining -= 1;
                const level = target.frames.items.len - remaining;
                const frame = target.frames.items[remaining];
                try self.appendCoroutineTracebackFrame(&out, target, frame, @intCast(level));
            }
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .string = try self.intern(out.items) }});
            return;
        }
        if (message != .nil and message != .string) {
            try self.returnValues(thread, op.base, op.return_count, &.{message});
            return;
        }
        if (message != .nil) {
            try appendValue(self.allocator, &out, message);
            try out.append(self.allocator, '\n');
        }
        try out.appendSlice(self.allocator, "stack traceback:");
        if (thread.traceback_native_name) |name| try appendFmt(self.allocator, &out, "\n\t{s}", .{name});
        if (self.traceback_error_in_close) try out.appendSlice(self.allocator, "\n\tzlua:?: in metamethod 'close'");
        const level = if (op.arg_count >= 2) toInteger(argValue(self, thread, op, 1)) orelse 1 else 1;
        if (level <= 0) try out.appendSlice(self.allocator, "\n\t'traceback'");
        const skip = if (level <= 0) thread.frames.items.len else std.math.cast(usize, level - 1) orelse thread.frames.items.len;
        var index = if (skip >= thread.frames.items.len) @as(usize, 0) else thread.frames.items.len - skip;
        if (index > 21) {
            var first = index;
            var emitted: usize = 0;
            while (emitted < 10) : (emitted += 1) {
                first -= 1;
                try self.appendThreadTracebackFrame(&out, thread, first);
            }
            try out.appendSlice(self.allocator, "\n\t...\t(skip)");
            var tail: usize = 11;
            while (tail > 0) {
                tail -= 1;
                try self.appendThreadTracebackFrame(&out, thread, tail);
            }
        } else {
            while (index > 0) {
                index -= 1;
                try self.appendThreadTracebackFrame(&out, thread, index);
            }
        }

        try self.returnValues(thread, op.base, op.return_count, &.{.{ .string = try self.intern(out.items) }});
    }

    fn appendThreadTracebackFrame(self: *State, out: *std.ArrayList(u8), thread: *Thread, frame_index: usize) !void {
        const frame = thread.frames.items[frame_index];
        const line = lineForFrame(frame) orelse 0;
        try out.appendSlice(self.allocator, "\n\tzlua:");
        try appendFmt(self.allocator, out, "{d}", .{line});
        try out.appendSlice(self.allocator, if (thread.hook_running and frame_index == thread.frames.items.len - 1) ": in hook" else ": in function");
    }

    fn appendCoroutineTracebackFrame(self: *State, out: *std.ArrayList(u8), target: *Thread, frame: CallFrame, level: i64) !void {
        try out.append(self.allocator, '\n');
        try out.append(self.allocator, '\t');
        try out.appendSlice(self.allocator, frame.proto.source_name);
        if (self.currentFunctionName(target, level)) |name| {
            try appendFmt(self.allocator, out, ": in function '{s}'", .{name});
        } else {
            try out.appendSlice(self.allocator, ": in function <");
        }
    }

    fn snapshotCoroutineErrorTraceback(self: *State, target: *Thread) ![]const u8 {
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.allocator);
        try out.appendSlice(self.allocator, "stack traceback:\n\t'error'");
        var remaining = target.frames.items.len;
        while (remaining > 0) {
            remaining -= 1;
            const level = target.frames.items.len - remaining;
            try self.appendCoroutineTracebackFrame(&out, target, target.frames.items[remaining], @intCast(level));
        }
        return self.intern(out.items);
    }

    fn coroutineCreate(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const entry = argValue(self, thread, op, 0);
        if (!functionLike(entry)) return self.failArgumentType("coroutine.create", 1, "function", entry);
        try self.returnValues(thread, op.base, op.return_count, &.{.{ .thread = try self.newCoroutineThread(entry) }});
    }

    fn coroutineResume(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const target = try self.expectThread(argValue(self, thread, op, 0));
        const args = try self.collectArgs(thread, op, 1);
        defer self.allocator.free(args);

        const result = try self.resumeCoroutine(target, args);
        defer freeCoroutineResumeResult(self.allocator, result);
        try self.returnCoroutineResumeResult(thread, op.base, op.return_count, result);
    }

    fn coroutineYield(self: *State, thread: *Thread, op: bytecode.Call) !void {
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

    fn coroutineStatus(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const target = try self.expectThread(argValue(self, thread, op, 0));
        try self.returnValues(thread, op.base, op.return_count, &.{.{ .string = try self.intern(threadStatusName(target.status)) }});
    }

    fn coroutineRunning(self: *State, thread: *Thread, op: bytecode.Call) !void {
        try self.returnValues(thread, op.base, op.return_count, &.{ .{ .thread = thread }, .{ .boolean = thread.is_main } });
    }

    fn coroutineIsYieldable(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const target = if (op.arg_count == 0) thread else try self.expectThread(argValue(self, thread, op, 0));
        const yieldable = if (target == thread)
            !thread.is_main and thread.status == .running and thread.native_call_depth <= 1 and !thread.closing
        else
            !target.is_main and target.status != .dead and !target.closing;
        try self.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = yieldable }});
    }

    fn coroutineClose(self: *State, thread: *Thread, op: bytecode.Call) !void {
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
        if (try self.closeCoroutine(target, null)) |error_value| {
            if (closes_self) return self.throwValue(error_value);
            try self.returnValues(thread, op.base, op.return_count, &.{ .{ .boolean = false }, error_value });
            return;
        }
        if (closes_self) return error.CoroutineClose;
        try self.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = true }});
    }

    fn coroutineWrap(self: *State, thread: *Thread, op: bytecode.Call) !void {
        if (argValue(self, thread, op, 0) == .gmatch_iterator) {
            try self.returnValues(thread, op.base, op.return_count, &.{argValue(self, thread, op, 0)});
            return;
        }
        const entry = argValue(self, thread, op, 0);
        if (!functionLike(entry)) return self.failArgumentType("coroutine.wrap", 1, "function", entry);
        try self.returnValues(thread, op.base, op.return_count, &.{.{ .coroutine_wrapper = try self.newCoroutineThread(entry) }});
    }

    fn callCoroutineWrapper(self: *State, thread: *Thread, op: bytecode.Call, target: *Thread) !void {
        const args = try self.collectArgs(thread, op, 0);
        defer self.allocator.free(args);
        try self.callCoroutineWrapperWithArgs(thread, op.base, op.return_count, target, args);
    }

    fn callCoroutineWrapperWithArgs(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, target: *Thread, args: []const Value) !void {
        const result = try self.resumeCoroutine(target, args);
        defer freeCoroutineResumeResult(self.allocator, result);
        switch (result) {
            .success => |values| try self.returnValues(thread, base, return_count, values),
            .failure => |error_value| return self.throwValue(error_value),
        }
    }

    fn newCoroutineThread(self: *State, entry: Value) !*Thread {
        const thread = try self.allocator.create(Thread);
        errdefer self.allocator.destroy(thread);
        thread.* = Thread.initCoroutine(entry);
        errdefer thread.deinit(self.allocator);
        try self.thread_allocations.append(self.allocator, thread);
        self.noteAllocation(@sizeOf(Thread));
        return thread;
    }

    fn closeCoroutine(self: *State, target: *Thread, error_value: ?Value) !?Value {
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

    fn resumeCoroutine(self: *State, target: *Thread, args: []const Value) !CoroutineResumeResult {
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
            try self.startCoroutine(target, args);
        } else if (target.pending_c_continuation) {
            target.pending_c_continuation = false;
            try self.resumeCClosureDispatch(target, args);
        } else {
            try self.setCoroutineResumeValues(target, args);
        }

        while (true) {
            self.runThreadUntil(target, 0) catch |err| switch (err) {
                error.CoroutineYield => return .{ .success = try self.copyValues(target.yield_values.items) },
                error.CoroutineClose => return .{ .success = try self.copyValues(&.{}) },
                error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => {
                    const error_value = self.currentErrorValue();
                    const completed = self.completeProtectedContinuationError(target, error_value) catch |continuation_err| switch (continuation_err) {
                        error.CoroutineYield => return .{ .success = try self.copyValues(target.yield_values.items) },
                        else => return continuation_err,
                    };
                    if (completed) continue;
                    var final_error = error_value;
                    target.error_traceback = try self.snapshotCoroutineErrorTraceback(target);
                    if (try self.closeCoroutine(target, final_error)) |close_error_value| final_error = close_error_value;
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
                return .{ .success = try self.copyValues(values[2..]) };
            }
        }
        return .{ .success = try self.copyStackSlice(target, target.last_result_base, target.last_result_count) };
    }

    fn startCoroutine(self: *State, target: *Thread, args: []const Value) !void {
        const closure, const arg_count = switch (target.entry) {
            .closure => |closure| blk: {
                try target.ensureStack(self.allocator, 1 + args.len, self.stackValueLimit());
                target.stack.items[0] = .{ .closure = closure };
                for (args, 0..) |arg, index| target.stack.items[1 + index] = arg;
                break :blk .{ closure, args.len };
            },
            else => blk: {
                const trampoline = try self.callableEntryClosure();
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

    fn callableEntryClosure(self: *State) !*Closure {
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

    fn setCoroutineResumeValues(self: *State, target: *Thread, args: []const Value) !void {
        const actual_count = try self.resolveReturnCount(target.yield_result_count, args.len);
        try target.ensureStack(self.allocator, target.yield_result_base + actual_count, self.stackValueLimit());
        for (0..actual_count) |index| {
            target.stack.items[target.yield_result_base + index] = if (index < args.len) args[index] else .nil;
        }
        target.last_result_base = target.yield_result_base;
        target.last_result_count = actual_count;
    }

    fn returnCoroutineResumeResult(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, result: CoroutineResumeResult) !void {
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

    fn copyValues(self: *State, values: []const Value) ![]Value {
        const copied = try self.allocator.alloc(Value, values.len);
        @memcpy(copied, values);
        return copied;
    }

    fn copyStackSlice(self: *State, thread: *Thread, base: usize, count: usize) ![]Value {
        const values = try self.allocator.alloc(Value, count);
        for (values, 0..) |*value, index| value.* = thread.stack.items[base + index];
        return values;
    }

    fn lineForErrorLevel(self: *State, thread: *Thread, level: usize) ?usize {
        _ = self;
        if (level == 0 or level > thread.frames.items.len) return null;
        const frame = thread.frames.items[thread.frames.items.len - level];
        return lineForFrame(frame);
    }

    fn sourceForErrorLevel(self: *State, thread: *Thread, level: usize) ?[]const u8 {
        _ = self;
        if (level == 0 or level > thread.frames.items.len) return null;
        const source_name = thread.frames.items[thread.frames.items.len - level].proto.source_name;
        if (source_name.len > 0 and (source_name[0] == '@' or source_name[0] == '=')) return source_name[1..];
        return source_name;
    }

    fn collectArgs(self: *State, thread: *Thread, op: bytecode.Call, first: u16) ![]Value {
        if (op.arg_count <= first) return self.allocator.alloc(Value, 0);
        const args = try self.allocator.alloc(Value, op.arg_count - first);
        for (args, 0..) |*arg, index| arg.* = argValue(self, thread, op, first + @as(u16, @intCast(index)));
        return args;
    }

    fn returnProtectedResult(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, result: ProtectedCallResult) !void {
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

    fn rawSet(self: *State, table_value: Value, key_value: Value, value: Value) !void {
        const table = try self.expectTable(table_value);
        const key = try self.writableTableKey(key_value);
        try self.setTableRaw(table, key, value);
        self.writeTableBarrier(table, key, value);
    }

    fn nextValues(self: *State, table_value: Value, key_value: Value) ![2]Value {
        const table = try self.expectTable(table_value);
        const key = try self.readableTableKey(key_value) orelse Value.nil;
        return table.next(key) catch return self.fail("invalid key to 'next'");
    }

    fn ipairsIterValues(self: *State, thread: *Thread, table_value: Value, key_value: Value) ![2]Value {
        const table = try self.expectTable(table_value);
        _ = table;
        const current = toInteger(key_value) orelse return self.fail("invalid index to 'ipairs'");
        const next_index = current +% 1;
        const value = try self.getTableFromThread(thread, table_value, .{ .integer = next_index });
        if (value == .nil) return .{ .nil, .nil };
        return .{ .{ .integer = next_index }, value };
    }

    fn advanceGenericFor(self: *State, thread: *Thread, op: bytecode.GenericFor, jump_on_nil: bool) !bool {
        const iterator = self.get(thread, op.base);
        const state = self.get(thread, op.base + 1);
        const control = self.get(thread, op.base + 2);
        var fixed: [2]Value = undefined;
        var owned_values: ?[]Value = null;
        defer if (owned_values) |values| self.allocator.free(values);
        const values: []const Value = switch (iterator) {
            .native_next => blk: {
                fixed = try self.nextValues(state, control);
                break :blk fixed[0..2];
            },
            .native_ipairs_iter => blk: {
                fixed = try self.ipairsIterValues(thread, state, control);
                break :blk fixed[0..2];
            },
            .native => |native| switch (native) {
                .string_gmatch_iter => blk: {
                    fixed = try stdlib.string.gmatchNext(self, state);
                    break :blk fixed[0..2];
                },
                .utf8_codes_iter => blk: {
                    fixed = try stdlib.utf8.codesNext(self, state, control);
                    break :blk fixed[0..2];
                },
                else => blk: {
                    const args = [_]Value{ state, control };
                    const frame_count = thread.frames.items.len;
                    const previous_name = thread.next_call_name;
                    thread.next_call_name = "for iterator";
                    defer thread.next_call_name = previous_name;
                    owned_values = self.callCollect(thread, iterator, &args) catch |err| switch (err) {
                        error.CoroutineYield => {
                            try self.pushGenericForContinuation(thread, frame_count, op, jump_on_nil);
                            return err;
                        },
                        else => return err,
                    };
                    break :blk owned_values.?;
                },
            },
            else => blk: {
                const args = [_]Value{ state, control };
                const frame_count = thread.frames.items.len;
                const previous_name = thread.next_call_name;
                thread.next_call_name = "for iterator";
                defer thread.next_call_name = previous_name;
                owned_values = self.callCollect(thread, iterator, &args) catch |err| switch (err) {
                    error.CoroutineYield => {
                        try self.pushGenericForContinuation(thread, frame_count, op, jump_on_nil);
                        return err;
                    },
                    else => return err,
                };
                break :blk owned_values.?;
            },
        };
        return self.applyGenericForValues(thread, op, values);
    }

    fn applyGenericForValues(self: *State, thread: *Thread, op: bytecode.GenericFor, values: []const Value) !bool {
        const first_value = if (values.len > 0) values[0] else Value.nil;
        self.set(thread, op.base + 2, first_value);
        for (0..op.variable_count) |index| {
            const value = if (index < values.len) values[index] else Value.nil;
            self.set(thread, op.base + 4 + @as(bytecode.Register, @intCast(index)), value);
        }
        return first_value != .nil;
    }

    fn pushGenericForContinuation(self: *State, thread: *Thread, frame_count: usize, op: bytecode.GenericFor, jump_on_nil: bool) !void {
        try thread.generic_for_continuations.append(self.allocator, .{
            .frame_count = frame_count,
            .op = op,
            .jump_on_nil = jump_on_nil,
        });
    }

    fn readyGenericForContinuationIndex(thread: *Thread) ?usize {
        for (thread.generic_for_continuations.items, 0..) |continuation, index| {
            if (continuation.frame_count == thread.frames.items.len) return index;
        }
        return null;
    }

    fn completeReadyGenericForContinuation(self: *State, thread: *Thread) !bool {
        const index = readyGenericForContinuationIndex(thread) orelse return false;
        const continuation = thread.generic_for_continuations.orderedRemove(index);
        const values = try self.copyStackSlice(thread, thread.last_result_base, thread.last_result_count);
        defer self.allocator.free(values);
        if (!(try self.applyGenericForValues(thread, continuation.op, values)) and continuation.jump_on_nil) {
            try self.jumpThread(thread, continuation.op.offset, false);
        }
        return true;
    }

    fn pushTailCallContinuation(self: *State, thread: *Thread, frame_count: usize, base: bytecode.Register, return_count: u16) !void {
        try thread.tail_call_continuations.append(self.allocator, .{
            .frame_count = frame_count,
            .base = base,
            .return_count = return_count,
        });
    }

    fn readyTailCallContinuationIndex(thread: *Thread) ?usize {
        var index = thread.tail_call_continuations.items.len;
        while (index > 0) {
            index -= 1;
            if (thread.tail_call_continuations.items[index].frame_count == thread.frames.items.len) return index;
        }
        return null;
    }

    fn completeReadyTailCallContinuation(self: *State, thread: *Thread) !bool {
        const index = readyTailCallContinuationIndex(thread) orelse return false;
        const continuation = thread.tail_call_continuations.orderedRemove(index);
        try self.returnFromFrame(thread, continuation.base, continuation.return_count);
        return true;
    }

    pub fn expectTable(self: *State, value: Value) !*Table {
        return switch (value) {
            .table => |table| table,
            else => self.fail("table expected"),
        };
    }

    pub fn expectString(self: *State, value: Value) ![]const u8 {
        return switch (value) {
            .string => |string| string,
            else => self.fail("string expected"),
        };
    }

    fn expectThread(self: *State, value: Value) !*Thread {
        return switch (value) {
            .thread => |thread| thread,
            else => self.fail("thread expected"),
        };
    }

    fn tableCreateHint(self: *State, value: Value, arg_index: u8) !u32 {
        const integer = toInteger(value) orelse return self.fail("number expected");
        if (integer < 0 or integer > std.math.maxInt(i32)) {
            return self.fail(if (arg_index == 1) "bad argument #1 to 'table.create' (out of range)" else "bad argument #2 to 'table.create' (out of range)");
        }
        return @intCast(integer);
    }

    fn callNative(self: *State, native: NativeFn, thread: *Thread, op: bytecode.Call) !void {
        try stdlib.callNative(self, native, thread, op);
    }

    fn collectGarbageValue(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const option = argValue(self, thread, op, 0);
        if (option == .nil or (option == .string and std.mem.eql(u8, option.string, "collect"))) {
            if (self.is_collecting) {
                try self.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = false }});
                return;
            }
            if (self.conservative_gc_depth != 0) {
                try self.collectGarbageConservatively(thread);
            } else {
                try self.collectGarbageWithFinalizers(thread);
            }
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .integer = 0 }});
            return;
        }
        if (option == .string and std.mem.eql(u8, option.string, "step")) {
            const budget = if (op.arg_count >= 2) toInteger(argValue(self, thread, op, 1)) orelse return self.fail("number expected") else 0;
            const complete = try self.collectGarbageStep(thread, budget);
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = complete }});
            return;
        }
        if (option == .string and std.mem.eql(u8, option.string, "count")) {
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .number = @as(f64, @floatFromInt(self.refreshAllocationTotal())) / 1024.0 }});
            return;
        }
        if (option == .string and std.mem.eql(u8, option.string, "isrunning")) {
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = self.gc_running }});
            return;
        }
        if (option == .string and std.mem.eql(u8, option.string, "stop")) {
            self.gc_running = false;
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .integer = 0 }});
            return;
        }
        if (option == .string and std.mem.eql(u8, option.string, "restart")) {
            self.gc_running = true;
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .integer = 0 }});
            return;
        }
        if (option == .string and std.mem.eql(u8, option.string, "incremental")) {
            const old = self.gc_mode;
            self.gc_mode = .incremental;
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .string = try self.intern(old.name()) }});
            return;
        }
        if (option == .string and std.mem.eql(u8, option.string, "generational")) {
            const old = self.gc_mode;
            self.gc_mode = .generational;
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .string = try self.intern(old.name()) }});
            return;
        }
        if (option == .string and std.mem.eql(u8, option.string, "param")) {
            const param_value = argValue(self, thread, op, 1);
            const param = try self.collectGarbageParam(param_value);
            const old = self.gc_params.get(param);
            if (op.arg_count >= 3) {
                const new_value = toInteger(argValue(self, thread, op, 2)) orelse return self.fail("number expected");
                self.gc_params.set(param, new_value);
            }
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .integer = old }});
            return;
        }
        return self.failArgumentMessage("collectgarbage", 1, "invalid option");
    }

    fn collectGarbageParam(self: *State, value: Value) !GcParam {
        if (value != .string) return self.fail("bad argument #2 to 'collectgarbage'");
        if (std.mem.eql(u8, value.string, "minormul")) return .minormul;
        if (std.mem.eql(u8, value.string, "majorminor")) return .majorminor;
        if (std.mem.eql(u8, value.string, "minormajor")) return .minormajor;
        if (std.mem.eql(u8, value.string, "pause")) return .pause;
        if (std.mem.eql(u8, value.string, "stepmul")) return .stepmul;
        if (std.mem.eql(u8, value.string, "stepsize")) return .stepsize;
        return self.fail("bad argument #2 to 'collectgarbage'");
    }

    fn collectGarbageStep(self: *State, thread: ?*Thread, budget: i64) !bool {
        _ = budget;
        if (self.conservative_gc_depth != 0) {
            try self.collectGarbageConservatively(thread);
        } else {
            try self.collectGarbageWithFinalizers(thread);
        }
        return false;
    }

    pub fn collectGarbage(self: *State) !void {
        try self.collectGarbageWithFinalizers(self.current_thread);
    }

    pub fn collectGarbageStepPublic(self: *State, budget: i64) !bool {
        return self.collectGarbageStep(self.current_thread, budget);
    }

    pub fn allocationByteCount(self: State) usize {
        return self.allocationStats().total();
    }

    pub fn gcIsRunning(self: State) bool {
        return self.gc_running;
    }

    pub fn stopGc(self: *State) void {
        self.gc_running = false;
    }

    pub fn restartGc(self: *State) void {
        self.gc_running = true;
    }

    pub fn switchGcMode(self: *State, mode: GcMode) GcMode {
        const old = self.gc_mode;
        self.gc_mode = mode;
        return old;
    }

    pub fn gcParam(self: State, param: GcParam) i64 {
        return self.gc_params.get(param);
    }

    pub fn setGcParam(self: *State, param: GcParam, value: i64) void {
        self.gc_params.set(param, value);
    }

    fn collectGarbageConservatively(self: *State, thread: ?*Thread) !void {
        try self.collectGarbageWithFinalizersMode(thread, true);
    }

    fn collectGarbageWithFinalizers(self: *State, thread: ?*Thread) !void {
        try self.collectGarbageWithFinalizersMode(thread, false);
    }

    fn collectGarbageWithFinalizersMode(self: *State, thread: ?*Thread, mark_all_stack_registers: bool) !void {
        if (self.is_collecting) return;
        self.is_collecting = true;
        const previous_mark_all = self.mark_all_stack_registers;
        self.mark_all_stack_registers = mark_all_stack_registers;
        defer {
            self.mark_all_stack_registers = previous_mark_all;
            self.is_collecting = false;
        }

        self.resetMarks();
        self.markRoots();
        if (self.hasWeakTables()) {
            self.convergeEphemerons();
            self.clearWeakValues();
        }
        if (self.table_metatable_count != 0) {
            try self.runPendingFinalizers(thread);
        }
        self.runPendingUserdataFinalizers();
        if (self.hasWeakTables()) self.clearWeakTables();
        self.clearDeadHashKeys();
        self.sweepThreads();
        self.sweepClosures();
        self.sweepUpvalues();
        self.sweepStrings();
        self.sweepUserdata();
        self.sweepTables();
        self.resetAutoGcThreshold();
    }

    fn shouldRunAutoGc(self: *State) bool {
        return !self.is_collecting and self.currentAllocationTotal() >= self.gc_next_total;
    }

    fn resetAutoGcThreshold(self: *State) void {
        const total = self.refreshAllocationTotal();
        self.gc_next_total = total + @max(total / 2, 256);
    }

    fn resetMarks(self: *State) void {
        for (self.string_allocations.items) |*allocation| allocation.marked = false;
        for (self.table_allocations.items) |table| table.marked = false;
        for (self.userdata_allocations.items) |userdata| userdata.marked = false;
        for (self.closure_allocations.items) |closure| closure.marked = false;
        for (self.c_closure_allocations.items) |closure| closure.marked = false;
        for (self.upvalue_allocations.items) |upvalue| upvalue.marked = false;
        for (self.c_upvalue_allocations.items) |upvalue| upvalue.marked = false;
        for (self.thread_allocations.items) |thread| thread.marked = false;
        if (self.current_thread) |thread| {
            var active: ?*Thread = thread;
            while (active) |active_thread| : (active = active_thread.resume_parent) {
                if (!self.isTrackedThread(active_thread)) active_thread.marked = false;
            }
        }
    }

    fn markRoots(self: *State) void {
        var globals = self.globals.iterator();
        while (globals.next()) |entry| {
            self.markString(entry.key_ptr.*);
            self.markValue(entry.value_ptr.*);
        }
        for (self.api_roots.items) |root| self.markValue(root);
        self.markRuntimeErrorPayload(self.last_error);
        if (self.current_thread) |thread| self.markThread(thread);
        if (self.string_metatable) |metatable| if (self.isTrackedTable(metatable)) self.markTable(metatable);
        if (self.number_metatable) |metatable| if (self.isTrackedTable(metatable)) self.markTable(metatable);
        if (self.boolean_metatable) |metatable| if (self.isTrackedTable(metatable)) self.markTable(metatable);
        if (self.nil_metatable) |metatable| if (self.isTrackedTable(metatable)) self.markTable(metatable);
    }

    fn markValue(self: *State, value: Value) void {
        switch (value) {
            .string => |string| self.markString(string),
            .table => |table| if (self.isTrackedTable(table)) self.markTable(table),
            .userdata => |userdata| if (self.isTrackedUserdata(userdata)) self.markUserdata(userdata),
            .closure => |closure| if (self.isTrackedClosure(closure)) self.markClosure(closure),
            .c_closure => |closure| if (self.isTrackedCClosure(closure)) self.markCClosure(closure),
            .thread, .coroutine_wrapper => |thread| if (self.isTrackedThread(thread) or thread == self.current_thread) self.markThread(thread),
            .gmatch_iterator => |table| if (self.isTrackedTable(table)) self.markTable(table),
            else => {},
        }
    }

    fn markRuntimeErrorPayload(self: *State, payload: ?RuntimeErrorPayload) void {
        const active = payload orelse return;
        switch (active) {
            .diagnostic => |message| self.markString(message),
            .argument => |argument| {
                self.markString(argument.function_name);
                switch (argument.detail) {
                    .message => |message| self.markString(message),
                    .expected => |expected| {
                        self.markString(expected.expected);
                        self.markString(expected.actual);
                    },
                }
            },
            .lua_value => |value| self.markValue(value),
        }
    }

    fn markString(self: *State, bytes: []const u8) void {
        if (self.findStringAllocation(bytes)) |index| self.string_allocations.items[index].marked = true;
    }

    fn markTable(self: *State, table: *Table) void {
        if (table.marked) return;
        table.marked = true;
        if (table.metatable) |metatable| self.markTable(metatable);
        const weak = self.weakMode(table);
        if (weak.keys and weak.values) {
            self.markWeakTableStrings(table, true, true);
            return;
        }
        if (weak.values) {
            for (table.entries.items) |entry| if (entry.value != .nil) self.markValue(entry.key);
            self.markWeakTableStrings(table, false, true);
            return;
        }
        if (weak.keys) {
            for (table.array.items) |value| self.markValue(value);
            _ = self.markEphemeronValues(table);
            return;
        }
        for (table.array.items) |value| self.markValue(value);
        for (table.entries.items) |entry| {
            if (entry.value == .nil) continue;
            self.markValue(entry.key);
            self.markValue(entry.value);
        }
    }

    fn markUserdata(self: *State, userdata: *Userdata) void {
        if (userdata.marked) return;
        userdata.marked = true;
        if (userdata.metatable) |metatable| self.markTable(metatable);
    }

    fn markWeakTableStrings(self: *State, table: *Table, keys: bool, values: bool) void {
        if (values) {
            for (table.array.items) |value| self.markWeakString(value);
        }
        for (table.entries.items) |entry| {
            if (entry.value == .nil) continue;
            if (keys) self.markWeakString(entry.key);
            if (values) self.markWeakString(entry.value);
        }
    }

    fn markWeakString(self: *State, value: Value) void {
        if (value == .string) self.markString(value.string);
    }

    fn markClosure(self: *State, closure: *Closure) void {
        if (closure.marked) return;
        closure.marked = true;
        if (closure.constants) |constants| for (constants) |constant| {
            if (constant) |value| self.markValue(value);
        };
        for (closure.upvalues) |upvalue| self.markUpvalue(upvalue);
    }

    fn markCClosure(self: *State, closure: *CClosure) void {
        if (closure.marked) return;
        closure.marked = true;
        for (closure.upvalues) |upvalue| self.markCUpvalue(upvalue);
    }

    fn markUpvalue(self: *State, upvalue: *Upvalue) void {
        if (!self.isTrackedUpvalue(upvalue)) return;
        if (upvalue.marked) return;
        upvalue.marked = true;
        if (upvalue.is_open) {
            if (upvalue.stack_index < upvalue.owner.stack.items.len) self.markValue(upvalue.owner.stack.items[upvalue.stack_index]);
        } else {
            self.markValue(upvalue.closed);
        }
    }

    fn markCUpvalue(self: *State, upvalue: *CUpvalue) void {
        if (!self.isTrackedCUpvalue(upvalue)) return;
        if (upvalue.marked) return;
        upvalue.marked = true;
        self.markValue(upvalue.value);
    }

    fn markThread(self: *State, thread: *Thread) void {
        if (thread.marked) return;
        thread.marked = true;
        self.markValue(thread.entry);
        if (thread.resume_parent) |parent| self.markThread(parent);
        self.markThreadStack(thread);
        self.markValue(thread.hook);
        self.markValue(thread.hook_level2_func);
        for (thread.hook_transfer_values) |value| self.markValue(value);
        for (thread.yield_values.items) |value| self.markValue(value);
        if (thread.close_error_value) |value| self.markValue(value);
        if (thread.error_traceback) |traceback| self.markString(traceback);
        for (thread.protected_continuations.items) |continuation| {
            self.markRuntimeErrorPayload(continuation.context.last_error);
            self.markValue(continuation.handler);
        }
        for (thread.frames.items) |frame| {
            self.markClosure(frame.closure);
            self.markValue(frame.vararg_table_local);
            for (frame.varargs) |value| self.markValue(value);
            if (frame.pending_returns) |returns| for (returns) |value| self.markValue(value);
        }
        var current = thread.open_upvalues;
        while (current) |upvalue| : (current = upvalue.next) self.markUpvalue(upvalue);
    }

    fn markThreadStack(self: *State, thread: *Thread) void {
        if (self.mark_all_stack_registers) {
            self.markStackRange(thread, 0, thread.stack.items.len);
            return;
        }
        for (thread.frames.items) |frame| {
            for (frame.proto.locals.items) |local| {
                if (!localActiveAt(local, frame.pc)) continue;
                self.markStackRange(thread, frame.base + local.register, 1);
            }
        }
        self.markStackRange(thread, thread.last_result_base, thread.last_result_count);
        self.markStackRange(thread, thread.last_transfer_base, thread.last_transfer_count);
        self.markStackRange(thread, thread.yield_result_base, thread.yield_result_count);
    }

    fn markStackRange(self: *State, thread: *Thread, base: usize, count: usize) void {
        if (base >= thread.stack.items.len) return;
        const end = @min(thread.stack.items.len, base + count);
        for (thread.stack.items[base..end]) |value| self.markValue(value);
    }

    fn weakMode(self: *State, table: *Table) WeakMode {
        _ = self;
        const metatable = table.metatable orelse return .{};
        const mode = metatable.get(.{ .string = "__mode" });
        if (mode != .string) return .{};
        return .{
            .keys = std.mem.indexOfScalar(u8, mode.string, 'k') != null,
            .values = std.mem.indexOfScalar(u8, mode.string, 'v') != null,
        };
    }

    fn hasWeakTables(self: *State) bool {
        var current = self.table_metatable_head;
        while (current) |table| : (current = table.metatable_next) {
            const weak = self.weakMode(table);
            if (weak.keys or weak.values) return true;
        }
        return false;
    }

    fn markEphemeronValues(self: *State, table: *Table) bool {
        var changed = false;
        for (table.entries.items) |entry| {
            if (entry.value == .nil) continue;
            if (self.valueIsWeaklyCleared(entry.key)) continue;
            self.markValue(entry.key);
            if (self.markValueChanged(entry.value)) changed = true;
        }
        return changed;
    }

    fn convergeEphemerons(self: *State) void {
        var changed = true;
        while (changed) {
            changed = false;
            var current = self.table_metatable_head;
            while (current) |table| : (current = table.metatable_next) {
                if (!table.marked) continue;
                const weak = self.weakMode(table);
                if (!weak.keys or weak.values) continue;
                if (self.markEphemeronValues(table)) changed = true;
            }
        }
    }

    fn markValueChanged(self: *State, value: Value) bool {
        const was_marked = self.valueIsMarked(value);
        self.markValue(value);
        return !was_marked and self.valueIsMarked(value);
    }

    fn valueIsMarked(self: *State, value: Value) bool {
        return switch (value) {
            .string => |string| if (self.findStringAllocation(string)) |index| self.string_allocations.items[index].marked else true,
            .table => |table| !self.isTrackedTable(table) or table.marked,
            .userdata => |userdata| !self.isTrackedUserdata(userdata) or userdata.marked,
            .closure => |closure| !self.isTrackedClosure(closure) or closure.marked,
            .thread, .coroutine_wrapper => |thread| !self.isTrackedThread(thread) or thread.marked,
            else => true,
        };
    }

    fn valueIsWeaklyCleared(self: *State, value: Value) bool {
        return switch (value) {
            .table => |table| self.isTrackedTable(table) and !table.marked,
            .userdata => |userdata| self.isTrackedUserdata(userdata) and !userdata.marked,
            .closure => |closure| self.isTrackedClosure(closure) and !closure.marked,
            .thread, .coroutine_wrapper => |thread| self.isTrackedThread(thread) and !thread.marked,
            else => false,
        };
    }

    fn valueIsCollectableUnmarked(self: *State, value: Value) bool {
        return switch (value) {
            .string => |string| if (self.findStringAllocation(string)) |index| !self.string_allocations.items[index].marked else false,
            .table => |table| self.isTrackedTable(table) and !table.marked,
            .userdata => |userdata| self.isTrackedUserdata(userdata) and !userdata.marked,
            .closure => |closure| self.isTrackedClosure(closure) and !closure.marked,
            .thread, .coroutine_wrapper => |thread| self.isTrackedThread(thread) and !thread.marked,
            else => false,
        };
    }

    fn clearWeakValues(self: *State) void {
        var current = self.table_metatable_head;
        while (current) |table| : (current = table.metatable_next) {
            if (!table.marked) continue;
            if (!self.weakMode(table).values) continue;
            self.clearWeakTableValues(table);
        }
    }

    fn clearWeakTables(self: *State) void {
        var current = self.table_metatable_head;
        while (current) |table| : (current = table.metatable_next) {
            if (!table.marked) continue;
            const weak = self.weakMode(table);
            if (weak.values) self.clearWeakTableValues(table);
            if (weak.keys) self.clearWeakTableKeys(table);
        }
    }

    fn clearDeadHashKeys(self: *State) void {
        for (self.table_allocations.items) |table| {
            if (!table.marked) continue;
            var read_index: usize = 0;
            var write_index: usize = 0;
            while (read_index < table.entries.items.len) : (read_index += 1) {
                const entry = table.entries.items[read_index];
                if (entry.value == .nil and self.valueIsCollectableUnmarked(entry.key)) {
                    _ = table.entry_index.remove(entry.key);
                } else {
                    if (write_index != read_index) table.entries.items[write_index] = entry;
                    table.entry_index.getPtr(entry.key).?.* = write_index;
                    write_index += 1;
                }
            }
            table.entries.items.len = write_index;
        }
    }

    fn clearWeakTableValues(self: *State, table: *Table) void {
        for (table.array.items) |*value| {
            if (self.valueIsWeaklyCleared(value.*)) value.* = .nil;
        }
        var index: usize = 0;
        while (index < table.entries.items.len) {
            if (self.valueIsWeaklyCleared(table.entries.items[index].value)) {
                table.removeEntryAt(index);
            } else {
                index += 1;
            }
        }
    }

    fn clearWeakTableKeys(self: *State, table: *Table) void {
        var index: usize = 0;
        while (index < table.entries.items.len) {
            if (self.valueIsWeaklyCleared(table.entries.items[index].key)) {
                table.removeEntryAt(index);
            } else {
                index += 1;
            }
        }
    }

    fn writeTableBarrier(self: *State, table: *Table, key: Value, value: Value) void {
        if (!self.is_collecting or !table.marked) return;
        const weak = self.weakMode(table);
        if (!weak.keys) self.markValue(key);
        if (!weak.values and (!weak.keys or !self.valueIsWeaklyCleared(key))) self.markValue(value);
    }

    fn writeBarrier(self: *State, parent_marked: bool, child: Value) void {
        if (!self.is_collecting or !parent_marked) return;
        self.markValue(child);
    }

    fn runPendingFinalizers(self: *State, thread: ?*Thread) !void {
        const active_thread = thread orelse return;
        var ran_finalizer = false;
        var current = self.table_metatable_head;
        while (current) |table| {
            current = table.metatable_next;
            if (table.marked or table.finalized) continue;
            const metatable = table.metatable orelse continue;
            const finalizer = metatable.get(.{ .string = "__gc" });
            if (finalizer == .nil) continue;
            if (self.weakMode(metatable).values and self.valueIsWeaklyCleared(finalizer)) continue;
            if (!self.callableValue(finalizer)) continue;
            self.markTable(table);
            table.finalized = true;
            self.convergeEphemerons();
            self.clearWeakValues();
            self.clearWeakTables();
            {
                const saved_stack_len = active_thread.stack.items.len;
                const saved_last_result_base = active_thread.last_result_base;
                const saved_last_result_count = active_thread.last_result_count;
                defer {
                    active_thread.stack.items.len = saved_stack_len;
                    active_thread.last_result_base = saved_last_result_base;
                    active_thread.last_result_count = saved_last_result_count;
                }
                const previous_name = active_thread.next_call_name;
                const previous_namewhat = active_thread.next_call_namewhat;
                active_thread.next_call_name = "__gc";
                active_thread.next_call_namewhat = "metamethod";
                defer {
                    active_thread.next_call_name = previous_name;
                    active_thread.next_call_namewhat = previous_namewhat;
                }
                _ = try self.callOneResult(active_thread, finalizer, &.{.{ .table = table }});
                try self.runThreadUntil(active_thread, active_thread.frames.items.len);
            }
            ran_finalizer = true;
        }
        if (!ran_finalizer) return;
        self.resetMarks();
        self.markRoots();
        self.convergeEphemerons();
        self.clearWeakValues();
    }

    fn runPendingUserdataFinalizers(self: *State) void {
        var ran_finalizer = false;
        for (self.userdata_allocations.items) |userdata| {
            if (userdata.marked or userdata.finalized) continue;
            const finalizer = userdata.finalizer orelse continue;
            userdata.marked = true;
            userdata.finalized = true;
            finalizer(userdata.ptr, userdata.finalizer_data);
            ran_finalizer = true;
        }
        if (!ran_finalizer) return;
        self.resetMarks();
        self.markRoots();
        self.convergeEphemerons();
        self.clearWeakValues();
    }

    fn callableValue(self: *State, value: Value) bool {
        if (functionLike(value)) return true;
        return (self.getMetamethod(value, "__call") catch null) != null;
    }

    fn sweepStrings(self: *State) void {
        var index: usize = 0;
        while (index < self.string_allocations.items.len) {
            const allocation = self.string_allocations.items[index];
            if (allocation.marked) {
                index += 1;
                continue;
            }
            if (self.strings.get(allocation.bytes)) |interned| {
                if (interned.ptr == allocation.bytes.ptr and interned.len == allocation.bytes.len) _ = self.strings.remove(allocation.bytes);
            }
            if (allocation.bytes.len != 0) _ = self.string_allocation_index.remove(@intFromPtr(allocation.bytes.ptr));
            self.allocator.free(allocation.bytes);
            const moved_index = self.string_allocations.items.len - 1;
            _ = self.string_allocations.swapRemove(index);
            if (index < moved_index) {
                const moved = self.string_allocations.items[index];
                if (moved.bytes.len != 0) self.string_allocation_index.getPtr(@intFromPtr(moved.bytes.ptr)).?.* = index;
            }
        }
    }

    fn sweepUserdata(self: *State) void {
        var index: usize = 0;
        while (index < self.userdata_allocations.items.len) {
            const userdata = self.userdata_allocations.items[index];
            if (userdata.marked) {
                index += 1;
                continue;
            }
            self.destroyUserdata(userdata);
            _ = self.userdata_allocations.swapRemove(index);
        }
    }

    fn sweepTables(self: *State) void {
        var index: usize = 0;
        while (index < self.table_allocations.items.len) {
            const table = self.table_allocations.items[index];
            if (table.marked) {
                index += 1;
                continue;
            }
            _ = self.table_allocation_index.remove(@intFromPtr(table));
            self.destroyTable(table);
            const moved_index = self.table_allocations.items.len - 1;
            _ = self.table_allocations.swapRemove(index);
            if (index < moved_index) {
                const moved = self.table_allocations.items[index];
                self.table_allocation_index.getPtr(@intFromPtr(moved)).?.* = index;
            }
        }
    }

    fn sweepClosures(self: *State) void {
        var index: usize = 0;
        while (index < self.closure_allocations.items.len) {
            const closure = self.closure_allocations.items[index];
            if (closure.marked) {
                index += 1;
                continue;
            }
            self.destroyClosure(closure);
            _ = self.closure_allocations.swapRemove(index);
        }
    }

    fn sweepCClosures(self: *State) void {
        var index: usize = 0;
        while (index < self.c_closure_allocations.items.len) {
            const closure = self.c_closure_allocations.items[index];
            if (closure.marked) {
                index += 1;
                continue;
            }
            self.destroyCClosure(closure);
            _ = self.c_closure_allocations.swapRemove(index);
        }
    }

    fn sweepUpvalues(self: *State) void {
        var index: usize = 0;
        while (index < self.upvalue_allocations.items.len) {
            const upvalue = self.upvalue_allocations.items[index];
            if (upvalue.marked) {
                index += 1;
                continue;
            }
            self.allocator.destroy(upvalue);
            _ = self.upvalue_allocations.swapRemove(index);
        }
    }

    fn sweepCUpvalues(self: *State) void {
        var index: usize = 0;
        while (index < self.c_upvalue_allocations.items.len) {
            const upvalue = self.c_upvalue_allocations.items[index];
            if (upvalue.marked) {
                index += 1;
                continue;
            }
            self.allocator.destroy(upvalue);
            _ = self.c_upvalue_allocations.swapRemove(index);
        }
    }

    fn sweepThreads(self: *State) void {
        var index: usize = 0;
        while (index < self.thread_allocations.items.len) {
            const thread = self.thread_allocations.items[index];
            if (thread.marked) {
                index += 1;
                continue;
            }
            self.closeUpvalues(thread, 0);
            self.destroyThread(thread);
            _ = self.thread_allocations.swapRemove(index);
        }
    }

    fn findStringAllocation(self: *State, bytes: []const u8) ?usize {
        if (bytes.len == 0) {
            for (self.string_allocations.items, 0..) |allocation, index| {
                if (allocation.bytes.ptr == bytes.ptr and allocation.bytes.len == bytes.len) return index;
            }
            return null;
        }
        return self.string_allocation_index.get(@intFromPtr(bytes.ptr));
    }

    fn isTrackedThread(self: *State, thread: *Thread) bool {
        for (self.thread_allocations.items) |allocation| {
            if (allocation == thread) return true;
        }
        return false;
    }

    fn isTrackedTable(self: *State, table: *Table) bool {
        return self.table_allocation_index.contains(@intFromPtr(table));
    }

    fn isTrackedUserdata(self: *State, userdata: *Userdata) bool {
        for (self.userdata_allocations.items) |allocation| {
            if (allocation == userdata) return true;
        }
        return false;
    }

    fn isTrackedClosure(self: *State, closure: *Closure) bool {
        for (self.closure_allocations.items) |allocation| {
            if (allocation == closure) return true;
        }
        return false;
    }

    fn isTrackedCClosure(self: *State, closure: *CClosure) bool {
        for (self.c_closure_allocations.items) |allocation| {
            if (allocation == closure) return true;
        }
        return false;
    }

    fn isTrackedUpvalue(self: *State, upvalue: *Upvalue) bool {
        for (self.upvalue_allocations.items) |allocation| {
            if (allocation == upvalue) return true;
        }
        return false;
    }

    fn isTrackedCUpvalue(self: *State, upvalue: *CUpvalue) bool {
        for (self.c_upvalue_allocations.items) |allocation| {
            if (allocation == upvalue) return true;
        }
        return false;
    }

    fn destroyTable(self: *State, table: *Table) void {
        if (table.metatable != null) {
            self.unlinkTableMetatable(table);
            self.table_metatable_count -= 1;
        }
        table.deinit(self.allocator);
        self.allocator.destroy(table);
    }

    fn destroyUserdata(self: *State, userdata: *Userdata) void {
        if (!userdata.finalized) {
            if (userdata.finalizer) |finalizer| finalizer(userdata.ptr, userdata.finalizer_data);
            userdata.finalized = true;
        }
        if (userdata.deinit_fn) |deinit_fn| deinit_fn(self.allocator, userdata.ptr);
        self.allocator.destroy(userdata);
    }

    fn destroyClosure(self: *State, closure: *Closure) void {
        if (closure.constants) |constants| self.allocator.free(constants);
        if (closure.upvalues.len != 0) self.allocator.free(closure.upvalues);
        self.allocator.destroy(closure);
    }

    fn destroyCClosure(self: *State, closure: *CClosure) void {
        if (closure.upvalues.len != 0) self.allocator.free(closure.upvalues);
        self.allocator.destroy(closure);
    }

    fn destroyThread(self: *State, thread: *Thread) void {
        thread.deinit(self.allocator);
        self.allocator.destroy(thread);
    }

    fn allocationStats(self: State) RuntimeAllocationStats {
        var bytes: usize = 0;
        for (self.string_allocations.items) |allocation| bytes += @sizeOf(StringAllocation) + allocation.bytes.len;
        for (self.table_allocations.items) |table| {
            if (table.counts_for_gc_count) bytes += @sizeOf(Table) + table.array.capacity * @sizeOf(Value) + table.entries.capacity * @sizeOf(TableEntry);
        }
        bytes += self.userdata_allocations.items.len * @sizeOf(Userdata);
        bytes += self.closure_allocations.items.len * @sizeOf(Closure);
        for (self.closure_allocations.items) |closure| {
            if (closure.constants) |constants| bytes += constants.len * @sizeOf(?Value);
        }
        bytes += self.c_closure_allocations.items.len * @sizeOf(CClosure);
        bytes += self.upvalue_allocations.items.len * @sizeOf(Upvalue);
        bytes += self.c_upvalue_allocations.items.len * @sizeOf(CUpvalue);
        bytes += self.thread_allocations.items.len * @sizeOf(Thread);

        return .{
            .strings = self.string_allocations.items.len,
            .tables = self.table_allocations.items.len,
            .closures = self.closure_allocations.items.len,
            .upvalues = self.upvalue_allocations.items.len,
            .threads = self.thread_allocations.items.len,
            .bytes = bytes,
        };
    }

    fn appendUnhandledErrorDebugDump(self: *State, thread: *Thread, err: anyerror) !void {
        const out = &self.stderr;
        const stats = self.allocationStats();
        try out.appendSlice(self.allocator, "\n[zlua debug] unhandled runtime exception\n");
        try appendFmt(self.allocator, out, "error={s}\n", .{@errorName(err)});
        try out.appendSlice(self.allocator, "error_value=");
        try self.appendDebugValue(out, self.currentErrorValue());
        try out.append(self.allocator, '\n');
        if (self.last_error) |payload| switch (payload) {
            .diagnostic => |message| try appendFmt(self.allocator, out, "last_error={s}\n", .{message}),
            .argument => |argument| {
                const rendered = try errors.renderArgumentError(self.allocator, argument);
                defer self.allocator.free(rendered);
                try appendFmt(self.allocator, out, "last_error={s}\n", .{rendered});
            },
            .lua_value => {},
        };
        try appendFmt(self.allocator, out, "allocations strings={d} tables={d} closures={d} upvalues={d} threads={d} bytes={d}\n", .{ stats.strings, stats.tables, stats.closures, stats.upvalues, stats.threads, stats.bytes });
        try appendFmt(self.allocator, out, "thread status={s} frames={d} stack={d} results={d}@{d} native_depth={d} protected_close_depth={d}\n", .{ @tagName(thread.status), thread.frames.items.len, thread.stack.items.len, thread.last_result_count, thread.last_result_base, thread.native_call_depth, thread.protected_close_depth });
        try appendFmt(self.allocator, out, "continuations protected={d} call_one={d} tail={d} generic_for={d}\n", .{ thread.protected_continuations.items.len, thread.call_one_continuations.items.len, thread.tail_call_continuations.items.len, thread.generic_for_continuations.items.len });
        try self.appendDebugFrames(out, thread);
        try self.appendDebugStack(out, thread);
        try out.appendSlice(self.allocator, "[/zlua debug]\n");
    }

    fn appendDebugFrames(self: *State, out: *std.ArrayList(u8), thread: *Thread) !void {
        try appendFmt(self.allocator, out, "frames newest-first ({d}):\n", .{thread.frames.items.len});
        var index = thread.frames.items.len;
        while (index > 0) {
            index -= 1;
            const frame = thread.frames.items[index];
            const pc = if (frame.pc == 0) @as(usize, 0) else frame.pc - 1;
            const line = lineForFrame(frame) orelse 0;
            const name = frame.proto.debug_name orelse "(anonymous)";
            const instruction = if (pc < frame.proto.instructions.items.len)
                @tagName(std.meta.activeTag(frame.proto.instructions.items[pc]))
            else
                "<end>";
            try appendFmt(self.allocator, out, "  frame {d}: {s}:{d} pc={d} op={s} func={s} base={d} return={d}@{d} registers={d}\n", .{ index, frame.proto.source_name, line, pc, instruction, name, frame.base, frame.return_count, frame.return_start, frame.proto.max_registers });
            try self.appendDebugLocals(out, thread, frame);
            try self.appendDebugVarargs(out, frame);
            try self.appendDebugUpvalues(out, frame);
        }
    }

    fn appendDebugLocals(self: *State, out: *std.ArrayList(u8), thread: *Thread, frame: CallFrame) !void {
        const pc = if (frame.pc == 0) @as(usize, 0) else frame.pc - 1;
        var found = false;
        for (frame.proto.locals.items) |local| {
            if (!localActiveAt(local, pc)) continue;
            found = true;
            try appendFmt(self.allocator, out, "    local {s} r{d}", .{ local.name, local.register });
            if (local.to_close) try out.appendSlice(self.allocator, " <close>");
            try out.appendSlice(self.allocator, " = ");
            const absolute_register = frame.base + local.register;
            if (absolute_register < thread.stack.items.len) {
                try self.appendDebugValue(out, thread.stack.items[absolute_register]);
            } else {
                try out.appendSlice(self.allocator, "<out-of-stack>");
            }
            try out.append(self.allocator, '\n');
        }
        if (!found) try out.appendSlice(self.allocator, "    locals: <none>\n");
    }

    fn appendDebugVarargs(self: *State, out: *std.ArrayList(u8), frame: CallFrame) !void {
        if (frame.varargs.len == 0) {
            try out.appendSlice(self.allocator, "    varargs: <none>\n");
            return;
        }
        for (frame.varargs, 0..) |value, index| {
            try appendFmt(self.allocator, out, "    vararg {d} = ", .{index});
            try self.appendDebugValue(out, value);
            try out.append(self.allocator, '\n');
        }
    }

    fn appendDebugUpvalues(self: *State, out: *std.ArrayList(u8), frame: CallFrame) !void {
        if (frame.closure.upvalues.len == 0) {
            try out.appendSlice(self.allocator, "    upvalues: <none>\n");
            return;
        }
        for (frame.closure.upvalues, 0..) |upvalue, index| {
            const name = if (index < frame.proto.upvalues.items.len) frame.proto.upvalues.items[index].name else "?";
            const value = if (upvalue.is_open) upvalue.owner.stack.items[upvalue.stack_index] else upvalue.closed;
            try appendFmt(self.allocator, out, "    upvalue U{d} {s} {s}", .{ index, name, if (upvalue.is_open) "open" else "closed" });
            if (upvalue.is_open) try appendFmt(self.allocator, out, " stack={d}", .{upvalue.stack_index});
            try out.appendSlice(self.allocator, " = ");
            try self.appendDebugValue(out, value);
            try out.append(self.allocator, '\n');
        }
    }

    fn appendDebugStack(self: *State, out: *std.ArrayList(u8), thread: *Thread) !void {
        try appendFmt(self.allocator, out, "stack ({d} slots):\n", .{thread.stack.items.len});
        for (thread.stack.items, 0..) |value, stack_index| {
            try appendFmt(self.allocator, out, "  [{d}]", .{stack_index});
            if (debugStackRegister(thread, stack_index)) |slot| {
                try appendFmt(self.allocator, out, " frame={d} r{d}", .{ slot.frame_index, slot.register });
            }
            try out.appendSlice(self.allocator, " = ");
            try self.appendDebugValue(out, value);
            try out.append(self.allocator, '\n');
        }
    }

    fn appendDebugValue(self: *State, out: *std.ArrayList(u8), value: Value) !void {
        try appendFmt(self.allocator, out, "({s}) ", .{debugValueTypeName(value)});
        if (value == .table and !self.isTrackedTable(value.table)) {
            try appendFmt(self.allocator, out, "table: 0x{x}", .{@intFromPtr(value.table)});
            return;
        }
        try appendValue(self.allocator, out, value);
    }

    fn failRuntimeDetail(self: *State, thread: ?*Thread, detail: []const u8) RuntimeError {
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.allocator);
        self.appendRuntimeErrorPrefix(&out, thread) catch return self.fail(detail);
        out.appendSlice(self.allocator, detail) catch return self.fail(detail);
        return self.fail(self.intern(out.items) catch return self.fail(detail));
    }

    fn failBinaryTypeError(self: *State, thread: *Thread, lhs: Value, rhs: Value, op: BinaryOp) RuntimeError {
        var detail = std.ArrayList(u8).empty;
        defer detail.deinit(self.allocator);
        const site = self.currentErrorSite(thread);
        switch (op) {
            .add, .sub, .mul, .div, .idiv, .mod, .pow => {
                if (lhs == .string or rhs == .string) {
                    appendFmt(self.allocator, &detail, "attempt to {s} a '{s}' with a '{s}'", .{ arithmeticVerb(op), self.luaTypeNameForError(lhs), self.luaTypeNameForError(rhs) }) catch return self.fail("attempt to perform operation on unsupported values");
                    return self.failRuntimeDetail(thread, detail.items);
                }
                const operand_index: usize = if (toNumberMaybe(lhs) == null) 0 else 1;
                const bad_value = if (operand_index == 0) lhs else rhs;
                appendFmt(self.allocator, &detail, "attempt to perform arithmetic on a {s} value", .{self.luaTypeNameForError(bad_value)}) catch return self.fail("attempt to perform operation on unsupported values");
                self.appendSiteOrigin(&detail, site, operand_index, false) catch return self.fail("attempt to perform operation on unsupported values");
            },
            .band, .bor, .bxor, .shl, .shr => {
                const operand_index: usize = if (toBitwiseInteger(lhs) == null) 0 else 1;
                const bad_value = if (operand_index == 0) lhs else rhs;
                appendFmt(self.allocator, &detail, "attempt to perform bitwise operation on a {s} value", .{self.luaTypeNameForError(bad_value)}) catch return self.fail("attempt to perform operation on unsupported values");
                self.appendSiteOrigin(&detail, site, operand_index, true) catch return self.fail("attempt to perform operation on unsupported values");
            },
            .concat => {
                const operand_index: usize = if (!luaStringLike(lhs)) 0 else 1;
                const bad_value = if (operand_index == 0) lhs else rhs;
                appendFmt(self.allocator, &detail, "attempt to concatenate a {s} value", .{self.luaTypeNameForError(bad_value)}) catch return self.fail("attempt to perform operation on unsupported values");
                self.appendSiteOrigin(&detail, site, operand_index, false) catch return self.fail("attempt to perform operation on unsupported values");
            },
        }
        return self.failRuntimeDetail(thread, detail.items);
    }

    fn failUnaryTypeError(self: *State, thread: *Thread, value: Value, op: UnaryMetamethodOp) RuntimeError {
        var detail = std.ArrayList(u8).empty;
        defer detail.deinit(self.allocator);
        const operation = switch (op) {
            .unm => "arithmetic",
            .bnot => "bitwise operation",
        };
        appendFmt(self.allocator, &detail, "attempt to perform {s} on a {s} value", .{ operation, self.luaTypeNameForError(value) }) catch return self.fail("attempt to perform operation on unsupported value");
        self.appendSiteOrigin(&detail, self.currentErrorSite(thread), 0, op == .bnot) catch return self.fail("attempt to perform operation on unsupported value");
        return self.failRuntimeDetail(thread, detail.items);
    }

    fn failCompareTypeError(self: *State, thread: *Thread, lhs: Value, rhs: Value) RuntimeError {
        var detail = std.ArrayList(u8).empty;
        defer detail.deinit(self.allocator);
        const lhs_type = self.luaTypeNameForError(lhs);
        const rhs_type = self.luaTypeNameForError(rhs);
        if (std.mem.eql(u8, lhs_type, rhs_type)) {
            appendFmt(self.allocator, &detail, "attempt to compare two {s} values", .{lhs_type}) catch return self.fail("attempt to compare unsupported values");
        } else {
            appendFmt(self.allocator, &detail, "attempt to compare {s} with {s}", .{ lhs_type, rhs_type }) catch return self.fail("attempt to compare unsupported values");
        }
        return self.failRuntimeDetail(thread, detail.items);
    }

    fn failLengthTypeError(self: *State, thread: *Thread, value: Value) RuntimeError {
        var detail = std.ArrayList(u8).empty;
        defer detail.deinit(self.allocator);
        appendFmt(self.allocator, &detail, "attempt to get length of a {s} value", .{self.luaTypeNameForError(value)}) catch return self.fail("attempt to get length of a non-string value");
        self.appendSiteOrigin(&detail, self.currentErrorSite(thread), 0, false) catch return self.fail("attempt to get length of a non-string value");
        return self.failRuntimeDetail(thread, detail.items);
    }

    fn failIndexTypeError(self: *State, thread: ?*Thread, value: Value) RuntimeError {
        return self.failAccessTypeError(thread, value, indexErrorMessage(value));
    }

    fn failNewIndexTypeError(self: *State, thread: ?*Thread, value: Value) RuntimeError {
        return self.failAccessTypeError(thread, value, indexErrorMessage(value));
    }

    fn failCallTypeError(self: *State, thread: *Thread, value: Value, call_name: ?[]const u8, call_namewhat: ?[]const u8) RuntimeError {
        var detail = std.ArrayList(u8).empty;
        defer detail.deinit(self.allocator);
        appendFmt(self.allocator, &detail, "attempt to call a {s} value", .{self.luaTypeNameForError(value)}) catch return self.fail(callErrorMessage(value));
        if (call_name != null and call_namewhat != null and std.mem.eql(u8, call_namewhat.?, "metamethod")) {
            appendFmt(self.allocator, &detail, " (metamethod '{s}')", .{call_name.?}) catch return self.fail(callErrorMessage(value));
        } else {
            self.appendCallOrigin(&detail, self.currentErrorSite(thread)) catch return self.fail(callErrorMessage(value));
        }
        return self.failRuntimeDetail(thread, detail.items);
    }

    fn failAccessTypeError(self: *State, thread: ?*Thread, value: Value, fallback: []const u8) RuntimeError {
        var detail = std.ArrayList(u8).empty;
        defer detail.deinit(self.allocator);
        appendFmt(self.allocator, &detail, "attempt to index a {s} value", .{self.luaTypeNameForError(value)}) catch return self.fail(fallback);
        const site = if (thread) |active| self.currentErrorSite(active) else null;
        self.appendSiteOrigin(&detail, site, 0, false) catch return self.fail(fallback);
        return self.failRuntimeDetail(thread, detail.items);
    }

    fn failForTypeError(self: *State, thread: *Thread, which: ForValueKind, value: Value) RuntimeError {
        var detail = std.ArrayList(u8).empty;
        defer detail.deinit(self.allocator);
        appendFmt(self.allocator, &detail, "bad 'for' {s} (number expected, got {s})", .{ forValueName(which), self.luaTypeNameForError(value) }) catch return self.fail("bad 'for' value");
        return self.failRuntimeDetail(thread, detail.items);
    }

    fn appendRuntimeErrorPrefix(self: *State, out: *std.ArrayList(u8), thread: ?*Thread) !void {
        const active = thread orelse return;
        if (active.frames.items.len == 0) return;
        if (active.frames.items[active.frames.items.len - 1].closure.stripped_debug) {
            try out.appendSlice(self.allocator, "?:?: ");
            return;
        }
        const site = self.currentErrorSite(active) orelse return;
        const frame = active.frames.items[active.frames.items.len - 1];
        try appendFmt(self.allocator, out, "{s}:{d}: ", .{ runtimeSourceName(frame.proto.source_name), site.line });
    }

    fn currentErrorSite(self: *State, thread: *Thread) ?proto_mod.ErrorSite {
        _ = self;
        if (thread.frames.items.len == 0) return null;
        const frame = thread.frames.items[thread.frames.items.len - 1];
        if (frame.closure.stripped_debug) return null;
        if (frame.pc == 0) return null;
        return frame.proto.errorSiteAt(frame.pc - 1) orelse blk: {
            if (frame.proto.line_info.items.len == 0) return null;
            const pc = @min(frame.pc - 1, frame.proto.line_info.items.len - 1);
            break :blk proto_mod.ErrorSite{ .line = frame.proto.line_info.items[pc].line, .op = .call };
        };
    }

    fn appendSiteOrigin(self: *State, out: *std.ArrayList(u8), site: ?proto_mod.ErrorSite, operand_index: usize, allow_constant: bool) !void {
        const active_site = site orelse return;
        if (operand_index >= active_site.operands.len) return;
        try self.appendOrigin(out, active_site.operands[operand_index], allow_constant);
    }

    fn appendCallOrigin(self: *State, out: *std.ArrayList(u8), site: ?proto_mod.ErrorSite) !void {
        const active_site = site orelse return;
        if (active_site.call_name) |origin| return self.appendOrigin(out, origin, false);
        if (active_site.operands.len != 0) return self.appendOrigin(out, active_site.operands[0], false);
    }

    fn appendOrigin(self: *State, out: *std.ArrayList(u8), origin: proto_mod.OperandOrigin, allow_constant: bool) !void {
        switch (origin) {
            .temporary => {},
            .local => |name| try appendFmt(self.allocator, out, " (local '{s}')", .{name}),
            .upvalue => |name| try appendFmt(self.allocator, out, " (upvalue '{s}')", .{name}),
            .global => |name| try appendFmt(self.allocator, out, " (global '{s}')", .{name}),
            .field => |name| try appendFmt(self.allocator, out, " (field '{s}')", .{name}),
            .method => |name| try appendFmt(self.allocator, out, " (method '{s}')", .{name}),
            .metamethod => |name| try appendFmt(self.allocator, out, " (metamethod '{s}')", .{name}),
            .constant => |value| if (allow_constant) try appendFmt(self.allocator, out, " (constant '{s}')", .{value}),
        }
    }

    pub fn errorDetailAlloc(self: *State, allocator: std.mem.Allocator, err: anyerror) ![]const u8 {
        if (self.last_error == null) return allocator.dupe(u8, @errorName(err));
        var out = std.ArrayList(u8).empty;
        defer out.deinit(allocator);
        try appendValue(allocator, &out, self.currentErrorValue());
        return allocator.dupe(u8, out.items);
    }

    pub fn fail(self: *State, message: []const u8) RuntimeError {
        self.last_error = .{ .diagnostic = message };
        return error.RuntimeError;
    }

    pub fn failArgument(self: *State, function_name: []const u8, index: u16, detail: errors.ArgumentErrorDetail) RuntimeError {
        self.last_error = .{ .argument = .{
            .function_name = function_name,
            .index = index,
            .detail = detail,
        } };
        return error.RuntimeError;
    }

    pub fn failArgumentMessage(self: *State, function_name: []const u8, index: u16, message: []const u8) RuntimeError {
        return self.failArgument(function_name, index, .{ .message = message });
    }

    pub fn failArgumentType(self: *State, function_name: []const u8, index: u16, expected: []const u8, actual: Value) RuntimeError {
        return self.failArgument(function_name, index, .{ .expected = .{
            .expected = expected,
            .actual = self.luaTypeNameForError(actual),
        } });
    }

    pub fn expectArgumentString(self: *State, thread: *Thread, op: bytecode.Call, function_name: []const u8, index: u16) ![]const u8 {
        const value = argValue(self, thread, op, index);
        return switch (value) {
            .string => |string| string,
            else => if (index == 0 and self.isMethodSelfArgument(thread, function_name))
                self.failArgumentMessage(function_name, 1, "bad self")
            else
                self.failArgumentType(function_name, index + 1, "string", value),
        };
    }

    fn isMethodSelfArgument(self: *State, thread: *Thread, function_name: []const u8) bool {
        const site = self.currentErrorSite(thread) orelse return false;
        const origin = site.call_name orelse return false;
        const method = switch (origin) {
            .method => |name| name,
            else => return false,
        };
        const dot = std.mem.lastIndexOfScalar(u8, function_name, '.') orelse return false;
        return std.mem.eql(u8, function_name[dot + 1 ..], method);
    }

    pub fn argumentDisplayIndex(self: *State, thread: *Thread, function_name: []const u8, index: u16) u16 {
        if (index > 0 and self.isMethodSelfArgument(thread, function_name)) return index;
        return index + 1;
    }

    pub fn expectArgumentTable(self: *State, thread: *Thread, op: bytecode.Call, function_name: []const u8, index: u16) !*Table {
        const value = argValue(self, thread, op, index);
        return switch (value) {
            .table => |table| table,
            else => self.failArgumentType(function_name, index + 1, "table", value),
        };
    }

    pub fn argumentInteger(self: *State, thread: *Thread, op: bytecode.Call, function_name: []const u8, index: u16) !i64 {
        const value = argValue(self, thread, op, index);
        return toInteger(value) orelse self.failArgumentType(function_name, index + 1, "number", value);
    }

    fn failLoadDiagnostic(self: *State, source_name: ?[]const u8, source_text: []const u8, diagnostic: ?errors.Diagnostic, fallback: []const u8) RuntimeError {
        const rendered = if (diagnostic) |diag|
            errors.renderLoadDiagnostic(self.allocator, source_name, source_text, diag) catch return self.fail(fallback)
        else
            return self.fail(fallback);
        defer self.allocator.free(rendered);
        return self.fail(self.intern(rendered) catch return self.fail(fallback));
    }

    pub fn failValue(self: *State, value: Value) RuntimeError {
        self.last_error = .{ .lua_value = value };
        return error.RuntimeError;
    }

    fn throwValue(self: *State, value: Value) RuntimeError {
        return self.failValue(value);
    }

    pub fn currentErrorValue(self: *State) Value {
        const payload = self.last_error orelse return .nil;
        return payload.luaValue(self);
    }
};

pub fn executeSource(allocator: std.mem.Allocator, source: []const u8) !process.ProcessResult {
    return executeSourceWithOptions(allocator, source, .{});
}

pub fn executeSourceWithOptions(allocator: std.mem.Allocator, source: []const u8, options: ExecuteOptions) !process.ProcessResult {
    var diagnostic: ?errors.Diagnostic = null;
    var tree = frontend.parseWithDiagnostic(allocator, source, &diagnostic) catch {
        return sourceFailureResult(allocator, source, diagnostic, "cannot load source");
    };
    defer tree.deinit();

    compile.resolver.resolveWithDiagnostic(allocator, &tree, &diagnostic) catch {
        return sourceFailureResult(allocator, source, diagnostic, "cannot resolve source");
    };

    var proto = compile.compileWithDiagnostic(allocator, &tree, &diagnostic) catch {
        return sourceFailureResult(allocator, source, diagnostic, "cannot compile source");
    };
    defer proto.deinit();

    var state = try State.initWithOptions(allocator, options.state);
    defer state.deinit();
    state.collect_after_instruction = options.collect_after_instruction;
    state.execute(&proto) catch |err| {
        const detail = try state.errorDetailAlloc(allocator, err);
        defer allocator.free(detail);
        const message = try std.fmt.allocPrint(allocator, "{s}\n", .{detail});
        defer allocator.free(message);
        var stderr = std.ArrayList(u8).empty;
        errdefer stderr.deinit(allocator);
        try stderr.appendSlice(allocator, state.stderr.items);
        try stderr.appendSlice(allocator, message);
        return .{
            .stdout = try allocator.dupe(u8, state.stdout.items),
            .stderr = try stderr.toOwnedSlice(allocator),
            .exit_code = 1,
            .signal = null,
            .timed_out = false,
        };
    };

    return .{
        .stdout = try allocator.dupe(u8, state.stdout.items),
        .stderr = try allocator.dupe(u8, state.stderr.items),
        .exit_code = 0,
        .signal = null,
        .timed_out = false,
    };
}

fn sourceFailureResult(allocator: std.mem.Allocator, source: []const u8, diagnostic: ?errors.Diagnostic, fallback: []const u8) !process.ProcessResult {
    const rendered = if (diagnostic) |diag|
        try errors.renderLoadDiagnostic(allocator, null, source, diag)
    else
        try allocator.dupe(u8, fallback);
    defer allocator.free(rendered);
    const message = try std.fmt.allocPrint(allocator, "{s}\n", .{rendered});
    defer allocator.free(message);
    return process.ownedResult(allocator, "", message, 1);
}

const BinaryOp = enum { add, sub, mul, div, idiv, mod, pow, band, bor, bxor, shl, shr, concat };
const UnaryMetamethodOp = enum { unm, bnot };
pub const CompareOp = enum { lt, le };
const ForValueKind = enum { initial, limit, step };

fn arithmeticVerb(op: BinaryOp) []const u8 {
    return switch (op) {
        .add => "add",
        .sub => "sub",
        .mul => "mul",
        .div => "div",
        .idiv => "idiv",
        .mod => "mod",
        .pow => "pow",
        else => "perform arithmetic on",
    };
}

fn forValueName(kind: ForValueKind) []const u8 {
    return switch (kind) {
        .initial => "initial value",
        .limit => "limit",
        .step => "step",
    };
}

fn luaTypeName(value: Value) []const u8 {
    return switch (value) {
        .nil => "nil",
        .boolean => "boolean",
        .integer, .number => "number",
        .string => "string",
        .table => "table",
        .userdata => "userdata",
        .thread => "thread",
        .closure,
        .c_closure,
        .coroutine_wrapper,
        .gmatch_iterator,
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
        => "function",
    };
}

fn runtimeSourceName(name: []const u8) []const u8 {
    if (name.len > 0 and (name[0] == '@' or name[0] == '=')) return name[1..];
    return name;
}

fn rawBinaryOp(lhs: Value, rhs: Value, op: BinaryOp) !?Value {
    switch (op) {
        .add, .sub, .mul, .idiv, .mod => {
            if (lhs == .integer and rhs == .integer) {
                return switch (op) {
                    .add => .{ .integer = lhs.integer +% rhs.integer },
                    .sub => .{ .integer = lhs.integer -% rhs.integer },
                    .mul => .{ .integer = lhs.integer *% rhs.integer },
                    .idiv => if (rhs.integer == 0) error.RuntimeError else .{ .integer = floorDiv(lhs.integer, rhs.integer) },
                    .mod => if (rhs.integer == 0) error.RuntimeError else .{ .integer = floorMod(lhs.integer, rhs.integer) },
                    else => unreachable,
                };
            }
            if (toInteger(lhs)) |left| {
                if (toInteger(rhs)) |right| {
                    return switch (op) {
                        .add => .{ .integer = left +% right },
                        .sub => .{ .integer = left -% right },
                        .mul => .{ .integer = left *% right },
                        .idiv => if (right == 0) error.RuntimeError else .{ .integer = floorDiv(left, right) },
                        .mod => if (right == 0) error.RuntimeError else .{ .integer = floorMod(left, right) },
                        else => unreachable,
                    };
                }
            }
        },
        .band, .bor, .bxor, .shl, .shr => {
            if (toBitwiseInteger(lhs)) |left| {
                if (toBitwiseInteger(rhs)) |right| {
                    return .{ .integer = rawBitwise(left, right, op) };
                }
            }
        },
        .div, .pow, .concat => {},
    }

    if (op == .concat) return null;
    const left = toNumberMaybe(lhs) orelse return null;
    const right = toNumberMaybe(rhs) orelse return null;
    return switch (op) {
        .add => .{ .number = left + right },
        .sub => .{ .number = left - right },
        .mul => .{ .number = left * right },
        .div => .{ .number = left / right },
        .idiv => .{ .number = @floor(left / right) },
        .mod => .{ .number = floorModNumber(left, right) },
        .pow => .{ .number = std.math.pow(f64, left, right) },
        else => null,
    };
}

fn rawNumericBinaryOpFast(lhs: Value, rhs: Value, op: BinaryOp) ?Value {
    return switch (lhs) {
        .integer => |left_integer| switch (rhs) {
            .integer => |right_integer| switch (op) {
                .add => .{ .integer = left_integer +% right_integer },
                .sub => .{ .integer = left_integer -% right_integer },
                .mul => .{ .integer = left_integer *% right_integer },
                .idiv => if (right_integer == 0) null else .{ .integer = floorDiv(left_integer, right_integer) },
                .mod => if (right_integer == 0) null else .{ .integer = floorMod(left_integer, right_integer) },
                .div => .{ .number = @as(f64, @floatFromInt(left_integer)) / @as(f64, @floatFromInt(right_integer)) },
                else => null,
            },
            .number => |right_number| switch (op) {
                .add => .{ .number = @as(f64, @floatFromInt(left_integer)) + right_number },
                .sub => .{ .number = @as(f64, @floatFromInt(left_integer)) - right_number },
                .mul => .{ .number = @as(f64, @floatFromInt(left_integer)) * right_number },
                .div => .{ .number = @as(f64, @floatFromInt(left_integer)) / right_number },
                .idiv => .{ .number = @floor(@as(f64, @floatFromInt(left_integer)) / right_number) },
                .mod => .{ .number = floorModNumber(@as(f64, @floatFromInt(left_integer)), right_number) },
                else => null,
            },
            else => null,
        },
        .number => |left_number| switch (rhs) {
            .integer => |right_integer| switch (op) {
                .add => .{ .number = left_number + @as(f64, @floatFromInt(right_integer)) },
                .sub => .{ .number = left_number - @as(f64, @floatFromInt(right_integer)) },
                .mul => .{ .number = left_number * @as(f64, @floatFromInt(right_integer)) },
                .div => .{ .number = left_number / @as(f64, @floatFromInt(right_integer)) },
                .idiv => .{ .number = @floor(left_number / @as(f64, @floatFromInt(right_integer))) },
                .mod => .{ .number = floorModNumber(left_number, @as(f64, @floatFromInt(right_integer))) },
                else => null,
            },
            .number => |right_number| switch (op) {
                .add => .{ .number = left_number + right_number },
                .sub => .{ .number = left_number - right_number },
                .mul => .{ .number = left_number * right_number },
                .div => .{ .number = left_number / right_number },
                .idiv => .{ .number = @floor(left_number / right_number) },
                .mod => .{ .number = floorModNumber(left_number, right_number) },
                else => null,
            },
            else => null,
        },
        else => null,
    };
}

fn rawIntegerBitwiseOpFast(lhs: Value, rhs: Value, op: BinaryOp) ?Value {
    if (lhs != .integer or rhs != .integer) return null;
    return .{ .integer = rawBitwise(lhs.integer, rhs.integer, op) };
}

fn rawCompareBranchResult(lhs: Value, rhs: Value, op: bytecode.CompareBranchOp) ?bool {
    return switch (op) {
        .eq => if (valuesEqual(lhs, rhs)) true else if (lhs == .table and rhs == .table) null else false,
        .lt => rawCompare(lhs, rhs, .lt),
        .le => rawCompare(lhs, rhs, .le),
    };
}

fn floorModNumber(left: f64, right: f64) f64 {
    var result = @rem(left, right);
    if (result != 0 and ((result < 0) != (right < 0))) result += right;
    return result;
}

fn rawUnaryOp(value: Value, op: UnaryMetamethodOp) ?Value {
    return switch (op) {
        .unm => switch (value) {
            .integer => |integer| .{ .integer = -%integer },
            .number => |number| .{ .number = -number },
            else => if (toNumberMaybe(value)) |number| .{ .number = -number } else null,
        },
        .bnot => if (toBitwiseInteger(value)) |integer| .{ .integer = ~integer } else null,
    };
}

fn toBitwiseInteger(value: Value) ?i64 {
    return switch (value) {
        .integer => |integer| integer,
        .number => |number| floatToInteger(number),
        .string => |string| parseIntegerStrict(string) orelse if (parseLuaNumber(string)) |number| floatToInteger(number) else |_| null,
        else => null,
    };
}

fn rawBitwise(left: i64, right: i64, op: BinaryOp) i64 {
    return switch (op) {
        .band => left & right,
        .bor => left | right,
        .bxor => left ^ right,
        .shl => shiftInteger(left, right),
        .shr => if (right == std.math.minInt(i64)) 0 else shiftInteger(left, -right),
        else => unreachable,
    };
}

fn bitwiseIntegerError(lhs: Value, rhs: Value, op: BinaryOp) ?[]const u8 {
    switch (op) {
        .band, .bor, .bxor, .shl, .shr => {},
        else => return null,
    }
    if (bitwiseValueError(lhs)) |message| return message;
    return bitwiseValueError(rhs);
}

fn bitwiseValueError(value: Value) ?[]const u8 {
    switch (value) {
        .integer => return null,
        .number => |number| {
            if (floatToInteger(number) != null) return null;
            if (std.math.isPositiveInf(number)) return "number (field 'huge') has no integer representation";
            return "number has no integer representation";
        },
        .string => |string| {
            if (toBitwiseInteger(.{ .string = string }) != null) return null;
            if (parseLuaNumber(string)) |number| {
                if (floatToInteger(number) == null) return "number has no integer representation";
            } else |_| {}
            return null;
        },
        else => return null,
    }
}

fn shiftInteger(value: i64, amount: i64) i64 {
    if (amount == 0) return value;
    if (amount >= 64 or amount <= -64) return 0;
    return if (amount > 0)
        value << @intCast(amount)
    else
        @as(i64, @bitCast(@as(u64, @bitCast(value)) >> @intCast(-amount)));
}

fn rawCompare(lhs: Value, rhs: Value, op: CompareOp) ?bool {
    return switch (lhs) {
        .integer => |left| switch (rhs) {
            .integer => |right| switch (op) {
                .lt => left < right,
                .le => left <= right,
            },
            .number => |right| compareIntegerNumber(left, right, op),
            else => null,
        },
        .number => |left| switch (rhs) {
            .integer => |right| compareNumberInteger(left, right, op),
            .number => |right| switch (op) {
                .lt => left < right,
                .le => left <= right,
            },
            else => null,
        },
        .string => |left| switch (rhs) {
            .string => |right| switch (op) {
                .lt => std.mem.lessThan(u8, left, right),
                .le => !std.mem.lessThan(u8, right, left),
            },
            else => null,
        },
        else => null,
    };
}

fn compareIntegerNumber(integer: i64, number: f64, op: CompareOp) bool {
    if (std.math.isNan(number)) return false;
    const min = @as(f64, @floatFromInt(std.math.minInt(i64)));
    const max_exclusive = -min;
    return switch (op) {
        .lt => {
            if (number <= min) return false;
            if (number >= max_exclusive) return true;
            return integer < @as(i64, @intFromFloat(@ceil(number)));
        },
        .le => {
            if (number < min) return false;
            if (number >= max_exclusive) return true;
            return integer <= @as(i64, @intFromFloat(@floor(number)));
        },
    };
}

fn compareNumberInteger(number: f64, integer: i64, op: CompareOp) bool {
    if (std.math.isNan(number)) return false;
    return switch (op) {
        .lt => !compareIntegerNumber(integer, number, .le),
        .le => !compareIntegerNumber(integer, number, .lt),
    };
}

fn binaryMetamethod(op: BinaryOp) []const u8 {
    return switch (op) {
        .add => "__add",
        .sub => "__sub",
        .mul => "__mul",
        .div => "__div",
        .idiv => "__idiv",
        .mod => "__mod",
        .pow => "__pow",
        .band => "__band",
        .bor => "__bor",
        .bxor => "__bxor",
        .shl => "__shl",
        .shr => "__shr",
        .concat => "__concat",
    };
}

fn unaryMetamethod(op: UnaryMetamethodOp) []const u8 {
    return switch (op) {
        .unm => "__unm",
        .bnot => "__bnot",
    };
}

pub fn valuesEqual(lhs: Value, rhs: Value) bool {
    return value_mod.valuesEqual(lhs, rhs);
}

fn hashValue(value: Value) u64 {
    return switch (value) {
        .nil => hashTag(0),
        .boolean => |payload| hashBool(1, payload),
        .integer => |payload| hashInteger(payload),
        .number => |payload| if (floatToInteger(payload)) |integer| hashInteger(integer) else hashFloat(payload),
        .string => |payload| hashBytes(4, payload),
        .table => |payload| hashPointer(5, payload),
        .userdata => |payload| hashPointer(6, payload),
        .closure => |payload| hashPointer(7, payload),
        .c_closure => |payload| hashPointer(8, payload),
        .thread => |payload| hashPointer(9, payload),
        .coroutine_wrapper => |payload| hashPointer(10, payload),
        .gmatch_iterator => |payload| hashPointer(11, payload),
        .native_print => hashTag(12),
        .native_tostring => hashTag(13),
        .native_getmetatable => hashTag(14),
        .native_setmetatable => hashTag(15),
        .native_rawequal => hashTag(16),
        .native_rawget => hashTag(17),
        .native_rawset => hashTag(18),
        .native_rawlen => hashTag(19),
        .native_next => hashTag(20),
        .native_pairs => hashTag(21),
        .native_ipairs => hashTag(22),
        .native_ipairs_iter => hashTag(23),
        .native_table_create => hashTag(24),
        .native_select => hashTag(25),
        .native_assert => hashTag(26),
        .native_error => hashTag(27),
        .native_pcall => hashTag(28),
        .native_xpcall => hashTag(29),
        .native_collectgarbage => hashTag(30),
        .native_debug_traceback => hashTag(31),
        .native_coroutine_create => hashTag(32),
        .native_coroutine_resume => hashTag(33),
        .native_coroutine_yield => hashTag(34),
        .native_coroutine_status => hashTag(35),
        .native_coroutine_running => hashTag(36),
        .native_coroutine_isyieldable => hashTag(37),
        .native_coroutine_close => hashTag(38),
        .native_coroutine_wrap => hashTag(39),
        .native => |payload| hashEnum(40, payload),
    };
}

fn hashTag(tag: u8) u64 {
    return std.hash.Wyhash.hash(0, &.{tag});
}

fn hashBytes(tag: u8, bytes: []const u8) u64 {
    return std.hash.Wyhash.hash(hashTag(tag), bytes);
}

fn hashBool(tag: u8, value: bool) u64 {
    const byte: u8 = if (value) 1 else 0;
    return std.hash.Wyhash.hash(hashTag(tag), &.{byte});
}

fn hashInteger(value: i64) u64 {
    const bits: u64 = @bitCast(value);
    return std.hash.Wyhash.hash(hashTag(2), std.mem.asBytes(&bits));
}

fn hashFloat(value: f64) u64 {
    const bits: u64 = @bitCast(value);
    return std.hash.Wyhash.hash(hashTag(3), std.mem.asBytes(&bits));
}

fn hashPointer(tag: u8, pointer: anytype) u64 {
    const address = @intFromPtr(pointer);
    return std.hash.Wyhash.hash(hashTag(tag), std.mem.asBytes(&address));
}

fn hashEnum(tag: u8, value: anytype) u64 {
    const integer = @intFromEnum(value);
    return std.hash.Wyhash.hash(hashTag(tag), std.mem.asBytes(&integer));
}

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

fn isYieldBlockingNative(value: Value) bool {
    return switch (value) {
        .native_pcall, .native_xpcall => false,
        .native => |native| native != .dofile,
        else => isNativeCallable(value),
    };
}

fn functionLike(value: Value) bool {
    return switch (value) {
        .closure, .c_closure, .coroutine_wrapper, .gmatch_iterator => true,
        else => isNativeCallable(value),
    };
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

fn lessThan(lhs: Value, rhs: Value) !bool {
    return switch (lhs) {
        .integer, .number => (try toNumber(lhs)) < (try toNumber(rhs)),
        .string => |left| switch (rhs) {
            .string => |right| std.mem.lessThan(u8, left, right),
            else => error.RuntimeError,
        },
        else => error.RuntimeError,
    };
}

fn lessEqual(lhs: Value, rhs: Value) !bool {
    return valuesEqual(lhs, rhs) or try lessThan(lhs, rhs);
}

pub fn truthy(value: Value) bool {
    return value_mod.truthy(value);
}

pub fn toInteger(value: Value) ?i64 {
    return value_mod.toInteger(value);
}

pub fn toNumber(value: Value) !f64 {
    return value_mod.toNumber(value);
}

fn toNumberMaybe(value: Value) ?f64 {
    return value_mod.toNumberMaybe(value);
}

fn luaStringLike(value: Value) bool {
    return value_mod.luaStringLike(value);
}

fn indexErrorMessage(value: Value) []const u8 {
    return value_mod.indexErrorMessage(value);
}

fn callErrorMessage(value: Value) []const u8 {
    return value_mod.callErrorMessage(value);
}

fn nativeHookName(value: Value) ?[]const u8 {
    return value_mod.nativeHookName(value);
}

fn shortNativeName(name: []const u8) []const u8 {
    return value_mod.shortNativeName(name);
}

const DebugStackSlot = struct {
    frame_index: usize,
    register: usize,
};

fn debugStackRegister(thread: *Thread, stack_index: usize) ?DebugStackSlot {
    var frame_index = thread.frames.items.len;
    while (frame_index > 0) {
        frame_index -= 1;
        const frame = thread.frames.items[frame_index];
        const register_count: usize = @intCast(frame.proto.max_registers);
        if (stack_index >= frame.base and stack_index < frame.base + register_count) {
            return .{ .frame_index = frame_index, .register = stack_index - frame.base };
        }
    }
    return null;
}

fn debugValueTypeName(value: Value) []const u8 {
    return value_mod.debugValueTypeName(value);
}

fn debugHookEvent(event: []const u8) DebugHookEvent {
    if (std.mem.eql(u8, event, "return")) return .ret;
    if (std.mem.eql(u8, event, "line")) return .line;
    if (std.mem.eql(u8, event, "count")) return .count;
    if (std.mem.eql(u8, event, "tail call")) return .tail_call;
    return .call;
}

pub fn appendLuaString(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: Value) !void {
    return value_mod.appendLuaString(allocator, out, value);
}

fn floorDiv(left: i64, right: i64) i64 {
    if (left == std.math.minInt(i64) and right == -1) return left;
    return @divFloor(left, right);
}

fn floorMod(left: i64, right: i64) i64 {
    if (left == std.math.minInt(i64) and right == -1) return 0;
    return @mod(left, right);
}

fn jumpTarget(pc: usize, offset: bytecode.JumpOffset) usize {
    return if (offset >= 0) pc + @as(usize, @intCast(offset)) else pc - @as(usize, @intCast(-offset));
}

fn instructionPreservesLastResult(instruction: bytecode.Instruction) bool {
    return switch (instruction) {
        .call, .tail_call, .ret, .vararg => true,
        else => false,
    };
}

fn plainFastLoopCanStart(instruction: bytecode.Instruction) bool {
    return switch (instruction) {
        .load_nil,
        .load_bool,
        .load_const,
        .move,
        .add,
        .sub,
        .mul,
        .div,
        .idiv,
        .mod,
        .band,
        .bor,
        .bxor,
        .shl,
        .shr,
        .eq,
        .lt,
        .le,
        .not,
        .len,
        .get_table,
        .get_field,
        .set_table,
        .set_field,
        .compare_branch,
        .jmp,
        .test_op,
        .test_set,
        .for_loop,
        .close,
        => true,
        else => false,
    };
}

fn forLoopContinuesInteger(current: i64, limit: i64, step: i64) bool {
    return if (step > 0) current <= limit else current >= limit;
}

fn integerForLimit(limit: f64, step: i64) ?i64 {
    if (std.math.isNan(limit)) return null;
    const min_integer: f64 = @floatFromInt(std.math.minInt(i64));
    const max_integer: f64 = @floatFromInt(std.math.maxInt(i64));
    if (step > 0) {
        if (limit < min_integer) return null;
        if (limit >= max_integer) return std.math.maxInt(i64);
        return @intFromFloat(std.math.floor(limit));
    }
    if (limit > max_integer) return null;
    if (limit <= min_integer) return std.math.minInt(i64);
    return @intFromFloat(std.math.ceil(limit));
}

fn forLoopContinuesNumber(current: f64, limit: f64, step: f64) bool {
    return if (step > 0) current <= limit else current >= limit;
}

pub fn localActiveAt(local: proto_mod.LocalDebug, pc: usize) bool {
    return value_mod.localActiveAt(local, pc);
}

fn isRuntimeError(err: anyerror) bool {
    return switch (err) {
        error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => true,
        else => false,
    };
}

fn lineForFrame(frame: CallFrame) ?usize {
    if (frame.proto.line_info.items.len == 0) return null;
    const pc = if (frame.pc == 0) 0 else frame.pc - 1;
    if (pc >= frame.proto.line_info.items.len) return null;
    const line = frame.proto.line_info.items[pc].line;
    return if (line == 0) null else line;
}

fn setProtoSourceName(proto: *proto_mod.Proto, name: []const u8) !void {
    proto.source_name = try proto.arena.allocator().dupe(u8, name);
    for (proto.children.items) |child| try setProtoSourceName(child, name);
}

fn copyStackValues(thread: *Thread, dest: usize, source: usize, count: usize) void {
    if (count == 0 or dest == source) return;
    if (dest > source and dest < source + count) {
        var index = count;
        while (index > 0) {
            index -= 1;
            thread.stack.items[dest + index] = thread.stack.items[source + index];
        }
    } else {
        for (0..count) |index| thread.stack.items[dest + index] = thread.stack.items[source + index];
    }
}

fn constantString(proto: *const proto_mod.Proto, index: bytecode.ConstantIndex) []const u8 {
    return proto.constants.items[index].string;
}

fn parseIntegerLiteral(lexeme: []const u8) !Value {
    return value_mod.parseIntegerLiteral(lexeme);
}

pub fn parseIntegerStrict(text: []const u8) ?i64 {
    return value_mod.parseIntegerStrict(text);
}

pub fn parseLuaNumber(text: []const u8) !f64 {
    return value_mod.parseLuaNumber(text);
}

fn parseHexNumber(text: []const u8) !f64 {
    var index: usize = 2;
    var value: f64 = 0;
    var digits: usize = 0;
    while (index < text.len and std.ascii.isHex(text[index])) : (index += 1) {
        value = value * 16 + @as(f64, @floatFromInt(hexValue(text[index])));
        digits += 1;
    }
    if (index < text.len and text[index] == '.') {
        index += 1;
        var place: f64 = 1.0 / 16.0;
        while (index < text.len and std.ascii.isHex(text[index])) : (index += 1) {
            value += @as(f64, @floatFromInt(hexValue(text[index]))) * place;
            place /= 16.0;
            digits += 1;
        }
    }
    if (digits == 0) return error.RuntimeError;

    var exponent: i32 = 0;
    if (index < text.len and (text[index] == 'p' or text[index] == 'P')) {
        index += 1;
        var sign: i32 = 1;
        if (index < text.len and (text[index] == '+' or text[index] == '-')) {
            sign = if (text[index] == '-') -1 else 1;
            index += 1;
        }
        const exponent_start = index;
        while (index < text.len and std.ascii.isDigit(text[index])) : (index += 1) {
            exponent = exponent * 10 + @as(i32, @intCast(text[index] - '0'));
        }
        if (index == exponent_start) return error.RuntimeError;
        exponent *= sign;
    }
    if (index != text.len) return error.RuntimeError;
    return value * std.math.pow(f64, 2.0, @floatFromInt(exponent));
}

pub fn floatToInteger(number: f64) ?i64 {
    return value_mod.floatToInteger(number);
}

fn isHex(text: []const u8) bool {
    return value_mod.isHex(text);
}

pub fn trimAscii(text: []const u8) []const u8 {
    return value_mod.trimAscii(text);
}

fn arrayIndex(value: Value) ?usize {
    return value_mod.arrayIndex(value);
}

fn fastTableArrayGet(table_value: Value, key_value: Value) ?Value {
    if (table_value != .table) return null;
    const index = arrayIndex(key_value) orelse return null;
    const table = table_value.table;
    if (index > table.array.items.len) return null;
    const value = table.array.items[index - 1];
    if (value != .nil or table.metatable == null) return value;
    return null;
}

fn fastTableRawGet(table_value: Value, key_value: Value) ?Value {
    if (fastTableArrayGet(table_value, key_value)) |value| return value;
    if (table_value != .table or key_value != .string) return null;
    const table = table_value.table;
    const value = table.get(key_value);
    if (value != .nil or table.metatable == null) return value;
    return null;
}

fn fastLengthNoMetamethod(value: Value) ?Value {
    return switch (value) {
        .string => |string| .{ .integer = @intCast(string.len) },
        .table => |table| if (table.metatable == null) .{ .integer = table.len() } else null,
        else => null,
    };
}

pub fn runtimeArgValue(state: *State, thread: *Thread, op: bytecode.Call, index: u16) Value {
    return value_mod.runtimeArgValue(state, thread, op, index);
}

pub fn argValue(state: *State, thread: *Thread, op: bytecode.Call, index: u16) Value {
    return value_mod.argValue(state, thread, op, index);
}

pub fn appendValue(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: Value) !void {
    return value_mod.appendValue(allocator, out, value);
}

pub fn isFileValue(value: Value) bool {
    return value_mod.isFileValue(value);
}

pub fn isClosedFileValue(value: Value) bool {
    return value_mod.isClosedFileValue(value);
}

fn appendNamedValue(allocator: std.mem.Allocator, out: *std.ArrayList(u8), name: []const u8, value: Value) !void {
    return value_mod.appendNamedValue(allocator, out, name, value);
}

fn freeProtectedResult(allocator: std.mem.Allocator, result: ProtectedCallResult) void {
    return value_mod.freeProtectedResult(allocator, result);
}

fn freeCoroutineResumeResult(allocator: std.mem.Allocator, result: CoroutineResumeResult) void {
    switch (result) {
        .success => |values| allocator.free(values),
        .failure => {},
    }
}

pub fn appendNumber(allocator: std.mem.Allocator, out: *std.ArrayList(u8), number: f64) !void {
    return value_mod.appendNumber(allocator, out, number);
}

pub fn appendFmt(allocator: std.mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) !void {
    return value_mod.appendFmt(allocator, out, fmt, args);
}

fn hexValue(byte: u8) u32 {
    return value_mod.hexValue(byte);
}

const max_lua_utf8_codepoint: u32 = 0x7fffffff;

fn appendUnicodeEscapeDigit(value: u32, digit: u32) u32 {
    if (value > max_lua_utf8_codepoint / 16) return max_lua_utf8_codepoint + 1;
    const next = value * 16 + digit;
    if (next > max_lua_utf8_codepoint) return max_lua_utf8_codepoint + 1;
    return next;
}

fn encodeLuaUtf8(code: u32, out: *[6]u8) ?usize {
    if (code <= 0x7f) {
        out[0] = @intCast(code);
        return 1;
    }
    if (code <= 0x7ff) {
        out[0] = 0xc0 | @as(u8, @intCast(code >> 6));
        out[1] = 0x80 | @as(u8, @intCast(code & 0x3f));
        return 2;
    }
    if (code <= 0xffff) {
        out[0] = 0xe0 | @as(u8, @intCast(code >> 12));
        out[1] = 0x80 | @as(u8, @intCast((code >> 6) & 0x3f));
        out[2] = 0x80 | @as(u8, @intCast(code & 0x3f));
        return 3;
    }
    if (code <= 0x1fffff) {
        out[0] = 0xf0 | @as(u8, @intCast(code >> 18));
        out[1] = 0x80 | @as(u8, @intCast((code >> 12) & 0x3f));
        out[2] = 0x80 | @as(u8, @intCast((code >> 6) & 0x3f));
        out[3] = 0x80 | @as(u8, @intCast(code & 0x3f));
        return 4;
    }
    if (code <= 0x3ffffff) {
        out[0] = 0xf8 | @as(u8, @intCast(code >> 24));
        out[1] = 0x80 | @as(u8, @intCast((code >> 18) & 0x3f));
        out[2] = 0x80 | @as(u8, @intCast((code >> 12) & 0x3f));
        out[3] = 0x80 | @as(u8, @intCast((code >> 6) & 0x3f));
        out[4] = 0x80 | @as(u8, @intCast(code & 0x3f));
        return 5;
    }
    if (code <= max_lua_utf8_codepoint) {
        out[0] = 0xfc | @as(u8, @intCast(code >> 30));
        out[1] = 0x80 | @as(u8, @intCast((code >> 24) & 0x3f));
        out[2] = 0x80 | @as(u8, @intCast((code >> 18) & 0x3f));
        out[3] = 0x80 | @as(u8, @intCast((code >> 12) & 0x3f));
        out[4] = 0x80 | @as(u8, @intCast((code >> 6) & 0x3f));
        out[5] = 0x80 | @as(u8, @intCast(code & 0x3f));
        return 6;
    }
    return null;
}

test "executes basic print and arithmetic" {
    var result = try executeSource(std.testing.allocator,
        \\print(1 + 2)
        \\print(9 // 4)
        \\print(2 ^ 8)
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "3\n2\n256.0\n"));
}

test "executes if while and repeat jumps" {
    var result = try executeSource(std.testing.allocator,
        \\local x = 0
        \\while x < 3 do
        \\  x = x + 1
        \\end
        \\if x == 3 then print("while") else print("bad") end
        \\repeat
        \\  x = x - 1
        \\until x == 0
        \\print(x)
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "while\n0\n"));
}

test "reports stack overflow for unbounded Lua recursion" {
    var result = try executeSource(std.testing.allocator,
        \\function f()
        \\  return 1 + f()
        \\end
        \\f()
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 1), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "stack overflow") != null);
}

test "reports calls to non-functions" {
    var result = try executeSource(std.testing.allocator,
        \\local value = 1
        \\value()
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 1), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "attempt to call a number value") != null);
}

test "debug errors dump stack state before unwinding" {
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\local x = 42
        \\error("boom", 0)
    , .{ .state = .{ .debug_errors = true } });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 1), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "[zlua debug] unhandled runtime exception") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "local x r") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "stack (") != null);
}

test "unhandled Lua errors render without zlua prefix" {
    var result = try executeSource(std.testing.allocator,
        \\error("boom", 0)
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 1), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stderr, "boom\n"));
}

test "last Lua error value is a GC root" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const object = try state.newTableWithHints(0, 1);
    try state.setTable(object, .{ .string = try state.intern("tag") }, .{ .string = try state.intern("live") });
    try std.testing.expectEqual(error.RuntimeError, state.throwValue(object));

    try state.collectGarbage();

    const error_value = state.currentErrorValue();
    try std.testing.expect(error_value == .table);
    try std.testing.expect(error_value.table == object.table);
    try std.testing.expect(state.isTrackedTable(object.table));
    try std.testing.expect(valuesEqual(error_value.table.get(.{ .string = "tag" }), .{ .string = "live" }));
}

test "safe stdlib omits host-facing libraries" {
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\print(type(io), type(os), type(package), type(debug))
    , .{ .state = .{ .stdlib = .safe } });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "nil\tnil\tnil\tnil\n"));
}

test "granular stdlib loads selected libraries only" {
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\print(type(string), type(table), string.upper("ok"))
    , .{ .state = .{ .stdlib = .{ .libraries = .{ .base = true, .string = true } } } });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "table\tnil\tOK\n"));
}

test "full stdlib can use memory-backed filesystem and fixed clock" {
    const files = [_]MemoryFile{
        .{ .path = "input.txt", .contents = "alpha\nbeta" },
        .{ .path = "loaded.lua", .contents = "return 'loaded'" },
    };
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\local file = assert(io.open("input.txt", "r"))
        \\print(file:read("*l"))
        \\print(file:read("*a"))
        \\print(assert(loadfile("loaded.lua"))())
        \\print(os.date("!%Y", 0))
    , .{ .state = .{ .filesystem = .{ .memory = &files }, .clock = .{ .fixed = 0 } } });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "alpha\nbeta\nloaded\n1970\n"));
}

test "disabled capabilities block filesystem and process access" {
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\local file, err = io.open("missing.lua", "r")
        \\print(file == nil, type(err))
        \\print(pcall(os.execute, "true"))
    , .{ .state = .{ .filesystem = .disabled, .process = .disabled, .clock = .{ .fixed = 0 } } });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "true\tstring\nfalse\tprocess access disabled\n"));
}

test "runtime internal phase two re-exports match facade" {
    const internal = @import("runtime/internal.zig");

    comptime {
        if (internal.Value != Value) @compileError("internal Value diverged from facade");
        if (internal.Table != Table) @compileError("internal Table diverged from facade");
        if (internal.Thread != Thread) @compileError("internal Thread diverged from facade");
        if (internal.GcMode != GcMode) @compileError("internal GcMode diverged from facade");
    }

    const memory_file: MemoryFile = internal.MemoryFile{ .path = "init.lua", .contents = "return 1" };
    _ = memory_file;
    const filesystem: FilesystemCapability = internal.FilesystemCapability.disabled;
    _ = filesystem;
    const clock: ClockCapability = internal.ClockCapability.system;
    _ = clock;
    const process_capability: ProcessCapability = internal.ProcessCapability.disabled;
    _ = process_capability;

    try std.testing.expect(internal.valuesEqual(Value.nil, .nil));
    var out = std.ArrayList(u8).empty;
    defer out.deinit(std.testing.allocator);
    try internal.appendValue(std.testing.allocator, &out, .{ .integer = 42 });
    try std.testing.expect(std.mem.eql(u8, out.items, "42"));

    out.clearRetainingCapacity();
    try internal.appendBinaryChunkHeader(std.testing.allocator, &out);
    try std.testing.expect(std.mem.startsWith(u8, out.items, binary_chunk_signature));
}

test "collects unreachable runtime allocations" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const before = state.allocationStats();
    _ = try state.intern("transient-gc-string");
    _ = try state.newTableWithHints(4, 4);

    try state.collectGarbage();

    const after = state.allocationStats();
    try std.testing.expect(after.strings >= before.strings);
    try std.testing.expectEqual(before.tables, after.tables);
    try std.testing.expectEqual(before.closures, after.closures);
    try std.testing.expectEqual(before.upvalues, after.upvalues);
    try std.testing.expectEqual(before.threads, after.threads);
}

test "keeps global table graph alive during collection" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const root = try state.newTableWithHints(0, 1);
    const child = try state.newTableWithHints(0, 1);
    const key = try state.intern("child");
    try state.setTable(child, .{ .string = try state.intern("answer") }, .{ .integer = 42 });
    try state.setTable(root, .{ .string = key }, child);
    try state.globals.put(try state.intern("gc_root"), root);

    try state.collectGarbage();

    const kept_root = state.globals.get("gc_root") orelse Value.nil;
    try std.testing.expect(kept_root == .table);
    const kept_child = kept_root.table.get(.{ .string = key });
    try std.testing.expect(kept_child == .table);
    try std.testing.expect(valuesEqual(kept_child.table.get(.{ .string = "answer" }), .{ .integer = 42 }));
}

test "weak value tables clear unreachable values" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const weak = try state.newTableWithHints(0, 1);
    const metatable = try state.newTableWithHints(0, 1);
    try state.setTable(metatable, .{ .string = try state.intern("__mode") }, .{ .string = try state.intern("v") });
    try state.setMetatableValue(weak, metatable);
    try state.globals.put(try state.intern("weak_values"), weak);

    const dead = try state.newTableWithHints(0, 0);
    try state.setTable(weak, .{ .string = try state.intern("item") }, dead);

    try state.collectGarbage();

    try std.testing.expect(weak.table.get(.{ .string = "item" }) == .nil);
}

test "weak key tables clear unreachable keys" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const weak = try state.newTableWithHints(0, 1);
    const metatable = try state.newTableWithHints(0, 1);
    try state.setTable(metatable, .{ .string = try state.intern("__mode") }, .{ .string = try state.intern("k") });
    try state.setMetatableValue(weak, metatable);
    try state.globals.put(try state.intern("weak_keys"), weak);

    const dead_key = try state.newTableWithHints(0, 0);
    try state.setTable(weak, dead_key, .{ .integer = 1 });

    try state.collectGarbage();

    try std.testing.expectEqual(@as(usize, 0), weak.table.entries.items.len);
}

test "ephemeron table marks value when key is reachable" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const ephemeron = try state.newTableWithHints(0, 1);
    const metatable = try state.newTableWithHints(0, 1);
    try state.setTable(metatable, .{ .string = try state.intern("__mode") }, .{ .string = try state.intern("k") });
    try state.setMetatableValue(ephemeron, metatable);
    try state.globals.put(try state.intern("ephemeron"), ephemeron);

    const key = try state.newTableWithHints(0, 0);
    const value = try state.newTableWithHints(0, 1);
    try state.setTable(value, .{ .string = try state.intern("answer") }, .{ .integer = 42 });
    try state.setTable(ephemeron, key, value);
    try state.globals.put(try state.intern("live_key"), key);

    try state.collectGarbage();

    const kept_value = ephemeron.table.get(key);
    try std.testing.expect(kept_value == .table);
    try std.testing.expect(valuesEqual(kept_value.table.get(.{ .string = "answer" }), .{ .integer = 42 }));
}

test "GC stress preserves live locals during execution" {
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\local keep = { answer = 42 }
        \\local i = 1
        \\while i <= 50 do
        \\  local transient = { i, { i + 1 } }
        \\  collectgarbage("collect")
        \\  i = i + 1
        \\end
        \\collectgarbage("collect")
        \\print(keep.answer)
    , .{ .collect_after_instruction = true });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "42\n"));
}

test "collectgarbage runs table finalizers before sweeping" {
    var result = try executeSource(std.testing.allocator,
        \\do
        \\  local dead = setmetatable({ name = "dead" }, {
        \\    __gc = function(self)
        \\      print("gc-final", self.name)
        \\    end,
        \\  })
        \\  dead = nil
        \\end
        \\collectgarbage("collect")
        \\collectgarbage("collect")
        \\print("done")
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "gc-final\tdead\ndone\n"));
}

test "string.dump reloads Lua closures" {
    var result = try executeSource(std.testing.allocator,
        \\local f = assert(load(string.dump(function() return 42 end)))
        \\local ok, message = pcall(string.dump, print)
        \\print(f(), ok, message ~= nil)
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "42\tfalse\ttrue\n"));
}

test "zlua binary chunks are portable across states" {
    var dump = std.ArrayList(u8).empty;
    defer dump.deinit(std.testing.allocator);

    {
        var source_state = try State.init(std.testing.allocator);
        defer source_state.deinit();
        const loaded = try source_state.loadSourceAsClosure("return 42, 'ok'");
        try dumpClosureBinary(std.testing.allocator, &dump, loaded.closure, false);
    }

    var target_state = try State.init(std.testing.allocator);
    defer target_state.deinit();
    const loaded = try target_state.loadBinaryDump(dump.items, .nil);
    const values = try target_state.callLoadedClosure(loaded.closure, &.{});
    defer target_state.allocator.free(values);

    try std.testing.expectEqual(@as(usize, 2), values.len);
    try std.testing.expect(valuesEqual(values[0], .{ .integer = 42 }));
    try std.testing.expect(valuesEqual(values[1], .{ .string = "ok" }));
}

test "zlua binary chunks preserve nested protos and upvalue descriptors" {
    var result = try executeSource(std.testing.allocator,
        \\local source = [[
        \\  return function(seed)
        \\    local total = seed
        \\    local function add(value)
        \\      total = total + value
        \\      return total
        \\    end
        \\    return add
        \\  end
        \\]]
        \\local factory = assert(load(string.dump(assert(load(source)))))()
        \\local add = factory(10)
        \\print(add(2), add(3))
        \\local debug = require "debug"
        \\local closure = factory(1)
        \\print(debug.getupvalue(closure, 1))
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "12\t15\ntotal\t1\n"));
}

test "zlua binary chunks honor supplied load environment" {
    var dump = std.ArrayList(u8).empty;
    defer dump.deinit(std.testing.allocator);

    {
        var source_state = try State.init(std.testing.allocator);
        defer source_state.deinit();
        const loaded = try source_state.loadSourceAsClosure("return answer + ...");
        try dumpClosureBinary(std.testing.allocator, &dump, loaded.closure, false);
    }

    var target_state = try State.init(std.testing.allocator);
    defer target_state.deinit();
    const environment = try target_state.newTableWithHints(0, 1);
    try target_state.setTable(environment, .{ .string = try target_state.intern("answer") }, .{ .integer = 40 });

    const loaded = try target_state.loadBinaryDump(dump.items, environment);
    const values = try target_state.callLoadedClosure(loaded.closure, &.{.{ .integer = 2 }});
    defer target_state.allocator.free(values);

    try std.testing.expectEqual(@as(usize, 1), values.len);
    try std.testing.expect(valuesEqual(values[0], .{ .integer = 42 }));
}

test "zlua binary chunks preserve stripped debug state" {
    var result = try executeSource(std.testing.allocator,
        \\local debug = require "debug"
        \\local secret = 12
        \\local f = assert(load(string.dump(function() return secret end, true)))
        \\print(debug.getupvalue(f, 1))
        \\print(debug.getinfo(f).currentline)
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "(no name)\tnil\n-1\n"));
}

test "PUC binary chunks are rejected explicitly" {
    var chunk = std.ArrayList(u8).empty;
    defer chunk.deinit(std.testing.allocator);
    try appendBinaryChunkHeader(std.testing.allocator, &chunk);
    try chunk.appendNTimes(std.testing.allocator, 0, binary_chunk_payload_magic.len);

    var state = try State.init(std.testing.allocator);
    defer state.deinit();
    try std.testing.expectError(error.RuntimeError, state.loadBinaryDump(chunk.items, .nil));
    const detail = try state.errorDetailAlloc(std.testing.allocator, error.RuntimeError);
    defer std.testing.allocator.free(detail);
    try std.testing.expect(std.mem.indexOf(u8, detail, "unsupported PUC Lua binary chunk") != null);
}

test "official closure upvalue edge cases" {
    var result = try executeSource(std.testing.allocator,
        \\local a = {}
        \\local i = 1
        \\repeat
        \\  local x = i
        \\  a[i] = function () i = x + 1; return x end
        \\until i > 10 or a[i]() ~= x
        \\assert(i == 11 and a[1]() == 1 and a[3]() == 3 and i == 4)
        \\
        \\a = {}
        \\for j = 1, 3 do
        \\  if j % 3 == 2 then
        \\    local t
        \\    goto make
        \\    ::assign:: a[j] = t; goto done
        \\    ::make::
        \\    local y = 2
        \\    t = function (x) local old = y; y = x; return old end
        \\    goto assign
        \\    ::done::
        \\  end
        \\end
        \\assert(a[2](20) == 2 and a[2]() == 20)
        \\
        \\local debug = require "debug"
        \\local foo1, foo2
        \\do
        \\  local x, y = 3, 5
        \\  foo1 = function () return x + y end
        \\  foo2 = function () return y + x end
        \\end
        \\assert(debug.upvalueid(foo1, 1) == debug.upvalueid(foo2, 2))
        \\debug.upvaluejoin(foo1, 2, foo2, 2)
        \\assert(foo1() == 6 and foo2() == 8)
        \\print("ok")
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "ok\n"));
}
