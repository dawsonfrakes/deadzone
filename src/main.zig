const std = @import("std");
const c = @cImport(@cInclude("GL/gl.h"));
const windows = std.os.windows;
const user32 = windows.user32;
const gdi32 = windows.gdi32;
const kernel32 = windows.kernel32;
const HGLRC = windows.HGLRC;
const WINAPI = windows.WINAPI;
extern "gdi32" fn wglDeleteContext(hglrc: ?HGLRC) callconv(WINAPI) bool;
extern "gdi32" fn wglGetProcAddress(procname: [*:0]const u8) callconv(WINAPI) ?*anyopaque;

fn windowProc(hwnd: windows.HWND, msg: windows.UINT, wparam: windows.WPARAM, lparam: windows.LPARAM) callconv(WINAPI) windows.LRESULT {
    switch (msg) {
        user32.WM_KEYDOWN, user32.WM_KEYUP, user32.WM_SYSKEYDOWN, user32.WM_SYSKEYUP => {
            const SYS_ALT_KEY = (1 << 29);
            const VK_ESCAPE = 0x1B;
            const VK_F4 = 0x73;
            if (wparam == VK_ESCAPE) {
                user32.postQuitMessage(0);
            }
            if (msg == user32.WM_SYSKEYDOWN and wparam == VK_F4 and (lparam & SYS_ALT_KEY) != 0) {
                user32.postQuitMessage(0);
            }
        },
        user32.WM_SIZE => c.glViewport(0, 0, @intCast(c_int, lparam) & 0xFFFF, (@intCast(c_int, lparam) >> 16) & 0xFFFF),
        user32.WM_CLOSE => user32.destroyWindow(hwnd) catch unreachable,
        user32.WM_DESTROY => user32.postQuitMessage(0),
        else => return user32.defWindowProcA(hwnd, msg, wparam, lparam),
    }
    return 0;
}

const GLsizeiptr = usize;
const GLintptr = isize;
const GLchar = u8;

const GL_STATIC_DRAW = 0x88E4;

const GL_ARRAY_BUFFER = 0x8892;
const GL_ELEMENT_ARRAY_BUFFER = 0x8893;

const GL_FRAGMENT_SHADER = 0x8B30;
const GL_VERTEX_SHADER = 0x8B31;

const GL_NEGATIVE_ONE_TO_ONE = 0x935E;
const GL_ZERO_TO_ONE = 0x935F;
const GL_LOWER_LEFT = 0x8CA1;
const GL_UPPER_LEFT = 0x8CA2;

