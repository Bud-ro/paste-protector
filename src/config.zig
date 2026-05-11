const std = @import("std");

pub const OverrideKey = enum {
    right_ctrl,
    right_alt,
    right_shift,
    f12,
};

pub const NotifPosition = enum {
    top_right,
    top_left,
    bottom_right,
    bottom_left,
};

pub const MonitorMode = enum {
    current_screen,
    primary,
    monitor_1,
    monitor_2,
    monitor_3,
    monitor_4,
};

pub const NotifScale = enum {
    x1,
    x1_5,
    x2,
    x3,
    x4,

    pub fn factor(self: NotifScale) f32 {
        return switch (self) {
            .x1 => 1.0,
            .x1_5 => 1.5,
            .x2 => 2.0,
            .x3 => 3.0,
            .x4 => 4.0,
        };
    }

    pub fn size(self: NotifScale) u32 {
        return @intFromFloat(48.0 * self.factor());
    }
};

pub const Config = struct {
    block_duration_ms: u32 = 5000,
    override_key: OverrideKey = .right_ctrl,
    notif_position: NotifPosition = .bottom_right,
    notif_duration_ms: u32 = 2400,
    notif_enabled: bool = true,
    notif_scale: NotifScale = .x2,
    block_enabled: bool = true,
    paste_resets_timer: bool = true,
    notif_monitor: MonitorMode = .current_screen,

    // IO-dependent functions use local imports to avoid pulling in std.Io globally
    pub fn load(allocator: std.mem.Allocator, io: std.Io, environ_map: *std.process.Environ.Map) !Config {
        const path = getConfigPath(allocator, environ_map) catch return Config{};
        defer allocator.free(path);

        const content = readFile(allocator, io, path) catch return Config{};
        defer allocator.free(content);

        return parse(content);
    }

    pub fn loadFromFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Config {
        const content = try readFile(allocator, io, path);
        defer allocator.free(content);

        return parse(content);
    }

    fn readFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) ![]u8 {
        const file = try std.Io.Dir.cwd().openFile(io, path, .{});
        defer file.close(io);
        const stat = try file.stat(io);
        if (stat.size == 0 or stat.size > 64 * 1024) return error.InvalidFileSize;
        const buf = try allocator.alloc(u8, @intCast(stat.size));
        errdefer allocator.free(buf);
        const n = try file.readPositionalAll(io, buf, 0);
        return buf[0..n];
    }

    pub fn parseForTest(content: []const u8) Config {
        return parse(content);
    }

    fn parse(content: []const u8) Config {
        var config = Config{};
        var lines = std.mem.splitScalar(u8, content, '\n');

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#' or trimmed[0] == '[') continue;

            const eq_idx = std.mem.indexOfScalar(u8, trimmed, '=') orelse continue;
            const key = std.mem.trim(u8, trimmed[0..eq_idx], " \t");
            const raw_val = std.mem.trim(u8, trimmed[eq_idx + 1 ..], " \t");
            const val = stripQuotes(raw_val);

            if (std.mem.eql(u8, key, "block_duration_ms")) {
                config.block_duration_ms = std.fmt.parseInt(u32, val, 10) catch config.block_duration_ms;
            } else if (std.mem.eql(u8, key, "override_key")) {
                config.override_key = parseOverrideKey(val);
            } else if (std.mem.eql(u8, key, "notif_position")) {
                config.notif_position = parsePosition(val);
            } else if (std.mem.eql(u8, key, "notif_duration_ms")) {
                config.notif_duration_ms = std.fmt.parseInt(u32, val, 10) catch config.notif_duration_ms;
            } else if (std.mem.eql(u8, key, "notif_enabled")) {
                config.notif_enabled = parseBool(val);
            } else if (std.mem.eql(u8, key, "notif_scale")) {
                config.notif_scale = parseScale(val);
            } else if (std.mem.eql(u8, key, "block_enabled")) {
                config.block_enabled = parseBool(val);
            } else if (std.mem.eql(u8, key, "paste_resets_timer")) {
                config.paste_resets_timer = parseBool(val);
            } else if (std.mem.eql(u8, key, "notif_monitor")) {
                config.notif_monitor = parseMonitorMode(val);
            }
        }

        return config;
    }

    fn stripQuotes(s: []const u8) []const u8 {
        if (s.len >= 2 and s[0] == '"' and s[s.len - 1] == '"') return s[1 .. s.len - 1];
        return s;
    }

    fn parseOverrideKey(val: []const u8) OverrideKey {
        if (std.mem.eql(u8, val, "RightAlt")) return .right_alt;
        if (std.mem.eql(u8, val, "RightShift")) return .right_shift;
        if (std.mem.eql(u8, val, "F12")) return .f12;
        return .right_ctrl;
    }

    fn parsePosition(val: []const u8) NotifPosition {
        if (std.mem.eql(u8, val, "top-left")) return .top_left;
        if (std.mem.eql(u8, val, "top-right")) return .top_right;
        if (std.mem.eql(u8, val, "bottom-left")) return .bottom_left;
        return .bottom_right;
    }

    fn parseScale(val: []const u8) NotifScale {
        if (std.mem.eql(u8, val, "1")) return .x1;
        if (std.mem.eql(u8, val, "1.5")) return .x1_5;
        if (std.mem.eql(u8, val, "3")) return .x3;
        if (std.mem.eql(u8, val, "4")) return .x4;
        return .x2;
    }

    fn parseBool(val: []const u8) bool {
        return std.mem.eql(u8, val, "true");
    }

    fn parseMonitorMode(val: []const u8) MonitorMode {
        if (std.mem.eql(u8, val, "current")) return .current_screen;
        if (std.mem.eql(u8, val, "primary")) return .primary;
        if (std.mem.eql(u8, val, "1")) return .monitor_1;
        if (std.mem.eql(u8, val, "2")) return .monitor_2;
        if (std.mem.eql(u8, val, "3")) return .monitor_3;
        if (std.mem.eql(u8, val, "4")) return .monitor_4;
        return .current_screen;
    }

    fn getConfigPath(allocator: std.mem.Allocator, env: *std.process.Environ.Map) ![]const u8 {
        if (env.get("XDG_CONFIG_HOME")) |xdg| {
            return std.fmt.allocPrint(allocator, "{s}/paste-protector/config.toml", .{xdg});
        }
        if (env.get("HOME")) |home| {
            return std.fmt.allocPrint(allocator, "{s}/.config/paste-protector/config.toml", .{home});
        }
        if (env.get("APPDATA")) |appdata| {
            return std.fmt.allocPrint(allocator, "{s}\\paste-protector\\config.toml", .{appdata});
        }
        return error.NoConfigPath;
    }
};

