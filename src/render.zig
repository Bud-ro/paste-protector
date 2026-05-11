const std = @import("std");
const NotifKind = @import("core/notifier.zig").NotifKind;

pub fn renderNotification(pixels: [*]u8, size: u32, alpha: f32, kind: NotifKind) void {
    const stride = size * 4;
    @memset(pixels[0 .. stride * size], 0);
    if (alpha < 0.004) return;

    const cx: f32 = @as(f32, @floatFromInt(size)) / 2.0;
    const cy = cx;
    const radius = cx - 1.0;
    const outline_width: f32 = @max(1.5, @as(f32, @floatFromInt(size)) / 32.0);

    switch (kind) {
        .copied => {
            drawCircleAA(pixels, stride, size, cx, cy, radius, outline_width, 34, 160, 34, 255, 255, 255, alpha);
            drawCheckmark(pixels, stride, size, cx, cy, radius, outline_width, alpha);
        },
        .override_hint => {
            drawCircleAA(pixels, stride, size, cx, cy, radius, outline_width, 170, 30, 30, 255, 255, 255, alpha);
            drawTextCentered(pixels, stride, size, "RCtrl", @max(1, size / 48), alpha);
        },
    }
}

fn drawCircleAA(pixels: [*]u8, stride: u32, size: u32, cx: f32, cy: f32, radius: f32, outline_w: f32, fill_r: u8, fill_g: u8, fill_b: u8, out_r: u8, out_g: u8, out_b: u8, alpha: f32) void {
    const inner_r = radius - outline_w;
    for (0..size) |py| {
        for (0..size) |px| {
            const dx = @as(f32, @floatFromInt(px)) + 0.5 - cx;
            const dy = @as(f32, @floatFromInt(py)) + 0.5 - cy;
            const dist = @sqrt(dx * dx + dy * dy);

            if (dist <= inner_r - 0.5) {
                // Fully inside fill
                blendPixel(pixels, stride, @intCast(px), @intCast(py), fill_b, fill_g, fill_r, alpha);
            } else if (dist <= inner_r + 0.5) {
                // AA edge between fill and outline
                const t = (inner_r + 0.5 - dist);
                blendPixel(pixels, stride, @intCast(px), @intCast(py), fill_b, fill_g, fill_r, alpha * t);
                blendPixel(pixels, stride, @intCast(px), @intCast(py), out_b, out_g, out_r, alpha * (1.0 - t));
            } else if (dist <= radius - 0.5) {
                // Fully inside outline
                blendPixel(pixels, stride, @intCast(px), @intCast(py), out_b, out_g, out_r, alpha);
            } else if (dist <= radius + 0.5) {
                // AA outer edge
                const t = (radius + 0.5 - dist);
                blendPixel(pixels, stride, @intCast(px), @intCast(py), out_b, out_g, out_r, alpha * t);
            }
        }
    }
}

fn drawCheckmark(pixels: [*]u8, stride: u32, size: u32, cx: f32, cy: f32, radius: f32, outline_w: f32, alpha: f32) void {
    const thick = outline_w * 1.5;
    // Short leg
    const x1 = cx - radius * 0.30;
    const y1 = cy + radius * 0.05;
    const x2 = cx - radius * 0.05;
    const y2 = cy + radius * 0.30;
    drawLineAA(pixels, stride, size, x1, y1, x2, y2, thick, 255, 255, 255, alpha);
    // Long leg
    const x3 = cx + radius * 0.35;
    const y3 = cy - radius * 0.30;
    drawLineAA(pixels, stride, size, x2, y2, x3, y3, thick, 255, 255, 255, alpha);
}

fn drawLineAA(pixels: [*]u8, stride: u32, size: u32, x1: f32, y1: f32, x2: f32, y2: f32, thickness: f32, r: u8, g: u8, b: u8, alpha: f32) void {
    const dx = x2 - x1;
    const dy = y2 - y1;
    const len = @sqrt(dx * dx + dy * dy);
    if (len < 0.1) return;

    // Normal perpendicular to line
    const nx = -dy / len;
    const ny = dx / len;
    const half_t = thickness / 2.0;

    // Bounding box
    const min_x: i32 = @intFromFloat(@max(0.0, @min(x1, x2) - half_t - 1.0));
    const max_x: i32 = @intFromFloat(@min(@as(f32, @floatFromInt(size)), @max(x1, x2) + half_t + 1.0));
    const min_y: i32 = @intFromFloat(@max(0.0, @min(y1, y2) - half_t - 1.0));
    const max_y: i32 = @intFromFloat(@min(@as(f32, @floatFromInt(size)), @max(y1, y2) + half_t + 1.0));

    var py = min_y;
    while (py < max_y) : (py += 1) {
        var px = min_x;
        while (px < max_x) : (px += 1) {
            const sx = @as(f32, @floatFromInt(px)) + 0.5;
            const sy = @as(f32, @floatFromInt(py)) + 0.5;

            // Distance from point to line segment
            const t_along = ((sx - x1) * dx + (sy - y1) * dy) / (len * len);
            if (t_along < -half_t / len or t_along > 1.0 + half_t / len) continue;

            const perp_dist = @abs((sx - x1) * nx + (sy - y1) * ny);

            // Clamp to segment endpoints
            const clamped_t = std.math.clamp(t_along, 0.0, 1.0);
            const closest_x = x1 + clamped_t * dx;
            const closest_y = y1 + clamped_t * dy;
            const end_dx = sx - closest_x;
            const end_dy = sy - closest_y;
            const end_dist = @sqrt(end_dx * end_dx + end_dy * end_dy);

            const dist = if (t_along >= 0.0 and t_along <= 1.0) perp_dist else end_dist;

            if (dist <= half_t + 0.5) {
                const coverage = std.math.clamp(half_t + 0.5 - dist, 0.0, 1.0);
                blendPixel(pixels, stride, @intCast(px), @intCast(py), b, g, r, alpha * coverage);
            }
        }
    }
}