const GLFuncs = struct {
    ClipControl: *const fn (origin: c.GLenum, depth: c.GLenum) void,

    CreateVertexArrays: *const fn (n: c.GLsizei, arrays: [*]c.GLuint) void,
    BindVertexArray: *const fn (array: c.GLuint) void,
    VertexArrayVertexBuffer: *const fn (vaobj: c.GLuint, bindingindex: c.GLuint, buffer: c.GLuint, offset: GLintptr, stride: c.GLsizei) void,
    VertexArrayElementBuffer: *const fn (vaobj: c.GLuint, buffer: c.GLuint) void,
    VertexArrayAttribBinding: *const fn (vaobj: c.GLuint, attribindex: c.GLuint, bindingindex: c.GLuint) void,
    VertexArrayBindingDivisor: *const fn (vaobj: c.GLuint, bindingindex: c.GLuint, divisor: c.GLuint) void,
    VertexArrayAttribFormat: *const fn (vaobj: c.GLuint, attribindex: c.GLuint, size: c.GLint, type: c.GLenum, normalized: c.GLboolean, relativeoffset: c.GLuint) void,
    EnableVertexArrayAttrib: *const fn (vaobj: c.GLuint, index: c.GLuint) void,
    DisableVertexArrayAttrib: *const fn (vaobj: c.GLuint, index: c.GLuint) void,
    DeleteVertexArrays: *const fn (n: c.GLsizei, arrays: [*]const c.GLuint) void,

    CreateBuffers: *const fn (n: c.GLsizei, buffers: [*]c.GLuint) void,
    NamedBufferData: *const fn (buffer: c.GLuint, size: GLsizeiptr, data: ?*const anyopaque, usage: c.GLenum) void,
    NamedBufferSubData: *const fn (buffer: c.GLuint, offset: GLintptr, size: c.GLsizei, data: *const anyopaque) void,
    DeleteBuffers: *const fn (n: c.GLsizei, buffers: [*]const c.GLuint) void,

    CreateShader: *const fn (shaderType: c.GLenum) c.GLuint,
    ShaderSource: *const fn (shader: c.GLuint, count: c.GLsizei, string: [*]const [*:0]const GLchar, length: ?[*]const c.GLint) void,
    CompileShader: *const fn (shader: c.GLuint) void,
    DeleteShader: *const fn (shader: c.GLuint) void,

    CreateProgram: *const fn () c.GLuint,
    AttachShader: *const fn (program: c.GLuint, shader: c.GLuint) void,
    DetachShader: *const fn (program: c.GLuint, shader: c.GLuint) void,
    LinkProgram: *const fn (program: c.GLuint) void,
    GetUniformLocation: *const fn (program: c.GLuint, name: [*:0]const GLchar) c.GLint,
    ProgramUniformMatrix4fv: *const fn (program: c.GLuint, location: c.GLint, count: c.GLsizei, transpose: c.GLboolean, value: [*]const c.GLfloat) void,
    UseProgram: *const fn (program: c.GLuint) void,
    DeleteProgram: *const fn (program: c.GLuint) void,

    CreateTextures: *const fn (target: c.GLenum, n: c.GLsizei, textures: [*]c.GLuint) void,
    BindTextureUnit: *const fn (unit: c.GLuint, texture: c.GLuint) void,
    TextureStorage2D: *const fn (texture: c.GLuint, levels: c.GLsizei, internalformat: c.GLenum, width: c.GLsizei, height: c.GLsizei) void,
    TextureSubImage2D: *const fn (texture: c.GLuint, level: c.GLint, xoffset: c.GLint, yoffset: c.GLint, width: c.GLsizei, height: c.GLsizei, format: c.GLenum, type: c.GLenum, pixels: *const anyopaque) void,
    DeleteTextures: *const fn (n: c.GLsizei, textures: [*]const c.GLuint) void,
};

var gl: GLFuncs = undefined;

fn load_func(name: [:0]const u8) !?*anyopaque {
    return wglGetProcAddress(name) orelse return error.CouldNotLoadFunc;
}

fn load_funcs() !void {
    inline for (@typeInfo(GLFuncs).Struct.fields) |field| {
        @field(gl, field.name) = @ptrCast(field.field_type, try load_func("gl" ++ field.name));
    }
}

