# errors

## Navigation

- [API Index](README.md)

<details>
<summary>All documents</summary>

- [root](root.md)
- [frontend](frontend.md)
- [errors](errors.md)
- [frontend.source](frontend/source.md)
- [frontend.token](frontend/token.md)
- [frontend.diagnostic](frontend/diagnostic.md)
- [frontend.lexer](frontend/lexer.md)
- [frontend.ast](frontend/ast.md)
- [frontend.parser](frontend/parser.md)
- [compile](compile.md)
- [compile.resolver](compile/resolver.md)
- [compile.bytecode](compile/bytecode.md)
- [compile.proto](compile/proto.md)
- [compile.compiler](compile/compiler.md)
- [compile.disasm](compile/disasm.md)
- [api](api.md)
- [runtime](runtime.md)
- [runtime.chunk](runtime/chunk.md)
- [runtime.types](runtime/types.md)
- [runtime.value](runtime/value.md)
- [runtime.execute](runtime/execute.md)
- [testing.process](testing/process.md)
- [runtime.state](runtime/state.md)
- [runtime.call](runtime/call.md)
- [runtime.coroutine](runtime/coroutine.md)
- [runtime.debug](runtime/debug.md)
- [runtime.gc](runtime/gc.md)
- [runtime.host](runtime/host.md)
- [stdlib](stdlib.md)
- [stdlib.base](stdlib/base.md)
- [stdlib.table](stdlib/table.md)
- [stdlib.string](stdlib/string.md)
- [stdlib.math](stdlib/math.md)
- [stdlib.utf8](stdlib/utf8.md)
- [stdlib.coroutine](stdlib/coroutine.md)
- [stdlib.debug](stdlib/debug.md)
- [stdlib.package](stdlib/package.md)
- [stdlib.io](stdlib/io.md)
- [stdlib.os](stdlib/os.md)
- [stdlib.json](stdlib/json.md)
- [stdlib.zerde_lua](stdlib/zerde_lua.md)
- [stdlib.toml](stdlib/toml.md)
- [stdlib.msgpack](stdlib/msgpack.md)
- [stdlib.csv](stdlib/csv.md)
- [runtime.vm](runtime/vm.md)
- [runtime.tests](runtime/tests.md)
- [runtime.internal](runtime/internal.md)
- [testing](testing.md)
- [testing.clua](testing/clua.md)
- [testing.bench_runner](testing/bench_runner.md)
- [testing.c_api_runner](testing/c_api_runner.md)
- [testing.diff_runner](testing/diff_runner.md)
- [testing.expected_failures](testing/expected_failures.md)
- [testing.metadata](testing/metadata.md)
- [testing.normalizer](testing/normalizer.md)
- [testing.extension_runner](testing/extension_runner.md)
- [testing.official_suite](testing/official_suite.md)

</details>

## Functions

