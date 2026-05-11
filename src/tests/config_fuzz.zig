const std = @import("std");
const Config = @import("../config.zig").Config;

test "fuzz config parser" {
    try std.testing.fuzz({}, fuzzConfigParse, .{
        .corpus = &.{
            "",
            "block_duration_ms = 3000",
            "override_key = \"RightCtrl\"\nnotif_position = \"top-left\"",
            "block_duration_ms = 0\nblock_enabled = false\nnotif_scale = \"4\"",
            "# comment\n[section]\nblock_duration_ms = 999",
            "=\n===\nkey=\n=value",
            "block_duration_ms = 4294967295",
            "block_duration_ms = -1",
        },
    });
}

fn fuzzConfigParse(_: void, smith: *std.testing.Smith) !void {
    var buf: [4096]u8 = undefined;
    smith.bytesWithHash(&buf, 0);

    const len: u32 = smith.valueRangeAtMostWithHash(u32, 0, buf.len, 1);

    _ = Config.parseForTest(buf[0..len]);
}
