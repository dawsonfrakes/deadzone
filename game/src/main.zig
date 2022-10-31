const Window = @import("Window.zig");
const Renderer = @import("Renderer.zig");
const Input = @import("Input.zig");
const Time = @import("Time.zig");

// TODO: move to game specific code rather than EngineMain()
const std = @import("std");
const math = @import("math.zig");
fn gameInit(renderer: *Renderer) void {
    renderer.appendStaticMesh(.{
        .mesh = .cube,
        .transform = math.Matrix(f32, 4, 4).I()
            .rotate(.{ std.math.pi / 4.0, 0.0, 0.0 }),
    });

    renderer.appendStaticMesh(.{
        .mesh = .triangle,
        .transform = math.Matrix(f32, 4, 4).I()
            .translate(.{ 0.0, 0.0, 1.1 })
            .rotate(.{ 0.0, 0.0, std.math.pi / 2.0 }),
    });
}

pub fn main() !void {
    var input = Input{};
    var time = Time.init();

    var window = try Window.create(&input);
    defer window.destroy();

    var renderer = try Renderer.create(&window, &time);
    defer renderer.destroy();

    gameInit(&renderer);

    while (true) {
        window.update() orelse break;
        time.update();
        if (input.getKeyJustDown(.escape) or input.getKeyJustDown(.q)) break;
        try renderer.update();
        input.save();
    }
}
