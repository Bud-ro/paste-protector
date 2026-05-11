const builtin = @import("builtin");

comptime {
    _ = @import("tests/config_test.zig");
    _ = @import("tests/config_fuzz.zig");
    _ = @import("tests/blocker_test.zig");
    _ = @import("tests/notifier_test.zig");
    _ = @import("tests/render_test.zig");
    if (builtin.os.tag == .windows) {
        _ = @import("tests/windows_test.zig");
    }
}
