const builtin = @import("builtin");
const Config = @import("../config.zig").Config;
const NotifKind = @import("../core/notifier.zig").NotifKind;
const std = @import("std");

const impl = switch (builtin.os.tag) {
    .linux => @import("x11.zig"),
    .windows => @import("windows.zig"),
    .macos => @import("macos.zig"),
    else => @compileError("unsupported platform"),
};

pub const Context = impl.Context;

pub const Event = enum {
    copy_detected,
    paste_attempted,
    override_key_pressed,
    tray_quit,
    tray_toggle_notif,
    tray_toggle_block,
    tray_toggle_paste_resets,
    tray_duration_1s,
    tray_duration_3s,
    tray_duration_5s,
    tray_duration_10s,
    tray_duration_30s,
    tray_pos_top_left,
    tray_pos_top_right,
    tray_pos_bottom_left,
    tray_pos_bottom_right,
    tray_scale_1x,
    tray_scale_1_5x,
    tray_scale_2x,
    tray_scale_3x,
    tray_scale_4x,
    tray_key_rctrl,
    tray_key_ralt,
    tray_key_rshift,
    tray_key_f12,
    tray_monitor_current,
    tray_monitor_primary,
    tray_monitor_1,
    tray_monitor_2,
    tray_monitor_3,
    tray_monitor_4,
    none,
};

pub fn init(config: Config) !Context {
    return impl.init(config);
}

pub fn deinit(ctx: *Context) void {
    impl.deinit(ctx);
}

pub fn pollEvent(ctx: *Context) !Event {
    return impl.pollEvent(ctx);
}

pub fn getClipboardContent(ctx: *Context) !?[]const u8 {
    return impl.getClipboardContent(ctx);
}

pub fn clearClipboard(ctx: *Context) !void {
    return impl.clearClipboard(ctx);
}

pub fn restoreClipboard(ctx: *Context, content: []const u8) !void {
    return impl.restoreClipboard(ctx, content);
}

pub fn showOverlay(ctx: *Context, alpha: f32, y_offset: f32, x_offset: f32, kind: NotifKind) !void {
    return impl.showOverlay(ctx, alpha, y_offset, x_offset, kind);
}


pub fn hideOverlay(ctx: *Context) !void {
    return impl.hideOverlay(ctx);
}

pub const ScreenRect = @import("../core/notifier.zig").ScreenRect;

pub fn getCurrentScreen(ctx: *Context, config: Config) ScreenRect {
    if (@hasDecl(impl, "getCurrentScreen")) {
        return impl.getCurrentScreen(ctx, config);
    }
    return .{};
}

const Notifier = @import("../core/notifier.zig").Notifier;
pub fn showOverlayStack(ctx: *Context, entries: *const [8]?Notifier.StackEntry, config: Config) !void {
    if (@hasDecl(impl, "showOverlayStack")) {
        return impl.showOverlayStack(ctx, entries, config);
    }
    // Fallback: show newest
    for (0..8) |ri| {
        const i = 7 - ri;
        if (entries[i]) |e| {
            return impl.showOverlay(ctx, e.alpha, e.y_offset, e.x_offset, e.kind);
        }
    }
}

pub fn updateConfig(ctx: *Context, config: @import("../config.zig").Config) void {
    if (@hasDecl(impl, "updateConfig")) {
        impl.updateConfig(ctx, config);
    }
}

pub const FdType = if (builtin.os.tag == .windows) i32 else std.posix.fd_t;

pub fn getFd(ctx: *const Context) ?FdType {
    return impl.getFd(ctx);
}
