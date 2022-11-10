const WindowAPI = enum { xlib, win32 };
const RenderAPI = enum { vulkan };

pub const Windowing = WindowAPI.xlib;
pub const Rendering = RenderAPI.vulkan;
