const std = @import("std");
const Config = @import("../config.zig").Config;
const NotifKind = @import("../core/notifier.zig").NotifKind;
const NotifPosition = @import("../config.zig").NotifPosition;
const Event = @import("platform.zig").Event;

// Wayland support requires:
//   - libwayland-client-dev
//   - wlr-protocols (for wlr-data-control and wlr-layer-shell)
//   - wayland-scanner to generate protocol headers
//
// Most wlroots-based compositors (Sway, Hyprland) support these protocols.
// GNOME (Mutter) and KDE (KWin) do NOT support wlr-data-control.

pub const Context = struct {
    _unused: u8 = 0,
};

pub fn init(_: Config) !Context {
    @compileError(
        \\Wayland platform not yet implemented.
        \\
        \\Paste Protector on Linux currently requires X11.
        \\If running under Wayland, use XWayland compatibility or
        \\build with -Dtarget=native (defaults to X11).
        \\
        \\Wayland support requires wlr-data-control-unstable-v1 and
        \\wlr-layer-shell-unstable-v1 protocols (Sway, Hyprland, etc).
    );
}

pub fn deinit(_: *Context) void {}
pub fn pollEvent(_: *Context) !Event { return .none; }
pub fn getClipboardContent(_: *Context) !?[]const u8 { return null; }
pub fn clearClipboard(_: *Context) !void {}
pub fn restoreClipboard(_: *Context, _: []const u8) !void {}
pub fn showOverlay(_: *Context, _: f32, _: f32, _: f32, _: NotifKind) !void {}
pub fn hideOverlay(_: *Context) !void {}
pub fn getFd(_: *const Context) ?i32 { return null; }
