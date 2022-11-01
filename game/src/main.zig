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

fn gameUpdate(renderer: *Renderer, input: Input, time: Time) ?void {
    if (input.getKeyJustDown(.escape) or input.getKeyJustDown(.q)) return null;

    var direction = @splat(3, @as(f32, 0.0));

    if (input.getKeyDown(.w)) {
        direction[2] -= 1.0;
    }
    if (input.getKeyDown(.s)) {
        direction[2] += 1.0;
    }
    if (input.getKeyDown(.d)) {
        direction[0] += 1.0;
    }
    if (input.getKeyDown(.a)) {
        direction[0] -= 1.0;
    }

    // because we actually move the world in opposite direction of camera location
    direction *= @splat(3, @as(f32, -1.0));

    const length = @sqrt(@reduce(.Add, direction * direction));
    const normalized = if (!std.math.approxEqAbs(f32, length, 0.0, std.math.floatEps(f32)))
        direction / @splat(3, length)
    else
        @splat(3, @as(f32, 0.0));

    const speed = 5.0;
    renderer.view = renderer.view
        .translate(normalized * @splat(3, @floatCast(f32, time.delta * speed)));
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
        gameUpdate(&renderer, input, time) orelse break;
        try renderer.update();
        input.save();
    }
}
