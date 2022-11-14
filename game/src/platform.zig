const builtin = @import("builtin");

const WindowAPI = enum { xlib, win32 };
const RenderAPI = enum { vulkan };

pub const Windowing = switch (builtin.os.tag) {
    .linux => WindowAPI.xlib,
    .windows => WindowAPI.win32,
    else => @compileError("not supported"),
};

pub const Rendering = switch (builtin.os.tag) {
    .linux, .windows => RenderAPI.vulkan,
    else => @compileError("not supported"),
};

pub const Window = switch (Windowing) {
    .xlib => @import("windowing/xlib.zig"),
    .win32 => @import("windowing/win32.zig"),
};

pub const Renderer = switch (Rendering) {
    .vulkan => @import("rendering/vulkan.zig"),
};
