const std = @import("std");
const c = @cImport({
    @cDefine("STBI_ONLY_PNG", {});
    @cInclude("stb_image.h");
    @cInclude("GL/gl.h");
});
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

const GL_STREAM_DRAW = 0x88E0;
const GL_STATIC_DRAW = 0x88E4;
const GL_DYNAMIC_DRAW = 0x88E8;

const GL_READ_ONLY = 0x88B8;
const GL_WRITE_ONLY = 0x88B9;
const GL_READ_WRITE = 0x88BA;

const GL_ARRAY_BUFFER = 0x8892;
const GL_ELEMENT_ARRAY_BUFFER = 0x8893;

const GL_FRAGMENT_SHADER = 0x8B30;
const GL_VERTEX_SHADER = 0x8B31;

const GL_NEGATIVE_ONE_TO_ONE = 0x935E;
const GL_ZERO_TO_ONE = 0x935F;
const GL_LOWER_LEFT = 0x8CA1;
const GL_UPPER_LEFT = 0x8CA2;

const GL_COMPILE_STATUS = 0x8B81;
const GL_INFO_LOG_LENGTH = 0x8B84;
const GL_LINK_STATUS = 0x8B82;

const GL_DEBUG_OUTPUT = 0x92E0;

const GL_DEBUG_SOURCE_API = 0x8246;
const GL_DEBUG_SOURCE_WINDOW_SYSTEM = 0x8247;
const GL_DEBUG_SOURCE_SHADER_COMPILER = 0x8248;
const GL_DEBUG_SOURCE_THIRD_PARTY = 0x8249;
const GL_DEBUG_SOURCE_APPLICATION = 0x824A;
const GL_DEBUG_SOURCE_OTHER = 0x824B;

const GL_DEBUG_TYPE_ERROR = 0x824C;
const GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR = 0x824D;
const GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR = 0x824E;
const GL_DEBUG_TYPE_PORTABILITY = 0x824F;
const GL_DEBUG_TYPE_PERFORMANCE = 0x8250;
const GL_DEBUG_TYPE_MARKER = 0x8268;
const GL_DEBUG_TYPE_OTHER = 0x8251;

const GL_DEBUG_SEVERITY_NOTIFICATION = 0x826B;
const GL_DEBUG_SEVERITY_LOW = 0x9148;
const GL_DEBUG_SEVERITY_MEDIUM = 0x9147;
const GL_DEBUG_SEVERITY_HIGH = 0x9146;

