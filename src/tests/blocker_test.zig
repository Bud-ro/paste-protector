const std = @import("std");
const Config = @import("../config.zig").Config;
const Blocker = @import("../core/blocker.zig").Blocker;

const T0: i128 = 1_000_000_000_000;
const MS = std.time.ns_per_ms;

test "initial state" {
    var b = Blocker.init(std.testing.allocator, Config{});
    defer b.deinit();
    try std.testing.expectEqual(.idle, b.state);
    try std.testing.expect(!b.isPasteBlocked());
    try std.testing.expect(b.tick(T0) == null);
}

test "copy transitions to allowing" {
    var b = Blocker.init(std.testing.allocator, Config{});
    defer b.deinit();
    b.onCopyDetected("hello", T0);
    try std.testing.expectEqual(.allowing, b.state);
    try std.testing.expect(!b.isPasteBlocked());
}

test "saves and returns content" {
    var b = Blocker.init(std.testing.allocator, Config{});
    defer b.deinit();
    b.onCopyDetected("secret", T0);
    try std.testing.expectEqualStrings("secret", b.getSavedContent().?);
}

test "null content" {
    var b = Blocker.init(std.testing.allocator, Config{});
    defer b.deinit();
    b.onCopyDetected(null, T0);
    try std.testing.expectEqual(.allowing, b.state);
    try std.testing.expect(b.getSavedContent() == null);
}

test "tick before duration returns null" {
    var b = Blocker.init(std.testing.allocator, Config{});
    defer b.deinit();
    b.onCopyDetected("x", T0);
    try std.testing.expect(b.tick(T0 + 2999 * MS) == null);
    try std.testing.expectEqual(.allowing, b.state);
}

test "tick at duration transitions to blocking" {
    var b = Blocker.init(std.testing.allocator, Config{});
    defer b.deinit();
    b.onCopyDetected("x", T0);
    try std.testing.expect(b.tick(T0 + 3000 * MS) != null);
    try std.testing.expectEqual(.blocking, b.state);
    try std.testing.expect(b.isPasteBlocked());
}

test "tick only fires once" {
    var b = Blocker.init(std.testing.allocator, Config{});
    defer b.deinit();
    b.onCopyDetected("x", T0);
    try std.testing.expect(b.tick(T0 + 5000 * MS) != null);
    try std.testing.expect(b.tick(T0 + 5001 * MS) == null);
    try std.testing.expect(b.tick(T0 + 9999 * MS) == null);
}

test "override key restarts allow window" {
    var b = Blocker.init(std.testing.allocator, Config{});
    defer b.deinit();
    b.onCopyDetected("password", T0);
    _ = b.tick(T0 + 5000 * MS);
    try std.testing.expect(b.isPasteBlocked());

    try std.testing.expect(b.onOverrideKey(T0 + 6000 * MS));
    try std.testing.expectEqual(.allowing, b.state);
    try std.testing.expectEqualStrings("password", b.getSavedContent().?);

    // Timer runs again from override time
    try std.testing.expect(b.tick(T0 + 8999 * MS) == null);
    try std.testing.expect(b.tick(T0 + 9000 * MS) != null);
    try std.testing.expect(b.isPasteBlocked());
}

test "override does nothing when not blocked" {
    var b = Blocker.init(std.testing.allocator, Config{});
    defer b.deinit();
    try std.testing.expect(!b.onOverrideKey(T0));

    b.onCopyDetected("x", T0);
    try std.testing.expect(!b.onOverrideKey(T0));
}

test "re-copy resets timer" {
    var b = Blocker.init(std.testing.allocator, Config{});
    defer b.deinit();
    b.onCopyDetected("first", T0);
    b.onCopyDetected("second", T0 + 2000 * MS);

    try std.testing.expect(b.tick(T0 + 4999 * MS) == null);
    try std.testing.expectEqual(.allowing, b.state);
    try std.testing.expectEqualStrings("second", b.getSavedContent().?);

    try std.testing.expect(b.tick(T0 + 5000 * MS) != null);
    try std.testing.expectEqual(.blocking, b.state);
}

test "paste resets timer" {
    var b = Blocker.init(std.testing.allocator, Config{});
    defer b.deinit();
    b.onCopyDetected("x", T0);
    b.onPasteAttempted(T0 + 2000 * MS);

    try std.testing.expect(b.tick(T0 + 4999 * MS) == null);
    try std.testing.expect(b.tick(T0 + 5000 * MS) != null);
}

test "paste does not reset when blocked" {
    var b = Blocker.init(std.testing.allocator, Config{});
    defer b.deinit();
    b.onCopyDetected("x", T0);
    _ = b.tick(T0 + 5000 * MS);
    try std.testing.expectEqual(.blocking, b.state);

    b.onPasteAttempted(T0 + 6000 * MS);
    try std.testing.expectEqual(.blocking, b.state);
}

test "setDuration" {
    var b = Blocker.init(std.testing.allocator, Config{});
    defer b.deinit();
    b.setDuration(100);
    b.onCopyDetected("x", T0);
    try std.testing.expect(b.tick(T0 + 99 * MS) == null);
    try std.testing.expect(b.tick(T0 + 100 * MS) != null);
}

test "clearAndIdle" {
    var b = Blocker.init(std.testing.allocator, Config{});
    defer b.deinit();
    b.onCopyDetected("data", T0);
    b.clearAndIdle();
    try std.testing.expectEqual(.idle, b.state);
    try std.testing.expect(b.getSavedContent() == null);
}


test "full lifecycle" {
    var b = Blocker.init(std.testing.allocator, Config{});
    defer b.deinit();

    b.onCopyDetected("sensitive", T0);
    try std.testing.expectEqual(.allowing, b.state);

    try std.testing.expect(b.tick(T0 + 1000 * MS) == null);

    try std.testing.expect(b.tick(T0 + 3000 * MS) != null);
    try std.testing.expect(b.isPasteBlocked());

    try std.testing.expect(b.onOverrideKey(T0 + 4000 * MS));
    try std.testing.expectEqual(.allowing, b.state);
    try std.testing.expectEqualStrings("sensitive", b.getSavedContent().?);

    b.onCopyDetected("new", T0 + 5000 * MS);
    try std.testing.expectEqual(.allowing, b.state);
}

test "copy after block resets to allowing" {
    var b = Blocker.init(std.testing.allocator, Config{});
    defer b.deinit();
    b.onCopyDetected("first", T0);
    _ = b.tick(T0 + 5000 * MS);
    try std.testing.expectEqual(.blocking, b.state);

    b.onCopyDetected("second", T0 + 6000 * MS);
    try std.testing.expectEqual(.allowing, b.state);
    try std.testing.expect(!b.isPasteBlocked());
}
