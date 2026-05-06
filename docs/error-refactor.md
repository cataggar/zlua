# Error Refactor Plan

## Goal

Replace string-first internal failures with structured zlua error values that can be carried through the frontend, compiler, runtime, stdlib, protected calls, and CLI, then materialized as Lua-observable error objects at semantic boundaries.

The intent is not to add a compatibility message layer. The internal representation should model the actual error cause and enough source/runtime context to render the exact Lua error text when Lua would expose a string error object.

## Current State

- `State.fail` in `src/runtime.zig` stores `last_error` as text and `last_error_value` as a Lua `Value`.
- `load` uses heuristic message recovery in `src/stdlib/base.zig` via `loadFailureMessage`; this should go away as typed load errors land.
- Lexer/parser/resolver/compiler mostly return coarse Zig errors such as `LexError`, `ParseError`, `ResolveError`, `CompileError`, and `TooManyReturns`, losing the specific cause and source span.
- The CLI currently wraps unhandled runtime errors as `zlua runtime error: ...`, which does not match Lua script execution output.
- The official `errors.lua` test expects precise syntax/load errors and runtime messages that include source names, line numbers, token text, variable provenance, metamethod names, and Lua type wording.

## Proposed Error Model

Add a central typed error module, likely `src/errors.zig`, exposed through the relevant facades.

Suggested top-level shape:

```zig
pub const ZluaError = union(enum) {
    lua_value: runtime.Value,
    diagnostic: Diagnostic,
    host: HostError,
};

pub const Diagnostic = union(enum) {
    syntax: SyntaxError,
    resolve: ResolveError,
    compile: CompileError,
    runtime: RuntimeErrorInfo,
    argument: ArgumentError,
};

pub const HostError = union(enum) {
    out_of_memory,
    io: IoError,
    internal_bug: InternalBug,
};
```

`diagnostic` is for structured zlua causes that Lua normally renders as strings. `lua_value` is for actual Lua error objects thrown by `error(x)`, `assert`, or equivalent API behavior. `host` is for failures from the embedding environment or VM invariants; it needs explicit policy rather than automatic conversion into ordinary Lua diagnostics.

When a structured failure crosses a Lua-observable boundary, materialize it into the Lua error object that Lua code would see:

```zig
pub fn materializeLuaError(state: *State, err: ZluaError) !runtime.Value {
    return switch (err) {
        .lua_value => |value| value,
        .diagnostic => |diagnostic| try renderDiagnosticAsLuaString(state, diagnostic),
        .host => |host| try materializeHostError(state, host),
    };
}
```

Host-error policy should be deliberate:

- Out-of-memory may need a distinct non-allocating path.
- I/O errors may become Lua errors when they happen inside Lua APIs that report I/O failures.
- Internal VM/compiler invariant failures should not be hidden as ordinary Lua load or runtime errors unless Lua itself would report them that way.

Runtime state should move from text fields:

```zig
last_error: ?[]const u8,
last_error_value: Value,
```

to a typed value:

```zig
last_error: ?errors.ZluaError,
```

If `last_error` can hold `.lua_value`, that value is a GC root. Tables, functions, strings, userdata, and other collectable values thrown through `error(obj)` must remain alive while stored in protected-call or coroutine error state.

A structured diagnostic may remain structured while unwinding internally, but the moment Lua code can observe it as an error object, it must materialize as the correct Lua value, usually a Lua string. Lua-observable boundaries include:

- `load` and `loadfile` returning `nil, msg`.
- `pcall` returning `false, err`.
- `xpcall` invoking the message handler.
- `coroutine.resume` returning `false, err`.
- `coroutine.wrap` rethrowing or resurfacing the error.
- C API protected calls and API functions that match `liblua` protected-call behavior.
- `debug.traceback(err)` and message-handler traceback behavior.
- Unhandled CLI script execution.

This rule prevents hidden structured diagnostics from leaking as non-Lua objects through protected calls, while preserving non-string Lua errors exactly when Lua code throws them.

Do not let `ZluaError` become a monolithic string-rendering object. Keep causes structured, keep rendering centralized but modular, and make object materialization semantics explicit.

## Frontend Diagnostics

Replace coarse lexer/parser failures with typed syntax diagnostics.

The typed syntax error should preserve:

- Source name, including `@file`, `=literal`, or string chunk names.
- Span and line number.
- Unexpected token text.
- Expected token or construct, where known.
- Context for messages such as `'}' expected (to close '{' at line 1)`.
- The rendered `near <token>` portion.