const GLFuncs = struct {
    DebugMessageCallback: *const fn (callback: *const fn (source: c.GLenum, type: c.GLenum, id: c.GLuint, severity: c.GLenum, length: c.GLsizei, message: [*]const GLchar, userParam: ?*const anyopaque) void, userParam: ?*anyopaque) void,
    DebugMessageControl: *const fn (source: c.GLenum, type: c.GLenum, severity: c.GLenum, count: c.GLsizei, ids: ?[*]const c.GLuint, enabled: c.GLboolean) void,
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
    MapNamedBuffer: *const fn (buffer: c.GLuint, access: c.GLenum) ?*anyopaque,
    UnmapNamedBuffer: *const fn (buffer: c.GLuint) c.GLboolean,
    DeleteBuffers: *const fn (n: c.GLsizei, buffers: [*]const c.GLuint) void,

    CreateShader: *const fn (shaderType: c.GLenum) c.GLuint,
    ShaderSource: *const fn (shader: c.GLuint, count: c.GLsizei, string: [*]const [*:0]const GLchar, length: ?[*]const c.GLint) void,
    CompileShader: *const fn (shader: c.GLuint) void,
    GetShaderiv: *const fn (shader: c.GLuint, pname: c.GLenum, params: *c.GLint) void,
    GetShaderInfoLog: *const fn (shader: c.GLuint, maxLength: c.GLsizei, length: ?*c.GLsizei, infoLog: [*]GLchar) void,
    DeleteShader: *const fn (shader: c.GLuint) void,

    CreateProgram: *const fn () c.GLuint,
    AttachShader: *const fn (program: c.GLuint, shader: c.GLuint) void,
    DetachShader: *const fn (program: c.GLuint, shader: c.GLuint) void,
    LinkProgram: *const fn (program: c.GLuint) void,
    GetProgramiv: *const fn (program: c.GLuint, pname: c.GLenum, params: *c.GLint) void,
    GetProgramInfoLog: *const fn (program: c.GLuint, maxLength: c.GLsizei, length: *c.GLsizei, infoLog: [*]GLchar) void,

    GetUniformLocation: *const fn (program: c.GLuint, name: [*:0]const GLchar) c.GLint,
    ProgramUniform2f: *const fn (program: c.GLuint, location: c.GLint, v0: c.GLfloat, v1: c.GLfloat) void,
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

fn loadGLFunc(name: [:0]const u8) !?*anyopaque {
    return wglGetProcAddress(name) orelse return error.CouldNotLoadFunc;
}

fn loadGLFuncs() !void {
    inline for (@typeInfo(GLFuncs).Struct.fields) |field| {
        @field(gl, field.name) = @ptrCast(field.field_type, try loadGLFunc("gl" ++ field.name));
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
        try loadGLFuncs();
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

pub const Shader = struct {
    pub const Module = struct {
        file_path: []const u8,
        shader_type: c.GLenum,
    };

    var loaded_shaders: std.StringHashMap(c.GLuint) = std.StringHashMap(c.GLuint).init(std.heap.c_allocator);
    program: c.GLuint,
    success: bool = true,

    pub fn init(comptime modules: []const Module) Shader {
        var result = Shader{ .program = gl.CreateProgram() };
        var shaders = std.BoundedArray(c.GLuint, modules.len){};
        inline for (modules) |module| {
            const shader = blk: {
                if (loaded_shaders.get(module.file_path)) |s| {
                    break :blk s;
                } else {
                    const s = gl.CreateShader(module.shader_type);
                    gl.ShaderSource(s, 1, &[_][*:0]const u8{@embedFile(module.file_path)}, null);
                    gl.CompileShader(s);
                    var status: c.GLint = undefined;
                    gl.GetShaderiv(s, GL_COMPILE_STATUS, &status);
                    if (status == c.GL_FALSE) {
                        var length: c.GLint = undefined;
                        gl.GetShaderiv(s, GL_INFO_LOG_LENGTH, &length);
                        var e = std.BoundedArray(u8, 1024).init(@intCast(usize, length)) catch @panic("length not long enough");
                        gl.GetShaderInfoLog(s, 1024, &length, &e.buffer);
                        std.debug.print("COMPILEERROR : {s}:{s}", .{ module.file_path, e.constSlice() });
                        gl.DeleteShader(s);
                        break :blk null;
                    }
                    loaded_shaders.putNoClobber(module.file_path, s) catch @panic("no space");
                    break :blk s;
                }
            };
            if (shader) |s| {
                shaders.appendAssumeCapacity(s);
                gl.AttachShader(result.program, s);
            }
        }
        gl.LinkProgram(result.program);
        for (shaders.constSlice()) |shader| {
            gl.DetachShader(result.program, shader);
        }
        var status: c.GLint = undefined;
        gl.GetProgramiv(result.program, GL_LINK_STATUS, &status);
        if (status == c.GL_FALSE) {
            var length: c.GLint = undefined;
            gl.GetProgramiv(result.program, GL_INFO_LOG_LENGTH, &length);
            var e = std.BoundedArray(u8, 1024).init(@intCast(usize, length)) catch @panic("length not long enough");
            gl.GetProgramInfoLog(result.program, 1024, &length, &e.buffer);
            std.debug.print("LINKERROR : Modules={{ ", .{});
            for (modules) |module| {
                std.debug.print("{s} ", .{module.file_path});
            }
            std.debug.print("}}\n{s}", .{e.constSlice()});
            gl.DeleteProgram(result.program);
            result.success = false;
        }
        return result;
    }

    pub fn deinit(self: Shader) void {
        gl.DeleteProgram(self.program);
    }

    pub fn use(self: Shader) void {
        gl.UseProgram(self.program);
    }

    pub fn uploadVec2(self: Shader, location: [:0]const u8, value: @Vector(2, f32)) void {
        gl.ProgramUniform2f(self.program, gl.GetUniformLocation(self.program, location), value[0], value[1]);
    }

    pub fn uploadMat4(self: Shader, location: [:0]const u8, value: Matrix(4, 4, f32)) void {
        gl.ProgramUniformMatrix4fv(self.program, gl.GetUniformLocation(self.program, location), 1, c.GL_FALSE, @ptrCast(*const [16]f32, &value.data));
    }
};

pub const Renderable2D = struct {
    position: @Vector(3, f32),
    size: @Vector(2, f32),
    color: @Vector(4, u8),
};

pub const Batch2DRenderer = struct {
    const VertexData = struct {
        position: @Vector(3, f32),
        color: @Vector(4, u8),
        texcoord: @Vector(2, f32),
    };

    const max_sprites = 10000;
    const vertices_len = 4 * max_sprites;
    const indices_len = 6 * max_sprites;

    vao: VertexArray,
    vertices: ?[*]VertexData = null,

    pub fn init() Batch2DRenderer {
        var indices: [indices_len]u16 = undefined;
        var offset: u16 = 0;
        var i: usize = 0;
        while (i < indices_len) : (i += 6) {
            indices[i + 0] = offset + 0;
            indices[i + 1] = offset + 1;
            indices[i + 2] = offset + 2;
            indices[i + 3] = offset + 2;
            indices[i + 4] = offset + 3;
            indices[i + 5] = offset + 0;
            offset += 4;
        }
        var result: Batch2DRenderer = .{
            .vao = VertexArray.init(
                VertexData,
                u16,
                .{ .len = vertices_len },
                &indices,
            ),
        };
        result.vao.draw_count = 0;
        return result;
    }

    pub fn begin(self: *Batch2DRenderer) void {
        self.vertices = @ptrCast([*]VertexData, @alignCast(@alignOf(VertexData), @ptrCast([*]u8, gl.MapNamedBuffer(self.vao.buffer, GL_WRITE_ONLY) orelse @panic("map failed")) + self.vao.vertices_offset));
    }

    pub fn submit(self: *Batch2DRenderer, renderable: *const Renderable2D) void {
        std.mem.copy(VertexData, self.vertices.?[@intCast(usize, self.vao.draw_count * 4)..vertices_len], &[_]VertexData{
            .{ .position = .{ renderable.position[0] + 0.0, renderable.position[1] + 0.0, 0.0 }, .color = renderable.color, .texcoord = .{ 0.0, 0.0 } },
            .{ .position = .{ renderable.position[0] + 0.0, renderable.position[1] + renderable.size[1], 0.0 }, .color = renderable.color, .texcoord = .{ 0.0, 1.0 } },
            .{ .position = .{ renderable.position[0] + renderable.size[0], renderable.position[1] + renderable.size[1], 0.0 }, .color = renderable.color, .texcoord = .{ 1.0, 1.0 } },
            .{ .position = .{ renderable.position[0] + renderable.size[0], renderable.position[1] + 0.0, 0.0 }, .color = renderable.color, .texcoord = .{ 1.0, 0.0 } },
        });
        self.vao.draw_count += 1;
    }

    pub fn end(self: *Batch2DRenderer) void {
        if (gl.UnmapNamedBuffer(self.vao.buffer) == c.GL_FALSE) @panic("unmap failed");
        self.vertices = null;
    }

    pub fn flush(self: *Batch2DRenderer) void {
        self.vao.bind();
        c.glDrawElements(c.GL_TRIANGLES, self.vao.draw_count * 6, self.vao.index_type, @intToPtr(?*const anyopaque, self.vao.indices_offset));
        self.vao.draw_count = 0;
    }
};

pub const VertexArray = struct {
    vaobj: c.GLuint,
    buffer: c.GLuint,
    index_type: c.GLenum,
    draw_count: c.GLsizei,
    indices_offset: usize,
    vertices_offset: usize,

    pub fn init(comptime VertexType: type, comptime IndexType: type, vertices: union(enum) { data: []const VertexType, len: usize }, indices: []const IndexType) VertexArray {
        const indices_len = indices.len;
        const vertices_len = switch (vertices) {
            .data => |data| data.len,
            .len => |len| len,
        };

        const indices_size = @sizeOf(IndexType) * indices_len;
        const vertices_size = @sizeOf(VertexType) * vertices_len;

        const result = VertexArray{
            .vaobj = blk: {
                var id: [1]c.GLuint = undefined;
                gl.CreateVertexArrays(1, &id);
                break :blk id[0];
            },
            .buffer = blk: {
                var id: [1]c.GLuint = undefined;
                gl.CreateBuffers(1, &id);
                break :blk id[0];
            },
            .index_type = switch (@typeInfo(IndexType).Int.bits) {
                8 => c.GL_UNSIGNED_BYTE,
                16 => c.GL_UNSIGNED_SHORT,
                32 => c.GL_UNSIGNED_INT,
                else => unreachable,
            },
            .draw_count = @intCast(c.GLint, indices.len),
            .indices_offset = 0,
            .vertices_offset = indices_size,
        };

        gl.NamedBufferData(result.buffer, vertices_size + indices_size, null, switch (vertices) {
            .data => GL_STATIC_DRAW,
            .len => GL_DYNAMIC_DRAW,
        });
        gl.NamedBufferSubData(result.buffer, @intCast(GLintptr, result.indices_offset), @intCast(c.GLint, indices_size), indices.ptr);
        if (vertices == .data)
            gl.NamedBufferSubData(result.buffer, @intCast(GLintptr, result.vertices_offset), @intCast(c.GLint, vertices_size), vertices.data.ptr);

        gl.VertexArrayVertexBuffer(result.vaobj, 0, result.buffer, @intCast(GLintptr, result.vertices_offset), @sizeOf(VertexType));
        gl.VertexArrayElementBuffer(result.vaobj, result.buffer);

        inline for (@typeInfo(VertexType).Struct.fields) |field, i| {
            const len = switch (@typeInfo(field.field_type)) {
                .Vector => |v| v.len,
                else => 1,
            };
            const singletype = switch (@typeInfo(field.field_type)) {
                .Vector => |v| @typeInfo(v.child),
                else => |t| t,
            };
            const gltype = switch (singletype) {
                .Int => |int| switch (int.signedness) {
                    .signed => switch (int.bits) {
                        8 => c.GL_BYTE,
                        16 => c.GL_SHORT,
                        32 => c.GL_INT,
                        else => unreachable,
                    },
                    .unsigned => switch (int.bits) {
                        8 => c.GL_UNSIGNED_BYTE,
                        16 => c.GL_UNSIGNED_SHORT,
                        32 => c.GL_UNSIGNED_INT,
                        else => unreachable,
                    },
                },
                .Float => |float| switch (float.bits) {
                    32 => c.GL_FLOAT,
                    64 => c.GL_DOUBLE,
                    else => unreachable,
                },
                .Bool => c.GL_BYTE,
                inline else => unreachable,
            };
            const normalized = switch (singletype) {
                .Int => |int| switch (int.bits) {
                    8 => c.GL_TRUE,
                    else => c.GL_FALSE,
                },
                else => c.GL_FALSE,
            };
            gl.VertexArrayAttribFormat(result.vaobj, i, len, gltype, normalized, @offsetOf(VertexType, field.name));
            gl.EnableVertexArrayAttrib(result.vaobj, i);
            gl.VertexArrayAttribBinding(result.vaobj, i, 0);
        }
        return result;
    }

    pub fn deinit(self: VertexArray) void {
        gl.DeleteBuffers(1, &[_]c.GLuint{self.buffer});
        gl.DeleteVertexArrays(self.vaobj);
    }

    pub fn bind(self: VertexArray) void {
        gl.BindVertexArray(self.vaobj);
    }
};

pub const Texture = struct {
    texid: c.GLuint,
    path: []const u8,

    pub fn init(path: []const u8) Texture {
        var result: Texture = .{
            .texid = blk: {
                var id: [1]c.GLuint = undefined;
                gl.CreateTextures(c.GL_TEXTURE_2D, 1, &id);
                break :blk id[0];
            },
            .path = path,
        };
        var width: i32 = undefined;
        var height: i32 = undefined;
        var num_channels: i32 = undefined;
        var data = c.stbi_load("test.png", &width, &height, &num_channels, 0);
        if (data) |d| {
            gl.TextureStorage2D(result.texid, 1, c.GL_RGBA8, width, height);
            gl.TextureSubImage2D(result.texid, 0, 0, 0, width, height, c.GL_RGB, c.GL_UNSIGNED_BYTE, data);
            c.stbi_image_free(d);
        }
        return result;
    }

    pub fn bind(self: Texture, unit: u32) void {
        gl.BindTextureUnit(unit, self.texid);
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

        pub fn mulv(self: Self, other: anytype) @Vector(@typeInfo(@TypeOf(other)).Vector.len, Element) {
            comptime std.debug.assert(w == @typeInfo(@TypeOf(other)).Vector.len);
            comptime std.debug.assert(Element == @typeInfo(@TypeOf(other)).Vector.child);

            var result = @splat(@typeInfo(@TypeOf(other)).Vector.len, @as(Element, 0.0));
            comptime var row = 0;
            inline while (row < h) : (row += 1) {
                comptime var inner = 0;
                inline while (inner < w) : (inner += 1) {
                    result[row] += self.data[inner][row] * other[inner];
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

            // TODO: This currently maps z to [-1, 1] and we want [0, 1]
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

            pub fn translate(by: @Vector(3, Element)) Self {
                var result = Self.I();
                comptime var i = 0;
                inline while (i < 3) : (i += 1) {
                    result.data[3][i] = by[i];
                }
                return result;
            }

            pub fn rotateZ(by: Element) Self {
                var result = Self.I();
                const cosa = @cos(by);
                const sina = @sin(by);
                result.data[0][0] = cosa;
                result.data[1][0] = sina;
                result.data[0][1] = -sina;
                result.data[1][1] = cosa;
                return result;
            }

            pub fn scale(by: @Vector(3, Element)) Self {
                var result = Self.I();
                comptime var i = 0;
                inline while (i < 3) : (i += 1) {
                    result.data[i][i] = by[i];
                }
                return result;
            }
        } else struct {};
    };
}

fn glDebugCallback(source: c.GLenum, @"type": c.GLenum, id: c.GLuint, severity: c.GLenum, length: c.GLsizei, message: [*]const GLchar, userParam: ?*const anyopaque) void {
    _ = userParam;
    std.debug.print("{s} {s} {s} {}: {s}\n", .{
        switch (source) {
            GL_DEBUG_SOURCE_API => "API",
            GL_DEBUG_SOURCE_WINDOW_SYSTEM => "WINDOW SYSTEM",
            GL_DEBUG_SOURCE_SHADER_COMPILER => "SHADER COMPILER",
            GL_DEBUG_SOURCE_THIRD_PARTY => "THIRD PARTY",
            GL_DEBUG_SOURCE_APPLICATION => "APPLICATION",
            GL_DEBUG_SOURCE_OTHER => "OTHER",
            else => unreachable,
        },
        switch (@"type") {
            GL_DEBUG_TYPE_ERROR => "ERROR",
            GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR => "DEPRECATED_BEHAVIOR",
            GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR => "UNDEFINED_BEHAVIOR",
            GL_DEBUG_TYPE_PORTABILITY => "PORTABILITY",
            GL_DEBUG_TYPE_PERFORMANCE => "PERFORMANCE",
            GL_DEBUG_TYPE_MARKER => "MARKER",
            GL_DEBUG_TYPE_OTHER => "OTHER",
            else => unreachable,
        },
        switch (severity) {
            GL_DEBUG_SEVERITY_NOTIFICATION => "NOTIFICATION",
            GL_DEBUG_SEVERITY_LOW => "LOW",
            GL_DEBUG_SEVERITY_MEDIUM => "MEDIUM",
            GL_DEBUG_SEVERITY_HIGH => "HIGH",
            else => unreachable,
        },
        id,
        @ptrCast([*]const u8, message)[0..@intCast(usize, length)],
    });
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
    c.glEnable(GL_DEBUG_OUTPUT);
    gl.DebugMessageCallback(glDebugCallback, null);
    gl.DebugMessageControl(c.GL_DONT_CARE, c.GL_DONT_CARE, GL_DEBUG_SEVERITY_NOTIFICATION, 0, null, c.GL_FALSE);

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

    // after all shaders are initialized
    var iter = Shader.loaded_shaders.valueIterator();
    while (iter.next()) |shaderid| {
        gl.DeleteShader(shaderid.*);
    }
    Shader.loaded_shaders.deinit();

    c.stbi_set_flip_vertically_on_load(1);
    const t1 = Texture.init("test.png");

    const dist = 20.0;
    const projection = comptime Matrix(4, 4, f32).orthographic(0.0, 16.0, 0.0, 9.0, -dist, dist);
    // const projection = comptime Matrix(4, 4, f32).perspective(std.math.pi / 2.0, 800.0 / 600.0, 0.1, 100.0);
    const view = comptime Matrix(4, 4, f32).translate(.{ 0.0, 0.0, -10.0 });
    const model = comptime Matrix(4, 4, f32).I();
    shader.uploadMat4("mvp", comptime projection.mul(view.mul(model)));

    const sprite1 = Renderable2D{ .position = .{ 5.0, 5.0, 0.0 }, .size = .{ 4.0, 4.0 }, .color = .{ 255, 0, 255, 255 } };
    const sprite2 = Renderable2D{ .position = .{ 7.0, 1.0, 0.0 }, .size = .{ 2.0, 3.0 }, .color = .{ @floatToInt(u8, 255.0 * 0.2), 0, 255, 255 } };
    var renderer = Batch2DRenderer.init();

    // c.glPolygonMode(c.GL_FRONT_AND_BACK, c.GL_LINE);
    gl.ClipControl(GL_LOWER_LEFT, GL_ZERO_TO_ONE);

    const start = try std.time.Instant.now();
    var previous = start;
    var t: f32 = 0.0;
    var frames: u32 = 0;

    var lightpos = @Vector(2, f32){ 8.0, 4.5 };

    game_loop: while (true) {
        const current = std.time.Instant.now() catch unreachable;
        const running = @intToFloat(f32, current.since(start)) / std.time.ns_per_s;
        // const delta = @intToFloat(f32, current.since(previous)) / std.time.ns_per_s;
        previous = current;

        frames += 1;
        if (running - t > 1.0) {
            std.debug.print("ms/f: {d} | fps: {d}\n", .{ 1.0 / @intToFloat(f32, frames), frames });
            t += 1.0;
            frames = 0;
        }
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

        lightpos[0] = 8.0 * @sin(running) + 8.0;
        shader.uploadVec2("u_lightpos", lightpos);
        t1.bind(0);
        shader.use();
        renderer.begin();
        const every = 0.5;
        const size = 1.0 - every;
        var x: f32 = 0.0;
        var r = std.rand.DefaultPrng.init(42);
        const rr = r.random();
        while (x < 16.0) : (x += every) {
            var y: f32 = 0.0;
            while (y < 9.0) : (y += every) {
                renderer.submit(&Renderable2D{
                    .position = .{ x, y, 0.0 },
                    .size = .{ size, size },
                    .color = .{ rr.uintAtMost(u8, 255), 0, rr.uintAtMost(u8, 255), 255 },
                });
            }
        }
        renderer.submit(&sprite1);
        renderer.submit(&sprite2);
        renderer.end();
        renderer.flush();
        if (!gdi32.SwapBuffers(dc)) break :game_loop;
    }
}
