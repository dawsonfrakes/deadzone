const std = @import("std");

pub const Transform = struct {
    translation: @Vector(3, f32) = @splat(3, @as(f32, 0.0)),
    rotation: @Vector(3, f32) = @splat(3, @as(f32, 0.0)),
    scale: @Vector(3, f32) = @splat(3, @as(f32, 1.0)),

    pub fn matrix(transform: Transform) Matrix(f32, 4, 4) {
        return (comptime Matrix(f32, 4, 4).I())
            .scale(transform.scale)
            .rotate(transform.rotation)
            .translate(transform.translation);
    }
};

pub fn Matrix(
    comptime T: type,
    comptime w: comptime_int,
    comptime h: comptime_int,
) type {
    return struct {
        const Self = @This();

        data: [w]@Vector(h, T),

        pub fn O() Self {
            return std.mem.zeroes(Self);
        }

        pub fn I() Self {
            var result = O();
            inline for (result.data) |*col_data, col_index| {
                col_data.*[col_index] = 1.0;
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
                        result.data[j][i] += self.data[k][i] * other.data[j][k];
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
            result.data[2][1] = -s;
            result.data[1][2] = s;
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
            result.data[1][0] = -s;
            result.data[0][1] = s;
            result.data[1][1] = c;
            return result;
        }

        // reference: https://vincent-p.github.io/posts/vulkan_perspective_matrix/
        pub fn Perspective(fovy: T, aspect: T, znear: T, zfar: T) Self {
            const focal_length = @as(T, 1) / @tan(fovy / @as(T, 2));

            var result = O();
            // map x coordinates to clip-space
            result.data[0][0] = focal_length / aspect;
            // map y coordinates to clip-space
            result.data[1][1] = -focal_length;
            // map z coordinates to clip-space (near:1-far:0)
            result.data[2][2] = znear / (zfar - znear);
            result.data[3][2] = (znear * zfar) / (zfar - znear);
            // copy -z into w for perspective divide
            result.data[2][3] = -@as(T, 1);
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

        pub fn rotate(self: Self, r: @Vector(3, T)) Self {
            return RotationZ(r[2]).mul(RotationX(r[0]).mul(RotationY(r[1]).mul(self)));
        }

        pub fn scale(self: Self, t: @Vector(3, T)) Self {
            var result = I();
            comptime var i = 0;
            inline while (i < 3) : (i += 1) {
                result.data[i][i] = t[i];
            }
            return result.mul(self);
        }
    };
}
