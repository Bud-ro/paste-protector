const std = @import("std");
const Config = @import("../config.zig").Config;
const NotifKind = @import("../core/notifier.zig").NotifKind;
const NotifPosition = @import("../config.zig").NotifPosition;
const NotifScale = @import("../config.zig").NotifScale;
const OverrideKey = @import("../config.zig").OverrideKey;
const Event = @import("platform.zig").Event;
const render = @import("../render.zig");

// Win32 types
const HWND = std.os.windows.HWND;
const HINSTANCE = std.os.windows.HINSTANCE;
const BOOL = std.os.windows.BOOL;
const UINT = c_uint;
const WPARAM = usize;
const LPARAM = isize;
const LRESULT = isize;
const DWORD = std.os.windows.DWORD;
const HANDLE = std.os.windows.HANDLE;
const HDC = *opaque {};
const HBITMAP = *opaque {};
const HBRUSH = *opaque {};
const HFONT = *opaque {};
const HGDIOBJ = *opaque {};
const HMENU = *opaque {};
const HICON = *opaque {};
const COLORREF = DWORD;
const ATOM = u16;
const BYTE = u8;

const POINT = extern struct { x: i32, y: i32 };
const SIZE = extern struct { cx: i32, cy: i32 };
const RECT = extern struct { left: i32, top: i32, right: i32, bottom: i32 };

const BLENDFUNCTION = extern struct {
    BlendOp: BYTE = 0,
    BlendFlags: BYTE = 0,
    SourceConstantAlpha: BYTE = 255,
    AlphaFormat: BYTE = 1, // AC_SRC_ALPHA
};

const MSG = extern struct {
    hwnd: ?HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
};

const WNDCLASSEXW = extern struct {
    cbSize: UINT = @sizeOf(WNDCLASSEXW),
    style: UINT = 0,
    lpfnWndProc: *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.c) LRESULT,
    cbClsExtra: c_int = 0,
    cbWndExtra: c_int = 0,
    hInstance: ?HINSTANCE = null,
    hIcon: ?HANDLE = null,
    hCursor: ?HANDLE = null,
    hbrBackground: ?HBRUSH = null,
    lpszMenuName: ?[*:0]const u16 = null,
    lpszClassName: [*:0]const u16,
    hIconSm: ?HANDLE = null,
};

const BITMAPINFOHEADER = extern struct {
    biSize: DWORD = @sizeOf(BITMAPINFOHEADER),
    biWidth: i32,
    biHeight: i32,
    biPlanes: u16 = 1,
    biBitCount: u16 = 32,
    biCompression: DWORD = 0, // BI_RGB
    biSizeImage: DWORD = 0,
    biXPelsPerMeter: i32 = 0,
    biYPelsPerMeter: i32 = 0,
    biClrUsed: DWORD = 0,
    biClrImportant: DWORD = 0,
};

const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER,
    bmiColors: [1]DWORD = .{0},
};

const NOTIFYICONDATAW = extern struct {
    cbSize: DWORD = @sizeOf(NOTIFYICONDATAW),
    hWnd: ?HWND = null,
    uID: UINT = 0,
    uFlags: UINT = 0,
    uCallbackMessage: UINT = 0,
    hIcon: ?HICON = null,
    szTip: [128]u16 = [_]u16{0} ** 128,
    dwState: DWORD = 0,
    dwStateMask: DWORD = 0,
    szInfo: [256]u16 = [_]u16{0} ** 256,
    uVersion: UINT = 0,
    szInfoTitle: [64]u16 = [_]u16{0} ** 64,
    dwInfoFlags: DWORD = 0,
    guidItem: [16]u8 = [_]u8{0} ** 16,
    hBalloonIcon: ?HICON = null,
};

const SavedFormat = struct {
    format: UINT = 0,
    data: ?HANDLE = null,
};

// Constants
const WM_CLIPBOARDUPDATE: UINT = 0x031D;
const WM_HOTKEY: UINT = 0x0312;
const WM_DESTROY: UINT = 0x0002;
const WM_PAINT: UINT = 0x000F;
const WM_TIMER: UINT = 0x0113;
const WM_COMMAND: UINT = 0x0111;
const WM_APP: UINT = 0x8000;
const WM_RBUTTONUP: UINT = 0x0205;
const WM_LBUTTONUP: UINT = 0x0202;

const WM_TRAYICON: UINT = WM_APP + 1;

const WS_EX_LAYERED: DWORD = 0x00080000;
const WS_EX_TRANSPARENT: DWORD = 0x00000020;
const WS_EX_TOPMOST: DWORD = 0x00000008;
const WS_EX_TOOLWINDOW: DWORD = 0x00000080;
const WS_EX_NOACTIVATE: DWORD = 0x08000000;
const WS_POPUP: DWORD = 0x80000000;
const WS_VISIBLE: DWORD = 0x10000000;

const CW_USEDEFAULT: i32 = @as(i32, @bitCast(@as(u32, 0x80000000)));

const PM_REMOVE: UINT = 0x0001;
const ULW_ALPHA: DWORD = 0x00000002;
const DIB_RGB_COLORS: UINT = 0;
const SRCCOPY: DWORD = 0x00CC0020;

const MOD_NOREPEAT: UINT = 0x4000;
const VK_CONTROL: c_int = 0x11;
const VK_V: c_int = 0x56;
const VK_RCONTROL: c_int = 0xA3;
const VK_RMENU: c_int = 0xA5;
const VK_RSHIFT: c_int = 0xA1;
const VK_F12: c_int = 0x7B;

const CF_UNICODETEXT: UINT = 13;
const GMEM_MOVEABLE: UINT = 0x0002;

const HOTKEY_ID: c_int = 1;

const SM_CXSCREEN: c_int = 0;
const SM_CYSCREEN: c_int = 1;

