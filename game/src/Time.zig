const std = @import("std");

const Time = @This();

_start: i128,
_previous: i128,
_current: i128,
delta: f64 = 0.0,
running: f64 = 0.0,

pub fn init() Time {
    const init_time = std.time.nanoTimestamp();
    return .{
        ._start = init_time,
        ._previous = init_time,
        ._current = init_time,
    };
}

pub fn update(self: *Time) void {
    self._current = std.time.nanoTimestamp();
    self.delta = @intToFloat(f64, self._current - self._previous) / std.time.ns_per_s;
    self.running = @intToFloat(f64, self._current - self._start) / std.time.ns_per_s;
    self._previous = self._current;
}
