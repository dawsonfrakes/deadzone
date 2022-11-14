const std = @import("std");
const c = @import("../c.zig");
const Input = @import("../Input.zig");
const user32 = std.os.windows.user32;

const Win32 = @This();

inst: c.HINSTANCE,
hwnd: c.HWND,

pub fn init(args: struct { title: [:0]const u8 = "Title" }) !Win32 {
    var result: Win32 = undefined;
    result.inst = c.GetModuleHandleA(null);
    _ = try user32.registerClassExA(&.{
        .style = user32.CS_OWNDC | user32.CS_VREDRAW | user32.CS_HREDRAW,
        .lpfnWndProc = user32.DefWindowProcA,
        .hInstance = @ptrCast(std.os.windows.HINSTANCE, result.inst),
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = "MUH_CLASS",
        .hIconSm = null,
    });
    result.hwnd = c.CreateWindowExA(
        0,
        "MUH_CLASS",
        args.title.ptr,
        user32.WS_OVERLAPPEDWINDOW | user32.WS_VISIBLE,
        user32.CW_USEDEFAULT,
        user32.CW_USEDEFAULT,
        user32.CW_USEDEFAULT,
        user32.CW_USEDEFAULT,
        null,
        null,
        result.inst,
        null,
    );
    return result;
}

pub fn deinit(self: Win32) void {
    _ = self;
}

pub fn update(self: *Win32, input: *Input) ?void {
    _ = .{ self, input };
    var msg: user32.MSG = undefined;
    while (user32.peekMessageA(&msg, null, 0, 0, user32.PM_REMOVE) catch return null) {
        _ = user32.translateMessage(&msg);
        _ = user32.dispatchMessageA(&msg);
    }
}
