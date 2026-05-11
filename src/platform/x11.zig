const std = @import("std");
const time_util = @import("../time_util.zig");
const render = @import("../render.zig");
const Config = @import("../config.zig").Config;
const NotifKind = @import("../core/notifier.zig").NotifKind;
const Event = @import("platform.zig").Event;

const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xatom.h");
    @cInclude("X11/keysym.h");
    @cInclude("X11/extensions/Xfixes.h");
    @cInclude("X11/extensions/Xrender.h");
});

pub const Context = struct {
    display: *c.Display,
    root: c.Window,
    window: c.Window,
    overlay_window: c.Window,
    clipboard_atom: c.Atom,
    utf8_atom: c.Atom,
    targets_atom: c.Atom,
    xfixes_event_base: c_int,
    override_keycode: c.KeyCode,
    owns_clipboard: bool = false,
    overlay_visible: bool = false,
    overlay_gc: c.GC = null,
    overlay_size: u32 = 96,
    screen_width: u32 = 0,
    screen_height: u32 = 0,
    notif_position: @import("../config.zig").NotifPosition = .top_right,
    colormap: c.Colormap = 0,
    visual: ?*c.Visual = null,
    depth: c_int = 24,
    // System tray fields
    tray_window: c.Window = 0,
    tray_manager: c.Window = 0,
    has_tray: bool = false,
    net_system_tray_atom: c.Atom = 0,
    xembed_info_atom: c.Atom = 0,
    tray_gc: c.GC = null,
    override_key_was_down: bool = false,
    // Content to serve when we own the clipboard (copied into local buffer)
    serve_buf: [65536]u8 = undefined,
    serve_len: usize = 0,
};

pub fn init(config: Config) !Context {
    const display = c.XOpenDisplay(null) orelse return error.NoDisplay;
    const screen = c.DefaultScreen(display);
    const root = c.RootWindow(display, screen);
    const screen_width: u32 = @intCast(c.DisplayWidth(display, screen));
    const screen_height: u32 = @intCast(c.DisplayHeight(display, screen));

    const clipboard_atom = c.XInternAtom(display, "CLIPBOARD", 0);
    const utf8_atom = c.XInternAtom(display, "UTF8_STRING", 0);
    const targets_atom = c.XInternAtom(display, "TARGETS", 0);

    // Create hidden window for clipboard events
    const window = c.XCreateSimpleWindow(display, root, 0, 0, 1, 1, 0, 0, 0);
    _ = c.XSelectInput(display, window, c.PropertyChangeMask);

    // Subscribe to clipboard ownership changes via XFixes
    var xfixes_event_base: c_int = 0;
    var xfixes_error_base: c_int = 0;
    if (c.XFixesQueryExtension(display, &xfixes_event_base, &xfixes_error_base) == 0) {
        return error.NoXFixes;
    }
    c.XFixesSelectSelectionInput(display, window, clipboard_atom, c.XFixesSetSelectionOwnerNotifyMask | c.XFixesSelectionClientCloseNotifyMask);

    // Find ARGB visual for transparent overlay
    var visual: ?*c.Visual = null;
    var depth: c_int = 24;
    var colormap: c.Colormap = 0;

    var vinfo: c.XVisualInfo = undefined;
    if (c.XMatchVisualInfo(display, screen, 32, c.TrueColor, &vinfo) != 0) {
        visual = vinfo.visual;
        depth = 32;
        colormap = c.XCreateColormap(display, root, visual, c.AllocNone);
    }

    // Create overlay window
    var attrs: c.XSetWindowAttributes = std.mem.zeroes(c.XSetWindowAttributes);
    attrs.override_redirect = 1;
    attrs.background_pixel = 0;
    attrs.border_pixel = 0;
    attrs.colormap = colormap;

    const overlay_window = c.XCreateWindow(
        display,
        root,
        @intCast(screen_width - 220),
        20,
        200,
        40,
        0,
        depth,
        c.InputOutput,
        visual,
        c.CWOverrideRedirect | c.CWBackPixel | c.CWBorderPixel | c.CWColormap,
        &attrs,
    );

    const keysym: c.KeySym = switch (config.override_key) {
        .right_ctrl => c.XK_Control_R,
        .right_alt => c.XK_Alt_R,
        .right_shift => c.XK_Shift_R,
        .f12 => c.XK_F12,
    };
    const keycode = c.XKeysymToKeycode(display, keysym);

    _ = c.XFlush(display);

    // Try to dock in system tray
    const net_system_tray_atom = c.XInternAtom(display, "_NET_SYSTEM_TRAY_S0", 0);
    const xembed_info_atom = c.XInternAtom(display, "_XEMBED_INFO", 0);
    const tray_manager = c.XGetSelectionOwner(display, net_system_tray_atom);

    var tray_window: c.Window = 0;
    var has_tray = false;

    if (tray_manager != 0) {
        // Create tray icon window (22x22 standard size)
        tray_window = c.XCreateSimpleWindow(display, root, 0, 0, 22, 22, 0, 0, 0x004400);
        _ = c.XSelectInput(display, tray_window, c.ButtonPressMask | c.ExposureMask | c.StructureNotifyMask);

        // Set _XEMBED_INFO property: version=0, flags=1 (XEMBED_MAPPED)
        const xembed_data = [2]c_ulong{ 0, 1 };
        _ = c.XChangeProperty(
            display,
            tray_window,
            xembed_info_atom,
            xembed_info_atom,
            32,
            c.PropModeReplace,
            @ptrCast(&xembed_data),
            2,
        );

        // Send SYSTEM_TRAY_REQUEST_DOCK to tray manager
        const tray_opcode_atom = c.XInternAtom(display, "_NET_SYSTEM_TRAY_OPCODE", 0);
        var dock_ev: c.XEvent = std.mem.zeroes(c.XEvent);
        dock_ev.xclient.type = c.ClientMessage;
        dock_ev.xclient.window = tray_manager;
        dock_ev.xclient.message_type = tray_opcode_atom;
        dock_ev.xclient.format = 32;
        dock_ev.xclient.data.l[0] = c.CurrentTime;
        dock_ev.xclient.data.l[1] = 0; // SYSTEM_TRAY_REQUEST_DOCK opcode
        dock_ev.xclient.data.l[2] = @intCast(tray_window);
        _ = c.XSendEvent(display, tray_manager, 0, c.NoEventMask, &dock_ev);
        _ = c.XFlush(display);

        has_tray = true;
    }

    return .{
        .display = display,
        .root = root,
        .window = window,
        .overlay_window = overlay_window,
        .clipboard_atom = clipboard_atom,
        .utf8_atom = utf8_atom,
        .targets_atom = targets_atom,
        .xfixes_event_base = xfixes_event_base,
        .override_keycode = keycode,
        .screen_width = screen_width,
        .screen_height = screen_height,
        .overlay_size = config.notif_scale.size(),
        .notif_position = config.notif_position,
        .colormap = colormap,
        .visual = visual,
        .depth = depth,
        .tray_window = tray_window,
        .tray_manager = tray_manager,
        .has_tray = has_tray,
        .net_system_tray_atom = net_system_tray_atom,
        .xembed_info_atom = xembed_info_atom,
    };
}

