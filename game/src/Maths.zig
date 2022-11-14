const std = @import("std");

pub const Transform = struct {
    position: @Vector(3, f32) = @splat(3, @as(f32, 0.0)),
    rotation: @Vector(3, f32) = @splat(3, @as(f32, 0.0)),
    scale: @Vector(3, f32) = @splat(3, @as(f32, 1.0)),

    pub fn matrix(self: Transform) Matrix(4, 4, f32) {
        return (comptime Matrix(4, 4, f32).I()).translate(self.position).rotate(self.rotation).scale(self.scale);
    }
};

pub fn Matrix(
    comptime w: comptime_int,
    comptime h: comptime_int,
    comptime Element: type,
) type {
    return struct {
        const Self = @This();

        data: [w]@Vector(h, Element),

        pub inline fn O() Self {
            return .{
                .data = [_]@Vector(h, Element){@splat(h, @as(Element, 0))} ** w,
            };
        }

        pub inline fn I() Self {
            comptime std.debug.assert(w == h);
            comptime var result = O();
            inline for (result.data) |*row, i| {
                row.*[i] = @as(Element, 1);
            }
            return result;
        }

        pub fn mul(self: Self, other: Self) Self {
            var result = O();
            comptime var i = 0;
            inline while (i < w) : (i += 1) {
                comptime var j = 0;
                inline while (j < h) : (j += 1) {
                    comptime var k = 0;
                    inline while (k < w) : (k += 1) {
                        result.data[i][j] += self.data[k][j] * other.data[i][k];
                    }
                }
            }
            return result;
        }

        pub fn mulv(self: Self, other: @Vector(w, Element)) @Vector(w, Element) {
            var result = @splat(h, @as(Element, 0));
            comptime var i = 0;
            inline while (i < w) : (i += 1) {
                comptime var j = 0;
                inline while (j < h) : (j += 1) {
                    result[j] += self.data[i][j] * other[i];
                }
            }
            return result;
        }

        pub fn perspective(fovy: Element, aspect: Element, znear: Element, zfar: Element) Self {
            comptime std.debug.assert(w == 4);
            const focal_length = @as(Element, 1) / @tan(fovy / @as(Element, 2));
            var result = O();
            // map x coordinates to clip-space
            result.data[0][0] = focal_length / aspect;
            // map y coordinates to clip-space
            result.data[1][1] = -focal_length;
            // map z coordinates to clip-space (near:1-far:0)
            result.data[2][2] = znear / (zfar - znear);
            result.data[3][2] = (znear * zfar) / (zfar - znear);
            // copy -z into w for perspective divide
            result.data[2][3] = -@as(Element, 1);
            return result;
        }

        pub fn orthographic(left: Element, right: Element, top: Element, bottom: Element, near: Element, far: Element) Self {
            comptime std.debug.assert(w == 4);
            var result = O();
            // scale
            result.data[0][0] = @as(Element, 2) / (right - left);
            result.data[1][1] = @as(Element, 2) / (top - bottom);
            result.data[2][2] = -@as(Element, 2) / (far - near);
            // translate
            result.data[3][0] = -(right + left) / (right - left);
            result.data[3][1] = -(top + bottom) / (top - bottom);
            result.data[3][2] = -(far + near) / (far - near);

            result.data[3][3] = @as(Element, 1);
            return result;
        }

        pub fn translate(self: Self, t: @Vector(3, Element)) Self {
            comptime std.debug.assert(w == 4);
            var m = comptime I();
            comptime var i = 0;
            inline while (i < 3) : (i += 1) {
                m.data[3][i] = t[i];
            }
            return self.mul(m);
        }

        pub fn RotationX(angle: Element) Self {
            var result = I();
            const ca = @cos(angle);
            const sa = @sin(angle);
            result.data[1][1] = ca;
            result.data[2][1] = sa;
            result.data[1][2] = -sa;
            result.data[2][2] = ca;
            return result;
        }

        pub fn RotationY(angle: Element) Self {
            var result = I();
            const ca = @cos(angle);
            const sa = @sin(angle);
            result.data[0][0] = ca;
            result.data[2][0] = sa;
            result.data[0][2] = -sa;
            result.data[2][2] = ca;
            return result;
        }

        pub fn RotationZ(angle: Element) Self {
            var result = I();
            const ca = @cos(angle);
            const sa = @sin(angle);
            result.data[0][0] = ca;
            result.data[1][0] = sa;
            result.data[0][1] = -sa;
            result.data[1][1] = ca;
            return result;
        }

        pub fn rotate(self: Self, r: @Vector(3, Element)) Self {
            return self.mul(RotationZ(r[2])).mul(RotationX(r[0])).mul(RotationY(r[1]));
        }

        pub fn scale(self: Self, s: @Vector(3, Element)) Self {
            comptime std.debug.assert(w == 4);
            var m = comptime I();
            comptime var i = 0;
            inline while (i < 3) : (i += 1) {
                m.data[i][i] = s[i];
            }
            return self.mul(m);
        }
    };
}
