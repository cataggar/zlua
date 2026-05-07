# Zig Lua 5.5 Implementation Plan

## 1. Project background

Build an independent **Lua 5.5 implementation in Zig 0.16.0**. The implementation should parse Lua source, compile it to an internal bytecode format, execute it on a register-based VM, provide the standard libraries, expose a Zig-native embedding API, and eventually offer a C API compatibility layer.

The current Lua release is **Lua 5.5.0**, and the official download page lists it as the current release. Lua is distributed as source code and is implemented in pure ISO C, making the official implementation a practical behavioral oracle for this project. ([Lua][1])

The project should treat the official Lua implementation, here called **CLua**, as the source of behavioral truth from day one. The official Lua test page also provides a **Lua 5.5.0-specific test suite** and states that suites do not work across different Lua versions, so the project should pin tests to Lua 5.5.0 exactly. ([Lua][2])

Zig 0.16.0 is the intended implementation language. Zig’s current site lists 0.16.0 as the latest release, and the 0.16.0 release notes introduce I/O as an explicit `Io` interface, which should influence the design of the CLI, REPL, file loading, module loading, and `io` library. ([Zig Programming Language][3]) ([Zig Programming Language][4])

---

# 2. Project goals

## 2.1 Primary goal

Implement a source-compatible Lua 5.5 runtime in Zig.

```text
zlua source.lua
```

should behave like:

```text
lua5.5 source.lua
```

for supported features.

## 2.2 Secondary goals

```text
Zig-native embedding API
safe sandbox mode
full CLI mode
standard library compatibility
differential test suite
official Lua 5.5 test suite integration
eventual C API compatibility layer
```

## 2.3 Explicit non-goals for early versions

```text
JIT
LuaJIT compatibility
multi-version Lua modes
PUC Lua binary chunk compatibility
ABI-compatible liblua replacement
LuaRocks compatibility
full dynamic native module loading
```

---

# 3. Core principle: CLua oracle first

Differential testing against CLua is not a final QA step. It is the backbone of the project.

Every feature should enter through this loop:

```text
1. Write a Lua test file.
2. Run it with lua5.5.
3. Run it with zlua.
4. Compare results.
5. Implement until zlua matches.
6. Keep the test forever.
```

## 3.1 Test stages

The differential harness should support staged comparison so it is useful before the VM exists.

| Stage      | CLua action    | zlua action               | Purpose                         |
| ---------- | -------------- | ------------------------- | ------------------------------- |
| `lex`      | usually none   | tokenize                  | frontend smoke tests            |
| `parse`    | `load(source)` | parse source              | syntax compatibility            |
| `resolve`  | `load(source)` | parse + resolve           | declaration/scope compatibility |
| `compile`  | `load(source)` | parse + resolve + compile | compiler acceptance             |
| `runtime`  | execute file   | execute file              | behavior compatibility          |
| `stdlib`   | execute file   | execute file              | library compatibility           |
| `official` | official suite | zlua suite mode           | release compatibility           |

## 3.2 Test result comparison

Compare:

```text
stdout
stderr
exit code
timeout
signal/crash status
```

Normalize only:

```text
absolute paths
memory addresses
some traceback paths
temporary filenames
line-number formatting during early compiler phases
table iteration order where Lua leaves it unspecified
```

Do not normalize:

```text
wrong values
missing output
extra output
success vs failure mismatch
wrong number of returns
wrong mutation behavior
wrong type behavior
```

## 3.3 Test metadata

Use Lua comments at the top of differential tests:

```lua
-- expect: pass
-- stage: runtime
-- feature: arithmetic
-- normalize: none

print(1 + 2)
print(10 // 3)
```

Known incomplete features:

```lua
-- expect: fail
-- stage: runtime
-- feature: coroutine
-- reason: coroutine VM support not implemented
-- issue: #123

local co = coroutine.create(function ()
  coroutine.yield(1)
end)

print(coroutine.resume(co))
```

## 3.4 Harness commands

```text
zlua test-diff
zlua test-diff tests/diff/runtime/arithmetic/basic.lua
zlua test-diff --stage=parse
zlua test-diff --stage=compile
zlua test-diff --stage=runtime
zlua test-diff --feature=table
zlua test-diff --bless
zlua test-diff --show-clua
zlua test-diff --show-zlua
zlua test-diff --update-expected-failures
```

## 3.5 CI policy

CI should always report:

```text
passed
failed
expected_failed
skipped
flaky
timed_out
```

The important rule:

```text
unexpected_failed must be 0
```

Expected failures are allowed while features are incomplete, but every expected failure needs a feature tag and reason.

---

# 4. Repository layout

