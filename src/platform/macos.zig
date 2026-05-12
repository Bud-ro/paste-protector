const std = @import("std");
const builtin = @import("builtin");
const Config = @import("../config.zig").Config;
const NotifKind = @import("../core/notifier.zig").NotifKind;
const NotifPosition = @import("../config.zig").NotifPosition;
const Event = @import("platform.zig").Event;

// Objective-C runtime types
const id = *anyopaque;
const SEL = *anyopaque;
const Class = *anyopaque;
const ObjcBool = i8;
const NSInteger = isize;
const NSUInteger = usize;
const CGFloat = f64;

const NSRect = extern struct {
    x: CGFloat,
    y: CGFloat,
    width: CGFloat,
    height: CGFloat,
};

// Objective-C runtime functions
extern "objc" fn objc_getClass(name: [*:0]const u8) callconv(.c) ?Class;
extern "objc" fn sel_registerName(name: [*:0]const u8) callconv(.c) SEL;
extern "objc" fn objc_msgSend() callconv(.c) void;
extern "objc" fn objc_allocateClassPair(superclass: Class, name: [*:0]const u8, extra_bytes: usize) callconv(.c) ?Class;
extern "objc" fn objc_registerClassPair(cls: Class) callconv(.c) void;
extern "objc" fn class_addMethod(cls: Class, name: SEL, imp: *const anyopaque, types: [*:0]const u8) callconv(.c) ObjcBool;

// Typed objc_msgSend wrappers via function pointer casts
fn send(target: anytype, sel: SEL) id {
    const f: *const fn (@TypeOf(target), SEL) callconv(.c) id = @ptrCast(&objc_msgSend);
    return f(target, sel);
}

fn sendI(target: anytype, sel: SEL) NSInteger {
    const f: *const fn (@TypeOf(target), SEL) callconv(.c) NSInteger = @ptrCast(&objc_msgSend);
    return f(target, sel);
}

fn sendV(target: anytype, sel: SEL) void {
    const f: *const fn (@TypeOf(target), SEL) callconv(.c) void = @ptrCast(&objc_msgSend);
    return f(target, sel);
}

fn send1(comptime R: type, target: anytype, sel: SEL, a1: anytype) R {
    const f: *const fn (@TypeOf(target), SEL, @TypeOf(a1)) callconv(.c) R = @ptrCast(&objc_msgSend);
    return f(target, sel, a1);
}

fn send2(comptime R: type, target: anytype, sel: SEL, a1: anytype, a2: anytype) R {
    const f: *const fn (@TypeOf(target), SEL, @TypeOf(a1), @TypeOf(a2)) callconv(.c) R = @ptrCast(&objc_msgSend);
    return f(target, sel, a1, a2);
}

fn send3(comptime R: type, target: anytype, sel: SEL, a1: anytype, a2: anytype, a3: anytype) R {
    const f: *const fn (@TypeOf(target), SEL, @TypeOf(a1), @TypeOf(a2), @TypeOf(a3)) callconv(.c) R = @ptrCast(&objc_msgSend);
    return f(target, sel, a1, a2, a3);
}

fn send4(comptime R: type, target: anytype, sel: SEL, a1: anytype, a2: anytype, a3: anytype, a4: anytype) R {
    const f: *const fn (@TypeOf(target), SEL, @TypeOf(a1), @TypeOf(a2), @TypeOf(a3), @TypeOf(a4)) callconv(.c) R = @ptrCast(&objc_msgSend);
    return f(target, sel, a1, a2, a3, a4);
}

// For methods returning NSRect (stret on some ABIs)
extern "objc" fn objc_msgSend_stret() callconv(.c) void;

fn sendRect(target: anytype, sel: SEL) NSRect {
    // On arm64 macOS, structs <= 4 registers are returned normally
    if (builtin.cpu.arch == .aarch64) {
        const f: *const fn (@TypeOf(target), SEL) callconv(.c) NSRect = @ptrCast(&objc_msgSend);
        return f(target, sel);
    } else {
        // x86_64 uses stret for large structs
        var result: NSRect = undefined;
        const f: *const fn (*NSRect, @TypeOf(target), SEL) callconv(.c) void = @ptrCast(&objc_msgSend_stret);
        f(&result, target, sel);
        return result;
    }
}

