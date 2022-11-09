const std = @import("std");
const platform = @import("src/platform.zig");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("game", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibC();
    switch (platform.Windowing) {
        .xlib => exe.linkSystemLibrary("X11"),
        .win32 => {},
    }
    switch (platform.Rendering) {
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

    const shaders_cmd = b.addSystemCommand(&[_][]const u8{ "/usr/bin/env", "bash", "-c", "spirv-link <(glslc src/shaders/mesh.vert -o -) <(glslc src/shaders/mesh.frag -o -) -o src/shaders/mesh.spv" });
    const shaders_step = b.step("shaders", "Compile and Link SPIR-V binaries");
    shaders_step.dependOn(&shaders_cmd.step);
}