```text
zlua/
  build.zig
  build.zig.zon
  README.md
  LICENSE

  docs/
    architecture.md
    compatibility.md
    testing.md
    bytecode.md
    gc.md
    embedding.md
    c-api.md

  src/
    main.zig
    zlua.zig

    frontend/
      source.zig
      diagnostic.zig
      token.zig
      lexer.zig
      ast.zig
      parser.zig

    compile/
      scope.zig
      resolver.zig
      bytecode.zig
      proto.zig
      compiler.zig
      disasm.zig

    runtime/
      value.zig
      object.zig
      state.zig
      thread.zig
      stack.zig
      call.zig
      vm.zig
      string.zig
      table.zig
      closure.zig
      userdata.zig
      metatable.zig
      coroutine.zig
      error.zig
      gc.zig

    stdlib/
      base.zig
      table.zig
      string.zig
      math.zig
      utf8.zig
      coroutine.zig
      debug.zig
      package.zig
      io.zig
      os.zig

    api/
      native.zig
      c_api.zig
      auxlib.zig
      lualib.zig

    testing/
      clua.zig
      diff_runner.zig
      normalizer.zig
      metadata.zig
      official_suite.zig

  tests/
    unit/
      lexer/
      parser/
      resolver/
      compiler/
      runtime/
      gc/

    diff/
      syntax/
      declarations/
      arithmetic/
      control_flow/
      functions/
      returns/
      varargs/
      tables/
      strings/
      metatables/
      errors/
      coroutines/
      gc/
      stdlib/

    official/
      lua-5.5.0-tests/

    fixtures/
      expected_failures.toml
      skips.toml
      normalizers.toml
```

---

# 5. Runtime architecture

## 5.1 State model

```text
State
  allocator
  GC state
  interned strings
  registry
  global environment
  loaded libraries
  limits
  I/O capabilities
```

```text
Thread
  stack
  call frames
  status
  error object
  coroutine parent/continuation state
```

## 5.2 Value representation

Start with a clear tagged union:

```zig
pub const Value = union(enum) {
    nil,
    boolean: bool,
    integer: i64,
    number: f64,
    string: *ObjString,
    table: *ObjTable,
    closure: *ObjClosure,
    thread: *ObjThread,
    userdata: *ObjUserdata,
    light_userdata: ?*anyopaque,
};
```

Do not begin with NaN boxing. It can be revisited after correctness.

## 5.3 Object model

All GC-managed objects should share a header:

```zig
pub const GcHeader = struct {
    tag: ObjTag,
    marked: MarkBits,
    next: ?*GcHeader,
};
```

Managed object types:

```text
ObjString
ObjExternalString
ObjTable
ObjProto
ObjClosure
ObjUpvalue
ObjThread
ObjUserdata
```

## 5.4 Bytecode model

Use a register-based internal bytecode.

Initial instruction families:

```text
LOAD_NIL
LOAD_BOOL
LOAD_INT
LOAD_FLOAT
LOAD_CONST
MOVE

GET_GLOBAL
SET_GLOBAL
GET_UPVALUE
SET_UPVALUE
GET_TABLE
SET_TABLE
GET_FIELD
SET_FIELD

NEW_TABLE
SET_LIST

ADD
SUB
MUL
DIV
IDIV
MOD
POW
UNM

BAND
BOR
BXOR
BNOT
SHL
SHR

EQ
LT
LE
NOT
LEN
CONCAT

JMP
TEST
TEST_SET

CALL
TAIL_CALL
RETURN
VARARG

CLOSURE
CLOSE

FOR_PREP
FOR_LOOP
TFOR_PREP
TFOR_CALL
TFOR_LOOP
```

Begin with readable instruction structs. Move to packed `u32` instructions later.

---

# 6. Milestone plan

## Milestone 0: CLua oracle harness

### Goal

Build the testing infrastructure before implementing the language.

### Implementation tasks

```text
Create build.zig
Create CLI skeleton
Detect lua5.5 executable
Validate lua5.5 version output
Create CLua runner
Create zlua runner
Create ProcessResult type
Create metadata parser
Create output normalizers
Create expected-failure registry
Create test report format
Create CI task
```

### Differential testing tasks

```text
Add one passing CLua smoke test
Add one intentionally failing zlua expected failure
Add parse-stage comparison mode
Add runtime-stage comparison mode
Add timeout support
Add stderr/stdout diff renderer
```

### Acceptance criteria

```text
zig build test works
zlua --version works
zlua test-diff works
CLua executable is detected or cleanly reported missing
expected failures are reported separately from unexpected failures
CI fails on unexpected failure
```

---

## Milestone 1: Lexer

### Goal

Tokenize Lua 5.5 source.

### Implementation tasks

```text
Token enum
source spans
line/column tracking
identifiers
keywords
operators
punctuation
integer literals
float literals
hex literals
short strings
long strings
escape sequences
comments
long comments
lexer diagnostics
```

### CLua-integrated tests

At this phase, CLua cannot directly test token streams, so use CLua as an acceptance oracle through `load`.

For each syntax fixture:

