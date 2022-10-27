const std = @import("std");
const platform = @import("src/platform.zig");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("game", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibC();
    switch (platform.WINDOW_LIBRARY) {
        .xlib => exe.linkSystemLibrary("X11"),
        .win32 => @compileError("WIN32 not yet supported"),
    }
    switch (platform.RENDER_LIBRARY) {
        .vulkan => exe.linkSystemLibrary("vulkan"),
    }
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const shaders_step = b.step("shaders", "Compile SPIR-V shaders");
    const vshad = b.addSystemCommand(&[_][]const u8{"glslc", "src/shaders/mesh.vert", "-o", "src/shaders/mesh.vert.spv"});
    const fshad = b.addSystemCommand(&[_][]const u8{"glslc", "src/shaders/mesh.frag", "-o", "src/shaders/mesh.frag.spv"});
    shaders_step.dependOn(&vshad.step);
    shaders_step.dependOn(&fshad.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
