pub const clua = @import("testing/clua.zig");
pub const bench_runner = @import("testing/bench_runner.zig");
pub const c_api_runner = @import("testing/c_api_runner.zig");
pub const diff_runner = @import("testing/diff_runner.zig");
pub const extension_runner = @import("testing/extension_runner.zig");
pub const expected_failures = @import("testing/expected_failures.zig");
pub const metadata = @import("testing/metadata.zig");
pub const normalizer = @import("testing/normalizer.zig");
pub const official_suite = @import("testing/official_suite.zig");
pub const process = @import("testing/process.zig");

test {
    _ = clua;
    _ = bench_runner;
    _ = c_api_runner;
    _ = diff_runner;
    _ = extension_runner;
    _ = expected_failures;
    _ = metadata;
    _ = normalizer;
    _ = official_suite;
    _ = process;
}