```text
CLua: load(source) succeeds or fails
zlua: lex(source) succeeds or fails
```

This is coarse, but catches many lexical edge cases.

### Test categories

```text
valid numeric literals
invalid numeric literals
valid strings
invalid strings
long bracket levels
comments
keywords
identifier boundaries
```

### Acceptance criteria

```text
lexer unit tests pass
parse-stage differential smoke tests run
invalid lexical forms broadly agree with CLua load()
```

---

## Milestone 2: Parser

### Goal

Parse Lua 5.5 source into an AST.

### Implementation tasks

Statements:

```text
empty statement
assignment
local declaration
global declaration
function declaration
local function declaration
if
while
repeat
numeric for
generic for
break
goto
label
do block
return
function-call statement
```

Expressions:

```text
nil
boolean
integer
float
string
vararg
named vararg syntax
table constructor
function literal
prefix expression
index expression
method call
unary operators
binary operators
```

Lua 5.5 syntax to cover early:

```lua
global x
global<const> x
global *
global<const> *
function f(a, b, ... rest) end
```

### CLua-integrated tests

Every parser feature gets at least one syntax differential test.

Comparison mode:

```text
CLua: load(source)
zlua: parse(source)
```

Compare:

```text
success vs failure
diagnostic category where useful
```

Do not require identical error strings yet.

### Acceptance criteria

```text
all parser unit tests pass
AST snapshots are stable
syntax differential tests cover every statement and expression family
unexpected parse-stage failures are zero for implemented syntax
```

---

## Milestone 3: Scope resolver and declarations

### Goal

Resolve local/global/upvalue references and enforce Lua 5.5 declaration rules.

### Implementation tasks

```text
block scopes
local declarations
global declarations
global *
global<const> *
const locals
to-be-closed locals
read-only for-loop variables
named vararg binding
_ENV handling
upvalue discovery
goto validation
label validation
assignment target validation
```

### CLua-integrated tests

Add resolver-stage tests:

```text
CLua: load(source)
zlua: parse + resolve(source)
```

Test files:

```lua
-- feature: global-decl
global x
x = 1
print(x)
```

```lua
-- feature: const-local
local x<const> = 1
x = 2
```

```lua
-- feature: goto
goto label
local x = 1
::label::
```

### Acceptance criteria

```text
resolver rejects invalid const/global/goto cases
resolver accepts matching CLua-valid declaration cases
scope dump snapshots are stable
all implemented declaration features have differential tests
```

---

## Milestone 4: Bytecode format and compiler skeleton

### Goal

Compile parsed/resolved programs to internal bytecode.

### Implementation tasks

```text
Proto object
constant table
register allocator
instruction enum
jump patching
line info
local debug info
upvalue descriptors
disassembler
bytecode snapshot tests
```

### CLua-integrated tests

Add compile-stage tests:

```text
CLua: load(source)
zlua: parse + resolve + compile(source)
```

At this point, success/failure compatibility matters more than runtime output.

### Acceptance criteria

```text
simple chunks compile
bytecode disassembler works
compiler diagnostics are useful
compile-stage differential tests are wired into CI
```

---

## Milestone 5: Minimal VM

### Goal

Execute basic bytecode.

### Implementation tasks

```text
State init/deinit
Thread init/deinit
stack allocation
call frame allocation
instruction dispatch
constant loading
move
basic arithmetic
basic comparisons
jumps
return
native print
runtime error object
```

### CLua-integrated tests

Enable runtime-stage tests for:

```text
nil
booleans
integers
floats
strings
arithmetic
comparisons
if
while
repeat
basic print
basic return
```

Example:

```lua
-- expect: pass
-- stage: runtime
-- feature: arithmetic

print(1 + 2)
print(9 // 4)
print(2 ^ 8)
```

### Acceptance criteria

```text
zlua can execute tiny scripts
runtime differential tests run in CI
all completed VM opcodes have CLua comparisons
```

---

## Milestone 6: Strings and numbers

### Goal

Complete core scalar value behavior.

### Implementation tasks

```text
short string interning
long strings
string hashing
string equality
string concatenation
integer operations
float operations
integer/float coercion
number parsing
number formatting
tostring behavior groundwork
```

### CLua-integrated tests

Add runtime tests for:

```text
integer overflow cases
float formatting cases
hex numerals
string escapes
string concatenation
string equality
string table keys
numeric coercions
division/idiv/mod/pow
```

### Acceptance criteria

```text
scalar operations match CLua for covered cases
string keys work
numeric edge cases have expected failures or passes documented
```

---

## Milestone 7: Tables

### Goal

Implement Lua tables as the core aggregate type.

### Implementation tasks

```text
array part
hash part
integer keys
string keys
general keys
nil deletion
raw get
raw set
length operator
table constructor compilation
iteration primitives
metatable pointer
capacity hints
table.create
```

### CLua-integrated tests

Add runtime tests for:

