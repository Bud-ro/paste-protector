const std = @import("std");
const config_mod = @import("../config.zig");
const Config = config_mod.Config;
const OverrideKey = config_mod.OverrideKey;
const NotifPosition = config_mod.NotifPosition;
const NotifScale = config_mod.NotifScale;

test "defaults" {
    const c = Config{};
    try std.testing.expectEqual(3000, c.block_duration_ms);
    try std.testing.expectEqual(.right_ctrl, c.override_key);
    try std.testing.expectEqual(.bottom_right, c.notif_position);
    try std.testing.expectEqual(1200, c.notif_duration_ms);
    try std.testing.expect(c.notif_enabled);
    try std.testing.expect(c.block_enabled);
    try std.testing.expect(c.paste_resets_timer);
    try std.testing.expectEqual(.x2, c.notif_scale);
}

test "parse all fields" {
    const c = Config.parseForTest(
        \\block_duration_ms = 5000
        \\override_key = "RightAlt"
        \\notif_position = "top-left"
        \\notif_duration_ms = 2000
        \\notif_enabled = false
        \\block_enabled = false
        \\paste_resets_timer = false
        \\notif_scale = "3"
    );
    try std.testing.expectEqual(5000, c.block_duration_ms);
    try std.testing.expectEqual(.right_alt, c.override_key);
    try std.testing.expectEqual(.top_left, c.notif_position);
    try std.testing.expectEqual(2000, c.notif_duration_ms);
    try std.testing.expect(!c.notif_enabled);
    try std.testing.expect(!c.block_enabled);
    try std.testing.expect(!c.paste_resets_timer);
    try std.testing.expectEqual(.x3, c.notif_scale);
}

test "comments and sections ignored" {
    const c = Config.parseForTest(
        \\# comment
        \\[section]
        \\block_duration_ms = 1000
    );
    try std.testing.expectEqual(1000, c.block_duration_ms);
}

test "invalid values fall back to defaults" {
    const c = Config.parseForTest(
        \\block_duration_ms = not_a_number
        \\override_key = "BogusKey"
        \\notif_position = "nowhere"
    );
    try std.testing.expectEqual(3000, c.block_duration_ms);
    try std.testing.expectEqual(.right_ctrl, c.override_key);
    try std.testing.expectEqual(.bottom_right, c.notif_position);
}

test "empty input" {
    const c = Config.parseForTest("");
    try std.testing.expectEqual(3000, c.block_duration_ms);
}

test "whitespace handling" {
    const c = Config.parseForTest("  block_duration_ms  =  1500  ");
    try std.testing.expectEqual(1500, c.block_duration_ms);
}

test "quoted and unquoted values" {
    try std.testing.expectEqual(.right_shift, Config.parseForTest("override_key = \"RightShift\"").override_key);
    try std.testing.expectEqual(.right_shift, Config.parseForTest("override_key = RightShift").override_key);
}

test "all override keys" {
    inline for (.{
        .{ "RightCtrl", OverrideKey.right_ctrl },
        .{ "RightAlt", OverrideKey.right_alt },
        .{ "RightShift", OverrideKey.right_shift },
        .{ "F12", OverrideKey.f12 },
    }) |pair| {
        try std.testing.expectEqual(pair[1], Config.parseForTest("override_key = " ++ pair[0]).override_key);
    }
}

test "all positions" {
    inline for (.{
        .{ "top-left", NotifPosition.top_left },
        .{ "top-right", NotifPosition.top_right },
        .{ "bottom-left", NotifPosition.bottom_left },
        .{ "bottom-right", NotifPosition.bottom_right },
    }) |pair| {
        try std.testing.expectEqual(pair[1], Config.parseForTest("notif_position = " ++ pair[0]).notif_position);
    }
}

test "all scales" {
    inline for (.{
        .{ "1", NotifScale.x1 },
        .{ "1.5", NotifScale.x1_5 },
        .{ "3", NotifScale.x3 },
        .{ "4", NotifScale.x4 },
    }) |pair| {
        try std.testing.expectEqual(pair[1], Config.parseForTest("notif_scale = " ++ pair[0]).notif_scale);
    }
}

test "scale dimensions" {
    try std.testing.expectEqual(48, NotifScale.x1.size());
    try std.testing.expectEqual(72, NotifScale.x1_5.size());
    try std.testing.expectEqual(96, NotifScale.x2.size());
    try std.testing.expectEqual(144, NotifScale.x3.size());
    try std.testing.expectEqual(192, NotifScale.x4.size());
}

test "pathological input" {
    const cases = [_][]const u8{
        "",
        "\n\n\n",
        "=",
        "===",
        "key=",
        "=value",
        "block_duration_ms = 0",
        "block_duration_ms = 4294967295",
        "block_duration_ms = -1",
    };
    for (cases) |input| {
        _ = Config.parseForTest(input);
    }
}

test "lines without equals sign ignored" {
    const c = Config.parseForTest("this has no equals sign\nblock_duration_ms = 999");
    try std.testing.expectEqual(999, c.block_duration_ms);
}

test "duplicate keys last wins" {
    const c = Config.parseForTest("block_duration_ms = 111\nblock_duration_ms = 222");
    try std.testing.expectEqual(222, c.block_duration_ms);
}

test "unknown keys ignored" {
    const c = Config.parseForTest("totally_unknown = 42\nblock_duration_ms = 500");
    try std.testing.expectEqual(500, c.block_duration_ms);
}

test "boolean edge cases" {
    const c1 = Config.parseForTest("notif_enabled = true");
    try std.testing.expect(c1.notif_enabled);

    const c2 = Config.parseForTest("notif_enabled = false");
    try std.testing.expect(!c2.notif_enabled);

    const c3 = Config.parseForTest("notif_enabled = TRUE");
    try std.testing.expect(!c3.notif_enabled);

    const c4 = Config.parseForTest("notif_enabled = 1");
    try std.testing.expect(!c4.notif_enabled);
}

test "scale factor values" {
    try std.testing.expectEqual(@as(f32, 1.0), NotifScale.x1.factor());
    try std.testing.expectEqual(@as(f32, 1.5), NotifScale.x1_5.factor());
    try std.testing.expectEqual(@as(f32, 2.0), NotifScale.x2.factor());
    try std.testing.expectEqual(@as(f32, 3.0), NotifScale.x3.factor());
    try std.testing.expectEqual(@as(f32, 4.0), NotifScale.x4.factor());
}