// Tray / menu constants
const NIF_MESSAGE: UINT = 0x01;
const NIF_ICON: UINT = 0x02;
const NIF_TIP: UINT = 0x04;
const NIM_ADD: DWORD = 0;
const NIM_DELETE: DWORD = 2;

const MF_STRING: UINT = 0x0000;
const MF_SEPARATOR: UINT = 0x0800;
const MF_CHECKED: UINT = 0x0008;
const MF_POPUP: UINT = 0x0010;

const TPM_RETURNCMD: UINT = 0x0100;
const TPM_RIGHTBUTTON: UINT = 0x0002;

// Menu item IDs
const IDM_TOGGLE_NOTIF: UINT = 1001;
const IDM_TOGGLE_BLOCK: UINT = 1002;
const IDM_QUIT: UINT = 1003;
const IDM_PASTE_RESETS: UINT = 1004;
const IDM_DURATION_1S: UINT = 1010;
const IDM_DURATION_3S: UINT = 1011;
const IDM_DURATION_5S: UINT = 1012;
const IDM_DURATION_10S: UINT = 1013;
const IDM_DURATION_30S: UINT = 1014;
const IDM_POS_TOP_LEFT: UINT = 1020;
const IDM_POS_TOP_RIGHT: UINT = 1021;
const IDM_POS_BOTTOM_LEFT: UINT = 1022;
const IDM_POS_BOTTOM_RIGHT: UINT = 1023;
const IDM_SCALE_1X: UINT = 1030;
const IDM_SCALE_1_5X: UINT = 1031;
const IDM_SCALE_2X: UINT = 1032;
const IDM_SCALE_3X: UINT = 1033;
const IDM_SCALE_4X: UINT = 1034;
const IDM_KEY_RCTRL: UINT = 1040;
const IDM_KEY_RALT: UINT = 1041;
const IDM_KEY_RSHIFT: UINT = 1042;
const IDM_KEY_F12: UINT = 1043;

// user32 functions
extern "user32" fn RegisterClassExW(lpWndClass: *const WNDCLASSEXW) callconv(.c) ATOM;
extern "user32" fn CreateWindowExW(dwExStyle: DWORD, lpClassName: [*:0]const u16, lpWindowName: ?[*:0]const u16, dwStyle: DWORD, x: c_int, y: c_int, nWidth: c_int, nHeight: c_int, hWndParent: ?HWND, hMenu: ?HANDLE, hInstance: ?HINSTANCE, lpParam: ?*anyopaque) callconv(.c) ?HWND;
extern "user32" fn DestroyWindow(hWnd: HWND) callconv(.c) BOOL;
extern "user32" fn DefWindowProcW(hWnd: HWND, msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.c) LRESULT;
extern "user32" fn PeekMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) callconv(.c) BOOL;
extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.c) BOOL;
extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(.c) LRESULT;
extern "user32" fn AddClipboardFormatListener(hwnd: HWND) callconv(.c) BOOL;
extern "user32" fn RemoveClipboardFormatListener(hwnd: HWND) callconv(.c) BOOL;
extern "user32" fn OpenClipboard(hWndNewOwner: ?HWND) callconv(.c) BOOL;
extern "user32" fn CloseClipboard() callconv(.c) BOOL;
extern "user32" fn EmptyClipboard() callconv(.c) BOOL;
extern "user32" fn GetClipboardData(uFormat: UINT) callconv(.c) ?HANDLE;
extern "user32" fn SetClipboardData(uFormat: UINT, hMem: ?HANDLE) callconv(.c) ?HANDLE;
extern "user32" fn GetAsyncKeyState(vKey: c_int) callconv(.c) c_short;
extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: c_int) callconv(.c) BOOL;
extern "user32" fn UpdateLayeredWindow(hWnd: HWND, hdcDst: ?HDC, pptDst: ?*POINT, psize: ?*SIZE, hdcSrc: ?HDC, pptSrc: ?*POINT, crKey: COLORREF, pblend: ?*BLENDFUNCTION, dwFlags: DWORD) callconv(.c) BOOL;
extern "user32" fn MoveWindow(hWnd: HWND, x: c_int, y: c_int, nWidth: c_int, nHeight: c_int, bRepaint: BOOL) callconv(.c) BOOL;
extern "user32" fn GetSystemMetrics(nIndex: c_int) callconv(.c) c_int;
extern "user32" fn GetDC(hWnd: ?HWND) callconv(.c) ?HDC;
extern "user32" fn ReleaseDC(hWnd: ?HWND, hDC: HDC) callconv(.c) c_int;
extern "user32" fn LoadIconW(hInstance: ?HINSTANCE, lpIconName: usize) callconv(.c) ?HICON;
extern "user32" fn CreatePopupMenu() callconv(.c) ?HMENU;
extern "user32" fn CreateMenu() callconv(.c) ?HMENU;
extern "user32" fn DestroyMenu(hMenu: HMENU) callconv(.c) BOOL;
extern "user32" fn AppendMenuW(hMenu: HMENU, uFlags: UINT, uIDNewItem: usize, lpNewItem: ?[*:0]const u16) callconv(.c) BOOL;
extern "user32" fn TrackPopupMenu(hMenu: HMENU, uFlags: UINT, x: c_int, y: c_int, nReserved: c_int, hWnd: HWND, prcRect: ?*const RECT) callconv(.c) BOOL;
extern "user32" fn SetForegroundWindow(hWnd: HWND) callconv(.c) BOOL;
extern "user32" fn GetCursorPos(lpPoint: *POINT) callconv(.c) BOOL;
extern "user32" fn PostMessageW(hWnd: ?HWND, msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.c) BOOL;

// shell32 functions
extern "shell32" fn Shell_NotifyIconW(dwMessage: DWORD, lpData: *NOTIFYICONDATAW) callconv(.c) BOOL;