// CoreGraphics event tap
const CGEventMask = u64;
const CGEventType = u32;
const CGEventRef = ?*anyopaque;
const CFMachPortRef = ?*anyopaque;
const CFRunLoopSourceRef = ?*anyopaque;
const CFRunLoopRef = ?*anyopaque;

const kCGSessionEventTap: u32 = 1;
const kCGHeadInsertEventTap: u32 = 0;
const kCGEventTapOptionListenOnly: u32 = 1;
const kCGEventKeyDown: CGEventType = 10;
const kCGEventFlagsChanged: CGEventType = 12;

const kVK_RightControl: u16 = 0x3E;
const kVK_RightOption: u16 = 0x3D;
const kVK_RightShift: u16 = 0x3C;
const kVK_F12: u16 = 0x6F;

extern "CoreGraphics" fn CGEventTapCreate(tap: u32, place: u32, options: u32, eventsOfInterest: CGEventMask, callback: *const fn (?*anyopaque, CGEventType, CGEventRef, ?*anyopaque) callconv(.c) CGEventRef, userInfo: ?*anyopaque) callconv(.c) CFMachPortRef;
extern "CoreGraphics" fn CGEventGetIntegerValueField(event: CGEventRef, field: u32) callconv(.c) i64;
extern "CoreFoundation" fn CFMachPortCreateRunLoopSource(allocator: ?*anyopaque, port: CFMachPortRef, order: i64) callconv(.c) CFRunLoopSourceRef;
extern "CoreFoundation" fn CFRunLoopGetCurrent() callconv(.c) CFRunLoopRef;
extern "CoreFoundation" fn CFRunLoopAddSource(rl: CFRunLoopRef, source: CFRunLoopSourceRef, mode: ?*anyopaque) callconv(.c) void;
extern "CoreFoundation" fn CFRunLoopRunInMode(mode: ?*anyopaque, seconds: f64, returnAfterSourceHandled: u8) callconv(.c) i32;

// System library
extern "System" fn usleep(usec: u32) callconv(.c) c_int;

// Globals for event tap callback
var g_event_queue: EventQueue = .{};
var g_override_keycode: u16 = kVK_RightControl;

// Menu bar globals
var g_last_menu_action: u32 = 0;
pub var g_notif_enabled: bool = true;
pub var g_block_enabled: bool = true;

// Menu item tags (matching Windows constants)
const TAG_NOTIF: NSInteger = 1001;
const TAG_BLOCK: NSInteger = 1002;
const TAG_QUIT: NSInteger = 1003;
const TAG_DUR_1S: NSInteger = 1010;
const TAG_DUR_3S: NSInteger = 1011;
const TAG_DUR_5S: NSInteger = 1012;
const TAG_DUR_10S: NSInteger = 1013;
const TAG_DUR_30S: NSInteger = 1014;

// Menu item references for updating checkmarks
var g_menu_item_notif: ?id = null;
var g_menu_item_block: ?id = null;
var g_menu_item_dur: [5]?id = .{ null, null, null, null, null };
var g_current_duration_tag: NSInteger = TAG_DUR_3S;

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
    pasteboard: id,
    last_change_count: NSInteger,
    overlay_window: id,
    overlay_visible: bool = false,
    screen_width: CGFloat,
    screen_height: CGFloat,
    notif_position: NotifPosition,
    app: id,
    status_item: id,
};

fn menuActionImpl(_self: id, _sel: SEL, sender: id) callconv(.c) void {
    _ = _self;
    _ = _sel;
    const tag: NSInteger = sendI(sender, sel_registerName("tag"));
    if (tag > 0) {
        g_last_menu_action = @intCast(@as(usize, @bitCast(tag)));
    }
}

