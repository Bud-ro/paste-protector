const std = @import("std");
const config_mod = @import("../config.zig");
const Config = config_mod.Config;
const OverrideKey = config_mod.OverrideKey;
const NotifPosition = config_mod.NotifPosition;
const NotifScale = config_mod.NotifScale;
const MonitorMode = config_mod.MonitorMode;

test "defaults" {
    const c = Config{};
    try std.testing.expectEqual(5000, c.block_duration_ms);
    try std.testing.expectEqual(.right_ctrl, c.override_key);
    try std.testing.expectEqual(.bottom_right, c.notif_position);
    try std.testing.expectEqual(2400, c.notif_duration_ms);
    try std.testing.expect(c.notif_copy);
    try std.testing.expect(c.notif_blocked);
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
        \\notif_copy = false
        \\notif_blocked = false
        \\block_enabled = false
        \\paste_resets_timer = false
        \\notif_scale = "3"
    );
    try std.testing.expectEqual(5000, c.block_duration_ms);
    try std.testing.expectEqual(.right_alt, c.override_key);
    try std.testing.expectEqual(.top_left, c.notif_position);
    try std.testing.expectEqual(2000, c.notif_duration_ms);
    try std.testing.expect(!c.notif_copy);
    try std.testing.expect(!c.notif_blocked);
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
    try std.testing.expectEqual(5000, c.block_duration_ms);
    try std.testing.expectEqual(.right_ctrl, c.override_key);
    try std.testing.expectEqual(.bottom_right, c.notif_position);
}

test "empty input" {
    const c = Config.parseForTest("");
    try std.testing.expectEqual(5000, c.block_duration_ms);
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
    try std.testing.expect(c1.notif_copy);
    try std.testing.expect(c1.notif_blocked);

    const c2 = Config.parseForTest("notif_enabled = false");
    try std.testing.expect(!c2.notif_copy);
    try std.testing.expect(!c2.notif_blocked);

    const c3 = Config.parseForTest("notif_copy = true\nnotif_blocked = false");
    try std.testing.expect(c3.notif_copy);
    try std.testing.expect(!c3.notif_blocked);

    const c4 = Config.parseForTest("notif_enabled = 1");
    try std.testing.expect(!c4.notif_copy);
}

test "scale factor values" {
    try std.testing.expectEqual(@as(f32, 1.0), NotifScale.x1.factor());
    try std.testing.expectEqual(@as(f32, 1.5), NotifScale.x1_5.factor());
    try std.testing.expectEqual(@as(f32, 2.0), NotifScale.x2.factor());
    try std.testing.expectEqual(@as(f32, 3.0), NotifScale.x3.factor());
    try std.testing.expectEqual(@as(f32, 4.0), NotifScale.x4.factor());
}

test "notif_monitor defaults" {
    const c = Config{};
    try std.testing.expectEqual(.current_screen, c.notif_monitor);
}

test "notif_monitor parsing" {
    inline for (.{
        .{ "current", MonitorMode.current_screen },
        .{ "primary", MonitorMode.primary },
        .{ "1", MonitorMode.monitor_1 },
        .{ "2", MonitorMode.monitor_2 },
        .{ "3", MonitorMode.monitor_3 },
        .{ "4", MonitorMode.monitor_4 },
    }) |pair| {
        try std.testing.expectEqual(pair[1], Config.parseForTest("notif_monitor = " ++ pair[0]).notif_monitor);
    }
}

test "notif_monitor invalid falls back to current_screen" {
    const c = Config.parseForTest("notif_monitor = \"bogus\"");
    try std.testing.expectEqual(.current_screen, c.notif_monitor);
}

test "formatToml produces valid TOML" {
    const config = Config{};
    var buf: [1024]u8 = undefined;
    const len = config_mod.formatToml(config, &buf);
    try std.testing.expect(len > 0);

    // Verify the output contains expected keys
    const output = buf[0..len];
    try std.testing.expect(std.mem.indexOf(u8, output, "block_duration_ms = 5000") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "override_key = \"RightCtrl\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "notif_position = \"bottom-right\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "notif_copy = true") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "notif_blocked = true") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "notif_scale = \"2\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "block_enabled = true") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "paste_resets_timer = true") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "notif_monitor = \"current\"") != null);
}