// kernel32 functions
extern "kernel32" fn GetModuleHandleW(lpModuleName: ?[*:0]const u16) callconv(.c) ?HINSTANCE;
extern "kernel32" fn GlobalAlloc(uFlags: UINT, dwBytes: usize) callconv(.c) ?HANDLE;
extern "kernel32" fn GlobalFree(hMem: HANDLE) callconv(.c) ?HANDLE;
extern "kernel32" fn GlobalLock(hMem: HANDLE) callconv(.c) ?[*]u8;
extern "kernel32" fn GlobalUnlock(hMem: HANDLE) callconv(.c) BOOL;
extern "kernel32" fn GlobalSize(hMem: HANDLE) callconv(.c) usize;
extern "kernel32" fn Sleep(dwMilliseconds: DWORD) callconv(.c) void;
extern "user32" fn EnumClipboardFormats(format: UINT) callconv(.c) UINT;

// gdi32 functions
extern "gdi32" fn CreateCompatibleDC(hdc: ?HDC) callconv(.c) ?HDC;
extern "gdi32" fn DeleteDC(hdc: HDC) callconv(.c) BOOL;
extern "gdi32" fn CreateDIBSection(hdc: ?HDC, pbmi: *const BITMAPINFO, usage: UINT, ppvBits: *?[*]u8, hSection: ?HANDLE, offset: DWORD) callconv(.c) ?HBITMAP;
extern "gdi32" fn SelectObject(hdc: HDC, h: *anyopaque) callconv(.c) ?HGDIOBJ;
extern "gdi32" fn DeleteObject(ho: *anyopaque) callconv(.c) BOOL;

// Global state for the window procedure callback
var g_event_queue: EventQueue = .{};
var g_notif_enabled: bool = true;
var g_block_enabled: bool = true;
var g_block_duration_secs: u32 = 3;
var g_paste_resets: bool = true;
var g_current_position: NotifPosition = .bottom_right;
var g_current_scale: NotifScale = .x2;
var g_current_key: OverrideKey = .right_ctrl;
var g_suppress_next_clipboard: bool = false;

const EventQueue = struct {
    events: [16]Event = [_]Event{.none} ** 16,
    head: u8 = 0,
    tail: u8 = 0,

    fn push(self: *EventQueue, ev: Event) void {
        self.events[self.tail] = ev;
        self.tail = (self.tail + 1) % 16;
    }

    fn pop(self: *EventQueue) Event {
        if (self.head == self.tail) return .none;
        const ev = self.events[self.head];
        self.head = (self.head + 1) % 16;
        return ev;
    }
};

pub const Context = struct {
    msg_window: HWND,
    overlay_window: HWND,
    overlay_visible: bool = false,
    screen_width: i32,
    screen_height: i32,
    overlay_size: u32 = 96,
    notif_position: NotifPosition,
    override_vk: c_int,
    override_key_was_down: bool = false,
    paste_key_was_down: bool = false,
    // Multi-format clipboard save
    saved_formats: [16]SavedFormat = [_]SavedFormat{.{}} ** 16,
    saved_format_count: u32 = 0,
    mem_dc: ?HDC = null,
    bitmap: ?HBITMAP = null,
    pixels: ?[*]u8 = null,
    tray_data: NOTIFYICONDATAW = .{},
    tray_added: bool = false,
};

pub fn init(config: Config) !Context {
    const hinstance = GetModuleHandleW(null);

    const class_name = std.unicode.utf8ToUtf16LeStringLiteral("PasteProtectorMsg");
    const wc: WNDCLASSEXW = .{
        .lpfnWndProc = &wndProc,
        .hInstance = hinstance,
        .lpszClassName = class_name,
    };
    _ = RegisterClassExW(&wc); // May fail if already registered (e.g. in tests)

    const msg_window = CreateWindowExW(
        0,
        class_name,
        null,
        0,
        0, 0, 0, 0,
        null, null, hinstance, null,
    ) orelse return error.CreateWindowFailed;

    if (AddClipboardFormatListener(msg_window) == .FALSE) return error.ClipboardListenerFailed;

    // Register overlay window class
    const overlay_class = std.unicode.utf8ToUtf16LeStringLiteral("PasteProtectorOverlay");
    const oc: WNDCLASSEXW = .{
        .lpfnWndProc = &DefWindowProcW,
        .hInstance = hinstance,
        .lpszClassName = overlay_class,
    };
    _ = RegisterClassExW(&oc);

    const screen_w = GetSystemMetrics(SM_CXSCREEN);
    const screen_h = GetSystemMetrics(SM_CYSCREEN);

    const init_s: i32 = @intCast(config.notif_scale.size());
    const init_w = init_s;
    const init_h = init_s;

    const overlay_window = CreateWindowExW(
        WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
        overlay_class,
        null,
        WS_POPUP,
        screen_w - init_w - 20, 20, init_w, init_h,
        null, null, hinstance, null,
    ) orelse return error.CreateOverlayFailed;

    const vk: c_int = switch (config.override_key) {
        .right_ctrl => VK_RCONTROL,
        .right_alt => VK_RMENU,
        .right_shift => VK_RSHIFT,
        .f12 => VK_F12,
    };

    // Create memory DC and bitmap for overlay rendering
    const screen_dc = GetDC(null);
    const mem_dc = CreateCompatibleDC(screen_dc);
    if (screen_dc) |dc| _ = ReleaseDC(null, dc);

    var bmi: BITMAPINFO = .{
        .bmiHeader = .{
            .biWidth = 240,
            .biHeight = -960, // top-down, tall enough for stacked notifications
        },
    };
    var pixels: ?[*]u8 = null;
    const bitmap = CreateDIBSection(mem_dc, &bmi, DIB_RGB_COLORS, &pixels, null, 0);

    if (mem_dc) |dc| {
        if (bitmap) |bmp| _ = SelectObject(dc, @ptrCast(bmp));
    }

    // Initialize global state for menu checkmarks
    g_notif_enabled = config.notif_enabled;
    g_block_enabled = config.block_enabled;
    g_block_duration_secs = config.block_duration_ms / 1000;
    g_paste_resets = config.paste_resets_timer;
    g_current_position = config.notif_position;
    g_current_scale = config.notif_scale;
    g_current_key = config.override_key;

    var ctx: Context = .{
        .msg_window = msg_window,
        .overlay_window = overlay_window,
        .screen_width = screen_w,
        .screen_height = screen_h,
        .overlay_size = config.notif_scale.size(),
        .notif_position = config.notif_position,
        .override_vk = vk,
        .mem_dc = mem_dc,
        .bitmap = bitmap,
        .pixels = pixels,
    };

    // Set up system tray icon
    initTray(&ctx);

    return ctx;
}

