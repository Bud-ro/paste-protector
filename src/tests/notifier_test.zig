const std = @import("std");
const Config = @import("../config.zig").Config;
const Notifier = @import("../core/notifier.zig").Notifier;

const T0: i128 = 1_000_000_000_000;
const MS = std.time.ns_per_ms;

test "initial state" {
    const n = Notifier.init(Config{});
    try std.testing.expect(!n.isActive());
}

test "spawn activates" {
    var n = Notifier.init(Config{});
    n.spawn(.copied, T0);
    try std.testing.expect(n.isActive());
}

test "tick returns state" {
    var n = Notifier.init(Config{});
    n.spawn(.copied, T0);
    const state = n.tick(T0).?;
    try std.testing.expectEqual(.copied, state.kind);
    try std.testing.expect(state.alpha > 0);
}

test "spawn stacks same-kind notifications" {
    var n = Notifier.init(Config{});
    n.spawn(.copied, T0);
    n.spawn(.copied, T0 + 100 * MS);
    n.spawn(.copied, T0 + 200 * MS);
    var entries: [8]?Notifier.StackEntry = undefined;
    const count = n.tickAll(T0 + 200 * MS, &entries);
    try std.testing.expectEqual(3, count);
}

test "spawn different kind clears previous" {
    var n = Notifier.init(Config{});
    n.spawn(.copied, T0);
    n.spawn(.override_hint, T0 + 100 * MS);
    var entries: [8]?Notifier.StackEntry = undefined;
    const count = n.tickAll(T0 + 100 * MS, &entries);
    try std.testing.expectEqual(1, count);
}

test "expires after duration" {
    var n = Notifier.init(Config{});
    n.spawn(.copied, T0);
    try std.testing.expect(n.tick(T0 + 2399 * MS) != null);
    try std.testing.expect(n.tick(T0 + 2400 * MS) == null);
    try std.testing.expect(!n.isActive());
}

test "alpha decreases over time" {
    var n = Notifier.init(Config{});
    n.spawn(.copied, T0);
    const early = n.tick(T0 + 100 * MS).?.alpha;
    const late = n.tick(T0 + 800 * MS).?.alpha;
    try std.testing.expect(late < early);
}

test "y_offset moves over time" {
    var n = Notifier.init(Config{});
    n.spawn(.copied, T0);
    const early = n.tick(T0 + 100 * MS).?.y_offset;
    const late = n.tick(T0 + 800 * MS).?.y_offset;
    try std.testing.expect(late < early);
}

test "alpha at start is near 1.0" {
    var n = Notifier.init(Config{});
    n.spawn(.copied, T0);
    const state = n.tick(T0).?;
    try std.testing.expect(state.alpha >= 0.99 and state.alpha <= 1.01);
}

test "y_offset at start is near 0" {
    var n = Notifier.init(Config{});
    n.spawn(.copied, T0);
    const state = n.tick(T0).?;
    try std.testing.expect(state.y_offset > -1.0 and state.y_offset <= 0.0);
}

test "custom duration" {
    var config = Config{};
    config.notif_duration_ms = 500;
    var n = Notifier.init(config);
    n.spawn(.copied, T0);
    try std.testing.expect(n.tick(T0 + 499 * MS) != null);
    try std.testing.expect(n.tick(T0 + 500 * MS) == null);
}

test "tick returns null when inactive" {
    var n = Notifier.init(Config{});
    try std.testing.expect(n.tick(T0) == null);
}

test "spawn after expiry works" {
    var config = Config{};
    config.notif_duration_ms = 100;
    var n = Notifier.init(config);

    n.spawn(.copied, T0);
    try std.testing.expect(n.tick(T0 + 200 * MS) == null);
    try std.testing.expect(!n.isActive());

    n.spawn(.override_hint, T0 + 300 * MS);
    try std.testing.expect(n.isActive());
    try std.testing.expectEqual(.override_hint, n.tick(T0 + 300 * MS).?.kind);
}
