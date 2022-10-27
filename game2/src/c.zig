const platform = @import("platform.zig");

pub usingnamespace @cImport({
    switch (platform.WINDOW_LIBRARY) {
        .xlib => {
            @cInclude("X11/Xlib.h");
            @cInclude("X11/keysym.h");
        },
        .win32 => @compileError("WIN32 not yet supported"),
    }
    switch (platform.RENDER_LIBRARY) {
        .vulkan => {
            switch (platform.WINDOW_LIBRARY) {
                .xlib => @cDefine("VK_USE_PLATFORM_XLIB_KHR", {}),
                .win32 => @cDefine("VK_USE_PLATFORM_WIN32_KHR", {}),
            }
            @cInclude("vulkan/vulkan.h");
        },
    }
});
