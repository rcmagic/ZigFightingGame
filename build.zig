const std = @import("std");
const raylib = @import("raylib_zig");
const zgui = @import("zgui");

pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    const raylib_zig = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    // const exe = b.addExecutable(.{
    //     .name = "zfg",
    //     .root_source_file = .{ .path = "src/main.zig" },
    //     .target = target,
    //     .optimize = optimize,
    // });

    const exe = try raylib.setup(b, raylib_zig, .{
        .name = "zfg",
        .src = "src/main.zig",
        .target = target,
        .optimize = optimize,
        .createRunStep = false,
    });

    exe.linkLibCpp();

    const zgui_pkg = zgui.package(b, target, optimize, .{
        .options = .{ .backend = .no_backend },
    });

    zgui_pkg.link(exe);
    exe.addIncludePath(.{ .path = "vendor/zgui/libs/imgui" });

    const rlimgui_cflags = &.{
        "-fno-sanitize=undefined",
        "-std=c++11",
        "-Wno-deprecated-declarations",
        "-DNO_FONT_AWESOME",
    };

    const rlimgui = b.dependency("rlimgui", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addCSourceFile(.{
        .file = rlimgui.path("rlImGui.cpp"),
        .flags = rlimgui_cflags,
    });

    exe.addIncludePath(rlimgui.path("."));

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);

    // const exe_tests = b.addTest("src/main.zig");
    // exe_tests.setTarget(target);
    // exe_tests.setBuildMode(mode);

    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&exe_tests.step);
}