fn initTray(ctx: *Context) void {
    const hinstance = GetModuleHandleW(null);
    // Load icon from embedded resource (ID 1 in .rc file)
    const icon = LoadIconW(hinstance, 1) orelse LoadIconW(null, 32512);

    ctx.tray_data = .{
        .hWnd = ctx.msg_window,
        .uID = 1,
        .uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP,
        .uCallbackMessage = WM_TRAYICON,
        .hIcon = icon,
    };

    // Set tooltip: "Paste Protector"
    const tip = std.unicode.utf8ToUtf16LeStringLiteral("Paste Protector");
    for (tip, 0..) |ch, i| {
        ctx.tray_data.szTip[i] = ch;
    }

    if (Shell_NotifyIconW(NIM_ADD, &ctx.tray_data) != .FALSE) {
        ctx.tray_added = true;
    }
}

fn removeTray(ctx: *Context) void {
    if (ctx.tray_added) {
        _ = Shell_NotifyIconW(NIM_DELETE, &ctx.tray_data);
        ctx.tray_added = false;
    }
}

pub fn deinit(ctx: *Context) void {
    removeTray(ctx);
    _ = RemoveClipboardFormatListener(ctx.msg_window);
    if (ctx.bitmap) |bmp| _ = DeleteObject(@ptrCast(bmp));
    if (ctx.mem_dc) |dc| _ = DeleteDC(dc);
    _ = DestroyWindow(ctx.overlay_window);
    _ = DestroyWindow(ctx.msg_window);
}