fn createMenuBar(app: id) id {
    _ = app;
    const NSStatusBar = objc_getClass("NSStatusBar") orelse unreachable;
    const NSMenu = objc_getClass("NSMenu") orelse unreachable;
    const NSMenuItem = objc_getClass("NSMenuItem") orelse unreachable;
    const NSObject = objc_getClass("NSObject") orelse unreachable;

    // Create a runtime class for handling menu actions
    const MenuHandler = objc_allocateClassPair(NSObject, "PasteProtectorMenuHandler", 0) orelse unreachable;
    _ = class_addMethod(
        MenuHandler,
        sel_registerName("menuAction:"),
        @as(*const anyopaque, @ptrCast(&menuActionImpl)),
        "v@:@",
    );
    objc_registerClassPair(MenuHandler);

    // Instantiate the handler
    const handler_alloc = send(MenuHandler, sel_registerName("alloc"));
    const handler = send(handler_alloc, sel_registerName("init"));

    // Get the system status bar
    const status_bar = send(NSStatusBar, sel_registerName("systemStatusBar"));
    const status_item = send1(id, status_bar, sel_registerName("statusItemWithLength:"), @as(CGFloat, -1.0)); // NSVariableStatusItemLength

    // Set the title
    const NSString = objc_getClass("NSString") orelse unreachable;
    const title = send1(id, NSString, sel_registerName("stringWithUTF8String:"), @as([*:0]const u8, "PP"));
    const button = send(status_item, sel_registerName("button"));
    _ = send1(void, button, sel_registerName("setTitle:"), title);

    // Create the menu
    const menu_alloc = send(NSMenu, sel_registerName("alloc"));
    const menu = send1(id, menu_alloc, sel_registerName("initWithTitle:"), send1(id, NSString, sel_registerName("stringWithUTF8String:"), @as([*:0]const u8, "")));

    const action_sel = sel_registerName("menuAction:");

    // "Notifications" (checkable)
    const notif_item = createMenuItem(NSMenuItem, "Notifications", action_sel, "", handler);
    _ = send1(void, notif_item, sel_registerName("setTag:"), TAG_NOTIF);
    _ = send1(void, notif_item, sel_registerName("setState:"), @as(NSInteger, 1)); // NSOnState
    _ = send1(void, menu, sel_registerName("addItem:"), notif_item);
    g_menu_item_notif = notif_item;

    // "Paste Protection" (checkable)
    const block_item = createMenuItem(NSMenuItem, "Paste Protection", action_sel, "", handler);
    _ = send1(void, block_item, sel_registerName("setTag:"), TAG_BLOCK);
    _ = send1(void, block_item, sel_registerName("setState:"), @as(NSInteger, 1)); // NSOnState
    _ = send1(void, menu, sel_registerName("addItem:"), block_item);
    g_menu_item_block = block_item;

    // Separator
    const sep1 = send(NSMenuItem, sel_registerName("separatorItem"));
    _ = send1(void, menu, sel_registerName("addItem:"), sep1);

    // "Block after: 3s" submenu
    const submenu_title_item = createMenuItem(NSMenuItem, "Block after: 3s", null, "", null);
    _ = send1(void, menu, sel_registerName("addItem:"), submenu_title_item);

    const submenu_alloc = send(NSMenu, sel_registerName("alloc"));
    const submenu = send1(id, submenu_alloc, sel_registerName("initWithTitle:"), send1(id, NSString, sel_registerName("stringWithUTF8String:"), @as([*:0]const u8, "")));

    const dur_labels = [_][*:0]const u8{ "1s", "3s", "5s", "10s", "30s" };
    const dur_tags = [_]NSInteger{ TAG_DUR_1S, TAG_DUR_3S, TAG_DUR_5S, TAG_DUR_10S, TAG_DUR_30S };

    for (dur_labels, 0..) |label, i| {
        const dur_item = createMenuItem(NSMenuItem, label, action_sel, "", handler);
        _ = send1(void, dur_item, sel_registerName("setTag:"), dur_tags[i]);
        if (dur_tags[i] == TAG_DUR_3S) {
            _ = send1(void, dur_item, sel_registerName("setState:"), @as(NSInteger, 1));
        }
        _ = send1(void, submenu, sel_registerName("addItem:"), dur_item);
        g_menu_item_dur[i] = dur_item;
    }

    _ = send1(void, submenu_title_item, sel_registerName("setSubmenu:"), submenu);

    // Separator
    const sep2 = send(NSMenuItem, sel_registerName("separatorItem"));
    _ = send1(void, menu, sel_registerName("addItem:"), sep2);

    // "Quit"
    const quit_item = createMenuItem(NSMenuItem, "Quit", action_sel, "q", handler);
    _ = send1(void, quit_item, sel_registerName("setTag:"), TAG_QUIT);
    _ = send1(void, menu, sel_registerName("addItem:"), quit_item);

    // Attach menu to status item
    _ = send1(void, status_item, sel_registerName("setMenu:"), menu);

    return status_item;
}