fn createContext(dc: windows.HDC) !HGLRC {
    const PFD_DRAW_TO_WINDOW = 0x00000004;
    const PFD_SUPPORT_OPENGL = 0x00000020;
    const PFD_DOUBLEBUFFER = 0x00000001;
    const PFD_TYPE_RGBA = 0;
    const PFD_MAIN_PLANE = 0;
    const pixelformat = gdi32.PIXELFORMATDESCRIPTOR{
        .nVersion = 1,
        .dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
        .iPixelType = PFD_TYPE_RGBA,
        .cColorBits = 32,
        .cRedBits = 0,
        .cRedShift = 0,
        .cGreenBits = 0,
        .cGreenShift = 0,
        .cBlueBits = 0,
        .cBlueShift = 0,
        .cAlphaBits = 0,
        .cAlphaShift = 0,
        .cAccumBits = 0,
        .cAccumRedBits = 0,
        .cAccumGreenBits = 0,
        .cAccumBlueBits = 0,
        .cAccumAlphaBits = 0,
        .cDepthBits = 24,
        .cStencilBits = 8,
        .cAuxBuffers = 0,
        .iLayerType = PFD_MAIN_PLANE,
        .bReserved = 0,
        .dwLayerMask = 0,
        .dwVisibleMask = 0,
        .dwDamageMask = 0,
    };
    const formatindex = gdi32.ChoosePixelFormat(dc, &pixelformat);
    if (formatindex == 0) return windows.unexpectedError(kernel32.GetLastError());
    if (!gdi32.SetPixelFormat(dc, formatindex, &pixelformat)) return windows.unexpectedError(kernel32.GetLastError());

    var wglCreateContextAttribsARB: *const fn (hdc: ?windows.HDC, hshareContext: ?HGLRC, attribList: []const i32) ?HGLRC = undefined;

    {
        const context = gdi32.wglCreateContext(dc) orelse return windows.unexpectedError(kernel32.GetLastError());
        errdefer _ = wglDeleteContext(context);
        if (!gdi32.wglMakeCurrent(dc, context)) return windows.unexpectedError(kernel32.GetLastError());
        errdefer _ = gdi32.wglMakeCurrent(dc, null);

        wglCreateContextAttribsARB = @ptrCast(*const fn (hdc: ?windows.HDC, hshareContext: ?HGLRC, attribList: []const i32) ?HGLRC, wglGetProcAddress("wglCreateContextAttribsARB") orelse return windows.unexpectedError(kernel32.GetLastError()));
        try load_funcs();
    }

    const WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091;
    const WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092;
    const WGL_CONTEXT_FLAGS_ARB = 0x2094;
    const WGL_CONTEXT_PROFILE_MASK_ARB = 0x9126;
    const WGL_CONTEXT_DEBUG_BIT_ARB = 0x0001;
    const WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001;
    const context = wglCreateContextAttribsARB(dc, null, &[_]i32{
        WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
        WGL_CONTEXT_MINOR_VERSION_ARB, 5,
        WGL_CONTEXT_PROFILE_MASK_ARB,  WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        WGL_CONTEXT_FLAGS_ARB,         WGL_CONTEXT_DEBUG_BIT_ARB,
        0,
    }) orelse return windows.unexpectedError(kernel32.GetLastError());
    errdefer _ = wglDeleteContext(context);
    if (!gdi32.wglMakeCurrent(dc, context)) return windows.unexpectedError(kernel32.GetLastError());
    return context;
}

const Shader = struct {
    const Module = struct {
        file_path: []const u8,
        shader_type: c.GLenum,
    };

    var loaded_shaders: std.StringHashMap(c.GLuint) = std.StringHashMap(c.GLuint).init(std.heap.c_allocator);
    program: c.GLuint,

    fn init(comptime modules: []const Module) Shader {
        var result = Shader{ .program = gl.CreateProgram() };
        var shaders = std.BoundedArray(c.GLuint, modules.len){};
        inline for (modules) |module| {
            const shader = (loaded_shaders.getOrPutValue(module.file_path, gl.CreateShader(module.shader_type)) catch unreachable).value_ptr.*;
            shaders.appendAssumeCapacity(shader);
            gl.ShaderSource(shader, 1, &[_][*:0]const u8{@embedFile(module.file_path)}, null);
            gl.CompileShader(shader);
            gl.AttachShader(result.program, shader);
        }
        gl.LinkProgram(result.program);
        for (shaders.constSlice()) |shader| {
            gl.DetachShader(result.program, shader);
        }
        return result;
    }

    fn deinit(self: Shader) void {
        gl.DeleteProgram(self.program);
    }

    fn bind(self: Shader) void {
        gl.UseProgram(self.program);
    }

    fn uploadMat4(self: Shader, location: [:0]const u8, value: Matrix(4, 4, f32)) void {
        gl.ProgramUniformMatrix4fv(self.program, gl.GetUniformLocation(self.program, location), 1, c.GL_FALSE, @ptrCast(*const [16]f32, &value.data));
    }

    fn unbind() void {
        gl.UseProgram(0);
    }
};