```text
array constructors
hash constructors
mixed constructors
nil deletion
integer key normalization
string keys
table length
nested tables
table.create
pairs groundwork
ipairs groundwork
```

Important test metadata: table iteration order should be normalized or avoided unless order is specified.

### Acceptance criteria

```text
table indexing and assignment match CLua
constructors work
table-heavy differential tests pass
table length behavior is documented where representation-dependent
```

---

## Milestone 8: Functions and calls

### Goal

Support ordinary Lua function calls.

### Implementation tasks

```text
Lua function objects
native function objects
call frames
argument passing
return passing
method call syntax
recursive functions
stack growth
stack overflow detection
```

### CLua-integrated tests

Add runtime tests for:

```text
simple calls
nested calls
recursive calls
method calls
argument count adjustment
return count adjustment
calling non-functions
stack overflow behavior
```

### Acceptance criteria

```text
basic function behavior matches CLua
call frame cleanup is correct
errors during calls do not corrupt the stack
```

---

## Milestone 9: Multiple returns, varargs, and tail calls

### Goal

Implement Lua’s call/return adjustment rules.

### Implementation tasks

```text
multiple return adjustment
assignment adjustment
function argument adjustment
return statement adjustment
table constructor adjustment
vararg expression
named vararg table
tail call opcode
tail call frame replacement
```

### CLua-integrated tests

Add tests for:

```text
multiple returns in assignment
multiple returns in function arguments
multiple returns in table constructors
select
vararg forwarding
named vararg table behavior
tail recursion
tail call stack behavior
```

Example:

```lua
-- expect: pass
-- stage: runtime
-- feature: varargs

function f(a, ... rest)
  print(a)
  print(rest.n)
  print(rest[1])
end

f(10, 20, 30)
```

### Acceptance criteria

```text
multiple-return behavior matches CLua in covered contexts
named varargs work
tail calls do not grow the Lua stack unnecessarily
```

---

## Milestone 10: Closures and upvalues

### Goal

Support lexical closures.

### Implementation tasks

```text
upvalue descriptors
open upvalue list
closing upvalues
closed upvalue storage
closure allocation
nested functions
captured mutation
recursive local functions
```

### CLua-integrated tests

Add runtime tests for:

```text
simple closure capture
mutation through closure
multiple closures sharing one upvalue
closures outliving parent frame
recursive closures
nested upvalue capture
```

Example:

```lua
-- expect: pass
-- stage: runtime
-- feature: closures

local function make()
  local x = 0
  return function()
    x = x + 1
    return x
  end
end

local f = make()
print(f())
print(f())
```

### Acceptance criteria

```text
closure behavior matches CLua
open and closed upvalues survive GC stress smoke tests
```

---

## Milestone 11: Metatables and metamethods

### Goal

Implement Lua’s extensible object behavior.

### Implementation tasks

```text
metatable storage
metamethod lookup
metamethod cache flags
__index
__newindex
__call
__tostring
__len
__concat
__eq
__lt
__le
arithmetic metamethods
bitwise metamethods
__close
__gc
__mode
__name
```

### CLua-integrated tests

Add runtime tests for:

```text
operator metamethods
index chains
newindex chains
callable tables
locked metatables
metamethod errors
recursive metamethod limits
rawequal
rawget
rawset
rawlen
```

### Acceptance criteria

```text
metamethod dispatch matches CLua for covered cases
operator fallback behavior is correct
raw operations bypass metamethods
```

---

## Milestone 12: Errors and protected calls

### Goal

Make error handling robust and compatible.

### Implementation tasks

```text
Lua error values
error throwing
pcall
xpcall
tracebacks
error levels
stack unwinding
protected call restoration
errors inside metamethods
errors inside native functions
```

### CLua-integrated tests

Add runtime tests for:

```text
error
assert
pcall success
pcall failure
xpcall handler
error level
traceback shape
error in __index
error in __call
error during return cleanup
```

Normalize paths and some traceback formatting at first.

### Acceptance criteria

```text
protected calls restore VM state
success/failure status matches CLua
tracebacks are useful and increasingly compatible
```

---

## Milestone 13: To-be-closed variables

### Goal

Support scope-exit cleanup semantics.

### Implementation tasks

```text
<close> local variables
__close metamethod
normal return cleanup
break cleanup
goto cleanup
error unwind cleanup
coroutine interaction
multiple close variables
close error handling
```

### CLua-integrated tests

Add runtime tests for:

```text
scope exit
return exit
break exit
goto exit
error unwind
close ordering
close errors
yield restrictions if applicable
```

### Acceptance criteria

```text
close behavior matches CLua for covered cases
cleanup runs on all control-flow exits
errors during close are handled correctly
```

---

## Milestone 14: Coroutines

### Goal

Implement Lua coroutines.

### Implementation tasks

