const std = @import("std");
const builtin = @import("builtin");
const Config = @import("config.zig").Config;
const Blocker = @import("core/blocker.zig").Blocker;
const Notifier = @import("core/notifier.zig").Notifier;
const Monitor = @import("core/monitor.zig").Monitor;
const main_mod = @import("main.zig");

pub fn mainFull(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var config_path: ?[]const u8 = null;
    var args_iter = if (builtin.os.tag == .windows)
        try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator)
    else
        std.process.Args.Iterator.init(init.minimal.args);
    defer if (builtin.os.tag == .windows) args_iter.deinit();
    _ = args_iter.skip();
    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try std.Io.File.stdout().writeStreamingAll(io, main_mod.usage_text);
            return;
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-V")) {
            try std.Io.File.stdout().writeStreamingAll(io, "paste-protector 0.1.0\n");
            return;
        } else if (std.mem.eql(u8, arg, "--config")) {
            config_path = args_iter.next();
        }
    }

    var config = blk: {
        if (config_path) |path| {
            break :blk Config.loadFromFile(allocator, io, path) catch |err| {
                std.log.err("failed to load config: {}", .{err});
                return err;
            };
        }
        break :blk Config.load(allocator, io, init.environ_map) catch Config{};
    };

    var monitor = Monitor.init(config) catch |err| {
        std.log.err("failed to initialize platform: {}", .{err});
        return err;
    };
    defer monitor.deinit();

    var blocker = Blocker.init(allocator, config);
    defer blocker.deinit();

    var notifier = Notifier.init(config);
    var clipboard_cleared = false;

    std.log.info("paste-protector running (block={}ms, key={s})", .{
        config.block_duration_ms,
        @tagName(config.override_key),
    });

    main_mod.eventLoop(&monitor, &blocker, &notifier, &config, &clipboard_cleared) catch |err| {
        if (err == error.QuitRequested) return;
        return err;
    };
}
