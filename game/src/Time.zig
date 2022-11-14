const std = @import("std");

const Time = @This();

delta: f64 = 0.0,
running: f64 = 0.0,
_start: i128 = 0,
_current: i128 = 0,
_previous: i128 = 0,

pub fn init() Time {
    var result = Time{};
    result._start = std.time.nanoTimestamp();
    result._current = result._start;
    result._previous = result._start;
    return result;
}

pub fn toSeconds(time: i128) f64 {
    return @intToFloat(f64, time) / std.time.ns_per_s;
}

pub fn tick(self: *Time) void {
    self._current = std.time.nanoTimestamp();
    self.delta = toSeconds(self._current - self._previous);
    self.running = toSeconds(self._current - self._start);
    self._previous = self._current;
}
