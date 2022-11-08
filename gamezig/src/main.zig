const std = @import("std");
const platform = @import("platform.zig");
const c = @import("c.zig");

const Renderer = Vulkan;

const Vulkan = struct {
    const zi = std.mem.zeroInit;

    instance: c.VkInstance,
    surface: c.VkSurfaceKHR,

    fn vkCheck(result: c.VkResult) !void {
        if (result != c.VK_SUCCESS) {
            std.debug.print("VkResult({})\n", .{result});
            return error.VkError;
        }
    }

    fn init(window: Window) !Vulkan {
        var result: Vulkan = undefined;
        const instance_extensions = [_][*c]const u8{ c.VK_KHR_SURFACE_EXTENSION_NAME, c.VK_KHR_XLIB_SURFACE_EXTENSION_NAME };
        try vkCheck(c.vkCreateInstance(&zi(c.VkInstanceCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .enabledLayerCount = 1,
            .ppEnabledLayerNames = &[_][*c]const u8{"VK_LAYER_KHRONOS_validation"},
            .enabledExtensionCount = instance_extensions.len,
            .ppEnabledExtensionNames = &instance_extensions,
        }), null, &result.instance));
        try vkCheck(switch (platform.Windowing) {
            .xlib => c.vkCreateXlibSurfaceKHR(result.instance, &zi(c.VkXlibSurfaceCreateInfoKHR, .{
                .sType = c.VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
                .dpy = window.dpy,
                .window = window.win,
            }), null, &result.surface),
            .win32 => c.vkCreateWin32SurfaceKHR(result.instance, &zi(c.VkWin32SurfaceCreateInfoKHR, .{
                .sType = c.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
                .hinstance = window.inst,
                .hwnd = window.hwnd,
            }), null, &result.surface),
        });
        return result;
    }

    fn deinit(self: Vulkan) void {
        c.vkDestroySurfaceKHR(self.instance, self.surface, null);
        c.vkDestroyInstance(self.instance, null);
    }
};

const Window = Xlib;

const Xlib = struct {
    dpy: *c.Display,
    win: c.Window,
    wm_close: c.Atom,

    fn init(args: struct { title: [:0]const u8 = "Title" }) !Xlib {
        var result: Xlib = undefined;
        result.dpy = c.XOpenDisplay(null) orelse return error.OpenDisplayFailure;
        const scr = c.XDefaultScreen(result.dpy);
        const root = c.XRootWindow(result.dpy, scr);
        var attrs = std.mem.zeroInit(c.XSetWindowAttributes, .{
            .event_mask = c.KeyPressMask | c.KeyReleaseMask,
        });
        result.win = c.XCreateWindow(
            result.dpy,
            root,
            0,
            0,
            800,
            600,
            0,
            c.CopyFromParent,
            c.InputOutput,
            c.CopyFromParent,
            c.CWEventMask,
            &attrs,
        );
        result.wm_close = c.XInternAtom(result.dpy, "WM_DELETE_WINDOW", c.False);
        _ = c.XSetWMProtocols(result.dpy, result.win, &result.wm_close, 1);
        _ = c.XStoreName(result.dpy, result.win, args.title.ptr);
        _ = c.XMapWindow(result.dpy, result.win);
        return result;
    }

    fn update(self: *Xlib) ?void {
        while (c.XPending(self.dpy) > 0) {
            var ev: c.XEvent = undefined;
            _ = c.XNextEvent(self.dpy, &ev);
            switch (ev.type) {
                c.KeyPress, c.KeyRelease => {
                    const sym = c.XLookupKeysym(&ev.xkey, 0);
                    const pressed = ev.type == c.KeyPress;
                    if (sym == c.XK_Escape and pressed) {
                        return null;
                    }
                },
                c.ClientMessage => if (ev.xclient.data.l[0] == @intCast(c_long, self.wm_close)) return null,
                c.DestroyNotify => return null,
                else => {},
            }
        }
    }

    fn deinit(self: Xlib) void {
        _ = c.XCloseDisplay(self.dpy);
    }
};

pub fn main() !void {
    var window = try Window.init(.{});
    defer window.deinit();
    const renderer = try Renderer.init(window);
    defer renderer.deinit();

    while (true) {
        window.update() orelse break;
    }
}