Rendering must follow Lua source-name rules, including string chunk previews and the 60-byte display limit used by the official tests.

This phase should delete `loadFailureMessage` and make `load` return the formatter output from typed syntax/resolve/compile errors.

## Resolver Diagnostics

Replace `error.ResolveError` with typed resolver causes.

Initial resolver error variants should cover:

- Duplicate label.
- Missing or invisible label.
- `goto` jumping into a local scope.
- `break` outside a loop.
- Assignment to a const binding.
- Undeclared global under restricted declarations.
- Invalid `<close>` usage.
- Unknown attributes.

The resolver already tracks spans for declarations, labels, and gotos in several structs. Thread those spans into the typed error payload instead of collapsing to `ResolveError`.

## Compiler Diagnostics

Add typed compiler errors for load-time compile failures.

Initial compiler error variants should cover:

- Too many returns.
- Register overflow.
- Too many local variables.
- Too many upvalues.
- Jump out of range.
- Invalid AST shapes that should be internal errors.

Compiler diagnostics should preserve source line and span where available. These should render as Lua load errors when surfaced through `load`, `loadfile`, or script loading.

## Runtime Errors

Add typed runtime constructors and move direct string failures behind them.

Runtime errors should be constructed at the semantic failure site, using structured operations instead of phrasing-shaped strings:

```zig
pub const TypeErrorOp = enum {
    arithmetic,
    bitwise,
    concatenate,
    compare,
    call,
    index,
    newindex,
    length,
    unary_minus,
};
```

Examples:

```zig
try state.raise(.{ .type_error = .{
    .operation = .arithmetic,
    .operand = lhs,
    .site = state.currentErrorSite(thread),
} });
```

Keep `throwValue(value)` behavior for actual Lua error objects. `error("message")` and `assert(false, message)` should still carry Lua values according to Lua semantics.

Typed runtime causes should initially cover:

- Type errors for arithmetic, bitwise, concat, compare, call, index, length, and unary operations.
- Division/modulo by zero.
- Integer conversion failures.
- Metamethod call failures and invalid metamethod values.
- For-loop initial value, limit, step, and iterator call errors.
- Stack overflow and unsupported opcode/internal runtime failures.
- Table key errors such as nil and NaN.

Runtime stringification should centralize Lua wording, including:

- `attempt to index a number value`.
- `attempt to call a nil value`.
- `attempt to perform arithmetic on a table value`.
- `attempt to call field 'x' (a nil value)` style provenance-aware messages.
- `bad argument #n to 'func' (...)`.
- Named types via `__name`, such as `FILE*`.

Runtime and stdlib argument diagnostics should share the same Lua type-name path, including `__name` lookup and special handle wording:

```zig
pub fn luaTypeNameForError(state: *State, value: Value) []const u8
```

## Runtime Provenance

The largest functional gap is preserving the semantic origin of values at failing instructions.

Official `errors.lua` checks messages containing:

- `global 'bbbb'`.
- `local 'a'`.
- `upvalue 'cc'`.
- `field 'x'`.
- `method 'bbbb'`.
- `metamethod 'add'`.
- Fallback wording when debug info is stripped.

Do not infer these from final strings. Add optional compiler-emitted error-site metadata to `Proto`, keyed by instruction index. This metadata can describe operands and call targets in terms of source-level provenance.

Keep the metadata sparse. Most instructions do not need rich diagnostic context; only ops that can produce name-sensitive diagnostics should get entries. A sorted side table keyed by instruction index is preferable to hanging a large optional payload off every instruction.

Possible metadata shape:

```zig
pub const ErrorSiteEntry = struct {
    pc: u32,
    site: ErrorSite,
};

pub const ErrorSite = struct {
    line: usize,
    op: ErrorOp,
    operands: []const OperandOrigin,
    call_name: ?CallName,
};

pub const OperandOrigin = union(enum) {
    temporary,
    local: NameRef,
    upvalue: NameRef,
    global: NameRef,
    field: NameRef,
    method: NameRef,
    metamethod: NameRef,
};

pub const NameRef = union(enum) {
    proto_string: u32,
    interned: StringId,
    static: []const u8,
};
```

Avoid borrowed slices into transient lexer/parser buffers for error payloads. Token text, source names, variable names, field names, metamethod names, spans, and string previews must either be owned by the diagnostic, interned, static, or referenced through proto-owned tables with a clear lifetime.