```text
ObjThread
independent Lua stacks
coroutine.create
coroutine.resume
coroutine.yield
coroutine.status
coroutine.running
coroutine.wrap
yield values
resume values
yield across Lua frames
yield restrictions across native frames
```

### CLua-integrated tests

Add runtime tests for:

```text
basic yield/resume
multiple yields
resume values
yield values
dead coroutine errors
coroutine.wrap errors
pcall inside coroutine
coroutine inside pcall
to-be-closed variables with coroutine behavior
```

### Acceptance criteria

```text
coroutine library matches CLua for covered cases
thread stacks are independent
yield/resume preserves call frames
```

---

## Milestone 15: Garbage collector, phase 1

### Goal

Implement a correct stop-the-world collector.

### Implementation tasks

```text
allocation registry
root marking
thread stack marking
call frame marking
global table marking
registry marking
string table marking
closure marking
upvalue marking
table marking
userdata marking
sweep
finalizer queue
allocator instrumentation
```

### CLua-integrated tests

CLua is not a perfect oracle for GC timing, so use two kinds of tests:

```text
behavioral differential tests
zlua-specific memory safety tests
```

Behavioral CLua tests:

```text
collectgarbage calls
__gc finalizer visibility
weak table visible behavior
object resurrection cases
```

zlua-specific tests:

```text
allocation stress
forced GC every allocation
leak checks
cycle collection
GC during table mutation
GC during closure allocation
```

### Acceptance criteria

```text
no leaks in zlua unit/stress tests
GC-visible behavior matches CLua where timing is not overly specific
all runtime differential tests pass with forced GC mode
```

---

## Milestone 16: Garbage collector, phase 2

### Goal

Move toward Lua 5.5-style incremental/generational behavior.

### Implementation tasks

```text
incremental marking
write barriers
gray lists
weak keys
weak values
ephemeron handling
incremental sweep
major collection pacing
generational mode skeleton
GC tuning parameters
```

### CLua-integrated tests

Add CLua comparison tests for:

```text
weak table behavior
ephemeron behavior
collectgarbage API
finalizer ordering where observable
GC mode API behavior
```

Keep internal collector pacing tests zlua-specific.

### Acceptance criteria

```text
barrier stress tests pass
weak table behavior matches CLua
incremental collector survives forced-step testing
```

---

## Milestone 17: Standard library, safe subset

### Goal

Implement libraries useful for embedded/sandboxed use.

### Libraries

```text
base
table
string
math
utf8
coroutine
```

### Implementation tasks

Base:

```text
assert
collectgarbage
error
getmetatable
ipairs
next
pairs
pcall
print
rawequal
rawget
rawlen
rawset
select
setmetatable
tonumber
tostring
type
warn
xpcall
_VERSION
```

Table:

```text
table.concat
table.insert
table.move
table.pack
table.remove
table.sort
table.unpack
table.create
```

String:

```text
string.byte
string.char
string.dump placeholder/unsupported if needed
string.find
string.format
string.gmatch
string.gsub
string.len
string.lower
string.match
string.pack
string.packsize
string.rep
string.reverse
string.sub
string.unpack
string.upper
```

Math and UTF-8:

```text
math.*
utf8.*
```

### CLua-integrated tests

Every standard library function gets differential tests:

```text
normal cases
argument validation
wrong type errors
boundary cases
large values
empty input
metatable interaction where relevant
```

### Acceptance criteria

```text
safe stdlib mode passes its differential test subset
unsupported functions are explicitly marked
argument errors increasingly match CLua
```

---

## Milestone 18: System libraries and Zig 0.16 I/O integration

### Goal

Implement host-facing libraries in a controlled way.

### Libraries

```text
io
os
package
debug
```

### Zig 0.16 design

Because Zig 0.16.0 requires I/O functionality to receive an `Io` instance, the runtime should not directly reach into process-global I/O. The host application or CLI should supply capabilities. ([Zig Programming Language][4])

### Implementation tasks

```text
StateOptions.io
StateOptions.filesystem
StateOptions.environment
StateOptions.clock
StateOptions.process
safe/full stdlib modes
fake I/O for tests
CLI I/O adapter
```

### CLua-integrated tests

Use three classes:

```text
portable CLua differential tests
host-specific CLua differential tests
zlua capability/sandbox tests
```

Test:

```text
loadfile
dofile
require
package.path
package.searchers
io.read
io.write
io.open
os.time
os.date
os.getenv
os.execute behavior where enabled
debug.getinfo
debug.traceback
```

### Acceptance criteria

```text
safe mode has no filesystem/process access
full mode behaves like CLua for portable tests
system-dependent deviations are documented
```

---

## Milestone 19: Official Lua 5.5 test suite integration

### Goal

Run the official Lua 5.5.0 test suite as a compatibility dashboard.

The official test suite page provides `lua-5.5.0-tests.tar.gz`, explains basic/complete/internal modes, and emphasizes running the exact Lua release under test. ([Lua][2])

