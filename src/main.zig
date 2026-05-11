const std = @import("std");
const builtin = @import("builtin");
const Config = @import("config.zig").Config;
const Blocker = @import("core/blocker.zig").Blocker;
const Notifier = @import("core/notifier.zig").Notifier;
const NotifKind = @import("core/notifier.zig").NotifKind;
const Monitor = @import("core/monitor.zig").Monitor;
const Event = @import("core/monitor.zig").Event;
const time_util = @import("time_util.zig");
const Io = std.Io;
const File = std.Io.File;

pub fn main(init: std.process.Init) !void {
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
            try File.stdout().writeStreamingAll(io, usage_text);
            return;
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-V")) {
            try File.stdout().writeStreamingAll(io, "paste-protector 0.1.0\n");
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

    eventLoop(&monitor, &blocker, &notifier, &config, &clipboard_cleared) catch |err| {
        if (err == error.QuitRequested) return;
        return err;
    };
}

fn processEvents(monitor: *Monitor, blocker: *Blocker, notifier: *Notifier, config: *Config, clipboard_cleared: *bool) !void {
    const now = time_util.nanoTimestamp();

    while (true) {
        const event = try monitor.poll();
        switch (event) {
            .copy_detected => {
                if (config.block_enabled) {
                    const content = monitor.getClipboardContent() catch null;
                    blocker.onCopyDetected(content, now);
                    clipboard_cleared.* = false;
                }
                if (config.notif_enabled) {
                    notifier.spawn(.copied, now);
                }
            },
            .paste_attempted => {
                if (blocker.isPasteBlocked() and config.notif_enabled) {
                    notifier.spawn(.override_hint, now);
                }
                if (config.paste_resets_timer and !blocker.isPasteBlocked()) {
                    blocker.onPasteAttempted(now);
                }
            },
            .override_key_pressed => {
                if (blocker.onOverrideKey(now)) {
                    monitor.restoreClipboard(blocker.getSavedContent() orelse "") catch {};
                    clipboard_cleared.* = false;
                    if (config.notif_enabled) {
                        notifier.spawn(.copied, now);
                    }
                }
            },
            .tray_quit => return error.QuitRequested,
            .tray_toggle_notif => config.notif_enabled = !config.notif_enabled,
            .tray_toggle_block => {
                config.block_enabled = !config.block_enabled;
                if (!config.block_enabled) {
                    blocker.clearAndIdle();
                    clipboard_cleared.* = false;
                }
            },
            .tray_toggle_paste_resets => config.paste_resets_timer = !config.paste_resets_timer,
            .tray_duration_1s => { config.block_duration_ms = 1000; blocker.setDuration(1000); },
            .tray_duration_3s => { config.block_duration_ms = 3000; blocker.setDuration(3000); },
            .tray_duration_5s => { config.block_duration_ms = 5000; blocker.setDuration(5000); },
            .tray_duration_10s => { config.block_duration_ms = 10000; blocker.setDuration(10000); },
            .tray_duration_30s => { config.block_duration_ms = 30000; blocker.setDuration(30000); },
            .tray_pos_top_left => config.notif_position = .top_left,
            .tray_pos_top_right => config.notif_position = .top_right,
            .tray_pos_bottom_left => config.notif_position = .bottom_left,
            .tray_pos_bottom_right => config.notif_position = .bottom_right,
            .tray_scale_1x => config.notif_scale = .x1,
            .tray_scale_1_5x => config.notif_scale = .x1_5,
            .tray_scale_2x => config.notif_scale = .x2,
            .tray_scale_3x => config.notif_scale = .x3,
            .tray_scale_4x => config.notif_scale = .x4,
            .tray_key_rctrl => config.override_key = .right_ctrl,
            .tray_key_ralt => config.override_key = .right_alt,
            .tray_key_rshift => config.override_key = .right_shift,
            .tray_key_f12 => config.override_key = .f12,
            .none => break,
        }
        // Push config updates to platform on any tray config change
        if (event != .none and event != .copy_detected and event != .paste_attempted and event != .override_key_pressed) {
            monitor.updateConfig(config.*);
        }
    }

    if (blocker.tick(now)) |_| {
        if (!clipboard_cleared.*) {
            monitor.clearClipboard() catch {};
            clipboard_cleared.* = true;
        }
    }

    if (notifier.tick(now)) |state| {
        monitor.showOverlay(state.alpha, state.y_offset, state.x_offset, state.kind) catch {};
    } else {
        monitor.hideOverlay() catch {};
    }
}

