pub const version = "0.3.1";
pub const lua_target_version = "Lua 5.5";

pub const frontend = @import("frontend.zig");
pub const compile = @import("compile.zig");
pub const errors = @import("errors.zig");
pub const api = @import("api.zig");
pub const runtime = @import("runtime.zig");
pub const stdlib = @import("stdlib.zig");
pub const testing = @import("testing.zig");

pub const State = api.State;
pub const Options = api.Options;
pub const Value = api.Value;
pub const Ref = api.Ref;
pub const Table = api.Table;
pub const Function = api.Function;
pub const Context = api.Context;
pub const Error = api.Error;
pub const BytecodeLoadOptions = api.BytecodeLoadOptions;
pub const BytecodeDumpOptions = api.BytecodeDumpOptions;
pub const Tuple = api.Tuple;
pub const HostFn = api.HostFn;
pub const Userdata = api.Userdata;
pub const AnyUserdata = api.AnyUserdata;
pub const MemoryFile = api.MemoryFile;
pub const MemoryFilesystem = api.MemoryFilesystem;
pub const FilesystemCapability = api.FilesystemCapability;
pub const CustomFilesystem = api.CustomFilesystem;
pub const EnvironmentCapability = api.EnvironmentCapability;
pub const CustomEnvironment = api.CustomEnvironment;
pub const ClockCapability = api.ClockCapability;
pub const CustomClock = api.CustomClock;
pub const ProcessCapability = api.ProcessCapability;
pub const CustomProcess = api.CustomProcess;
pub const ProcessResult = api.ProcessResult;
pub const ProcessStatus = api.ProcessStatus;

test {
    _ = frontend;
    _ = compile;
    _ = errors;
    _ = api;
    _ = runtime;
    _ = stdlib;
    _ = testing;
}
