const std = @import("std");
const Config = @import("../config.zig").Config;

pub const NotifKind = enum {
    copied,
    override_hint,
};

pub const ScreenRect = struct {
    x: i32 = 0,
    y: i32 = 0,
    w: i32 = 1920,
    h: i32 = 1080,
};

pub const Notification = struct {
    kind: NotifKind,
    start_ns: i128,
    duration_ns: i128,
    x_jitter: f32 = 0,
    screen: ScreenRect = .{},

    pub fn progress(self: *const Notification, now: i128) f32 {
        const elapsed = now - self.start_ns;
        const t: f32 = @floatCast(@as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(self.duration_ns)));
        return @min(t, 1.0);
    }

    pub fn alpha(self: *const Notification, now: i128) f32 {
        const t = self.progress(now);
        return 1.0 - easeInCubic(t);
    }

    pub fn yOffset(self: *const Notification, now: i128) f32 {
        const t = self.progress(now);
        return -40.0 * t;
    }

    pub fn isExpired(self: *const Notification, now: i128) bool {
        return self.progress(now) >= 1.0;
    }
};

fn easeInCubic(t: f32) f32 {
    return t * t * t;
}

pub const TickResult = struct {
    alpha: f32,
    y_offset: f32,
    x_offset: f32,
    kind: NotifKind,
};

const MAX_STACK = 8;

pub const Notifier = struct {
    slots: [MAX_STACK]?Notification = [_]?Notification{null} ** MAX_STACK,
    duration_ns: i128,

    pub fn init(config: Config) Notifier {
        return .{
            .duration_ns = @as(i128, config.notif_duration_ms) * std.time.ns_per_ms,
        };
    }

    pub fn spawn(self: *Notifier, kind: NotifKind, now: i128) void {
        self.spawnOnScreen(kind, now, .{});
    }

    pub fn spawnOnScreen(self: *Notifier, kind: NotifKind, now: i128, screen: ScreenRect) void {
        const dur = switch (kind) {
            .copied => self.duration_ns,
            .override_hint => 6000 * std.time.ns_per_ms,
        };

        // Clear notifications of a different kind
        for (&self.slots) |*slot| {
            if (slot.*) |n| {
                if (n.kind != kind) slot.* = null;
            }
        }

        const hash: u32 = @truncate(@as(u128, @bitCast(now)) *% 2654435761);
        const jitter: f32 = (@as(f32, @floatFromInt(hash % 1000)) / 1000.0) - 0.5;

        // Find an empty slot, or evict the oldest
        var oldest_idx: usize = 0;
        var oldest_start: i128 = std.math.maxInt(i128);
        for (self.slots, 0..) |slot, i| {
            if (slot == null) {
                self.slots[i] = .{ .kind = kind, .start_ns = now, .duration_ns = dur, .x_jitter = jitter, .screen = screen };
                return;
            }
            if (slot.?.start_ns < oldest_start) {
                oldest_start = slot.?.start_ns;
                oldest_idx = i;
            }
        }
        self.slots[oldest_idx] = .{ .kind = kind, .start_ns = now, .duration_ns = dur, .x_jitter = jitter, .screen = screen };
    }

    pub fn tick(self: *Notifier, now: i128) ?TickResult {
        var newest: ?*Notification = null;
        for (&self.slots) |*slot| {
            const notif = &(slot.* orelse continue);
            if (notif.isExpired(now)) {
                slot.* = null;
                continue;
            }
            if (newest == null or notif.start_ns > newest.?.start_ns) {
                newest = notif;
            }
        }
        const n = newest orelse return null;
        return .{
            .alpha = n.alpha(now),
            .y_offset = n.yOffset(now),
            .x_offset = n.x_jitter,
            .kind = n.kind,
        };
    }

    pub const StackEntry = struct {
        alpha: f32,
        y_offset: f32,
        x_offset: f32,
        kind: NotifKind,
        screen: ScreenRect,
    };

    // Returns entries sorted oldest-first so newest renders on top
    pub fn tickAll(self: *Notifier, now: i128, out: *[MAX_STACK]?StackEntry) u32 {
        @memset(out, null);

        // Collect active notifications with their start times
        var active: [MAX_STACK]struct { idx: usize, start: i128 } = undefined;
        var count: u32 = 0;

        for (&self.slots, 0..) |*slot, i| {
            const notif = &(slot.* orelse continue);
            if (notif.isExpired(now)) {
                slot.* = null;
                continue;
            }
            active[count] = .{ .idx = i, .start = notif.start_ns };
            count += 1;
        }

        // Sort by start_ns ascending (oldest first → renders first → newest on top)
        for (0..count) |i| {
            for (i + 1..count) |j| {
                if (active[j].start < active[i].start) {
                    const tmp = active[i];
                    active[i] = active[j];
                    active[j] = tmp;
                }
            }
        }

        for (0..count) |i| {
            const notif = &(self.slots[active[i].idx].?);
            out.*[i] = .{
                .alpha = notif.alpha(now),
                .y_offset = notif.yOffset(now),
                .x_offset = notif.x_jitter,
                .kind = notif.kind,
                .screen = notif.screen,
            };
        }

        return count;
    }

    pub fn isActive(self: *const Notifier) bool {
        for (self.slots) |slot| {
            if (slot != null) return true;
        }
        return false;
    }
};