fn showTrayMenu(hwnd: HWND) void {
    const menu = CreatePopupMenu() orelse return;
    const dur_submenu = CreatePopupMenu() orelse {
        _ = DestroyMenu(menu);
        return;
    };
    const pos_submenu = CreatePopupMenu() orelse {
        _ = DestroyMenu(dur_submenu);
        _ = DestroyMenu(menu);
        return;
    };
    const scale_submenu = CreatePopupMenu() orelse {
        _ = DestroyMenu(pos_submenu);
        _ = DestroyMenu(dur_submenu);
        _ = DestroyMenu(menu);
        return;
    };
    const key_submenu = CreatePopupMenu() orelse {
        _ = DestroyMenu(scale_submenu);
        _ = DestroyMenu(pos_submenu);
        _ = DestroyMenu(dur_submenu);
        _ = DestroyMenu(menu);
        return;
    };

    // Build duration submenu
    const dur_items = [_]struct { id: UINT, label: [*:0]const u16, secs: u32 }{
        .{ .id = IDM_DURATION_1S, .label = std.unicode.utf8ToUtf16LeStringLiteral("1s"), .secs = 1 },
        .{ .id = IDM_DURATION_3S, .label = std.unicode.utf8ToUtf16LeStringLiteral("3s"), .secs = 3 },
        .{ .id = IDM_DURATION_5S, .label = std.unicode.utf8ToUtf16LeStringLiteral("5s"), .secs = 5 },
        .{ .id = IDM_DURATION_10S, .label = std.unicode.utf8ToUtf16LeStringLiteral("10s"), .secs = 10 },
        .{ .id = IDM_DURATION_30S, .label = std.unicode.utf8ToUtf16LeStringLiteral("30s"), .secs = 30 },
    };
    for (dur_items) |item| {
        const flags: UINT = MF_STRING | (if (g_block_duration_secs == item.secs) MF_CHECKED else @as(UINT, 0));
        _ = AppendMenuW(dur_submenu, flags, item.id, item.label);
    }

    // Build position submenu
    const pos_items = [_]struct { id: UINT, label: [*:0]const u16, pos: NotifPosition }{
        .{ .id = IDM_POS_TOP_LEFT, .label = std.unicode.utf8ToUtf16LeStringLiteral("Top-Left"), .pos = .top_left },
        .{ .id = IDM_POS_TOP_RIGHT, .label = std.unicode.utf8ToUtf16LeStringLiteral("Top-Right"), .pos = .top_right },
        .{ .id = IDM_POS_BOTTOM_LEFT, .label = std.unicode.utf8ToUtf16LeStringLiteral("Bottom-Left"), .pos = .bottom_left },
        .{ .id = IDM_POS_BOTTOM_RIGHT, .label = std.unicode.utf8ToUtf16LeStringLiteral("Bottom-Right"), .pos = .bottom_right },
    };
    for (pos_items) |item| {
        const flags: UINT = MF_STRING | (if (g_current_position == item.pos) MF_CHECKED else @as(UINT, 0));
        _ = AppendMenuW(pos_submenu, flags, item.id, item.label);
    }

    // Build scale submenu
    const scale_items = [_]struct { id: UINT, label: [*:0]const u16, scale: NotifScale }{
        .{ .id = IDM_SCALE_1X, .label = std.unicode.utf8ToUtf16LeStringLiteral("1x"), .scale = .x1 },
        .{ .id = IDM_SCALE_1_5X, .label = std.unicode.utf8ToUtf16LeStringLiteral("1.5x"), .scale = .x1_5 },
        .{ .id = IDM_SCALE_2X, .label = std.unicode.utf8ToUtf16LeStringLiteral("2x"), .scale = .x2 },
        .{ .id = IDM_SCALE_3X, .label = std.unicode.utf8ToUtf16LeStringLiteral("3x"), .scale = .x3 },
        .{ .id = IDM_SCALE_4X, .label = std.unicode.utf8ToUtf16LeStringLiteral("4x"), .scale = .x4 },
    };
    for (scale_items) |item| {
        const flags: UINT = MF_STRING | (if (g_current_scale == item.scale) MF_CHECKED else @as(UINT, 0));
        _ = AppendMenuW(scale_submenu, flags, item.id, item.label);
    }

    // Build override key submenu
    const key_items = [_]struct { id: UINT, label: [*:0]const u16, key: OverrideKey }{
        .{ .id = IDM_KEY_RCTRL, .label = std.unicode.utf8ToUtf16LeStringLiteral("RCtrl"), .key = .right_ctrl },
        .{ .id = IDM_KEY_RALT, .label = std.unicode.utf8ToUtf16LeStringLiteral("RAlt"), .key = .right_alt },
        .{ .id = IDM_KEY_RSHIFT, .label = std.unicode.utf8ToUtf16LeStringLiteral("RShift"), .key = .right_shift },
        .{ .id = IDM_KEY_F12, .label = std.unicode.utf8ToUtf16LeStringLiteral("F12"), .key = .f12 },
    };
    for (key_items) |item| {
        const flags: UINT = MF_STRING | (if (g_current_key == item.key) MF_CHECKED else @as(UINT, 0));
        _ = AppendMenuW(key_submenu, flags, item.id, item.label);
    }

    // Build main menu
    const notif_flags: UINT = MF_STRING | (if (g_notif_enabled) MF_CHECKED else @as(UINT, 0));
    _ = AppendMenuW(menu, notif_flags, IDM_TOGGLE_NOTIF, std.unicode.utf8ToUtf16LeStringLiteral("Notifications"));

    const block_flags: UINT = MF_STRING | (if (g_block_enabled) MF_CHECKED else @as(UINT, 0));
    _ = AppendMenuW(menu, block_flags, IDM_TOGGLE_BLOCK, std.unicode.utf8ToUtf16LeStringLiteral("Paste Protection"));

    const paste_resets_flags: UINT = MF_STRING | (if (g_paste_resets) MF_CHECKED else @as(UINT, 0));
    _ = AppendMenuW(menu, paste_resets_flags, IDM_PASTE_RESETS, std.unicode.utf8ToUtf16LeStringLiteral("Paste Resets Timer"));

    _ = AppendMenuW(menu, MF_SEPARATOR, 0, null);

    // Duration submenu label depends on current value
    const dur_label = switch (g_block_duration_secs) {
        1 => std.unicode.utf8ToUtf16LeStringLiteral("Block after: 1s"),
        3 => std.unicode.utf8ToUtf16LeStringLiteral("Block after: 3s"),
        5 => std.unicode.utf8ToUtf16LeStringLiteral("Block after: 5s"),
        10 => std.unicode.utf8ToUtf16LeStringLiteral("Block after: 10s"),
        30 => std.unicode.utf8ToUtf16LeStringLiteral("Block after: 30s"),
        else => std.unicode.utf8ToUtf16LeStringLiteral("Block after: 3s"),
    };
    _ = AppendMenuW(menu, MF_STRING | MF_POPUP, @intFromPtr(dur_submenu), dur_label);

    _ = AppendMenuW(menu, MF_STRING | MF_POPUP, @intFromPtr(pos_submenu), std.unicode.utf8ToUtf16LeStringLiteral("Position"));
    _ = AppendMenuW(menu, MF_STRING | MF_POPUP, @intFromPtr(scale_submenu), std.unicode.utf8ToUtf16LeStringLiteral("Scale"));
    _ = AppendMenuW(menu, MF_STRING | MF_POPUP, @intFromPtr(key_submenu), std.unicode.utf8ToUtf16LeStringLiteral("Override Key"));

    _ = AppendMenuW(menu, MF_SEPARATOR, 0, null);
    _ = AppendMenuW(menu, MF_STRING, IDM_QUIT, std.unicode.utf8ToUtf16LeStringLiteral("Quit"));

    // Show context menu
    var pt: POINT = undefined;
    _ = GetCursorPos(&pt);
    _ = SetForegroundWindow(hwnd);

    const cmd = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON, pt.x, pt.y, 0, hwnd, null);
    // TrackPopupMenu with TPM_RETURNCMD returns the menu item ID as a BOOL-typed value
    const cmd_raw: c_int = @intFromEnum(cmd);
    const cmd_id: UINT = @intCast(cmd_raw);

    _ = DestroyMenu(key_submenu);
    _ = DestroyMenu(scale_submenu);
    _ = DestroyMenu(pos_submenu);
    _ = DestroyMenu(dur_submenu);
    _ = DestroyMenu(menu);

    // Post WM_NULL to dismiss the menu properly
    _ = PostMessageW(hwnd, 0, 0, 0);

    // Handle the selected command
    switch (cmd_id) {
        IDM_TOGGLE_NOTIF => {
            g_notif_enabled = !g_notif_enabled;
            g_event_queue.push(.tray_toggle_notif);
        },
        IDM_TOGGLE_BLOCK => {
            g_block_enabled = !g_block_enabled;
            g_event_queue.push(.tray_toggle_block);
        },
        IDM_PASTE_RESETS => {
            g_paste_resets = !g_paste_resets;
            g_event_queue.push(.tray_toggle_paste_resets);
        },
        IDM_QUIT => g_event_queue.push(.tray_quit),
        IDM_DURATION_1S => {
            g_block_duration_secs = 1;
            g_event_queue.push(.tray_duration_1s);
        },
        IDM_DURATION_3S => {
            g_block_duration_secs = 3;
            g_event_queue.push(.tray_duration_3s);
        },
        IDM_DURATION_5S => {
            g_block_duration_secs = 5;
            g_event_queue.push(.tray_duration_5s);
        },
        IDM_DURATION_10S => {
            g_block_duration_secs = 10;
            g_event_queue.push(.tray_duration_10s);
        },
        IDM_DURATION_30S => {
            g_block_duration_secs = 30;
            g_event_queue.push(.tray_duration_30s);
        },
        IDM_POS_TOP_LEFT => {
            g_current_position = .top_left;
            g_event_queue.push(.tray_pos_top_left);
        },
        IDM_POS_TOP_RIGHT => {
            g_current_position = .top_right;
            g_event_queue.push(.tray_pos_top_right);
        },
        IDM_POS_BOTTOM_LEFT => {
            g_current_position = .bottom_left;
            g_event_queue.push(.tray_pos_bottom_left);
        },
        IDM_POS_BOTTOM_RIGHT => {
            g_current_position = .bottom_right;
            g_event_queue.push(.tray_pos_bottom_right);
        },
        IDM_SCALE_1X => {
            g_current_scale = .x1;
            g_event_queue.push(.tray_scale_1x);
        },
        IDM_SCALE_1_5X => {
            g_current_scale = .x1_5;
            g_event_queue.push(.tray_scale_1_5x);
        },
        IDM_SCALE_2X => {
            g_current_scale = .x2;
            g_event_queue.push(.tray_scale_2x);
        },
        IDM_SCALE_3X => {
            g_current_scale = .x3;
            g_event_queue.push(.tray_scale_3x);
        },
        IDM_SCALE_4X => {
            g_current_scale = .x4;
            g_event_queue.push(.tray_scale_4x);
        },
        IDM_KEY_RCTRL => {
            g_current_key = .right_ctrl;
            g_event_queue.push(.tray_key_rctrl);
        },
        IDM_KEY_RALT => {
            g_current_key = .right_alt;
            g_event_queue.push(.tray_key_ralt);
        },
        IDM_KEY_RSHIFT => {
            g_current_key = .right_shift;
            g_event_queue.push(.tray_key_rshift);
        },
        IDM_KEY_F12 => {
            g_current_key = .f12;
            g_event_queue.push(.tray_key_f12);
        },
        else => {},
    }
}

