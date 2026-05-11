const std = @import("std");
const Config = @import("../config.zig").Config;

pub const State = enum {
    idle,
    allowing,
    blocking,
};

pub const Blocker = struct {
    state: State = .idle,
    saved_content: ?[]u8 = null,
    copy_time_ns: i128 = 0,
    block_duration_ns: i128,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: Config) Blocker {
        return .{
            .allocator = allocator,
            .block_duration_ns = @as(i128, config.block_duration_ms) * std.time.ns_per_ms,
        };
    }

    pub fn deinit(self: *Blocker) void {
        self.clearSaved();
    }

    pub fn setDuration(self: *Blocker, ms: u32) void {
        self.block_duration_ns = @as(i128, ms) * std.time.ns_per_ms;
    }

    pub fn onCopyDetected(self: *Blocker, content: ?[]const u8, now: i128) void {
        self.clearSaved();

        if (content) |data| {
            self.saved_content = self.allocator.dupe(u8, data) catch null;
        }

        self.state = .allowing;
        self.copy_time_ns = now;
    }

    pub fn onPasteAttempted(self: *Blocker, now: i128) void {
        if (self.state == .allowing) {
            self.copy_time_ns = now;
        }
    }

    pub fn onOverrideKey(self: *Blocker, now: i128) bool {
        if (self.state != .blocking) return false;
        // Restart the allow window — content stays saved
        self.state = .allowing;
        self.copy_time_ns = now;
        return true;
    }

    pub fn tick(self: *Blocker, now: i128) ?enum { should_block } {
        if (self.state != .allowing) return null;

        const elapsed = now - self.copy_time_ns;
        if (elapsed >= self.block_duration_ns) {
            self.state = .blocking;
            return .should_block;
        }
        return null;
    }

    pub fn isPasteBlocked(self: *const Blocker) bool {
        return self.state == .blocking;
    }

    pub fn getSavedContent(self: *const Blocker) ?[]const u8 {
        return self.saved_content;
    }

    pub fn clearAndIdle(self: *Blocker) void {
        self.clearSaved();
        self.state = .idle;
    }


    fn clearSaved(self: *Blocker) void {
        if (self.saved_content) |buf| {
            @memset(buf, 0);
            self.allocator.free(buf);
            self.saved_content = null;
        }
    }
};
