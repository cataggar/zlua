set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

zig := "zig"
zlua := "zig-out/bin/zlua"
clua := "zig-out/bin/lua5.5"

# Show available commands.
default:
    @just --list

# Build zlua and the downloaded Lua 5.5 oracle.
build:
    {{zig}} build

docs:
    {{zig}} build docs

docs-serve: docs
    {{zig}} build docs-serve

docs-serve-pub: docs
    {{zig}} build docs-serve -- 0.0.0.0

# Download and extract Lua 5.5 source and official tests.
fetch-lua:
    {{zig}} build fetch-lua

# Build with ReleaseSafe optimization.
release:
    {{zig}} build -Doptimize=ReleaseSafe

# Run all unit tests.
test:
    {{zig}} build --summary all test

# Run all CI checks.
ci:
    {{zig}} build ci

# Run all embedding examples, or selected examples by file name.
example *args:
    {{zig}} build run-example -- {{args}}

# Format Zig sources.
fmt:
    {{zig}} fmt build.zig src/*.zig src/testing/*.zig examples/*.zig

# Run zlua through the Zig build runner.
run *args:
    {{zig}} build run -- {{args}}

# Print zlua version.
version:
    {{zig}} build run -- --version

# Print downloaded CLua version.
clua-version: build
    {{clua}} -v

# Run the differential harness with the downloaded CLua oracle.
diff *args:
    {{zig}} build --summary all run-test-diff -- --debug-errors {{args}}

# Run all official Lua 5.5 files, or selected files by name.
official *args:
    {{zig}} build --summary all run-test-official -- --debug-errors --memory-limit-mb=256 {{args}}

# Run all C API fixtures, or one fixture file/directory.
c-api *args:
    {{zig}} build --summary all test-c-api -- {{args}}

# Run ReleaseFast zlua vs CLua benchmarks, or one benchmark file/directory.
bench *args:
    {{zig}} build -Doptimize=ReleaseFast --summary all run-test-bench -- {{args}}

# Remove build outputs and Zig cache directories.
clean:
    rm -rf zig-out .zig-cache
