const std = @import("std");

pub fn Matrix(
    comptime T: type,
    comptime w: comptime_int,
    comptime h: comptime_int,
) type {
    return struct {
        const Self = @This();

        data: [h]@Vector(w, T) = I().data,

        pub fn O() Self {
            return std.mem.zeroes(Self);
        }

        pub fn I() Self {
            var result = O();
            inline for (result.data) |*row_data, row_index| {
                row_data.*[row_index] = 1.0;
            }
            return result;
        }

        pub fn mul(self: Self, other: Self) Self {
            var result = O();
            comptime var i = 0;
            inline while (i < h) : (i += 1) {
                comptime var j = 0;
                inline while (j < w) : (j += 1) {
                    comptime var k = 0;
                    inline while (k < h) : (k += 1) {
                        result.data[i][j] += self.data[i][k] * other.data[k][j];
                    }
                }
            }
            return result;
        }

        // 3d maths
        pub fn RotationX(angle: T) Self {
            var result = I();
            const c = @cos(angle);
            const s = @sin(angle);
            result.data[1][1] = c;
            result.data[2][1] = s;
            result.data[1][2] = -s;
            result.data[2][2] = c;
            return result;
        }

        pub fn RotationY(angle: T) Self {
            var result = I();
            const c = @cos(angle);
            const s = @sin(angle);
            result.data[0][0] = c;
            result.data[2][0] = s;
            result.data[0][2] = -s;
            result.data[2][2] = c;
            return result;
        }

        pub fn RotationZ(angle: T) Self {
            var result = I();
            const c = @cos(angle);
            const s = @sin(angle);
            result.data[0][0] = c;
            result.data[1][0] = s;
            result.data[0][1] = -s;
            result.data[1][1] = c;
            return result;
        }

        pub fn translate(self: Self, t: @Vector(3, T)) Self {
            var result = I();
            comptime var i = 0;
            inline while (i < 3) : (i += 1) {
                result.data[h - 1][i] = t[i];
            }
            return result.mul(self);
        }

        pub fn scale(self: Self, t: @Vector(3, T)) Self {
            var result = I();
            comptime var i = 0;
            inline while (i < 3) : (i += 1) {
                result.data[i][i] = t[i];
            }
            return result.mul(self);
        }

        pub fn rotate(self: Self, r: @Vector(3, T)) Self {
            return RotationZ(r[2]).mul(RotationX(r[0]).mul(RotationY(r[1]).mul(self)));
        }
    };
}