pub fn formatToml(config: Config, buf: []u8) usize {
    var pos: usize = 0;

    // block_duration_ms
    pos = appendStr(buf, pos, "block_duration_ms = ");
    pos = appendU32(buf, pos, config.block_duration_ms);
    pos = appendStr(buf, pos, "\n");

    // override_key
    pos = appendStr(buf, pos, "override_key = \"");
    pos = appendStr(buf, pos, switch (config.override_key) {
        .right_ctrl => "RightCtrl",
        .right_alt => "RightAlt",
        .right_shift => "RightShift",
        .f12 => "F12",
    });
    pos = appendStr(buf, pos, "\"\n");

    // notif_position
    pos = appendStr(buf, pos, "notif_position = \"");
    pos = appendStr(buf, pos, switch (config.notif_position) {
        .top_right => "top-right",
        .top_left => "top-left",
        .bottom_right => "bottom-right",
        .bottom_left => "bottom-left",
    });
    pos = appendStr(buf, pos, "\"\n");

    // notif_duration_ms
    pos = appendStr(buf, pos, "notif_duration_ms = ");
    pos = appendU32(buf, pos, config.notif_duration_ms);
    pos = appendStr(buf, pos, "\n");

    // notif_enabled
    pos = appendStr(buf, pos, "notif_enabled = ");
    pos = appendStr(buf, pos, if (config.notif_enabled) "true" else "false");
    pos = appendStr(buf, pos, "\n");

    // notif_scale
    pos = appendStr(buf, pos, "notif_scale = \"");
    pos = appendStr(buf, pos, switch (config.notif_scale) {
        .x1 => "1",
        .x1_5 => "1.5",
        .x2 => "2",
        .x3 => "3",
        .x4 => "4",
    });
    pos = appendStr(buf, pos, "\"\n");

    // block_enabled
    pos = appendStr(buf, pos, "block_enabled = ");
    pos = appendStr(buf, pos, if (config.block_enabled) "true" else "false");
    pos = appendStr(buf, pos, "\n");

    // paste_resets_timer
    pos = appendStr(buf, pos, "paste_resets_timer = ");
    pos = appendStr(buf, pos, if (config.paste_resets_timer) "true" else "false");
    pos = appendStr(buf, pos, "\n");

    // notif_monitor
    pos = appendStr(buf, pos, "notif_monitor = \"");
    pos = appendStr(buf, pos, switch (config.notif_monitor) {
        .current_screen => "current",
        .primary => "primary",
        .monitor_1 => "1",
        .monitor_2 => "2",
        .monitor_3 => "3",
        .monitor_4 => "4",
    });
    pos = appendStr(buf, pos, "\"\n");

    return pos;
}

fn appendStr(buf: []u8, pos: usize, s: []const u8) usize {
    if (pos + s.len > buf.len) return pos;
    @memcpy(buf[pos..][0..s.len], s);
    return pos + s.len;
}

fn appendU32(buf: []u8, pos: usize, val: u32) usize {
    // Convert u32 to decimal string
    var tmp: [10]u8 = undefined;
    var v = val;
    var len: usize = 0;
    if (v == 0) {
        tmp[0] = '0';
        len = 1;
    } else {
        while (v > 0) : (len += 1) {
            tmp[len] = @intCast((v % 10) + '0');
            v /= 10;
        }
        // Reverse
        var i: usize = 0;
        var j: usize = len - 1;
        while (i < j) {
            const t = tmp[i];
            tmp[i] = tmp[j];
            tmp[j] = t;
            i += 1;
            j -= 1;
        }
    }
    return appendStr(buf, pos, tmp[0..len]);
}
