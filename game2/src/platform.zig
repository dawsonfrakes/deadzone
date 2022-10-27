const builtin = @import("builtin");

pub const Windowing = enum { xlib, win32 };

pub const WINDOW_LIBRARY: Windowing = switch (builtin.target.os.tag) {
    .linux => .xlib,
    .windows => .win32,
    else => @compileError("OS not yet supported"),
};

pub const Rendering = enum { vulkan };

pub const RENDER_LIBRARY: Rendering = switch (WINDOW_LIBRARY) {
    .xlib, .win32 => .vulkan,
};