fn blendPixel(pixels: [*]u8, stride: u32, x: u32, y: u32, b_val: u8, g: u8, r: u8, alpha: f32) void {
    const offset = y * stride + x * 4;
    const a_byte: u8 = @intFromFloat(std.math.clamp(alpha * 255.0, 0.0, 255.0));
    if (a_byte == 0) return;

    const dst_a = pixels[offset + 3];
    if (dst_a == 0) {
        pixels[offset + 0] = @intCast(@as(u16, b_val) * @as(u16, a_byte) / 255);
        pixels[offset + 1] = @intCast(@as(u16, g) * @as(u16, a_byte) / 255);
        pixels[offset + 2] = @intCast(@as(u16, r) * @as(u16, a_byte) / 255);
        pixels[offset + 3] = a_byte;
    } else {
        // Source-over compositing (premultiplied alpha)
        const sa = @as(u16, a_byte);
        const inv_sa = 255 - sa;
        pixels[offset + 0] = @intCast((@as(u16, b_val) * sa + @as(u16, pixels[offset + 0]) * inv_sa) / 255);
        pixels[offset + 1] = @intCast((@as(u16, g) * sa + @as(u16, pixels[offset + 1]) * inv_sa) / 255);
        pixels[offset + 2] = @intCast((@as(u16, r) * sa + @as(u16, pixels[offset + 2]) * inv_sa) / 255);
        pixels[offset + 3] = @intCast((@as(u16, dst_a) + sa * (255 - @as(u16, dst_a)) / 255));
    }
}

fn drawTextCentered(pixels: [*]u8, stride: u32, size: u32, text: []const u8, scale: u32, alpha: f32) void {
    const char_w: u32 = 8 * scale;
    const char_h: u32 = 12 * scale;
    const text_w = @as(u32, @intCast(text.len)) * char_w;
    const start_x = if (text_w < size) (size - text_w) / 2 else 0;
    const start_y = if (char_h < size) (size - char_h) / 2 else 0;

    for (text, 0..) |ch, i| {
        renderChar(pixels, stride, size, start_x + @as(u32, @intCast(i)) * char_w, start_y, ch, scale, alpha);
    }
}

fn renderChar(pixels: [*]u8, stride: u32, size: u32, x: u32, y: u32, ch: u8, scale: u32, alpha: f32) void {
    const bitmap = getCharBitmap(ch);
    for (0..12) |row| {
        const bits: u8 = if (row < bitmap.len) bitmap[row] else 0;
        for (0..8) |col| {
            if (bits & (@as(u8, 0x80) >> @intCast(col)) != 0) {
                for (0..scale) |sy| {
                    for (0..scale) |sx| {
                        const px = x + @as(u32, @intCast(col)) * scale + @as(u32, @intCast(sx));
                        const py = y + @as(u32, @intCast(row)) * scale + @as(u32, @intCast(sy));
                        if (px >= size or py >= size) continue;
                        blendPixel(pixels, stride, px, py, 255, 255, 255, alpha);
                    }
                }
            }
        }
    }
}

fn getCharBitmap(ch: u8) []const u8 {
    return switch (ch) {
        'C' => &[_]u8{ 0x3C, 0x66, 0x60, 0x60, 0x60, 0x60, 0x60, 0x60, 0x66, 0x3C, 0x00, 0x00 },
        'R' => &[_]u8{ 0x7C, 0x66, 0x66, 0x7C, 0x6C, 0x66, 0x66, 0x66, 0x66, 0x00, 0x00, 0x00 },
        't' => &[_]u8{ 0x00, 0x18, 0x18, 0x7E, 0x18, 0x18, 0x18, 0x18, 0x0E, 0x00, 0x00, 0x00 },
        'r' => &[_]u8{ 0x00, 0x00, 0x00, 0x6C, 0x76, 0x60, 0x60, 0x60, 0x60, 0x00, 0x00, 0x00 },
        'l' => &[_]u8{ 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x0E, 0x00, 0x00, 0x00 },
        else => &[_]u8{ 0x00, 0x00, 0x00, 0x7E, 0x7E, 0x7E, 0x7E, 0x7E, 0x7E, 0x00, 0x00, 0x00 },
    };
}
