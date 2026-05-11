const std = @import("std");
const render = @import("../render.zig");

test "produces visible pixels" {
    var pixels: [96 * 96 * 4]u8 = undefined;
    render.renderNotification(&pixels, 96, 1.0, .copied);

    var has_nonzero = false;
    for (pixels[0 .. 96 * 96 * 4]) |b| {
        if (b > 200) { has_nonzero = true; break; }
    }
    try std.testing.expect(has_nonzero);
}

test "zero alpha produces zero alpha channel" {
    var pixels: [48 * 48 * 4]u8 = undefined;
    render.renderNotification(&pixels, 48, 0.0, .copied);
    for (0..48) |y| {
        for (0..48) |x| {
            try std.testing.expectEqual(0, pixels[(y * 48 + x) * 4 + 3]);
        }
    }
}

test "different kinds produce different output" {
    var p1: [96 * 96 * 4]u8 = undefined;
    var p2: [96 * 96 * 4]u8 = undefined;
    render.renderNotification(&p1, 96, 1.0, .copied);
    render.renderNotification(&p2, 96, 1.0, .override_hint);
    try std.testing.expect(!std.mem.eql(u8, &p1, &p2));
}

test "scaled output has more filled pixels" {
    var p1: [48 * 48 * 4]u8 = undefined;
    var p2: [96 * 96 * 4]u8 = undefined;
    render.renderNotification(&p1, 48, 1.0, .copied);
    render.renderNotification(&p2, 96, 1.0, .copied);

    var c1: u32 = 0;
    var c2: u32 = 0;
    for (0 .. 48 * 48) |i| { if (p1[i * 4 + 3] > 200) c1 += 1; }
    for (0 .. 96 * 96) |i| { if (p2[i * 4 + 3] > 200) c2 += 1; }
    try std.testing.expect(c2 > c1 * 2);
}

test "half alpha produces lower alpha values" {
    var p_full: [96 * 96 * 4]u8 = undefined;
    var p_half: [96 * 96 * 4]u8 = undefined;
    render.renderNotification(&p_full, 96, 1.0, .copied);
    render.renderNotification(&p_half, 96, 0.5, .copied);

    var max_full: u8 = 0;
    var max_half: u8 = 0;
    for (0 .. 96 * 96) |i| {
        max_full = @max(max_full, p_full[i * 4 + 3]);
        max_half = @max(max_half, p_half[i * 4 + 3]);
    }
    try std.testing.expect(max_half < max_full);
}

test "all scales render without crash" {
    var buf: [192 * 192 * 4]u8 = undefined;
    inline for (.{ 48, 72, 96, 144, 192 }) |s| {
        render.renderNotification(&buf, s, 0.8, .copied);
        render.renderNotification(&buf, s, 0.8, .override_hint);
    }
}