fn createMenuItem(NSMenuItem: Class, title: [*:0]const u8, action: ?SEL, key_equiv: [*:0]const u8, target: ?id) id {
    const NSString = objc_getClass("NSString") orelse unreachable;
    const title_str = send1(id, NSString, sel_registerName("stringWithUTF8String:"), title);
    const key_str = send1(id, NSString, sel_registerName("stringWithUTF8String:"), key_equiv);

    const alloc = send(NSMenuItem, sel_registerName("alloc"));
    const nil_sel: ?SEL = null;
    const item = send3(id, alloc, sel_registerName("initWithTitle:action:keyEquivalent:"), title_str, action orelse nil_sel, key_str);

    if (target) |t| {
        _ = send1(void, item, sel_registerName("setTarget:"), t);
    }

    return item;
}

pub fn init(config: Config) !Context {
    const NSApplication = objc_getClass("NSApplication") orelse return error.NoAppKit;
    const app = send(NSApplication, sel_registerName("sharedApplication"));
    _ = send1(ObjcBool, app, sel_registerName("setActivationPolicy:"), @as(NSInteger, 1));

    const NSPasteboard = objc_getClass("NSPasteboard") orelse return error.NoAppKit;
    const pasteboard = send(NSPasteboard, sel_registerName("generalPasteboard"));
    const change_count = sendI(pasteboard, sel_registerName("changeCount"));

    const NSScreen = objc_getClass("NSScreen") orelse return error.NoAppKit;
    const main_screen = send(NSScreen, sel_registerName("mainScreen"));
    const frame = sendRect(main_screen, sel_registerName("frame"));

    const NSWindow = objc_getClass("NSWindow") orelse return error.NoAppKit;
    const NSColor = objc_getClass("NSColor") orelse return error.NoAppKit;

    const window_rect: NSRect = .{
        .x = frame.width - 220,
        .y = frame.height - 60,
        .width = 200,
        .height = 40,
    };

    const alloc = send(NSWindow, sel_registerName("alloc"));
    const window = send4(id, alloc, sel_registerName("initWithContentRect:styleMask:backing:defer:"), window_rect, @as(NSUInteger, 0), @as(NSUInteger, 2), @as(ObjcBool, 0));

    _ = send1(void, window, sel_registerName("setLevel:"), @as(NSInteger, 25));
    _ = send1(void, window, sel_registerName("setOpaque:"), @as(ObjcBool, 0));
    const clear = send(NSColor, sel_registerName("clearColor"));
    _ = send1(void, window, sel_registerName("setBackgroundColor:"), clear);
    _ = send1(void, window, sel_registerName("setHasShadow:"), @as(ObjcBool, 0));
    _ = send1(void, window, sel_registerName("setIgnoresMouseEvents:"), @as(ObjcBool, 1));
    _ = send1(void, window, sel_registerName("setCollectionBehavior:"), @as(NSUInteger, 1 << 4));

    // Setup global key monitor via CGEventTap
    g_override_keycode = switch (config.override_key) {
        .right_ctrl => kVK_RightControl,
        .right_alt => kVK_RightOption,
        .right_shift => kVK_RightShift,
        .f12 => kVK_F12,
    };

    const event_mask: CGEventMask = (@as(u64, 1) << kCGEventKeyDown) | (@as(u64, 1) << kCGEventFlagsChanged);
    const tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionListenOnly, event_mask, &eventTapCallback, null);

    if (tap) |port| {
        const source = CFMachPortCreateRunLoopSource(null, port, 0);
        if (source) |src| {
            const rl = CFRunLoopGetCurrent();
            // Pass null for default mode - CFRunLoopAddSource with null uses default
            CFRunLoopAddSource(rl, src, null);
        }
    }

    // Create the menu bar status item
    const status_item = createMenuBar(app);

    return .{
        .pasteboard = pasteboard,
        .last_change_count = change_count,
        .overlay_window = window,
        .screen_width = frame.width,
        .screen_height = frame.height,
        .notif_position = config.notif_position,
        .app = app,
        .status_item = status_item,
    };
}

