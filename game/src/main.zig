const std = @import("std");
const Maths = @import("Maths.zig");
const Time = @import("Time.zig");
const Input = @import("Input.zig");
const Window = @import("platform.zig").Window;
const Renderer = @import("platform.zig").Renderer;

pub fn main() !void {
    var input = Input{};
    var time = Time.init();
    var window = try Window.init(.{});
    defer window.deinit();
    var renderer = try Renderer.init(window);
    defer renderer.deinit();

    var view = Maths.Transform{};
    view.position[2] = -10.0;

    while (true) {
        window.update(&input) orelse break;
        time.tick();

        // gameUpdate()
        if (input.getKeyJustDown(.escape)) {
            break;
        }
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
        const direction_len = @sqrt(@reduce(.Add, direction * direction));
        direction = if (std.math.approxEqAbs(f32, direction_len, 0.0, comptime std.math.floatEps(f32)))
            @splat(3, @as(f32, 0.0))
        else
            direction / @splat(3, direction_len);
        const speed = 5.0;
        view.position -= direction * @splat(3, @floatCast(f32, time.delta) * speed);

        const nodedata = Renderer.RenderObject{
            .mesh = .cube,
            .transform = Maths.Transform{
                // .position = .{ @floatCast(f32, @sin(time.running)) * 5.0, 0.0, 0.0 },
                .rotation = @splat(3, @floatCast(f32, time.running)),
            },
        };
        renderer.render_objects.append(&.{ .data = nodedata });

        // resize()
        {
            renderer.projection = Maths.Matrix(4, 4, f32).perspective(std.math.pi / 2.0, @intToFloat(f32, renderer.surface_capabilities.currentExtent.width) / @intToFloat(f32, renderer.surface_capabilities.currentExtent.height), 0.1, 100.0);
            // renderer.projection = Maths.Matrix(4, 4, f32).orthographic(0.0, @intToFloat(f32, renderer.surface_capabilities.currentExtent.width), -@intToFloat(f32, renderer.surface_capabilities.currentExtent.height), 0.0, -1.0, 1.0);
        }
        renderer.view = view.matrix();

        try renderer.update();
        input.save();
    }
}