fn wndProc(hwnd: HWND, msg: UINT, wparam: WPARAM, lparam: LPARAM) callconv(.c) LRESULT {
    switch (msg) {
        WM_CLIPBOARDUPDATE => {
            if (g_suppress_next_clipboard) {
                g_suppress_next_clipboard = false;
            } else {
                g_event_queue.push(.copy_detected);
            }
            return 0;
        },
        WM_TRAYICON => {
            const mouse_msg: UINT = @intCast(@as(u32, @truncate(@as(usize, @bitCast(lparam)))));
            if (mouse_msg == WM_RBUTTONUP or mouse_msg == WM_LBUTTONUP) {
                showTrayMenu(hwnd);
            }
            return 0;
        },
        else => return DefWindowProcW(hwnd, msg, wparam, lparam),
    }
}

pub fn pollEvent(ctx: *Context) !Event {
    // Poll override key via GetAsyncKeyState (reliable for modifier keys)
    const key_state = GetAsyncKeyState(ctx.override_vk);
    const is_down = (key_state & @as(c_short, @bitCast(@as(u16, 0x8000)))) != 0;
    if (is_down and !ctx.override_key_was_down) {
        ctx.override_key_was_down = true;
        return .override_key_pressed;
    }
    ctx.override_key_was_down = is_down;

    // Detect Ctrl+V paste attempts
    const ctrl_down = (GetAsyncKeyState(VK_CONTROL) & @as(c_short, @bitCast(@as(u16, 0x8000)))) != 0;
    const v_down = (GetAsyncKeyState(VK_V) & @as(c_short, @bitCast(@as(u16, 0x8000)))) != 0;
    const paste_down = ctrl_down and v_down;
    if (paste_down and !ctx.paste_key_was_down) {
        ctx.paste_key_was_down = true;
        return .paste_attempted;
    }
    ctx.paste_key_was_down = paste_down;

    // Drain Windows message queue into our event queue
    var msg: MSG = undefined;
    while (PeekMessageW(&msg, null, 0, 0, PM_REMOVE) != .FALSE) {
        _ = TranslateMessage(&msg);
        _ = DispatchMessageW(&msg);
    }
    return g_event_queue.pop();
}

pub fn getClipboardContent(ctx: *Context) !?[]const u8 {
    _ = ctx;
    if (OpenClipboard(null) == .FALSE) return null;
    defer _ = CloseClipboard();

    const handle = GetClipboardData(CF_UNICODETEXT) orelse return null;
    const ptr = GlobalLock(handle) orelse return null;
    defer _ = GlobalUnlock(handle);

    const size = GlobalSize(handle);
    if (size == 0) return null;

    // Return raw bytes — caller handles as opaque blob
    return ptr[0..size];
}

fn freeSavedFormats(ctx: *Context) void {
    for (ctx.saved_formats[0..ctx.saved_format_count]) |*sf| {
        if (sf.data) |d| {
            _ = GlobalFree(d);
            sf.data = null;
        }
    }
    ctx.saved_format_count = 0;
}