pub fn deinit(ctx: *Context) void {
    if (ctx.has_tray) {
        if (ctx.tray_gc != null) _ = c.XFreeGC(ctx.display, ctx.tray_gc);
        _ = c.XDestroyWindow(ctx.display, ctx.tray_window);
    }
    _ = c.XDestroyWindow(ctx.display, ctx.overlay_window);
    _ = c.XDestroyWindow(ctx.display, ctx.window);
    if (ctx.colormap != 0) _ = c.XFreeColormap(ctx.display, ctx.colormap);
    _ = c.XCloseDisplay(ctx.display);
}

pub fn pollEvent(ctx: *Context) !Event {
    // Poll override key via XQueryKeymap (works reliably for modifier keys)
    var keymap: [32]u8 = undefined;
    _ = c.XQueryKeymap(ctx.display, &keymap);
    const kc: u8 = @intCast(ctx.override_keycode);
    const is_down = (keymap[kc / 8] & (@as(u8, 1) << @intCast(kc % 8))) != 0;
    if (is_down and !ctx.override_key_was_down) {
        ctx.override_key_was_down = true;
        return .override_key_pressed;
    }
    ctx.override_key_was_down = is_down;

    if (c.XPending(ctx.display) == 0) return .none;

    var ev: c.XEvent = undefined;
    _ = c.XNextEvent(ctx.display, &ev);

    // XFixes selection notify — only fire when a real window claims CLIPBOARD
    if (ev.type == ctx.xfixes_event_base + c.XFixesSelectionNotify) {
        const sel_ev: *const c.XFixesSelectionNotifyEvent = @ptrCast(&ev);
        if (sel_ev.selection == ctx.clipboard_atom and sel_ev.owner != ctx.window and sel_ev.owner != 0) {
            return .copy_detected;
        }
        return .none;
    }

    // Button press on tray icon
    if (ev.type == c.ButtonPress and ctx.has_tray) {
        const btn: *const c.XButtonEvent = @ptrCast(&ev);
        if (btn.window == ctx.tray_window) {
            if (btn.button == 1) return .tray_toggle_notif;
            if (btn.button == 3) return .tray_quit;
        }
    }

    // Expose event for tray icon redraw
    if (ev.type == c.Expose and ctx.has_tray) {
        const exp: *const c.XExposeEvent = @ptrCast(&ev);
        if (exp.window == ctx.tray_window) {
            drawTrayIcon(ctx);
            return .none;
        }
    }

    // SelectionRequest — someone is trying to paste from us
    if (ev.type == c.SelectionRequest) {
        const req: *const c.XSelectionRequestEvent = @ptrCast(&ev);
        handleSelectionRequest(ctx, req);
        return .paste_attempted;
    }

    return .none;
}