pub fn Matrix(comptime w: comptime_int, comptime h: comptime_int, comptime Element: type) type {
    return struct {
        const Self = @This();

        data: [w]@Vector(h, Element),

        pub inline fn O() Self {
            return std.mem.zeroes(Self);
        }

        // TODO: check this for bugs
        // NOTE: POTENTIALLY BUGGY AF
        pub fn mul(self: Self, other: anytype) Matrix(@typeInfo(@typeInfo(@TypeOf(other)).Struct.fields[0].field_type).Array.len, h, Element) {
            // A.cols == B.rows
            comptime std.debug.assert(w == @typeInfo(@typeInfo(@typeInfo(@TypeOf(other)).Struct.fields[0].field_type).Array.child).Vector.len);
            // A.Element == B.Element
            comptime std.debug.assert(Element == @typeInfo(@typeInfo(@typeInfo(@TypeOf(other)).Struct.fields[0].field_type).Array.child).Vector.child);

            var result = Matrix(@typeInfo(@typeInfo(@TypeOf(other)).Struct.fields[0].field_type).Array.len, h, Element).O();
            comptime var row = 0;
            inline while (row < h) : (row += 1) {
                comptime var col = 0;
                inline while (col < @typeInfo(@typeInfo(@TypeOf(other)).Struct.fields[0].field_type).Array.len) : (col += 1) {
                    comptime var inner = 0;
                    inline while (inner < w) : (inner += 1) {
                        result.data[col][row] += self.data[inner][row] * other.data[col][inner];
                    }
                }
            }
            return result;
        }

        pub usingnamespace if (w == h) struct {
            pub inline fn I() Self {
                var result = O();
                comptime var i = 0;
                inline while (i < w) : (i += 1) {
                    result.data[i][i] = @as(Element, 1);
                }
                return result;
            }
        } else struct {};

        pub usingnamespace if (w == 4 and h == 4 and @typeInfo(Element) == .Float) struct {
            pub fn perspective(fovy: Element, aspect: Element, znear: Element, zfar: Element) Self {
                var result = O();
                const focal_length = @as(Element, 1) / @tan(fovy / @as(Element, 2));
                // project x-coordinates to clip coordinates
                result.data[0][0] = focal_length / aspect;
                // project y-coordinates to clip coordinates
                result.data[1][1] = focal_length;
                // project z-coordinates to clip coordinates [0, 1]
                result.data[2][2] = znear / (zfar - znear);
                result.data[3][2] = znear * zfar / (zfar - znear);
                // save -z in w for perspective divide
                result.data[2][3] = -@as(Element, 1);
                return result;
            }

            pub fn orthographic(left: Element, right: Element, bottom: Element, top: Element, near: Element, far: Element) Self {
                var result = Self.I();
                result.data[0][0] = @as(Element, 2) / (right - left);
                result.data[3][0] = -(right + left) / (right - left);
                result.data[1][1] = @as(Element, 2) / (top - bottom);
                result.data[3][1] = -(top + bottom) / (top - bottom);
                result.data[2][2] = -@as(Element, 2) / (far - near);
                result.data[3][2] = -(far + near) / (far - near);
                return result;
            }

            pub fn translate(self: Self, by: @Vector(3, Element)) Self {
                var result = Self.I();
                comptime var i = 0;
                inline while (i < 3) : (i += 1) {
                    result.data[3][i] = by[i];
                }
                return self.mul(result);
            }

            pub fn scale(self: Self, by: @Vector(3, Element)) Self {
                var result = Self.I();
                comptime var i = 0;
                inline while (i < 3) : (i += 1) {
                    result.data[i][i] = by[i];
                }
                return self.mul(result);
            }
        } else struct {};
    };
}