pub fn clearClipboard(ctx: *Context) !void {
    if (!openClipboardRetry()) return error.OpenClipboardFailed;

    // Save current clipboard formats into a temp array
    var new_formats: [16]SavedFormat = [_]SavedFormat{.{}} ** 16;
    var count: u32 = 0;
    var fmt: UINT = EnumClipboardFormats(0);
    while (fmt != 0 and count < 16) {
        // Skip non-memory formats (GDI bitmap/metafile/palette/enhmetafile handles)
        if (fmt == 2 or fmt == 9 or fmt == 3 or fmt == 14) {
            fmt = EnumClipboardFormats(fmt);
            continue;
        }
        const src_handle = GetClipboardData(fmt) orelse {
            fmt = EnumClipboardFormats(fmt);
            continue;
        };
        const size = GlobalSize(src_handle);
        if (size > 0 and size < 16 * 1024 * 1024) {
            const src_ptr = GlobalLock(src_handle);
            if (src_ptr) |sp| {
                const dst = GlobalAlloc(GMEM_MOVEABLE, size);
                if (dst) |d| {
                    const dp = GlobalLock(d);
                    if (dp) |dest_ptr| {
                        @memcpy(dest_ptr[0..size], sp[0..size]);
                        _ = GlobalUnlock(d);
                        new_formats[count] = .{ .format = fmt, .data = d };
                        count += 1;
                    } else {
                        _ = GlobalFree(d);
                    }
                }
                _ = GlobalUnlock(src_handle);
            }
        }
        fmt = EnumClipboardFormats(fmt);
    }

    g_suppress_next_clipboard = true;
    _ = EmptyClipboard();
    _ = CloseClipboard();

    // Only replace saved formats after successful save+clear
    if (count > 0) {
        freeSavedFormats(ctx);
        ctx.saved_formats = new_formats;
        ctx.saved_format_count = count;
    }
    // If count == 0 (clipboard was empty/unreadable), keep existing saved formats
}

pub fn restoreClipboard(ctx: *Context, _: []const u8) !void {
    if (ctx.saved_format_count == 0) return;

    g_suppress_next_clipboard = true;
    if (!openClipboardRetry()) {
        g_suppress_next_clipboard = false;
        return error.OpenClipboardFailed;
    }
    _ = EmptyClipboard();

    // Copy saved data into new handles for the clipboard (keep originals for future restores)
    for (ctx.saved_formats[0..ctx.saved_format_count]) |sf| {
        const src_handle = sf.data orelse continue;
        const size = GlobalSize(src_handle);
        if (size == 0) continue;
        const src_ptr = GlobalLock(src_handle) orelse continue;
        defer _ = GlobalUnlock(src_handle);

        const dst = GlobalAlloc(GMEM_MOVEABLE, size) orelse continue;
        const dst_ptr = GlobalLock(dst) orelse {
            _ = GlobalFree(dst);
            continue;
        };
        @memcpy(dst_ptr[0..size], src_ptr[0..size]);
        _ = GlobalUnlock(dst);
        _ = SetClipboardData(sf.format, dst);
    }

    _ = CloseClipboard();
}

pub fn showOverlay(ctx: *Context, alpha: f32, y_offset: f32, x_offset: f32, kind: NotifKind) !void {
    const s: i32 = @intCast(ctx.overlay_size);
    const margin: i32 = 16;
    // Jitter only AWAY from the edge (inward), never off-screen
    const jitter_px: i32 = @intFromFloat(@abs(x_offset) * @as(f32, @floatFromInt(s)) * 0.5);

    const base_x: i32 = switch (ctx.notif_position) {
        .top_right, .bottom_right => ctx.screen_width - s - margin - jitter_px,
        .top_left, .bottom_left => margin + jitter_px,
    };
    const base_y: i32 = switch (ctx.notif_position) {
        .top_right, .top_left => margin,
        .bottom_right, .bottom_left => ctx.screen_height - s - margin,
    };
    // y_offset goes from 0 to -40. For top positions, add offset (moves up/away).
    // For bottom positions, subtract offset (moves down/away).
    const y: i32 = switch (ctx.notif_position) {
        .top_right, .top_left => base_y - @as(i32, @intFromFloat(y_offset)),
        .bottom_right, .bottom_left => base_y + @as(i32, @intFromFloat(y_offset)),
    };

    _ = MoveWindow(ctx.overlay_window, base_x, y, s, s, .FALSE);

    // Render into a correctly-strided local buffer, then copy rows to the DIB
    // (DIB stride is fixed at 192 but overlay_size may be smaller)
    const sz_u = ctx.overlay_size;
    var local_pixels: [192 * 192 * 4]u8 = undefined;
    render.renderNotification(&local_pixels, sz_u, alpha, kind);

    if (ctx.pixels) |dib_pixels| {
        const dib_stride: u32 = 192 * 4;
        const src_stride: u32 = sz_u * 4;
        for (0..sz_u) |row| {
            const dst_off = row * dib_stride;
            const src_off = row * src_stride;
            @memcpy(dib_pixels[dst_off..][0..src_stride], local_pixels[src_off..][0..src_stride]);
        }
    }

    if (!ctx.overlay_visible) {
        _ = ShowWindow(ctx.overlay_window, 8); // SW_SHOWNA
        ctx.overlay_visible = true;
    }

    var pt_src: POINT = .{ .x = 0, .y = 0 };
    var sz: SIZE = .{ .cx = s, .cy = s };
    var blend: BLENDFUNCTION = .{
        .SourceConstantAlpha = @intFromFloat(alpha * 255.0),
    };
    _ = UpdateLayeredWindow(ctx.overlay_window, null, null, &sz, ctx.mem_dc, &pt_src, 0, &blend, ULW_ALPHA);
}

fn openClipboardRetry() bool {
    for (0..10) |_| {
        if (OpenClipboard(null) != .FALSE) return true;
        Sleep(1);
    }
    return false;
}

const StackEntry = @import("../core/notifier.zig").Notifier.StackEntry;
const DIB_W: u32 = 240;
const DIB_H: u32 = 960;

