const std = @import("std");
const platform = @import("src/platform.zig");

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    var files = std.ArrayList([]const u8).init(b.allocator);
    defer files.deinit();
    var options = b.addOptions();

    var dir = try std.fs.cwd().openIterableDir("src/meshes", .{});
    defer dir.close();
    var it = dir.iterate();
    while (try it.next()) |file| {
        if (file.kind != .File)
            continue;

        try files.append(b.dupe(file.name[0 .. std.mem.indexOf(u8, file.name, ".") orelse unreachable]));
    }
    options.addOption([]const u8, "files_folder", "meshes");
    options.addOption([]const []const u8, "files", files.items);

    const exe = b.addExecutable("game", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibC();
    switch (platform.window_lib) {
        .xlib => exe.linkSystemLibrary("X11"),
        .win32 => @compileError("WIN32 not yet supported"),
    }
    switch (platform.render_lib) {
        .vulkan => exe.linkSystemLibrary("vulkan"),
    }
    exe.addOptions("options", options);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // TODO: eventually these will be built at comptime with libshaderc and
    // an enum will be generated to indicate which shader to use
    // Example: fn use(shader: Shader) {} will look like this => use(.mesh);
    const shaders_step = b.step("shaders", "Compile SPIR-V shaders");
    const spvgen = b.addSystemCommand(&[_][]const u8{
        "/usr/bin/env",
        "bash",
        "-c",
        "spirv-link <(glslc src/shaders/mesh.vert -o -) <(glslc src/shaders/mesh.frag -o -) -o src/shaders/mesh.spv",
    });
    shaders_step.dependOn(&spvgen.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
