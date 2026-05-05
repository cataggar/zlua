pub const clua = @import("testing/clua.zig");
pub const diff_runner = @import("testing/diff_runner.zig");
pub const expected_failures = @import("testing/expected_failures.zig");
pub const metadata = @import("testing/metadata.zig");
pub const normalizer = @import("testing/normalizer.zig");
pub const process = @import("testing/process.zig");

test {
    _ = clua;
    _ = diff_runner;
    _ = expected_failures;
    _ = metadata;
    _ = normalizer;
    _ = process;
}
