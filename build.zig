const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });
    const tiny = b.option(bool, "tiny", "Minimize binary size aggressively") orelse false;

    const os = target.result.os.tag;

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = if (tiny) .ReleaseSmall else optimize,
        .link_libc = if (os == .linux) true else null,
        .strip = if (tiny) true else null,
        .single_threaded = if (tiny) true else null,
        .unwind_tables = if (tiny) .none else null,
        .omit_frame_pointer = if (tiny) true else null,
        .error_tracing = if (tiny) false else null,
        .red_zone = if (tiny) true else null,
    });

    if (os == .linux) {
        mod.linkSystemLibrary("X11", .{});
        mod.linkSystemLibrary("Xfixes", .{});
        mod.linkSystemLibrary("Xrender", .{});
    } else if (os == .macos) {
        mod.linkFramework("AppKit", .{});
        mod.linkFramework("CoreGraphics", .{});
        mod.linkFramework("CoreFoundation", .{});
    }

    if (os == .windows and !tiny) {
        mod.addWin32ResourceFile(.{ .file = b.path("res/paste-protector.rc") });
    }

    const exe = b.addExecutable(.{
        .name = "paste-protector",
        .root_module = mod,
    });

    if (os == .windows) {
        exe.subsystem = .Windows;
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run paste-protector");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = .Debug,
        .link_libc = if (os == .linux) true else null,
    });

    const tests = b.addTest(.{
        .name = "paste-protector-tests",
        .root_module = test_mod,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