fn eventLoop(monitor: *Monitor, blocker: *Blocker, notifier: *Notifier, config: *Config, clipboard_cleared: *bool) !void {
    switch (builtin.os.tag) {
        .linux => try eventLoopLinux(monitor, blocker, notifier, config, clipboard_cleared),
        .windows => try eventLoopWindows(monitor, blocker, notifier, config, clipboard_cleared),
        .macos => try eventLoopMacos(monitor, blocker, notifier, config, clipboard_cleared),
        else => return error.UnsupportedPlatform,
    }
}

fn eventLoopLinux(monitor: *Monitor, blocker: *Blocker, notifier: *Notifier, config: *Config, clipboard_cleared: *bool) !void {
    const poll_fd = monitor.getFd() orelse return error.NoPollFd;

    var epoll_ev: std.c.epoll_event = .{
        .events = std.os.linux.EPOLL.IN,
        .data = .{ .fd = poll_fd },
    };
    const epoll_fd = std.c.epoll_create1(std.os.linux.EPOLL.CLOEXEC);
    if (epoll_fd < 0) return error.EpollCreateFailed;
    defer _ = std.c.close(epoll_fd);

    if (std.c.epoll_ctl(epoll_fd, std.os.linux.EPOLL.CTL_ADD, poll_fd, &epoll_ev) < 0) return error.EpollCtlFailed;

    while (true) {
        try processEvents(monitor, blocker, notifier, config, clipboard_cleared);

        const timeout: c_int = if (notifier.isActive() or blocker.isPasteBlocked()) 16 else 1000;
        var events: [4]std.c.epoll_event = undefined;
        _ = std.c.epoll_wait(epoll_fd, &events, 4, timeout);
    }
}

fn eventLoopWindows(monitor: *Monitor, blocker: *Blocker, notifier: *Notifier, config: *Config, clipboard_cleared: *bool) !void {
    const win = @import("platform/windows.zig");
    while (true) {
        _ = win.peekMessage();
        try processEvents(monitor, blocker, notifier, config, clipboard_cleared);
        const sleep_ms: u32 = if (notifier.isActive() or blocker.isPasteBlocked()) 16 else 100;
        win.sleep(sleep_ms);
    }
}

fn eventLoopMacos(monitor: *Monitor, blocker: *Blocker, notifier: *Notifier, config: *Config, clipboard_cleared: *bool) !void {
    const mac = @import("platform/macos.zig");
    while (true) {
        try processEvents(monitor, blocker, notifier, config, clipboard_cleared);
        const sleep_ms: u32 = if (notifier.isActive() or blocker.isPasteBlocked()) 16 else 100;
        mac.sleep(sleep_ms);
    }
}

const usage_text =
    \\paste-protector - clipboard enhancement daemon
    \\
    \\USAGE:
    \\  paste-protector [OPTIONS]
    \\
    \\OPTIONS:
    \\  --config <path>   Path to config file
    \\  --help, -h        Show this help
    \\  --version, -V     Show version
    \\
    \\DESCRIPTION:
    \\  Monitors clipboard for copy events, shows a floating notification,
    \\  and optionally blocks paste for a configurable duration to prevent
    \\  accidental paste of sensitive data. Press the override key (default:
    \\  Right Ctrl) to unlock paste immediately.
    \\
    \\CONFIG:
    \\  Default location: ~/.config/paste-protector/config.toml
    \\  Windows: %APPDATA%\paste-protector\config.toml
    \\
;