fn handleSelectionRequest(ctx: *Context, req: *const c.XSelectionRequestEvent) void {
    var response: c.XSelectionEvent = .{
        .type = c.SelectionNotify,
        .serial = 0,
        .send_event = 1,
        .display = ctx.display,
        .requestor = req.requestor,
        .selection = req.selection,
        .target = req.target,
        .property = req.property,
        .time = req.time,
    };

    if (req.target == ctx.targets_atom) {
        const targets = [_]c.Atom{ ctx.targets_atom, ctx.utf8_atom };
        _ = c.XChangeProperty(ctx.display, req.requestor, req.property, c.XA_ATOM, 32, c.PropModeReplace, @ptrCast(&targets), targets.len);
    } else if (ctx.serve_len > 0) {
        _ = c.XChangeProperty(ctx.display, req.requestor, req.property, ctx.utf8_atom, 8, c.PropModeReplace, @ptrCast(&ctx.serve_buf), @intCast(ctx.serve_len));
    } else {
        _ = c.XChangeProperty(ctx.display, req.requestor, req.property, ctx.utf8_atom, 8, c.PropModeReplace, "", 0);
    }

    _ = c.XSendEvent(ctx.display, req.requestor, 0, 0, @ptrCast(&response));
    _ = c.XFlush(ctx.display);
}

pub fn getClipboardContent(ctx: *Context) !?[]const u8 {
    // Request clipboard content from current owner
    const prop_atom = c.XInternAtom(ctx.display, "PASTE_PROTECTOR_SEL", 0);
    _ = c.XConvertSelection(ctx.display, ctx.clipboard_atom, ctx.utf8_atom, prop_atom, ctx.window, c.CurrentTime);
    _ = c.XFlush(ctx.display);

    // Wait briefly for SelectionNotify
    var ev: c.XEvent = undefined;
    const deadline = time_util.nanoTimestamp() + 50 * std.time.ns_per_ms;
    while (time_util.nanoTimestamp() < deadline) {
        if (c.XPending(ctx.display) > 0) {
            _ = c.XNextEvent(ctx.display, &ev);
            if (ev.type == c.SelectionNotify) {
                const sel: *const c.XSelectionEvent = @ptrCast(&ev);
                if (sel.property == 0) return null; // None
                return readProperty(ctx, prop_atom);
            }
        }
        const req: std.c.timespec = .{ .sec = 0, .nsec = 1_000_000 };
        _ = std.c.nanosleep(&req, null);
    }
    return null;
}

fn readProperty(ctx: *Context, prop: c.Atom) ?[]const u8 {
    var actual_type: c.Atom = undefined;
    var actual_format: c_int = undefined;
    var nitems: c_ulong = undefined;
    var bytes_after: c_ulong = undefined;
    var data: [*c]u8 = undefined;

    if (c.XGetWindowProperty(ctx.display, ctx.window, prop, 0, 1024 * 1024, 1, c.AnyPropertyType, &actual_type, &actual_format, &nitems, &bytes_after, &data) != c.Success) {
        return null;
    }

    if (nitems == 0 or data == null) return null;

    // Return a slice; caller must be aware this is X-allocated
    return data[0..nitems];
}

pub fn clearClipboard(ctx: *Context) !void {
    _ = c.XSetSelectionOwner(ctx.display, ctx.clipboard_atom, ctx.window, c.CurrentTime);
    _ = c.XFlush(ctx.display);
    ctx.owns_clipboard = true;
    ctx.serve_len = 0;
}

pub fn restoreClipboard(ctx: *Context, content: []const u8) !void {
    if (content.len == 0) return;
    const len = @min(content.len, ctx.serve_buf.len);
    @memcpy(ctx.serve_buf[0..len], content[0..len]);
    ctx.serve_len = len;
    _ = c.XSetSelectionOwner(ctx.display, ctx.clipboard_atom, ctx.window, c.CurrentTime);
    _ = c.XFlush(ctx.display);
    ctx.owns_clipboard = true;
}

