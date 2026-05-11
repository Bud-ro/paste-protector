const std = @import("std");
const builtin = @import("builtin");
const win = @import("../platform/windows.zig");
const Config = @import("../config.zig").Config;
const Event = @import("../platform/platform.zig").Event;

// These tests exercise the Windows clipboard save/restore logic.
// They call the real Win32 APIs so they must run on Windows.

test "clipboard round-trip: text survives clear and restore" {
    if (builtin.os.tag != .windows) return error.SkipZigTest;

    var ctx = try win.init(Config{});
    defer win.deinit(&ctx);

    // Put text on clipboard via public API (simulating a user copy)
    setClipboardText("paste-protector test data");

    // Clear (internally saves all formats)
    try win.clearClipboard(&ctx);

    // Clipboard should now be empty
    try std.testing.expect(!clipboardHasText());

    // Restore
    try win.restoreClipboard(&ctx, "");

    // Clipboard should have text again
    try std.testing.expect(clipboardHasText());
}

test "clipboard round-trip: survives 5 clear/restore cycles" {
    if (builtin.os.tag != .windows) return error.SkipZigTest;

    var ctx = try win.init(Config{});
    defer win.deinit(&ctx);

    setClipboardText("cycle data");

    for (0..5) |_| {
        try win.clearClipboard(&ctx);
        try std.testing.expect(!clipboardHasText());
        try win.restoreClipboard(&ctx, "");
        try std.testing.expect(clipboardHasText());
    }
}

test "clearClipboard on empty clipboard preserves saved data for restore" {
    if (builtin.os.tag != .windows) return error.SkipZigTest;

    var ctx = try win.init(Config{});
    defer win.deinit(&ctx);

    setClipboardText("preserved");

    // First clear saves the data
    try win.clearClipboard(&ctx);

    // Second clear finds empty clipboard — should NOT destroy saved data
    try win.clearClipboard(&ctx);

    // Restore should still work
    try win.restoreClipboard(&ctx, "");
    try std.testing.expect(clipboardHasText());
}

test "restoreClipboard is idempotent" {
    if (builtin.os.tag != .windows) return error.SkipZigTest;

    var ctx = try win.init(Config{});
    defer win.deinit(&ctx);

    setClipboardText("idempotent");
    try win.clearClipboard(&ctx);

    // Restore multiple times — all should succeed
    try win.restoreClipboard(&ctx, "");
    try std.testing.expect(clipboardHasText());
    try win.restoreClipboard(&ctx, "");
    try std.testing.expect(clipboardHasText());
    try win.restoreClipboard(&ctx, "");
    try std.testing.expect(clipboardHasText());
}

test "full override key cycle simulation" {
    if (builtin.os.tag != .windows) return error.SkipZigTest;

    var ctx = try win.init(Config{});
    defer win.deinit(&ctx);

    // Simulate: user copies → timer fires (clear) → user presses RCtrl (restore)
    // → timer fires again (clear) → user presses RCtrl again (restore)
    setClipboardText("secret password");

    // Timer fires: save+clear
    try win.clearClipboard(&ctx);
    try std.testing.expect(!clipboardHasText());

    // RCtrl: restore
    try win.restoreClipboard(&ctx, "");
    try std.testing.expect(clipboardHasText());

    // Timer fires again: re-save from clipboard + clear
    try win.clearClipboard(&ctx);
    try std.testing.expect(!clipboardHasText());

    // RCtrl again: restore from re-saved data
    try win.restoreClipboard(&ctx, "");
    try std.testing.expect(clipboardHasText());
}

// Helpers using Win32 directly
extern "user32" fn OpenClipboard(hWndNewOwner: ?std.os.windows.HWND) callconv(.c) std.os.windows.BOOL;
extern "user32" fn CloseClipboard() callconv(.c) std.os.windows.BOOL;
extern "user32" fn EmptyClipboard() callconv(.c) std.os.windows.BOOL;
extern "user32" fn GetClipboardData(uFormat: c_uint) callconv(.c) ?std.os.windows.HANDLE;
extern "user32" fn SetClipboardData(uFormat: c_uint, hMem: ?std.os.windows.HANDLE) callconv(.c) ?std.os.windows.HANDLE;
extern "kernel32" fn GlobalAlloc(uFlags: c_uint, dwBytes: usize) callconv(.c) ?std.os.windows.HANDLE;
extern "kernel32" fn GlobalLock(hMem: std.os.windows.HANDLE) callconv(.c) ?[*]u8;
extern "kernel32" fn GlobalUnlock(hMem: std.os.windows.HANDLE) callconv(.c) std.os.windows.BOOL;

const CF_UNICODETEXT: c_uint = 13;
const GMEM_MOVEABLE: c_uint = 0x0002;

fn setClipboardText(text: []const u8) void {
    if (OpenClipboard(null) == .FALSE) return;
    _ = EmptyClipboard();
    const size = (text.len + 1) * 2; // UTF-16 + null
    const hmem = GlobalAlloc(GMEM_MOVEABLE, size) orelse {
        _ = CloseClipboard();
        return;
    };
    const ptr = GlobalLock(hmem) orelse {
        _ = CloseClipboard();
        return;
    };
    // Simple ASCII to UTF-16LE
    for (text, 0..) |ch, i| {
        ptr[i * 2] = ch;
        ptr[i * 2 + 1] = 0;
    }
    ptr[text.len * 2] = 0;
    ptr[text.len * 2 + 1] = 0;
    _ = GlobalUnlock(hmem);
    _ = SetClipboardData(CF_UNICODETEXT, hmem);
    _ = CloseClipboard();
}

fn clipboardHasText() bool {
    for (0..10) |_| {
        if (OpenClipboard(null) != .FALSE) {
            defer _ = CloseClipboard();
            return GetClipboardData(CF_UNICODETEXT) != null;
        }
        Sleep(1);
    }
    return false;
}

extern "kernel32" fn Sleep(dwMilliseconds: u32) callconv(.c) void;
