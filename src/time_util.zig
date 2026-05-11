const std = @import("std");
const builtin = @import("builtin");

pub fn nanoTimestamp() i128 {
    if (builtin.os.tag == .windows) {
        return windowsNanoTimestamp();
    } else if (builtin.os.tag == .macos) {
        return macosNanoTimestamp();
    } else {
        return posixNanoTimestamp();
    }
}

fn posixNanoTimestamp() i128 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(std.c.CLOCK.MONOTONIC, &ts);
    return @as(i128, ts.sec) * std.time.ns_per_s + ts.nsec;
}

fn macosNanoTimestamp() i128 {
    const ticks = mach_absolute_time();
    const S = struct {
        var numer: u32 = 0;
        var denom: u32 = 0;
    };
    if (S.numer == 0) {
        var info: mach_timebase_info_data = undefined;
        _ = mach_timebase_info(&info);
        S.numer = info.numer;
        S.denom = info.denom;
    }
    return @divFloor(@as(i128, ticks) * S.numer, S.denom);
}

fn windowsNanoTimestamp() i128 {
    var counter: i64 = undefined;
    _ = QueryPerformanceCounter(&counter);
    const freq = blk: {
        const F = struct {
            var f: i64 = 0;
        };
        if (F.f == 0) {
            _ = QueryPerformanceFrequency(&F.f);
        }
        break :blk F.f;
    };
    const seconds = @divFloor(counter, freq);
    const remainder = counter - seconds * freq;
    return @as(i128, seconds) * std.time.ns_per_s +
        @divFloor(@as(i128, remainder) * std.time.ns_per_s, freq);
}

// Platform-specific extern declarations
const mach_timebase_info_data = extern struct {
    numer: u32,
    denom: u32,
};

extern "System" fn mach_absolute_time() callconv(.c) u64;
extern "System" fn mach_timebase_info(info: *mach_timebase_info_data) callconv(.c) c_int;
extern "kernel32" fn QueryPerformanceCounter(lpPerformanceCount: *i64) callconv(.c) std.os.windows.BOOL;
extern "kernel32" fn QueryPerformanceFrequency(lpFrequency: *i64) callconv(.c) std.os.windows.BOOL;
