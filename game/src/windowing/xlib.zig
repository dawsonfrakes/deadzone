const std = @import("std");
const c = @import("../c.zig");
const Input = @import("../Input.zig");

const Xlib = @This();

dpy: *c.Display,
win: c.Window,
wm_close: c.Atom,

pub fn init(args: struct { title: [:0]const u8 = "Title" }) !Xlib {
    var result: Xlib = undefined;
    result.dpy = c.XOpenDisplay(null) orelse return error.OpenDisplayFailure;
    _ = c.XAutoRepeatOff(result.dpy);
    const scr = c.XDefaultScreen(result.dpy);
    const root = c.XRootWindow(result.dpy, scr);
    var attrs = std.mem.zeroInit(c.XSetWindowAttributes, .{
        .event_mask = c.KeyPressMask | c.KeyReleaseMask | c.ButtonPressMask | c.ButtonReleaseMask,
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

pub fn deinit(self: Xlib) void {
    _ = c.XAutoRepeatOn(self.dpy);
    _ = c.XSync(self.dpy, c.False);
    _ = c.XDestroyWindow(self.dpy, self.win);
    // NOTE: XCloseDisplay seems to segfault with nvidia. I'm just avoiding it for now
    // _ = c.XCloseDisplay(self.dpy);
}

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
const button_lookup = std.enums.directEnumArray(Input.MouseButtons, u8, 0, .{
    .left = c.Button1,
    .middle = c.Button2,
    .right = c.Button3,
});
pub fn update(self: *Xlib, input: *Input) ?void {
    while (c.XPending(self.dpy) > 0) {
        var ev: c.XEvent = undefined;
        _ = c.XNextEvent(self.dpy, &ev);
        switch (ev.type) {
            c.KeyPress, c.KeyRelease => {
                const sym = c.XLookupKeysym(&ev.xkey, 0);
                const pressed = ev.type == c.KeyPress;
                var i: usize = 0;
                while (i < key_lookup.len) : (i += 1) {
                    if (key_lookup[i] == sym)
                        input.setKey(@intToEnum(Input.Keys, i), pressed);
                }
            },
            c.ButtonPress, c.ButtonRelease => {
                const pressed = ev.type == c.ButtonPress;
                switch (ev.xbutton.button) {
                    c.Button4 => input.mouse[2] += 1,
                    c.Button5 => input.mouse[2] -= 1,
                    else => |b| {
                        var i: usize = 0;
                        while (i < button_lookup.len) : (i += 1) {
                            if (button_lookup[i] == b)
                                input.setMouseButton(@intToEnum(Input.MouseButtons, i), pressed);
                        }
                    },
                }
            },
            c.MappingNotify => _ = c.XRefreshKeyboardMapping(&ev.xmapping),
            c.ClientMessage => if (ev.xclient.data.l[0] == @intCast(c_long, self.wm_close)) return null,
            c.DestroyNotify => return null,
            else => {},
        }
    }
}
