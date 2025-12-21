const std = @import("std");

pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    const exe = b.addExecutable(.{
        .name = "zfg",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_module = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize }),
    });

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    exe.linkLibCpp();

    const zgui = b.dependency("zgui", .{
        .shared = false,
        .with_implot = true,
    });

    exe.root_module.addImport("zgui", zgui.module("root"));
    exe.linkLibrary(zgui.artifact("imgui"));
    exe.addIncludePath(zgui.path("libs/imgui"));

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

    const sfd = b.dependency("sfd", .{
        .target = target,
        .optimize = optimize,
    });

    const sfd_cflags = &.{};
    exe.root_module.addCSourceFile(.{
        .file = sfd.path("src/sfd.c"),
        .flags = sfd_cflags,
    });

    exe.addIncludePath(sfd.path("src/"));

    // @todo might use this library for dialogs in the future. chase 2024/7/23
    // const tinyfiledialogs = b.dependency("tinyfiledialogs", .{
    //     .target = target,
    //     .optimize = optimize,
    // });

    // const tinyfiledialogs_cflags = &.{};
    // exe.root_module.addCSourceFile(.{
    //     .file = tinyfiledialogs.path("tinyfiledialogs.c"),
    //     .flags = tinyfiledialogs_cflags,
    // });

    // exe.addIncludePath(tinyfiledialogs.path("."));

    // Windows link for file dialogs. Will add other platforms later. Pull request please orz.
    exe.linkSystemLibrary("comdlg32");
    // exe.linkSystemLibrary("ole32");

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);

    // const unit_tests = b.addTest(.{
    //     .root_source_file = .{ .path = "src/main.zig" },
    //     .target = target,
    //     .optimize = optimize,
    // });

    // const run_unit_tests = b.addRunArtifact(unit_tests);

    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_unit_tests.step);
}
