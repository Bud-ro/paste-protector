const std = @import("std");
const Io = std.Io;
const Dir = std.Io.Dir;
const File = std.Io.File;
const Environ = std.process.Environ;

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
    notif_duration_ms: u32 = 1200,
    notif_enabled: bool = true,
    notif_scale: NotifScale = .x2,
    block_enabled: bool = true,
    paste_resets_timer: bool = true,

    pub fn load(allocator: std.mem.Allocator, io: Io, environ_map: *Environ.Map) !Config {
        const path = getConfigPath(allocator, environ_map) catch return Config{};
        defer allocator.free(path);

        const content = readFile(allocator, io, path) catch return Config{};
        defer allocator.free(content);

        return parse(content);
    }

    pub fn loadFromFile(allocator: std.mem.Allocator, io: Io, path: []const u8) !Config {
        const content = try readFile(allocator, io, path);
        defer allocator.free(content);

        return parse(content);
    }

    fn readFile(allocator: std.mem.Allocator, io: Io, path: []const u8) ![]u8 {
        const file = try Dir.cwd().openFile(io, path, .{});
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

    fn getConfigPath(allocator: std.mem.Allocator, env: *Environ.Map) ![]const u8 {
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
