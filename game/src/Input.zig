const std = @import("std");
const Input = @This();

pub const Keys = enum {
    a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z,
    @"0",  @"1",  @"2",  @"3",  @"4",  @"5",  @"6",  @"7",  @"8",  @"9",
    f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12,
    left_arrow, down_arrow, up_arrow, right_arrow,
    backtick, minus, equals, period, comma, slash, backslash, semicolon, apostrophe, left_bracket, right_bracket,
    backspace, tab, caps, space, escape, @"return", delete,
    left_control, left_alt, left_shift, right_control, right_alt, right_shift,
};

keys: std.EnumArray(Keys, bool) = std.EnumArray(Keys, bool).initFill(false),
keys_previous: std.EnumArray(Keys, bool) = std.EnumArray(Keys, bool).initFill(false),

pub fn tick(self: *Input) void {
    self.keys_previous = self.keys;
}

pub fn setKey(self: *Input, key: Keys, value: bool) void {
    self.keys.set(key, value);
}

pub fn getKeyDown(self: Input, key: Keys) bool {
    return self.keys.get(key);
}

pub fn getKeyUp(self: Input, key: Keys) bool {
    return !self.keys.get(key);
}

pub fn getKeyJustDown(self: Input, key: Keys) bool {
    return self.keys.get(key) and !self.keys_previous.get(key);
}

pub fn getKeyJustUp(self: Input, key: Keys) bool {
    return !self.keys.get(key) and self.keys_previous.get(key);
}