### Implementation tasks

```text
vendor/download lua-5.5.0-tests.tar.gz
verify checksum
extract into tests/official
create zlua official-test runner
support basic mode
support complete mode
support internal mode later
map failures to feature tags
create official status report
```

### CLua-integrated tests

For official tests:

```text
CLua: run official suite as baseline
zlua: run same suite
compare suite-level result
track individual failures where possible
```

### Acceptance criteria

```text
official basic suite is runnable
official suite failures are categorized
README shows current official suite status
CI can run the full official suite under a memory cap
legacy heavy/quick command split is no longer needed for CI
```

---

## Milestone 20: CLI and REPL

### Goal

Provide a usable command-line interpreter.

### CLI commands

```text
zlua file.lua
zlua -e "code"
zlua -i
zlua -v
zlua --stdlib=none|base|safe|full
zlua --dump-ast file.lua
zlua --dump-scope file.lua
zlua --dump-bytecode file.lua
zlua --trace-vm file.lua
zlua test-diff
zlua test-official
```

### Implementation tasks

```text
arg table
script loading
-e execution
interactive mode
multiline REPL
expression echoing
diagnostics
exit codes
I/O wiring through std.Io
```

### CLua-integrated tests

Add CLI differential tests:

```text
-v
-e
script args
arg table
stdin execution
interactive smoke tests where practical
exit code behavior
```

### Acceptance criteria

```text
common lua5.5 CLI usage works
CLI behavior is covered by differential tests
REPL is usable
```

---

## Milestone 21: Zig-native embedding API

### Goal

Make zlua useful from Zig applications.

### API areas

```text
State lifecycle
library opening
chunk loading
function calling
value pushing
value reading
table construction
native callbacks
userdata
memory limits
instruction limits
I/O capabilities
sandbox configuration
```

### Example shape

```zig
var lua = try zlua.State.init(allocator, .{
    .stdlib = .safe,
    .limits = .{
        .max_memory = 64 * 1024 * 1024,
        .max_stack = 1024,
    },
    .io = io,
});
defer lua.deinit();

try lua.openLibs(.safe);
var host_log = try lua.register("host_log", hostLog);
defer host_log.deinit();
try lua.setGlobal("host_log", host_log);
try lua.doString("host_log('hello')");
```

### CLua-integrated tests

Embedding behavior should still reuse Lua files where possible:

```text
host registers native function
Lua calls native function
native function calls Lua callback
native function throws error
sandbox limits terminate script
custom I/O captures print output
```

CLua comparison is less direct here, but scripts executed through the embedding API should have equivalent behavior to CLua where host functions are mirrored.

### Acceptance criteria

```text
embedding examples compile
native callback behavior is tested
sandbox limits are tested
API docs exist
```

---

## Milestone 22: C API compatibility preview

### Goal

Expose a source-compatible C API shim over zlua.

### Implementation tasks

```text
lua_State type
lua_newstate
lua_close
lua_gettop
lua_settop
lua_push*
lua_to*
lua_type
lua_typename
lua_getglobal
lua_setglobal
lua_gettable
lua_settable
lua_pcall
lua_call
luaL_loadstring
luaL_loadfile
luaL_openlibs
registry
userdata basics
```

### CLua-integrated tests

Create C embedding tests that compile twice:

```text
once against CLua
once against zlua C API
```

Compare output.

Test categories:

```text
stack manipulation
push/to conversion
global access
table access
protected call
userdata basics
error handling
library opening
```

### Acceptance criteria

```text
small C embedding programs compile
C API stack effects are tested
unsupported C API functions are documented
no ABI compatibility promise yet
```

---

## Milestone 23: Binary chunks decision

### Goal

Decide whether zlua supports binary bytecode.

### Options

| Option             | Meaning                    |
| ------------------ | -------------------------- |
| Source only        | Load Lua source only              |
| zlua bytecode only | zlua-owned dump/load format       |
| PUC reader         | Load Lua 5.5 `luac` binary chunks |
| PUC writer         | Emit Lua 5.5 `luac` binary chunks |

### Recommendation

Final decision for v1.0:

```text
support source loading
support zlua bytecode export/import through string.dump, lua_dump, load, and lua_load
reject PUC Lua binary chunks cleanly
do not emit PUC Lua binary chunks
```

zlua binary chunks are a project-owned serialization of zlua prototypes. They are not a stable PUC Lua `luac` format and are only intended for zlua-to-zlua interchange.

### CLua-integrated tests

Binary chunk tests:

```text
zlua dump -> zlua load
zlua dump -> zlua load in a fresh State/process
PUC/foreign binary chunk -> clean rejection
```

### Acceptance criteria

```text
binary chunk support status is explicit
unsupported binary chunks fail cleanly
zlua bytecode round-trips without source recompilation
```

---

## Milestone 24: Performance and hardening

