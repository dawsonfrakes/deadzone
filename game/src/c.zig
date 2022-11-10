const platform = @import("platform.zig");

// debug (because zls isn't good enough yet Sadge)
// pub usingnamespace @cImport({
//     @cInclude("X11/Xlib.h");
//     @cInclude("X11/keysym.h");
//     @cDefine("VK_USE_PLATFORM_XLIB_KHR", {});
//     @cInclude("vulkan/vulkan.h");
// });

// release
pub usingnamespace @cImport({
    if (platform.Windowing == .xlib) {
        @cDefine("VK_USE_PLATFORM_XLIB_KHR", {});
        @cInclude("X11/Xlib.h");
        @cInclude("X11/keysym.h");
    }
    if (platform.Windowing == .win32) {
        @cDefine("VK_USE_PLATFORM_WIN32_KHR", {});
        @cDefine("WIN32_LEAN_AND_MEAN", {});
        @cInclude("windows.h");
    }

    if (platform.Rendering == .vulkan) {
        @cInclude("vulkan/vulkan.h");
    }
});
