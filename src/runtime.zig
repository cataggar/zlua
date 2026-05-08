const chunk_mod = @import("runtime/chunk.zig");
const execute_mod = @import("runtime/execute.zig");
const host = @import("runtime/host.zig");
const state_mod = @import("runtime/state.zig");
const tests = @import("runtime/tests.zig");
const types = @import("runtime/types.zig");

pub const RuntimeError = types.RuntimeError;
pub const binary_chunk_signature = chunk_mod.binary_chunk_signature;
pub const binary_chunk_payload_magic = chunk_mod.binary_chunk_payload_magic;

pub const State = state_mod.State;
pub const StateOptions = state_mod.StateOptions;

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

pub const appendBinaryChunkHeader = chunk_mod.appendBinaryChunkHeader;
pub const dumpClosureBinary = chunk_mod.dumpClosureBinary;

pub const Closure = types.Closure;
pub const CClosure = types.CClosure;
pub const CUpvalue = types.CUpvalue;
pub const Upvalue = types.Upvalue;
pub const Table = types.Table;
pub const Userdata = types.Userdata;
pub const Thread = types.Thread;
pub const GcMode = types.GcMode;
pub const GcParam = types.GcParam;

pub const StdlibMode = state_mod.StdlibMode;
pub const MemoryFile = host.MemoryFile;
pub const MemoryFilesystem = host.MemoryFilesystem;
pub const FilesystemCapability = host.FilesystemCapability;
pub const ClockCapability = host.ClockCapability;
pub const ProcessCapability = host.ProcessCapability;

pub const CompareOp = state_mod.CompareOp;
pub const valuesEqual = state_mod.valuesEqual;
pub const truthy = state_mod.truthy;
pub const toInteger = state_mod.toInteger;
pub const toNumber = state_mod.toNumber;
pub const appendLuaString = state_mod.appendLuaString;
pub const localActiveAt = state_mod.localActiveAt;
pub const parseIntegerStrict = state_mod.parseIntegerStrict;
pub const parseLuaNumber = state_mod.parseLuaNumber;
pub const floatToInteger = state_mod.floatToInteger;
pub const trimAscii = state_mod.trimAscii;
pub const runtimeArgValue = state_mod.runtimeArgValue;
pub const argValue = state_mod.argValue;
pub const appendValue = state_mod.appendValue;
pub const isFileValue = state_mod.isFileValue;
pub const isClosedFileValue = state_mod.isClosedFileValue;
pub const appendNumber = state_mod.appendNumber;
pub const appendFmt = state_mod.appendFmt;

pub const ExecuteOptions = execute_mod.ExecuteOptions;
pub const executeSource = execute_mod.executeSource;
pub const executeSourceWithOptions = execute_mod.executeSourceWithOptions;

test {
    _ = tests;
}
