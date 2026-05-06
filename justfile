set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

zig := "zig"
zlua := "zig-out/bin/zlua"
clua := "zig-out/bin/lua5.5"

# Show available commands.
default:
    @just --list

# Build zlua and the vendored Lua 5.5 oracle.
build:
    {{zig}} build

# Build with ReleaseSafe optimization.
release:
    {{zig}} build -Doptimize=ReleaseSafe

# Run all unit tests.
test:
    {{zig}} build --summary all test

# Run all CI checks.
ci:
    {{zig}} build ci

# Format Zig sources.
fmt:
    {{zig}} fmt build.zig src/*.zig src/testing/*.zig

# Run zlua through the Zig build runner.
run *args:
    {{zig}} build run -- {{args}}

# Print zlua version.
version:
    {{zig}} build run -- --version

# Print vendored CLua version.
clua-version: build
    {{clua}} -v

# Run the differential harness with the vendored CLua oracle.
diff *args:
    {{zig}} build --summary all run-test-diff -- --debug-errors {{args}}

# Run the official Lua 5.5 suite dashboard.
official *args:
    {{zig}} build --summary all run-test-official -- --debug-errors --memory-limit-mb=256 {{args}}

# Run one official Lua 5.5 test file by name, e.g. `just official-file attrib`.
official-file name *args:
    {{zig}} build --summary all
    file="{{name}}"; if [[ "$file" != *.lua ]]; then file="$file.lua"; fi; cd tests/official/lua-5.5.0-tests; ../../../{{zlua}} --debug-errors -e "_U=true; _soft=true; _port=true; _nomsg=true; T=nil; ARG=arg" "$file" {{args}}

# Remove build outputs and Zig cache directories.
clean:
    rm -rf zig-out .zig-cache
