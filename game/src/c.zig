const platform = @import("platform.zig");

pub usingnamespace @cImport({
    if (platform.window_lib == .xlib) {
        @cInclude("X11/Xlib.h");
        @cInclude("X11/keysym.h");
    } else if (platform.window_lib == .win32) {
        @compileError("Win32 windowing not yet supported");
    }

    if (platform.render_lib == .vulkan) {
        if (platform.window_lib == .xlib) {
            @cDefine("VK_USE_PLATFORM_XLIB_KHR", {});
        } else if (platform.window_lib == .win32) {
            @cDefine("VK_USE_PLATFORM_WIN32_KHR", {});
        }
        @cInclude("vulkan/vulkan.h");
    }
});
