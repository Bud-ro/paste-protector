const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const os = target.result.os.tag;
    const is_release = optimize != .Debug;

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = if (os == .linux) true else null,
        .strip = if (is_release) true else null,
        .single_threaded = if (is_release) true else null,
        .unwind_tables = if (is_release) .none else null,
        .omit_frame_pointer = if (is_release) true else null,
        .error_tracing = if (is_release) false else null,
        .red_zone = if (is_release) true else null,
    });

    if (os == .linux) {
        mod.linkSystemLibrary("X11", .{});
        mod.linkSystemLibrary("Xfixes", .{});
        mod.linkSystemLibrary("Xrender", .{});
    } else if (os == .macos) {
        // For cross-compilation, provide SDK path:
        //   zig fetch git+https://github.com/AeroNotix/macos-sdk.git
        //   zig build -Dmacos-sdk=~/.cache/zig/p/HASH -Dtarget=aarch64-macos
        if (b.option([]const u8, "macos-sdk", "Path to macOS SDK (for cross-compilation)")) |sdk_path| {
            mod.addSystemFrameworkPath(.{ .cwd_relative = b.fmt("{s}/Frameworks", .{sdk_path}) });
            mod.addSystemIncludePath(.{ .cwd_relative = b.fmt("{s}/include", .{sdk_path}) });
            mod.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/lib", .{sdk_path}) });
        }
        mod.linkFramework("AppKit", .{});
        mod.linkFramework("CoreGraphics", .{});
        mod.linkFramework("CoreFoundation", .{});
    }

    if (os == .windows) {
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