pub fn showOverlay(ctx: *Context, alpha: f32, y_offset: f32, x_offset: f32, kind: NotifKind) !void {
    const s = ctx.overlay_size;
    const si: i32 = @intCast(s);
    const margin: i32 = 16;
    const jitter_px: i32 = @intFromFloat(@abs(x_offset) * @as(f32, @floatFromInt(si)) * 0.5);

    const base_x: i32 = switch (ctx.notif_position) {
        .top_right, .bottom_right => @as(i32, @intCast(ctx.screen_width)) - si - margin - jitter_px,
        .top_left, .bottom_left => margin + jitter_px,
    };
    const base_y: i32 = switch (ctx.notif_position) {
        .top_right, .top_left => margin,
        .bottom_right, .bottom_left => @as(i32, @intCast(ctx.screen_height)) - si - margin,
    };

    // y_offset goes from 0 to -40. Move away from the nearest edge.
    const y: i32 = switch (ctx.notif_position) {
        .top_right, .top_left => base_y - @as(i32, @intFromFloat(y_offset)),
        .bottom_right, .bottom_left => base_y + @as(i32, @intFromFloat(y_offset)),
    };

    _ = c.XResizeWindow(ctx.display, ctx.overlay_window, s, s);
    _ = c.XMoveWindow(ctx.display, ctx.overlay_window, base_x, y);

    if (!ctx.overlay_visible) {
        _ = c.XMapRaised(ctx.display, ctx.overlay_window);
        ctx.overlay_visible = true;
    }

    renderOverlay(ctx, alpha, kind);
    _ = c.XFlush(ctx.display);
}

fn renderOverlay(ctx: *Context, alpha: f32, kind: NotifKind) void {
    const s = ctx.overlay_size;
    const stride = s * 4;

    // Max 192x192 at 4x scale = 144KB
    var pixels: [192 * 192 * 4]u8 = undefined;
    const needed = stride * s;
    if (needed > pixels.len) return;

    render.renderNotification(&pixels, s, alpha, kind);

    const image = c.XCreateImage(
        ctx.display,
        ctx.visual,
        @intCast(ctx.depth),
        c.ZPixmap,
        0,
        @ptrCast(&pixels),
        s,
        s,
        32,
        @intCast(stride),
    );
    if (image == null) return;

    if (ctx.overlay_gc == null) {
        ctx.overlay_gc = c.XCreateGC(ctx.display, ctx.overlay_window, 0, null);
    }

    _ = c.XPutImage(ctx.display, ctx.overlay_window, ctx.overlay_gc, image, 0, 0, 0, 0, s, s);
    image.*.data = null;
    _ = image.*.f.destroy_image.?(image);
}


pub fn hideOverlay(ctx: *Context) !void {
    if (ctx.overlay_visible) {
        _ = c.XUnmapWindow(ctx.display, ctx.overlay_window);
        ctx.overlay_visible = false;
        _ = c.XFlush(ctx.display);
    }
}

fn drawTrayIcon(ctx: *Context) void {
    if (ctx.tray_gc == null) {
        ctx.tray_gc = c.XCreateGC(ctx.display, ctx.tray_window, 0, null);
    }

    // Draw a green filled square as a simple "active" indicator
    // Green color: 0x22CC22
    const color: c_ulong = if (ctx.owns_clipboard) 0xCC2222 else 0x22CC22;
    _ = c.XSetForeground(ctx.display, ctx.tray_gc, color);
    _ = c.XFillRectangle(ctx.display, ctx.tray_window, ctx.tray_gc, 2, 2, 18, 18);

    // Draw a small "P" letter in white for "Paste Protector"
    _ = c.XSetForeground(ctx.display, ctx.tray_gc, 0xFFFFFF);
    _ = c.XFillRectangle(ctx.display, ctx.tray_window, ctx.tray_gc, 6, 5, 3, 12); // vertical stroke
    _ = c.XFillRectangle(ctx.display, ctx.tray_window, ctx.tray_gc, 9, 5, 5, 3); // top horizontal
    _ = c.XFillRectangle(ctx.display, ctx.tray_window, ctx.tray_gc, 9, 8, 5, 3); // middle horizontal
    _ = c.XFillRectangle(ctx.display, ctx.tray_window, ctx.tray_gc, 14, 5, 2, 6); // right vertical of P bowl

    _ = c.XFlush(ctx.display);
}

pub fn updateConfig(ctx: *Context, config: Config) void {
    ctx.overlay_size = config.notif_scale.size();
    ctx.notif_position = config.notif_position;
}

pub fn getFd(ctx: *const Context) ?std.posix.fd_t {
    return c.ConnectionNumber(ctx.display);
}