pub fn main() !void {
    const inst = @ptrCast(windows.HINSTANCE, kernel32.GetModuleHandleW(null) orelse return error.ModuleNotFound);
    _ = try user32.registerClassExA(&.{
        .style = user32.CS_OWNDC | user32.CS_HREDRAW | user32.CS_VREDRAW,
        .lpfnWndProc = windowProc,
        .hInstance = inst,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = "MUH_CLASS_LOL",
        .hIconSm = null,
    });
    const hwnd = try user32.createWindowExA(
        0,
        "MUH_CLASS_LOL",
        "WINDOW TITLE",
        user32.WS_OVERLAPPEDWINDOW | user32.WS_VISIBLE,
        user32.CW_USEDEFAULT,
        user32.CW_USEDEFAULT,
        user32.CW_USEDEFAULT,
        user32.CW_USEDEFAULT,
        null,
        null,
        inst,
        null,
    );
    const dc = try user32.getDC(hwnd);
    _ = try createContext(dc);
    std.debug.print("GL Version: {s}\n", .{c.glGetString(c.GL_VERSION)});

    var shader = Shader.init(&[_]Shader.Module{
        .{
            .file_path = "shaders/shader.vert",
            .shader_type = GL_VERTEX_SHADER,
        },
        .{
            .file_path = "shaders/shader.frag",
            .shader_type = GL_FRAGMENT_SHADER,
        },
    });

    // const dist = 20.0;
    // const projection = comptime Matrix(4, 4, f32).orthographic(0.0, 16.0, 0.0, 9.0, -dist, dist);
    const projection = comptime Matrix(4, 4, f32).perspective(std.math.pi / 2.0, 800.0 / 600.0, 0.1, 100.0);
    const view = comptime Matrix(4, 4, f32).I().translate(.{ 0.0, 0.0, -10.0 });
    const model = comptime Matrix(4, 4, f32).I().scale(.{ 10.0, 10.0, 0.0 });
    shader.uploadMat4("mvp", projection.mul(view.mul(model)));

    const Vertex = struct {
        position: @Vector(3, f32),
        color: @Vector(4, f32),
    };

    const vertices = &[_]Vertex{
        .{
            .position = .{ 0.5, 0.5, 0.0 },
            .color = .{ 1.0, 0.0, 0.0, 1.0 },
        },
        .{
            .position = .{ 0.5, -0.5, 0.0 },
            .color = .{ 0.0, 1.0, 0.0, 1.0 },
        },
        .{
            .position = .{ -0.5, -0.5, 0.0 },
            .color = .{ 0.0, 0.0, 1.0, 1.0 },
        },
        .{
            .position = .{ -0.5, 0.5, 0.0 },
            .color = .{ 1.0, 0.0, 1.0, 1.0 },
        },
    };

    const indices = &[_]u16{
        0, 1, 2, 2, 3, 0,
    };

    const VAO = blk: {
        var result: [1]c.GLuint = undefined;
        gl.CreateVertexArrays(1, &result);
        break :blk result[0];
    };

    const VBO = blk: {
        var result: [1]c.GLuint = undefined;
        gl.CreateBuffers(1, &result);
        break :blk result[0];
    };
    gl.NamedBufferData(VBO, @sizeOf(u16) * indices.len + @sizeOf(Vertex) * vertices.len, null, GL_STATIC_DRAW);
    gl.NamedBufferSubData(VBO, 0, @sizeOf(u16) * indices.len, indices);
    gl.NamedBufferSubData(VBO, @sizeOf(u16) * indices.len, @sizeOf(Vertex) * vertices.len, vertices);

    gl.VertexArrayElementBuffer(VAO, VBO);

    gl.VertexArrayVertexBuffer(VAO, 0, VBO, @sizeOf(u16) * indices.len, @sizeOf(Vertex));

    gl.VertexArrayAttribFormat(VAO, 0, 3, c.GL_FLOAT, c.GL_FALSE, @offsetOf(Vertex, "position"));
    gl.EnableVertexArrayAttrib(VAO, 0);
    gl.VertexArrayAttribBinding(VAO, 0, 0);

    gl.VertexArrayAttribFormat(VAO, 1, 4, c.GL_FLOAT, c.GL_FALSE, @offsetOf(Vertex, "color"));
    gl.EnableVertexArrayAttrib(VAO, 1);
    gl.VertexArrayAttribBinding(VAO, 1, 0);

    // c.glPolygonMode(c.GL_FRONT_AND_BACK, c.GL_LINE);
    gl.ClipControl(GL_LOWER_LEFT, GL_ZERO_TO_ONE);

    const start = try std.time.Instant.now();
    var previous = start;

    game_loop: while (true) {
        const current = std.time.Instant.now() catch unreachable;
        // const delta = @intToFloat(f32, current.since(previous)) / std.time.ns_per_s;
        previous = current;
        // std.debug.print("fps: {d}\n", .{1.0 / delta});
        var msg: user32.MSG = undefined;
        while (try user32.peekMessageA(&msg, null, 0, 0, user32.PM_REMOVE)) {
            if (msg.message == user32.WM_QUIT) {
                break :game_loop;
            }
            _ = user32.translateMessage(&msg);
            _ = user32.dispatchMessageA(&msg);
        }
        c.glClearColor(0.15, 0.15, 0.15, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);
        shader.bind();
        gl.BindVertexArray(VAO);
        c.glDrawElements(c.GL_TRIANGLES, indices.len, c.GL_UNSIGNED_SHORT, null);
        if (!gdi32.SwapBuffers(dc)) break :game_loop;
    }
}
