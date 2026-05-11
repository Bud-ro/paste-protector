const NotifKind = @import("core/notifier.zig").NotifKind;

pub fn renderNotification(pixels: [*]u8, width: u32, height: u32, alpha: f32, kind: NotifKind) void {
    const stride = width * 4;
    const scale: u32 = @max(1, width / 48);

    // Clear
    @memset(pixels[0 .. stride * height], 0);

    const a: u8 = @intFromFloat(alpha * 255.0);
    if (a == 0) return;

    switch (kind) {
        .copied => renderCheckmark(pixels, stride, width, height, scale, a),
        .override_hint => renderOverrideHint(pixels, stride, width, height, scale, a),
    }
}

fn renderCheckmark(pixels: [*]u8, stride: u32, width: u32, height: u32, scale: u32, a: u8) void {
    // Green circle background
    const cx = width / 2;
    const cy = height / 2;
    const radius = @min(width, height) / 2 - 1;
    const r2 = radius * radius;

    // Background circle
    const bg_r: u8 = @intCast(@as(u16, 34) * @as(u16, a) / 255);
    const bg_g: u8 = @intCast(@as(u16, 160) * @as(u16, a) / 255);
    const bg_b: u8 = @intCast(@as(u16, 34) * @as(u16, a) / 255);

    for (0..height) |py| {
        for (0..width) |px| {
            const dx = if (px > cx) px - cx else cx - px;
            const dy = if (py > cy) py - cy else cy - py;
            if (dx * dx + dy * dy <= r2) {
                setPixel(pixels, stride, @intCast(px), @intCast(py), bg_b, bg_g, bg_r, a);
            }
        }
    }

    // White checkmark
    const fg_a = a;
    const fg_val: u8 = @intCast(@as(u16, 255) * @as(u16, fg_a) / 255);
    const thick = @max(2, scale * 2);

    // Short leg: from bottom-left to bottom-center
    const x1 = cx - radius / 3;
    const y1 = cy;
    const x2 = cx - radius / 8;
    const y2 = cy + radius / 3;

    drawThickLine(pixels, stride, width, height, x1, y1, x2, y2, thick, fg_val, fg_val, fg_val, fg_a);

    // Long leg: from bottom-center to top-right
    const x3 = cx + radius / 3;
    const y3 = cy - radius / 3;

    drawThickLine(pixels, stride, width, height, x2, y2, x3, y3, thick, fg_val, fg_val, fg_val, fg_a);
}

fn renderOverrideHint(pixels: [*]u8, stride: u32, width: u32, height: u32, scale: u32, a: u8) void {
    const cx = width / 2;
    const cy = height / 2;
    const radius = @min(width, height) / 2 - 1;
    const r2 = radius * radius;

    // Red circle background
    const bg_r: u8 = @intCast(@as(u16, 170) * @as(u16, a) / 255);
    const bg_g: u8 = @intCast(@as(u16, 30) * @as(u16, a) / 255);
    const bg_b: u8 = @intCast(@as(u16, 30) * @as(u16, a) / 255);

    for (0..height) |py| {
        for (0..width) |px| {
            const dx = if (px > cx) px - cx else cx - px;
            const dy = if (py > cy) py - cy else cy - py;
            if (dx * dx + dy * dy <= r2) {
                setPixel(pixels, stride, @intCast(px), @intCast(py), bg_b, bg_g, bg_r, a);
            }
        }
    }

    // White "RCtrl" text centered
    const text = "RCtrl";
    const char_w: u32 = 8 * scale;
    const char_h: u32 = 12 * scale;
    const text_w = @as(u32, text.len) * char_w;
    const start_x = if (text_w < width) (width - text_w) / 2 else 0;
    const start_y = if (char_h < height) (height - char_h) / 2 else 0;

    const fg: u8 = @intCast(@as(u16, 255) * @as(u16, a) / 255);

    for (text, 0..) |ch, i| {
        renderChar(pixels, stride, width, height, start_x + @as(u32, @intCast(i)) * char_w, start_y, ch, fg, fg, fg, a, scale);
    }
}

fn drawThickLine(pixels: [*]u8, stride: u32, width: u32, height: u32, x1: u32, y1: u32, x2: u32, y2: u32, thickness: u32, b_val: u8, g: u8, r: u8, a: u8) void {
    const steps: u32 = @max(absDiff(x1, x2), absDiff(y1, y2));
    if (steps == 0) return;

    for (0..steps + 1) |step| {
        const t: f32 = @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(steps));
        const px: i32 = @as(i32, @intCast(x1)) + @as(i32, @intFromFloat(t * @as(f32, @floatFromInt(@as(i32, @intCast(x2)) - @as(i32, @intCast(x1))))));
        const py: i32 = @as(i32, @intCast(y1)) + @as(i32, @intFromFloat(t * @as(f32, @floatFromInt(@as(i32, @intCast(y2)) - @as(i32, @intCast(y1))))));

        for (0..thickness) |dy| {
            for (0..thickness) |dx| {
                const fx: i32 = px + @as(i32, @intCast(dx)) - @as(i32, @intCast(thickness / 2));
                const fy: i32 = py + @as(i32, @intCast(dy)) - @as(i32, @intCast(thickness / 2));
                if (fx >= 0 and fy >= 0 and fx < @as(i32, @intCast(width)) and fy < @as(i32, @intCast(height))) {
                    setPixel(pixels, stride, @intCast(fx), @intCast(fy), b_val, g, r, a);
                }
            }
        }
    }
}

fn absDiff(a: u32, b: u32) u32 {
    return if (a > b) a - b else b - a;
}

fn setPixel(pixels: [*]u8, stride: u32, x: u32, y: u32, b_val: u8, g: u8, r: u8, a: u8) void {
    const offset = y * stride + x * 4;
    pixels[offset + 0] = b_val;
    pixels[offset + 1] = g;
    pixels[offset + 2] = r;
    pixels[offset + 3] = a;
}

fn renderChar(pixels: [*]u8, stride: u32, buf_width: u32, buf_height: u32, x: u32, y: u32, ch: u8, b_val: u8, g: u8, r: u8, a: u8, scale: u32) void {
    const bitmap = getCharBitmap(ch);
    for (0..12) |row| {
        const bits: u8 = if (row < bitmap.len) bitmap[row] else 0;
        for (0..8) |col| {
            if (bits & (@as(u8, 0x80) >> @intCast(col)) != 0) {
                for (0..scale) |sy| {
                    for (0..scale) |sx| {
                        const px = x + @as(u32, @intCast(col)) * scale + @as(u32, @intCast(sx));
                        const py = y + @as(u32, @intCast(row)) * scale + @as(u32, @intCast(sy));
                        if (px >= buf_width or py >= buf_height) continue;
                        setPixel(pixels, stride, px, py, b_val, g, r, a);
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
