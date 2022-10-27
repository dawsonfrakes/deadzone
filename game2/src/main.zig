const Window = @import("Window.zig");
const Renderer = @import("Renderer.zig");
const Input = @import("Input.zig");

pub fn main() anyerror!void {
    var input = Input{};

    var window = try Window.create(.{ .input = &input });
    defer window.destroy();

    var renderer = try Renderer.create(.{ .window = &window });
    defer renderer.destroy();

    while (true) {
        window.update() orelse break;
        if (input.getKeyJustDown(.escape) or input.getKeyJustDown(.q)) break;
        renderer.update() orelse break;
        input.tick();
    }
}
