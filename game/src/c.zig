const platform = @import("platform.zig");

pub usingnamespace @cImport({
    if (platform.WINDOW_LIBRARY == .xlib) {
        @cInclude("X11/Xlib.h");
        @cInclude("X11/keysym.h");
    } else if (platform.WINDOW_LIBRARY == .win32) {
        @compileError("Win32 windowing not yet supported");
    }

    if (platform.RENDER_LIBRARY == .vulkan) {
        if (platform.WINDOW_LIBRARY == .xlib) {
            @cDefine("VK_USE_PLATFORM_XLIB_KHR", {});
        } else if (platform.WINDOW_LIBRARY == .win32) {
            @cDefine("VK_USE_PLATFORM_WIN32_KHR", {});
        }
        @cInclude("vulkan/vulkan.h");
    }
});