When functions are dumped with stripped debug info, drop this metadata so errors degrade like Lua's stripped-debug behavior. Prefer making `ErrorSite` live inside debug metadata so stripping debug info naturally removes it:

```zig
if (proto.debug_info == .stripped) {
    proto.error_site_metadata = null;
}
```

## Stdlib Argument Errors

After runtime plumbing exists, convert stdlib `state.fail("...")` calls into typed argument errors. Argument errors are Lua API/library diagnostics and should use the central `Diagnostic.argument` machinery, not ad hoc strings in each stdlib module.

Prioritize public APIs exercised by official `errors.lua`:

- `assert`, `pcall`, `xpcall`, `load`, `tostring`, `tonumber`.
- `math.*` numeric argument checks.
- `string.*` argument checks and integer conversion errors.
- `table.sort`, `table.unpack`, and table argument checks.
- `io.*` named file errors and `FILE*` messages.
- `debug.*` argument errors.
- Coroutine errors around yield/resume/wrap.

The goal is one central formatter for argument errors, not per-function Lua-message strings. It should consume the same runtime type-name helper used by VM type errors so `__name`, userdata/file handles, and ordinary Lua types render consistently.

## Migration Phases

### Phase 1: Source And Load Errors

- Implement typed frontend, resolver, and compiler errors.
- Add Lua-compatible source-name and syntax error rendering.
- Delete `loadFailureMessage` from `src/stdlib/base.zig`.
- Make `load`, script loading, and differential compile/load paths use typed formatted errors.
- Target the initial syntax and load assertions in official `errors.lua`.

### Phase 2: Runtime Error Object Plumbing

- Replace `State.last_error` and `State.last_error_value` with a typed error payload that can preserve Lua values.
- Update protected call context save/restore to carry the typed error.
- Prove `error(table)` survives `pcall` with object identity preserved.
- Prove `error("x")` returns the correct Lua string object/message.
- Prove `xpcall` receives the correct object in the message handler.
- Prove coroutine `resume` and `wrap` error paths preserve or resurface the correct object.
- Make thrown Lua values visible to GC marking while stored in error state.
- Update CLI unhandled error formatting to emit Lua-style errors rather than `zlua runtime error:` for user-code failures.

### Phase 3: Name-Aware Runtime Messages

- Add `Proto` error-site metadata from the compiler.
- Convert arithmetic, bitwise, concat, compare, index, call, length, and for-loop errors to typed causes.
- Use metadata and current frame state to render local/global/upvalue/field/method/metamethod wording.
- Ensure stripped debug info degrades correctly.

### Phase 4: Stdlib Argument Errors

- Convert stdlib direct string failures to typed argument errors.
- Centralize function-name, argument-index, self, expected-type, and actual-type rendering.
- Preserve special named-type behavior from `__name` and file handles.

### Phase 5: Cleanup And Validation

- Remove remaining compatibility-string helpers and heuristic message builders.
- Add focused differential fixtures for syntax, resolver, compiler, runtime type errors, and stdlib argument errors.
- Run:

```sh
zig build test
zig build test-diff
zig build test-official
```

## Risks

- The error union itself is straightforward; the hard part is preserving enough provenance to render Lua's high-quality runtime messages without guessing.
- Parser diagnostics may need additional context stacks to produce exact `expected` and `to close` messages.
- Compiler-emitted metadata must not perturb runtime behavior or register allocation.
- Protected-call and coroutine paths are sensitive because they must preserve arbitrary Lua error objects, not just strings.
- Error payloads must not borrow transient frontend/compiler buffers unless the lifetime is guaranteed.
- `lua_value` errors stored in runtime state must be traced as GC roots.
- Host errors need explicit materialization policy so internal bugs and resource failures are not silently disguised as user Lua errors.
- Stripped debug info must intentionally remove provenance metadata.

## Success Criteria

- Official `errors.lua` passes without string compatibility heuristics.
- Existing official tests continue to pass.
- `load` and `loadfile` return Lua-compatible syntax/load messages from structured errors.
- Runtime and stdlib failures are represented internally as typed zlua diagnostics until Lua code can observe them as error objects.
- Structured diagnostics materialize into Lua strings at `pcall`, `xpcall`, coroutine, debug traceback, C API protected-call, load, and CLI boundaries as appropriate.
- Non-string Lua error objects remain identity-preserving through `pcall`, `xpcall`, and coroutine APIs.
- The CLI no longer adds `zlua runtime error:` to user-code failures.
