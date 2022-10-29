const Window = @import("Window.zig");
const Renderer = @import("Renderer.zig");
const Input = @import("Input.zig");
const Time = @import("Time.zig");

pub fn main() !void {
    var input = Input{};
    var time = Time.init();

    var window = try Window.create(.{ .input = &input });
    defer window.destroy();

    var renderer = try Renderer.create(.{ .window = &window, .time = &time });
    defer renderer.destroy();

    while (true) {
        window.update() orelse break;
        time.update();
        if (input.getKeyJustDown(.escape) or input.getKeyJustDown(.q)) break;
        try renderer.update();
        input.save();
    }
}