fn eventTapCallback(_: ?*anyopaque, etype: CGEventType, event: CGEventRef, _: ?*anyopaque) callconv(.c) CGEventRef {
    if (etype == kCGEventKeyDown or etype == kCGEventFlagsChanged) {
        const keycode: u16 = @intCast(CGEventGetIntegerValueField(event, 9));
        if (keycode == g_override_keycode) {
            g_event_queue.push(.override_key_pressed);
        }
    }
    return event;
}

pub fn deinit(ctx: *Context) void {
    sendV(ctx.overlay_window, sel_registerName("close"));
}

pub fn pollEvent(ctx: *Context) !Event {
    // Pump the run loop briefly to process events
    _ = CFRunLoopRunInMode(null, 0.0, 1);

    // Check for menu actions
    const action = g_last_menu_action;
    if (action != 0) {
        g_last_menu_action = 0;
        const tag: NSInteger = @intCast(action);
        switch (tag) {
            TAG_NOTIF => {
                g_notif_enabled = !g_notif_enabled;
                updateMenuCheckmarks();
                g_event_queue.push(.tray_toggle_notif_copy);
            },
            TAG_BLOCK => {
                g_block_enabled = !g_block_enabled;
                updateMenuCheckmarks();
                g_event_queue.push(.tray_toggle_block);
            },
            TAG_QUIT => {
                g_event_queue.push(.tray_quit);
            },
            TAG_DUR_1S => {
                g_current_duration_tag = TAG_DUR_1S;
                updateMenuCheckmarks();
                g_event_queue.push(.tray_duration_1s);
            },
            TAG_DUR_3S => {
                g_current_duration_tag = TAG_DUR_3S;
                updateMenuCheckmarks();
                g_event_queue.push(.tray_duration_3s);
            },
            TAG_DUR_5S => {
                g_current_duration_tag = TAG_DUR_5S;
                updateMenuCheckmarks();
                g_event_queue.push(.tray_duration_5s);
            },
            TAG_DUR_10S => {
                g_current_duration_tag = TAG_DUR_10S;
                updateMenuCheckmarks();
                g_event_queue.push(.tray_duration_10s);
            },
            TAG_DUR_30S => {
                g_current_duration_tag = TAG_DUR_30S;
                updateMenuCheckmarks();
                g_event_queue.push(.tray_duration_30s);
            },
            else => {},
        }
    }

    // Check pasteboard change count
    const new_count = sendI(ctx.pasteboard, sel_registerName("changeCount"));
    if (new_count != ctx.last_change_count) {
        ctx.last_change_count = new_count;
        g_event_queue.push(.copy_detected);
    }

    return g_event_queue.pop();
}

fn updateMenuCheckmarks() void {
    const set_state_sel = sel_registerName("setState:");
    const on: NSInteger = 1; // NSOnState
    const off: NSInteger = 0; // NSOffState

    if (g_menu_item_notif) |item| {
        _ = send1(void, item, set_state_sel, if (g_notif_enabled) on else off);
    }
    if (g_menu_item_block) |item| {
        _ = send1(void, item, set_state_sel, if (g_block_enabled) on else off);
    }

    const dur_tags = [_]NSInteger{ TAG_DUR_1S, TAG_DUR_3S, TAG_DUR_5S, TAG_DUR_10S, TAG_DUR_30S };
    for (g_menu_item_dur, 0..) |maybe_item, i| {
        if (maybe_item) |item| {
            _ = send1(void, item, set_state_sel, if (dur_tags[i] == g_current_duration_tag) on else off);
        }
    }
}

