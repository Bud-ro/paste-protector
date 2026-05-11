const platform = @import("../platform/platform.zig");
const Config = @import("../config.zig").Config;
const NotifKind = @import("notifier.zig").NotifKind;

pub const Event = platform.Event;

pub const Monitor = struct {
    platform_ctx: platform.Context,

    pub fn init(config: Config) !Monitor {
        return .{
            .platform_ctx = try platform.init(config),
        };
    }

    pub fn deinit(self: *Monitor) void {
        platform.deinit(&self.platform_ctx);
    }

    pub fn poll(self: *Monitor) !Event {
        return platform.pollEvent(&self.platform_ctx);
    }

    pub fn getClipboardContent(self: *Monitor) !?[]const u8 {
        return platform.getClipboardContent(&self.platform_ctx);
    }

    pub fn clearClipboard(self: *Monitor) !void {
        return platform.clearClipboard(&self.platform_ctx);
    }

    pub fn restoreClipboard(self: *Monitor, content: []const u8) !void {
        return platform.restoreClipboard(&self.platform_ctx, content);
    }

    pub fn showOverlay(self: *Monitor, alpha: f32, y_offset: f32, x_offset: f32, kind: NotifKind) !void {
        return platform.showOverlay(&self.platform_ctx, alpha, y_offset, x_offset, kind);
    }


    pub fn hideOverlay(self: *Monitor) !void {
        return platform.hideOverlay(&self.platform_ctx);
    }

    pub fn getFd(self: *const Monitor) ?platform.FdType {
        return platform.getFd(&self.platform_ctx);
    }

    pub fn updateConfig(self: *Monitor, config: Config) void {
        platform.updateConfig(&self.platform_ctx, config);
    }
};
