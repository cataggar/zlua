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
    {{zig}} build test

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
    {{zig}} build run -- test-diff --clua {{clua}} {{args}}

# Run parse-stage differential tests.
diff-parse *args:
    just diff --stage=parse {{args}}

# Run runtime-stage differential tests.
diff-runtime *args:
    just diff --stage=runtime {{args}}

# Run differential tests for one feature.
diff-feature feature *args:
    just diff --feature={{feature}} {{args}}

# Run a single differential fixture.
diff-file file *args:
    just diff {{file}} {{args}}

# Run the build-system differential step exactly as CI does.
diff-ci:
    {{zig}} build test-diff

# Run the official Lua 5.5 suite dashboard exactly as CI does.
official-ci:
    {{zig}} build test-official

# Run the official Lua 5.5 suite dashboard.
official *args:
    {{zig}} build run -- test-official --clua {{clua}} {{args}}

# Run the official basic suite dashboard.
official-basic *args:
    just official --mode=basic {{args}}

# Run the official complete suite dashboard.
official-complete *args:
    just official --mode=complete {{args}}

# Remove build outputs and Zig cache directories.
clean:
    rm -rf zig-out .zig-cache