pub fn getClipboardContent(ctx: *Context) !?[]const u8 {
    const str: ?id = @ptrFromInt(@as(usize, @bitCast(send1(NSInteger, ctx.pasteboard, sel_registerName("stringForType:"), getPasteboardType()))));
    const s = str orelse return null;
    const utf8: ?[*:0]const u8 = @ptrFromInt(@as(usize, @bitCast(sendI(s, sel_registerName("UTF8String")))));
    const ptr = utf8 orelse return null;
    return std.mem.sliceTo(ptr, 0);
}

fn getPasteboardType() id {
    const NSString = objc_getClass("NSString") orelse unreachable;
    return send1(id, NSString, sel_registerName("stringWithUTF8String:"), @as([*:0]const u8, "public.utf8-plain-text"));
}

pub fn clearClipboard(ctx: *Context) !void {
    _ = sendI(ctx.pasteboard, sel_registerName("clearContents"));
}

pub fn restoreClipboard(ctx: *Context, content: []const u8) !void {
    if (content.len == 0) return;

    const NSString = objc_getClass("NSString") orelse return error.NoFoundation;
    const alloc = send(NSString, sel_registerName("alloc"));
    const ns_str = send3(id, alloc, sel_registerName("initWithBytes:length:encoding:"), content.ptr, @as(NSUInteger, content.len), @as(NSUInteger, 4));

    _ = sendI(ctx.pasteboard, sel_registerName("clearContents"));

    const NSArray = objc_getClass("NSArray") orelse return error.NoFoundation;
    const array = send1(id, NSArray, sel_registerName("arrayWithObject:"), ns_str);
    _ = send1(ObjcBool, ctx.pasteboard, sel_registerName("writeObjects:"), array);
}

pub fn showOverlay(ctx: *Context, alpha: f32, y_offset: f32, x_offset: f32, kind: NotifKind) !void {
    _ = x_offset;
    const base_x: CGFloat = switch (ctx.notif_position) {
        .top_right, .bottom_right => ctx.screen_width - 220,
        .top_left, .bottom_left => 20,
    };
    const base_y: CGFloat = switch (ctx.notif_position) {
        .top_right, .top_left => ctx.screen_height - 60,
        .bottom_right, .bottom_left => 20,
    };
    const y: CGFloat = base_y - @as(CGFloat, @floatCast(y_offset));

    const new_frame: NSRect = .{ .x = base_x, .y = y, .width = 200, .height = 40 };
    _ = send2(void, ctx.overlay_window, sel_registerName("setFrame:display:"), new_frame, @as(ObjcBool, 1));
    _ = send1(void, ctx.overlay_window, sel_registerName("setAlphaValue:"), @as(CGFloat, @floatCast(alpha)));

    // Set background color based on notification kind
    const NSColor = objc_getClass("NSColor") orelse return;
    const bg = switch (kind) {
        .copied => send4(id, NSColor, sel_registerName("colorWithRed:green:blue:alpha:"), @as(CGFloat, 0.15), @as(CGFloat, 0.7), @as(CGFloat, 0.15), @as(CGFloat, 0.85)),
        .override_hint => send4(id, NSColor, sel_registerName("colorWithRed:green:blue:alpha:"), @as(CGFloat, 0.7), @as(CGFloat, 0.12), @as(CGFloat, 0.12), @as(CGFloat, 0.85)),
    };
    _ = send1(void, ctx.overlay_window, sel_registerName("setBackgroundColor:"), bg);

    if (!ctx.overlay_visible) {
        _ = send1(void, ctx.overlay_window, sel_registerName("orderFront:"), @as(?id, null));
        ctx.overlay_visible = true;
    }
}

pub fn hideOverlay(ctx: *Context) !void {
    if (ctx.overlay_visible) {
        _ = send1(void, ctx.overlay_window, sel_registerName("orderOut:"), @as(?id, null));
        ctx.overlay_visible = false;
    }
}

pub fn getFd(_: *const Context) ?i32 {
    return null;
}

pub fn peekMessage() bool {
    return false;
}

pub fn sleep(ms: u32) void {
    _ = usleep(ms * 1000);
}
