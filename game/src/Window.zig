const std = @import("std");
const platform = @import("platform.zig");
const c = @import("c.zig");
const Input = @import("Input.zig");

const Window = @This();
const Impl = switch (platform.window_lib) {
    .xlib => XlibWindowImpl,
    .win32 => @compileError("Win32WindowImpl is not yet implemented"),
};
pub usingnamespace Impl;

impl: Impl,
x: i16 = 0,
y: i16 = 0,
width: u16 = 800,
height: u16 = 600,
input: *Input,

const XlibWindowImpl = struct {
    // zig fmt: off
    const key_lookup = std.enums.directEnumArray(Input.Keys, u16, 0, .{
        .a = c.XK_a, .b = c.XK_b, .c = c.XK_c, .d = c.XK_d, .e = c.XK_e, .f = c.XK_f, .g = c.XK_g, .h = c.XK_h, .i = c.XK_i, .j = c.XK_j, .k = c.XK_k, .l = c.XK_l, .m = c.XK_m, .n = c.XK_n, .o = c.XK_o, .p = c.XK_p, .q = c.XK_q, .r = c.XK_r, .s = c.XK_s, .t = c.XK_t, .u = c.XK_u, .v = c.XK_v, .w = c.XK_w, .x = c.XK_x, .y = c.XK_y, .z = c.XK_z,
        .@"0" = c.XK_0, .@"1" = c.XK_1, .@"2" = c.XK_2, .@"3" = c.XK_3, .@"4" = c.XK_4, .@"5" = c.XK_5, .@"6" = c.XK_6, .@"7" = c.XK_7, .@"8" = c.XK_8, .@"9" = c.XK_9,
        .f1 = c.XK_F1, .f2 = c.XK_F2, .f3 = c.XK_F3, .f4 = c.XK_F4, .f5 = c.XK_F5, .f6 = c.XK_F6, .f7 = c.XK_F7, .f8 = c.XK_F8, .f9 = c.XK_F9, .f10 = c.XK_F10, .f11 = c.XK_F11, .f12 = c.XK_F12,
        .left_arrow = c.XK_Left, .down_arrow = c.XK_Down, .up_arrow = c.XK_Up, .right_arrow = c.XK_Right,
        .backtick = c.XK_grave, .minus = c.XK_minus, .equals = c.XK_equal, .period = c.XK_period, .comma = c.XK_comma, .slash = c.XK_slash, .backslash = c.XK_backslash, .semicolon = c.XK_semicolon, .apostrophe = c.XK_apostrophe, .left_bracket = c.XK_bracketleft, .right_bracket = c.XK_bracketright,
        .backspace = c.XK_BackSpace, .tab = c.XK_Tab, .caps = c.XK_Caps_Lock, .space = c.XK_space, .escape = c.XK_Escape, .@"return" = c.XK_Return, .delete = c.XK_Delete,
        .left_control = c.XK_Control_L, .left_alt = c.XK_Alt_L, .left_shift = c.XK_Shift_L, .right_control = c.XK_Control_R, .right_alt = c.XK_Alt_R, .right_shift = c.XK_Shift_R,
    });
    // zig fmt: on

    dpy: ?*c.Display,
    win: c.Window,
    wm_close: c.Atom,

    pub fn create(input: *Input) !Window {
        var result: Window = undefined;
        result.input = input;
        result.impl.dpy = c.XOpenDisplay(null);
        try std.testing.expect(result.impl.dpy != null);
        _ = c.XAutoRepeatOff(result.impl.dpy);
        const scr = c.XDefaultScreen(result.impl.dpy);
        const root = c.XRootWindow(result.impl.dpy, scr);
        var s = std.mem.zeroInit(c.XSetWindowAttributes, .{ .event_mask = c.ExposureMask | c.KeyPressMask | c.KeyReleaseMask });
        result.impl.win = c.XCreateWindow(result.impl.dpy, root, result.x, result.y, result.width, result.height, 0, c.CopyFromParent, c.InputOutput, c.CopyFromParent, c.CWEventMask, &s);
        result.impl.wm_close = c.XInternAtom(result.impl.dpy, "WM_DELETE_WINDOW", c.False);
        _ = c.XSetWMProtocols(result.impl.dpy, result.impl.win, &result.impl.wm_close, 1);
        _ = c.XMapWindow(result.impl.dpy, result.impl.win);
        return result;
    }

    pub fn update(self: *Window) ?void {
        while (c.XPending(self.impl.dpy) > 0) {
            var ev: c.XEvent = undefined;
            _ = c.XNextEvent(self.impl.dpy, &ev);
            switch (ev.@"type") {
                c.Expose => std.debug.print("Window(w={}, h={})\n", .{ ev.xexpose.width, ev.xexpose.height }),
                c.KeyPress, c.KeyRelease => {
                    const sym = c.XLookupKeysym(&ev.xkey, 0);
                    const pressed = ev.@"type" == c.KeyPress;
                    var i: usize = 0;
                    while (i < key_lookup.len) : (i += 1) {
                        if (key_lookup[i] == sym)
                            self.input.setKey(@intToEnum(Input.Keys, i), pressed);
                    }
                },
                c.MappingNotify => _ = c.XRefreshKeyboardMapping(&ev.xmapping),
                c.ClientMessage => if (ev.xclient.data.l[0] == self.impl.wm_close) return null,
                c.DestroyNotify => return null,
                else => {},
            }
        }
    }

    pub fn destroy(self: Window) void {
        _ = c.XDestroyWindow(self.impl.dpy, self.impl.win);
        _ = c.XAutoRepeatOn(self.impl.dpy);
        _ = c.XCloseDisplay(self.impl.dpy);
    }
};
