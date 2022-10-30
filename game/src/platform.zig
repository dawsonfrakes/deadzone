const builtin = @import("builtin");

pub const Windowing = enum { xlib, win32 };

pub const window_lib: Windowing = switch (builtin.target.os.tag) {
    .linux => .xlib,
    .windows => .win32,
    else => @compileError("OS not yet supported"),
};

pub const Rendering = enum { vulkan };

pub const render_lib: Rendering = switch (window_lib) {
    .xlib, .win32 => .vulkan,
};