- [tokenRef](#fn-tokenref)
- [eofToken](#fn-eoftoken)
- [renderLoadDiagnostic](#fn-renderloaddiagnostic)
- [renderArgumentError](#fn-renderargumenterror)

## Types

- [ZluaError](#type-zluaerror)
- [HostError](#type-hosterror)
- [Diagnostic](#type-diagnostic)
- [ArgumentError](#type-argumenterror)
- [ArgumentErrorDetail](#type-argumenterrordetail)
- [SyntaxError](#type-syntaxerror)
- [TokenRef](#type-tokenref)
- [UnexpectedSyntax](#type-unexpectedsyntax)
- [SyntaxMessage](#type-syntaxmessage)
- [ExpectedSyntax](#type-expectedsyntax)
- [ExpectedClose](#type-expectedclose)
- [ResolveError](#type-resolveerror)
- [CompileError](#type-compileerror)

<a id="type-zluaerror"></a>

## ZluaError

```zig
pub const ZluaError = union(enum) {
    diagnostic: Diagnostic,
    host: HostError,
};
```

<a id="type-hosterror"></a>

## HostError

```zig
pub const HostError = union(enum) {
    out_of_memory,
    io,
    internal_bug,
};
```

<a id="type-diagnostic"></a>

## Diagnostic

```zig
pub const Diagnostic = union(enum) {
    syntax: SyntaxError,
    resolve: ResolveError,
    compile: CompileError,
    argument: ArgumentError,
};
```

<a id="type-argumenterror"></a>

## ArgumentError

```zig
pub const ArgumentError = struct {
    function_name: []const u8,
    index: u16,
    detail: ArgumentErrorDetail,
};
```

<a id="type-argumenterrordetail"></a>

## ArgumentErrorDetail

```zig
pub const ArgumentErrorDetail = union(enum) {
    message: []const u8,
    expected: struct {
            expected: []const u8,
            actual: []const u8,
        },
};
```

<a id="type-syntaxerror"></a>

## SyntaxError

```zig
pub const SyntaxError = union(enum) {
    unexpected: UnexpectedSyntax,
    expected: ExpectedSyntax,
    expected_close: ExpectedClose,
};
```

<a id="type-tokenref"></a>

## TokenRef

```zig
pub const TokenRef = struct {
    tag: token_mod.Tag,
    lexeme: []const u8,
    span: source.Span,
    unquoted: bool = false,
};
```

<a id="type-unexpectedsyntax"></a>

## UnexpectedSyntax

```zig
pub const UnexpectedSyntax = struct {
    token: TokenRef,
    message: SyntaxMessage = .syntax_error,
};
```

<a id="type-syntaxmessage"></a>

## SyntaxMessage

```zig
pub const SyntaxMessage = enum {
    syntax_error,
    unexpected_symbol,
    malformed_number,
    unfinished_string,
    invalid_escape,
    hex_digit_expected,
    decimal_escape_too_large,
    utf8_value_too_large,
    missing_open_brace,
    missing_close_brace,
    unfinished_long_bracket,
    too_many_syntax_levels,
};
```

<a id="type-expectedsyntax"></a>

## ExpectedSyntax

```zig
pub const ExpectedSyntax = struct {
    expected: []const u8,
    near: TokenRef,
};
```

<a id="type-expectedclose"></a>

## ExpectedClose

```zig
pub const ExpectedClose = struct {
    expected: []const u8,
    opener: []const u8,
    opener_line: usize,
    near: TokenRef,
};
```

<a id="type-resolveerror"></a>

## ResolveError

```zig
pub const ResolveError = union(enum) {
    duplicate_label: struct { name: []const u8, span: source.Span, previous_line: usize },
    missing_label: struct { name: []const u8, span: source.Span },
    goto_into_scope: struct { label: []const u8, decl: []const u8, span: source.Span },
    break_outside_loop: source.Span,
    assign_const: struct { name: []const u8, span: source.Span },
    undeclared_global: struct { name: []const u8, span: source.Span },
    invalid_close: struct { span: source.Span, global: bool = false, multiple: bool = false },
    unknown_attribute: struct { name: []const u8, span: source.Span },
    invalid_assignment_target: source.Span,
    invalid_environment: struct { name: []const u8, span: source.Span },
};
```

<a id="type-compileerror"></a>

## CompileError

```zig
pub const CompileError = union(enum) {
    too_many_returns: source.Span,
    register_overflow: struct { line: usize },
    too_many_local_variables: struct { line: usize },
    too_many_upvalues: struct { line: usize },
    jump_out_of_range: struct { line: usize },
    invalid_ast: struct { line: usize },
};
```

<a id="fn-tokenref"></a>

## tokenRef

```zig
pub fn tokenRef(token: token_mod.Token) TokenRef
```

References: [`TokenRef`](#type-tokenref)

<a id="fn-eoftoken"></a>

## eofToken

```zig
pub fn eofToken(source_text: []const u8, line: usize, column: usize) TokenRef
```

References: [`TokenRef`](#type-tokenref)

<a id="fn-renderloaddiagnostic"></a>

## renderLoadDiagnostic

```zig
pub fn renderLoadDiagnostic(
    allocator: std.mem.Allocator,
    source_name: ?[]const u8,
    source_text: []const u8,
    diagnostic: Diagnostic,
) ![]u8
```

References: [`Diagnostic`](#type-diagnostic)

<a id="fn-renderargumenterror"></a>

## renderArgumentError

```zig
pub fn renderArgumentError(allocator: std.mem.Allocator, argument: ArgumentError) ![]u8
```

References: [`ArgumentError`](#type-argumenterror)