Detailed scope: [`docs/milestone-24-performance-hardening.md`](milestone-24-performance-hardening.md).

### Goal

Improve speed and reliability after compatibility is credible.

### Implementation tasks

```text
opcode dispatch optimization
packed instruction encoding
constant folding
register allocation improvements
string interning tuning
table resizing tuning
metamethod cache tuning
GC pacing tuning
allocation reduction
debug/release benchmark modes
```

### CLua-integrated tests

Keep all differential tests running under:

```text
debug
release-safe
release-fast
forced-GC
small-stack
small-memory
```

Add benchmarks comparing:

```text
zlua debug
zlua release
CLua 5.5
```

Benchmarks should not become compatibility gates.

### Acceptance criteria

```text
no performance work changes observable behavior
all differential tests pass after optimization
regressions are tracked by benchmark snapshots
```

---

# 7. Release plan

## v0.1: Oracle harness and frontend

### Features

```text
CLua runner
differential test harness
lexer
parser
AST dumps
parse-stage oracle comparisons
```

### Required test state

```text
parse-stage differential tests active
unexpected parse failures: 0 for implemented syntax
expected failures documented
```

---

## v0.2: Resolver and compiler skeleton

### Features

```text
scope resolver
global declarations
const checking
goto/label validation
bytecode format
disassembler
compile-stage oracle comparisons
```

### Required test state

```text
syntax tests pass
resolver tests pass
compile-stage differential tests active
```

---

## v0.3: Minimal runtime

### Features

```text
basic VM
scalars
arithmetic
control flow
simple functions
native print
runtime-stage oracle comparisons
```

### Required test state

```text
small runtime differential suite passes
all implemented opcodes have behavior tests
```

---

## v0.4: Tables, strings, and calls

### Features

```text
strings
tables
constructors
function calls
method calls
basic standard functions
```

### Required test state

```text
table/string/call differential tests pass
known holes documented as expected failures
```

---

## v0.5: Full function semantics

### Features

```text
closures
upvalues
multiple returns
varargs
named vararg tables
tail calls
```

### Required test state

```text
function semantics differential suite passes
Lua 5.5-specific vararg tests active
```

---

## v0.6: Metatables and protected errors

### Features

```text
metatables
metamethods
pcall
xpcall
tracebacks
to-be-closed variables
```

### Required test state

```text
metamethod/error differential tests pass
traceback differences documented
```

---

## v0.7: Coroutines and basic GC

### Features

```text
coroutines
stop-the-world GC
finalizers
weak table groundwork
```

### Required test state

```text
coroutine differential tests pass
forced-GC runtime tests pass
leak tests pass
```

---

## v0.8: Standard library safe mode

### Features

```text
base
table
string
math
utf8
coroutine
safe stdlib mode
```

### Required test state

```text
stdlib differential tests pass for safe subset
official basic suite begins running
```

---

## v0.9: Full stdlib and official suite

### Features

```text
io
os
package
debug
full stdlib mode
official Lua 5.5 test tracking
```

### Required test state

```text
official basic tests mostly or fully pass
official complete suite is categorized
```

---

## v1.0: Source-compatible Lua 5.5 runtime

### Features

```text
Lua 5.5 source compatibility
CLI
REPL
safe/full stdlib modes
Zig-native embedding API
documented compatibility table
official test status report
```

### Required test state

```text
unexpected differential failures: 0
official basic suite passes or deviations documented
official complete suite mostly passes or deviations documented
forced-GC test mode passes
allocator leak tests pass
```

---

# 8. Test suite design

## 8.1 Differential test directory

```text
tests/diff/
  syntax/
    literals.lua
    strings.lua
    comments.lua
    operators.lua

  declarations/
    locals.lua
    globals.lua
    const.lua
    close.lua
    goto.lua

  runtime/
    arithmetic.lua
    comparisons.lua
    control_flow.lua
    functions.lua
    returns.lua

  tables/
    constructors.lua
    indexing.lua
    length.lua
    iteration.lua
    table_create.lua

  functions/
    closures.lua
    upvalues.lua
    varargs.lua
    named_varargs.lua
    tailcalls.lua

  metatables/
    index.lua
    newindex.lua
    arithmetic.lua
    call.lua
    close.lua
    gc.lua

  stdlib/
    base.lua
    table.lua
    string.lua
    math.lua
    utf8.lua
    coroutine.lua
    debug.lua
    io.lua
    os.lua
    package.lua
```

## 8.2 Expected failure registry

```toml
[[failure]]
path = "tests/diff/coroutines/basic.lua"
stage = "runtime"
feature = "coroutine"
reason = "ObjThread not implemented"
issue = 123
```

## 8.3 Skip registry

```toml
[[skip]]
path = "tests/diff/stdlib/os_execute.lua"
reason = "host-specific process behavior"
platforms = ["windows", "wasi"]
```

## 8.4 Normalizer registry

