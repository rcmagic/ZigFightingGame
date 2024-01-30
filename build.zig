const std = @import("std");
const Builder = std.build.Builder;
const raylib = @import("libs/raylib-zig/lib.zig"); //call .Pkg() with the folder raylib-zig is in relative to project build.zig

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const system_lib = b.option(bool, "system-raylib", "link to preinstalled raylib libraries") orelse false;

    const exe = b.addExecutable("hello-wold", "src/main.zig");
    exe.setTarget(target); 
    exe.setBuildMode(mode);
    
    // Link against libC
    exe.linkLibC();

    // Link raylib
    raylib.link(exe, system_lib);
    raylib.addAsPackage("raylib", exe);    
    raylib.math.addAsPackage("raylib-math", exe);

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