pub fn showOverlayStack(ctx: *Context, entries: *const [8]?StackEntry, config: Config) !void {
    const s = ctx.overlay_size;
    const si: i32 = @intCast(s);
    const margin: i32 = 16;

    // Count active entries and find bounding box
    var count: u32 = 0;
    var min_y_off: f32 = 0;
    var max_jitter: f32 = 0;
    for (entries) |maybe| {
        if (maybe) |e| {
            count += 1;
            if (e.y_offset < min_y_off) min_y_off = e.y_offset;
            if (@abs(e.x_offset) > max_jitter) max_jitter = @abs(e.x_offset);
        }
    }
    if (count == 0) return;

    const jitter_max: i32 = @intFromFloat(max_jitter * @as(f32, @floatFromInt(si)) * 0.5);
    const travel: i32 = @intFromFloat(@abs(min_y_off));
    const strip_w: i32 = si + jitter_max;
    const strip_h: i32 = si + travel;

    // Position the strip window
    const strip_x: i32 = switch (config.notif_position) {
        .top_right, .bottom_right => ctx.screen_width - strip_w - margin,
        .top_left, .bottom_left => margin,
    };
    const strip_y: i32 = switch (config.notif_position) {
        .top_right, .top_left => margin,
        .bottom_right, .bottom_left => ctx.screen_height - strip_h - margin,
    };

    _ = MoveWindow(ctx.overlay_window, strip_x, strip_y, strip_w, strip_h, .FALSE);

    // Clear DIB
    if (ctx.pixels) |dib| {
        const clear_bytes = @min(DIB_W * @as(u32, @intCast(strip_h)) * 4, DIB_W * DIB_H * 4);
        @memset(dib[0..clear_bytes], 0);

        // Render each icon into a temp buffer, then blit to the DIB
        var icon_buf: [192 * 192 * 4]u8 = undefined;

        for (entries) |maybe| {
            const e = maybe orelse continue;
            render.renderNotification(&icon_buf, s, e.alpha, e.kind);

            const jitter_px: u32 = @intFromFloat(@abs(e.x_offset) * @as(f32, @floatFromInt(si)) * 0.5);

            // x position: jitter inward from edge
            const icon_x: u32 = switch (config.notif_position) {
                .top_right, .bottom_right => @intCast(@as(i32, @intCast(jitter_max)) - @as(i32, @intCast(jitter_px))),
                .top_left, .bottom_left => jitter_px,
            };

            // y position based on y_offset within the strip
            const icon_y: u32 = switch (config.notif_position) {
                .top_right, .top_left => @intCast(@max(0, -@as(i32, @intFromFloat(e.y_offset)))),
                .bottom_right, .bottom_left => @intCast(@max(0, travel + @as(i32, @intFromFloat(e.y_offset)))),
            };

            // Blit icon into DIB
            for (0..s) |row| {
                const dy = icon_y + @as(u32, @intCast(row));
                if (dy >= @as(u32, @intCast(strip_h)) or dy >= DIB_H) break;
                const dx_start = icon_x;
                const dx_end = @min(icon_x + s, @min(@as(u32, @intCast(strip_w)), DIB_W));
                if (dx_start >= dx_end) continue;
                const w = dx_end - dx_start;

                const src_off = row * s * 4;
                const dst_off = dy * DIB_W * 4 + dx_start * 4;

                // Alpha-composite each pixel
                for (0..w) |col| {
                    const si_off = src_off + col * 4;
                    const di_off = dst_off + col * 4;
                    const sa = icon_buf[si_off + 3];
                    if (sa == 0) continue;
                    if (dib[di_off + 3] == 0) {
                        dib[di_off + 0] = icon_buf[si_off + 0];
                        dib[di_off + 1] = icon_buf[si_off + 1];
                        dib[di_off + 2] = icon_buf[si_off + 2];
                        dib[di_off + 3] = sa;
                    } else {
                        const inv = 255 - @as(u16, sa);
                        dib[di_off + 0] = @intCast((@as(u16, icon_buf[si_off + 0]) * 255 + @as(u16, dib[di_off + 0]) * inv) / 255);
                        dib[di_off + 1] = @intCast((@as(u16, icon_buf[si_off + 1]) * 255 + @as(u16, dib[di_off + 1]) * inv) / 255);
                        dib[di_off + 2] = @intCast((@as(u16, icon_buf[si_off + 2]) * 255 + @as(u16, dib[di_off + 2]) * inv) / 255);
                        dib[di_off + 3] = @intCast(@min(255, @as(u16, dib[di_off + 3]) + @as(u16, sa) * (255 - @as(u16, dib[di_off + 3])) / 255));
                    }
                }
            }
        }
    }

    if (!ctx.overlay_visible) {
        _ = ShowWindow(ctx.overlay_window, 8);
        ctx.overlay_visible = true;
    }

    var pt_src: POINT = .{ .x = 0, .y = 0 };
    var sz: SIZE = .{ .cx = @min(strip_w, @as(i32, DIB_W)), .cy = @min(strip_h, @as(i32, DIB_H)) };
    var blend: BLENDFUNCTION = .{ .SourceConstantAlpha = 255 };
    _ = UpdateLayeredWindow(ctx.overlay_window, null, null, &sz, ctx.mem_dc, &pt_src, 0, &blend, ULW_ALPHA);
}

pub fn hideOverlay(ctx: *Context) !void {
    if (ctx.overlay_visible) {
        _ = ShowWindow(ctx.overlay_window, 0); // SW_HIDE
        ctx.overlay_visible = false;
    }
}

pub fn updateConfig(ctx: *Context, config: Config) void {
    ctx.overlay_size = config.notif_scale.size();
    ctx.notif_position = config.notif_position;
    // Update global state for menu checkmarks
    g_notif_enabled = config.notif_enabled;
    g_block_enabled = config.block_enabled;
    g_paste_resets = config.paste_resets_timer;
    g_current_position = config.notif_position;
    g_current_scale = config.notif_scale;
    g_current_key = config.override_key;
    g_block_duration_secs = config.block_duration_ms / 1000;
}

pub fn getFd(_: *const Context) ?i32 {
    return null;
}

// Helpers called from main.zig event loop
pub fn peekMessage() bool {
    var msg: MSG = undefined;
    if (PeekMessageW(&msg, null, 0, 0, PM_REMOVE) != .FALSE) {
        _ = TranslateMessage(&msg);
        _ = DispatchMessageW(&msg);
        return true;
    }
    return false;
}

pub fn sleep(ms: u32) void {
    Sleep(ms);
}