```toml
[[normalizer]]
name = "traceback-paths"
pattern = "/[^\\s:]+/"
replacement = "@PATH@"
```

---

# 9. CI matrix

Run on every PR:

```text
zig build test
zlua test-diff --stage=parse
zlua test-diff --stage=compile
zlua test-diff --stage=runtime --quick
```

Run nightly or locally:

```text
zlua test-diff --all
zlua test-official --basic
zlua test-official --complete
zlua test-diff --forced-gc
zlua test-diff --small-stack
zlua test-diff --small-memory
```

Required invariant:

```text
unexpected failures: 0
new expected failures require a reason
new skipped tests require a reason
```

---

# 10. Compatibility tracking

Maintain `docs/compatibility.md`.

```text
Language syntax
Declarations
Functions
Closures
Varargs
Tables
Metatables
Coroutines
GC
Base library
Table library
String library
Math library
UTF-8 library
Coroutine library
Debug library
I/O library
OS library
Package library
C API
Binary chunks
```

Each section should include:

```text
status
implemented features
known deviations
differential test count
official test status
links to issues
```

Example:

| Area         |      Status |   Differential tests | Notes                                  |
| ------------ | ----------: | -------------------: | -------------------------------------- |
| lexer/parser |     partial |                  120 | expected failures for edge diagnostics |
| globals      |     partial |                   24 | `global<const> *` pending              |
| closures     | not started | 18 expected failures | planned v0.5                           |
| tables       |     partial |                   40 | iteration normalization active         |
| C API        | not started |                    0 | planned after v1 API stabilizes        |

---

# 11. Engineering guidelines

## 11.1 Implementation rule

No new feature merges without at least one CLua differential test unless it is purely internal.

Examples:

```text
new opcode -> runtime differential test
new parser rule -> parse differential test
new stdlib function -> stdlib differential test
new metamethod -> runtime differential test
new error case -> error differential test
```

## 11.2 Internal-only exceptions

Internal changes can use Zig-only tests:

```text
allocator behavior
GC mark bits
bytecode encoding
disassembler formatting
table resize internals
register allocator details
```

## 11.3 Debug tooling

Build early:

```text
--dump-tokens
--dump-ast
--dump-scope
--dump-bytecode
--trace-vm
--trace-gc
--trace-stack
```

## 11.4 Memory policy

```text
all allocations use explicit allocator
GC owns collectable objects
tests run with leak detection
forced-GC mode exists
allocation-failure tests exist
```

## 11.5 I/O policy

```text
State does not assume process-global I/O
CLI supplies I/O
embedding host supplies I/O
safe mode denies filesystem/process access
tests use fake I/O
```

---

# 12. Hard problems and test strategy

## 12.1 Multiple returns

Test every context:

```text
assignment
function arguments
return statements
table constructors
vararg forwarding
tail calls
```

## 12.2 Globals and declarations

Test:

```text
implicit chunk globals
global declarations
global *
global<const> *
local shadowing
_ENV interactions
assignment to undeclared globals
assignment to read-only globals
```

## 12.3 Upvalues

Test:

```text
open upvalue mutation
closed upvalue mutation
shared upvalues
nested captures
captures across loops
captures with to-be-closed locals
```

## 12.4 Metamethods

Test:

```text
raw vs non-raw access
recursive lookup
operator dispatch
missing metamethod behavior
error propagation
comparison fallbacks
```

## 12.5 GC

Test with both:

```text
CLua-visible behavior tests
zlua forced-GC stress tests
```

Run the same runtime suite in forced-GC mode to expose missing roots.

## 12.6 C API

Once started, every exported function gets:

```text
stack before
operation
stack after
error behavior
CLua comparison where practical
```

---

# 13. Definition of done

## v1.0 done

```text
zlua runs nontrivial Lua 5.5 source programs
CLua differential harness is mandatory in CI
unexpected differential failures are zero
official Lua 5.5 basic suite passes or all deviations are documented
official complete suite status is documented
Zig-native embedding API is stable enough for use
safe and full stdlib modes exist
forced-GC mode passes the runtime suite
allocator leak tests pass
CLI and REPL work
known incompatibilities are documented
```

## Not required for v1.0

```text
JIT
PUC binary chunk compatibility
ABI-compatible liblua replacement
LuaRocks support
dynamic native module loading
multi-version Lua support
```

The project shape is: **CLua first, tests always, implementation second**. Every milestone should leave behind executable proof that zlua either matches Lua 5.5 or explicitly documents the gap.

[1]: https://www.lua.org/download.html "Lua: download"
[2]: https://www.lua.org/tests/ "Lua: test suites"
[3]: https://ziglang.org/ "
      Home
      ⚡
      Zig Programming Language
    "
[4]: https://ziglang.org/download/0.16.0/release-notes.html?utm_source=chatgpt.com "0.16.0 Release Notes"