test "formatToml roundtrip default config" {
    const original = Config{};
    var buf: [1024]u8 = undefined;
    const len = config_mod.formatToml(original, &buf);
    const parsed = Config.parseForTest(buf[0..len]);

    try std.testing.expectEqual(original.block_duration_ms, parsed.block_duration_ms);
    try std.testing.expectEqual(original.override_key, parsed.override_key);
    try std.testing.expectEqual(original.notif_position, parsed.notif_position);
    try std.testing.expectEqual(original.notif_duration_ms, parsed.notif_duration_ms);
    try std.testing.expectEqual(original.notif_copy, parsed.notif_copy);
    try std.testing.expectEqual(original.notif_blocked, parsed.notif_blocked);
    try std.testing.expectEqual(original.notif_scale, parsed.notif_scale);
    try std.testing.expectEqual(original.block_enabled, parsed.block_enabled);
    try std.testing.expectEqual(original.paste_resets_timer, parsed.paste_resets_timer);
    try std.testing.expectEqual(original.notif_monitor, parsed.notif_monitor);
}

test "formatToml roundtrip non-default config" {
    const original = Config{
        .block_duration_ms = 7777,
        .override_key = .f12,
        .notif_position = .top_left,
        .notif_duration_ms = 1234,
        .notif_copy = false,
        .notif_blocked = false,
        .notif_scale = .x1_5,
        .block_enabled = false,
        .paste_resets_timer = false,
        .notif_monitor = .monitor_3,
    };
    var buf: [1024]u8 = undefined;
    const len = config_mod.formatToml(original, &buf);
    const parsed = Config.parseForTest(buf[0..len]);

    try std.testing.expectEqual(original.block_duration_ms, parsed.block_duration_ms);
    try std.testing.expectEqual(original.override_key, parsed.override_key);
    try std.testing.expectEqual(original.notif_position, parsed.notif_position);
    try std.testing.expectEqual(original.notif_duration_ms, parsed.notif_duration_ms);
    try std.testing.expectEqual(original.notif_copy, parsed.notif_copy);
    try std.testing.expectEqual(original.notif_blocked, parsed.notif_blocked);
    try std.testing.expectEqual(original.notif_scale, parsed.notif_scale);
    try std.testing.expectEqual(original.block_enabled, parsed.block_enabled);
    try std.testing.expectEqual(original.paste_resets_timer, parsed.paste_resets_timer);
    try std.testing.expectEqual(original.notif_monitor, parsed.notif_monitor);
}

test "formatToml roundtrip all enum combinations" {
    // Test all override keys
    inline for (.{ OverrideKey.right_ctrl, OverrideKey.right_alt, OverrideKey.right_shift, OverrideKey.f12 }) |key| {
        var c = Config{};
        c.override_key = key;
        var buf: [1024]u8 = undefined;
        const len = config_mod.formatToml(c, &buf);
        const parsed = Config.parseForTest(buf[0..len]);
        try std.testing.expectEqual(key, parsed.override_key);
    }

    // Test all positions
    inline for (.{ NotifPosition.top_left, NotifPosition.top_right, NotifPosition.bottom_left, NotifPosition.bottom_right }) |pos| {
        var c = Config{};
        c.notif_position = pos;
        var buf: [1024]u8 = undefined;
        const len = config_mod.formatToml(c, &buf);
        const parsed = Config.parseForTest(buf[0..len]);
        try std.testing.expectEqual(pos, parsed.notif_position);
    }

    // Test all scales
    inline for (.{ NotifScale.x1, NotifScale.x1_5, NotifScale.x2, NotifScale.x3, NotifScale.x4 }) |scale| {
        var c = Config{};
        c.notif_scale = scale;
        var buf: [1024]u8 = undefined;
        const len = config_mod.formatToml(c, &buf);
        const parsed = Config.parseForTest(buf[0..len]);
        try std.testing.expectEqual(scale, parsed.notif_scale);
    }

    // Test all monitor modes
    inline for (.{ MonitorMode.current_screen, MonitorMode.primary, MonitorMode.monitor_1, MonitorMode.monitor_2, MonitorMode.monitor_3, MonitorMode.monitor_4 }) |mode| {
        var c = Config{};
        c.notif_monitor = mode;
        var buf: [1024]u8 = undefined;
        const len = config_mod.formatToml(c, &buf);
        const parsed = Config.parseForTest(buf[0..len]);
        try std.testing.expectEqual(mode, parsed.notif_monitor);
    }
}
