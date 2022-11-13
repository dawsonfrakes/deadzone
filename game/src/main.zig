const std = @import("std");
const options = @import("options");
const platform = @import("platform.zig");
const c = @import("c.zig");

const Time = struct {
    delta: f64 = 0.0,
    running: f64 = 0.0,
    _start: i128 = 0,
    _current: i128 = 0,
    _previous: i128 = 0,

    fn init() Time {
        var result = Time{};
        result._start = std.time.nanoTimestamp();
        result._current = result._start;
        result._previous = result._start;
        return result;
    }

    fn toSeconds(time: i128) f64 {
        return @intToFloat(f64, time) / std.time.ns_per_s;
    }

    fn tick(self: *Time) void {
        self._current = std.time.nanoTimestamp();
        self.delta = toSeconds(self._current - self._previous);
        self.running = toSeconds(self._current - self._start);
        self._previous = self._current;
    }
};

const Input = struct {
    // zig fmt: off
    pub const Keys = enum {
        a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z,
        @"0",  @"1",  @"2",  @"3",  @"4",  @"5",  @"6",  @"7",  @"8",  @"9",
        f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12,
        left_arrow, down_arrow, up_arrow, right_arrow,
        backtick, minus, equals, period, comma, slash, backslash, semicolon, apostrophe, left_bracket, right_bracket,
        backspace, tab, caps, space, escape, @"return", delete,
        left_control, left_alt, left_shift, right_control, right_alt, right_shift,
    };
    // zig fmt: on
    pub const MouseButtons = enum {
        left,
        middle,
        right,
    };

    keys: std.EnumArray(Keys, bool) = std.EnumArray(Keys, bool).initFill(false),
    keys_previous: std.EnumArray(Keys, bool) = std.EnumArray(Keys, bool).initFill(false),
    buttons: std.EnumArray(MouseButtons, bool) = std.EnumArray(MouseButtons, bool).initFill(false),
    buttons_previous: std.EnumArray(MouseButtons, bool) = std.EnumArray(MouseButtons, bool).initFill(false),
    mouse: @Vector(3, i32) = @splat(3, @as(i32, 0.0)),

    pub fn save(self: *Input) void {
        self.keys_previous = self.keys;
        self.buttons_previous = self.buttons;
        // NOTE: z is the delta of mousewheelscroll per frame. it doesn't need to be saved, just reset
        self.mouse[2] = 0;
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

    pub fn setMouseButton(self: *Input, button: MouseButtons, value: bool) void {
        self.buttons.set(button, value);
    }

    pub fn getMouseButtonDown(self: Input, button: MouseButtons) bool {
        return self.buttons.get(button);
    }

    pub fn getMouseButtonUp(self: Input, button: MouseButtons) bool {
        return !self.buttons.get(button);
    }

    pub fn getMouseButtonJustDown(self: Input, button: MouseButtons) bool {
        return self.buttons.get(button) and !self.buttons_previous.get(button);
    }

    pub fn getMouseButtonJustUp(self: Input, button: MouseButtons) bool {
        return !self.buttons.get(button) and self.buttons_previous.get(button);
    }
};

const Transform = struct {
    position: @Vector(3, f32) = @splat(3, @as(f32, 0.0)),
    rotation: @Vector(3, f32) = @splat(3, @as(f32, 0.0)),
    scale: @Vector(3, f32) = @splat(3, @as(f32, 1.0)),

    fn matrix(self: Transform) Matrix(4, 4, f32) {
        return (comptime Matrix(4, 4, f32).I()).translate(self.position).rotate(self.rotation).scale(self.scale);
    }
};

fn Matrix(
    comptime w: comptime_int,
    comptime h: comptime_int,
    comptime Element: type,
) type {
    return struct {
        const Self = @This();

        data: [w]@Vector(h, Element),

        fn O() Self {
            return .{
                .data = [_]@Vector(h, Element){@splat(h, @as(Element, 0))} ** w,
            };
        }

        fn I() Self {
            comptime std.debug.assert(w == h);
            comptime var result = O();
            inline for (result.data) |*row, i| {
                row.*[i] = @as(Element, 1);
            }
            return result;
        }

        fn mul(self: Self, other: Self) Self {
            var result = comptime O();
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

        fn mulv(self: Self, other: @Vector(w, Element)) @Vector(w, Element) {
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

        fn perspective(fovy: Element, aspect: Element, znear: Element, zfar: Element) Self {
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

        fn orthographic(left: Element, right: Element, top: Element, bottom: Element, near: Element, far: Element) Self {
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

        fn translate(self: Self, t: @Vector(3, Element)) Self {
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

const Renderer = switch (platform.Rendering) {
    .vulkan => Vulkan,
};

const Vulkan = struct {
    const zi = std.mem.zeroInit;

    const min_image_count = 2;

    instance: c.VkInstance,
    physical_device: c.VkPhysicalDevice,
    physical_device_memory_properties: c.VkPhysicalDeviceMemoryProperties,
    physical_device_properties: c.VkPhysicalDeviceProperties,
    surface: c.VkSurfaceKHR,
    surface_format: c.VkSurfaceFormatKHR,
    present_mode: c.VkPresentModeKHR,
    graphics_queue_family_index: u32,
    present_queue_family_index: u32,
    device: c.VkDevice,
    graphics_queue: c.VkQueue,
    present_queue: c.VkQueue,
    graphics_command_pool: c.VkCommandPool,
    render_pass: c.VkRenderPass,

    mesh_graphics_pipeline_layout: c.VkPipelineLayout,
    mesh_graphics_pipeline: c.VkPipeline,

    surface_capabilities: c.VkSurfaceCapabilitiesKHR,
    image_count: u32,
    swapchain: c.VkSwapchainKHR,
    swapchain_images: []c.VkImage,
    depth_buffer: Image,
    swapchain_image_views: []c.VkImageView,
    framebuffers: []c.VkFramebuffer,
    graphics_command_buffers: []c.VkCommandBuffer,
    image_acquired_semaphores: []c.VkSemaphore,
    image_written_semaphores: []c.VkSemaphore,
    currently_rendering_fences: []c.VkFence,

    current_frame: u32,
    view: Matrix(4, 4, f32),
    projection: Matrix(4, 4, f32),
    render_objects: std.ArrayList(*const RenderObject),
    gpu_meshes: [options.files.len]Mesh,

    fn find_mem_type(self: Vulkan, type_filter: u32, properties: c.VkMemoryPropertyFlags) !u32 {
        const count = self.physical_device_memory_properties.memoryTypeCount;
        for (self.physical_device_memory_properties.memoryTypes[0..count]) |mem_type, i| {
            if ((type_filter & (@as(u32, 1) << @intCast(u5, i))) != 0 and (mem_type.propertyFlags & properties) == properties) {
                return @intCast(u32, i);
            }
        }
        return error.MemoryTypeNotFound;
    }

    const Vertex = struct {
        position: @Vector(3, f32),
        normal: @Vector(3, f32),
        texcoord: @Vector(2, f32),
    };

    const ObjModel = struct {
        vertices: []Vertex,
        indices: []u16,
    };

    fn parseObj(comptime path: []const u8) !ObjModel {
        @setEvalBranchQuota(100000);
        const obj = @embedFile(path);

        // NOTE: Remove Vec3 when Zig compiler bug is fixed
        // error: expected type '*@Vector(3, f32)', found '*align(0:96:16) @Vector(3, f32)'
        // potentially this: https://github.com/ziglang/zig/issues/12812
        const Vec3 = struct {
            data: @Vector(3, f32),
        };

        const Face = struct {
            position_indices: [3]u16,
            normal_indices: [3]u16,
            texcoord_indices: [3]u16,
        };

        var positions = std.BoundedArray(Vec3, std.mem.count(u8, obj, "v ")){};
        var normals = std.BoundedArray(Vec3, std.mem.count(u8, obj, "vn ")){};
        var texcoords = std.BoundedArray(@Vector(2, f32), std.mem.count(u8, obj, "vt ")){};
        var faces = std.BoundedArray(Face, std.mem.count(u8, obj, "f ")){};

        var stream = std.io.fixedBufferStream(obj);
        const reader = stream.reader();
        var line_buf: [obj.len]u8 = undefined;
        while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
            var tokens = std.mem.split(u8, line, " ");
            _ = tokens.next();
            switch (line[0]) {
                'v' => {
                    switch (line[1]) {
                        ' ' => positions.appendAssumeCapacity(.{ .data = .{
                            try std.fmt.parseFloat(f32, tokens.next().?),
                            try std.fmt.parseFloat(f32, tokens.next().?),
                            try std.fmt.parseFloat(f32, tokens.next().?),
                        } }),
                        'n' => normals.appendAssumeCapacity(.{ .data = .{
                            try std.fmt.parseFloat(f32, tokens.next().?),
                            try std.fmt.parseFloat(f32, tokens.next().?),
                            try std.fmt.parseFloat(f32, tokens.next().?),
                        } }),
                        't' => texcoords.appendAssumeCapacity(.{
                            try std.fmt.parseFloat(f32, tokens.next().?),
                            try std.fmt.parseFloat(f32, tokens.next().?),
                        }),
                        else => unreachable,
                    }
                },
                'f' => faces.appendAssumeCapacity(blk: {
                    // NOTE: OBJ FACE ORDER IS V/T/N
                    var result: Face = undefined;
                    comptime var i = 0;
                    inline while (i < 3) : (i += 1) {
                        var inner_tokens = std.mem.split(u8, tokens.next().?, "/");
                        result.position_indices[i] = try std.fmt.parseUnsigned(u16, inner_tokens.next().?, 10) - 1;
                        result.texcoord_indices[i] = try std.fmt.parseUnsigned(u16, inner_tokens.next().?, 10) - 1;
                        result.normal_indices[i] = try std.fmt.parseUnsigned(u16, inner_tokens.next().?, 10) - 1;
                    }
                    break :blk result;
                }),
                else => {},
            }
        }

        var vertices: [faces.len * 3]Vertex = undefined;
        var num_vertices: usize = 0;
        var indices: [faces.len * 3]u16 = undefined;

        for (faces.constSlice()) |face, i| {
            comptime var j = 0;
            inline while (j < 3) : (j += 1) {
                vertices[i * 3 + j] = .{
                    .position = positions.get(face.position_indices[j]).data,
                    .normal = normals.get(face.normal_indices[j]).data,
                    .texcoord = texcoords.get(face.texcoord_indices[j]),
                };
                indices[i * 3 + j] = num_vertices;
                num_vertices += 1;
            }
        }
        return .{
            .vertices = &vertices,
            .indices = &indices,
        };
    }

    const vertex_bindings = [_]c.VkVertexInputBindingDescription{
        .{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
        },
    };

    const vertex_attributes = [_]c.VkVertexInputAttributeDescription{
        .{
            .location = 0,
            .binding = 0,
            .format = c.VK_FORMAT_R32G32B32_SFLOAT,
            .offset = @offsetOf(Vertex, "position"),
        },
        .{
            .location = 1,
            .binding = 0,
            .format = c.VK_FORMAT_R32G32B32_SFLOAT,
            .offset = @offsetOf(Vertex, "normal"),
        },
        .{
            .location = 2,
            .binding = 0,
            .format = c.VK_FORMAT_R32G32_SFLOAT,
            .offset = @offsetOf(Vertex, "texcoord"),
        },
    };

    const MeshPushConstants = struct {
        mvp: Matrix(4, 4, f32),
    };

    const Mesh = struct {
        draw_count: u16,
        vbo: Buffer,
        ibo: Buffer,

        fn init(renderer: *const Vulkan, comptime file: []const u8) !Mesh {
            const obj = comptime try parseObj(options.files_folder ++ "/" ++ file ++ ".obj");
            var result: Mesh = undefined;
            result.draw_count = obj.indices.len;

            var data: ?*anyopaque = undefined;
            // vbo
            const sizeof_vertices = @sizeOf(Vertex) * obj.vertices.len;
            result.vbo = try Buffer.init(renderer, sizeof_vertices, c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
            try vkCheck(c.vkMapMemory(renderer.device, result.vbo.memory, 0, sizeof_vertices, 0, &data));
            std.debug.assert(data != null);
            std.mem.copy(Vertex, @ptrCast([*]Vertex, @alignCast(@alignOf(Vertex), data.?))[0..obj.vertices.len], obj.vertices);
            c.vkUnmapMemory(renderer.device, result.vbo.memory);

            // ibo
            const sizeof_indices = @sizeOf(u16) * obj.indices.len;
            result.ibo = try Buffer.init(renderer, sizeof_indices, c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
            try vkCheck(c.vkMapMemory(renderer.device, result.ibo.memory, 0, sizeof_indices, 0, &data));
            std.debug.assert(data != null);
            std.mem.copy(u16, @ptrCast([*]u16, @alignCast(@alignOf(u16), data.?))[0..obj.indices.len], obj.indices);
            c.vkUnmapMemory(renderer.device, result.ibo.memory);
            return result;
        }

        fn deinit(self: Mesh) void {
            self.ibo.deinit();
            self.vbo.deinit();
        }
    };

    const Buffer = struct {
        device: c.VkDevice,
        memory: c.VkDeviceMemory,
        buffer: c.VkBuffer,

        fn init(renderer: *const Vulkan, size: c.VkDeviceSize, usage: c.VkBufferUsageFlags, properties: c.VkMemoryPropertyFlags) !Buffer {
            var result: Buffer = undefined;
            result.device = renderer.device;
            try vkCheck(c.vkCreateBuffer(renderer.device, &zi(c.VkBufferCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
                .size = size,
                .usage = usage,
                .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
            }), null, &result.buffer));
            var mem_req: c.VkMemoryRequirements = undefined;
            c.vkGetBufferMemoryRequirements(renderer.device, result.buffer, &mem_req);
            try vkCheck(c.vkAllocateMemory(renderer.device, &zi(c.VkMemoryAllocateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
                .allocationSize = mem_req.size,
                .memoryTypeIndex = try renderer.find_mem_type(mem_req.memoryTypeBits, properties),
            }), null, &result.memory));
            try vkCheck(c.vkBindBufferMemory(renderer.device, result.buffer, result.memory, 0));
            return result;
        }

        fn deinit(self: Buffer) void {
            c.vkFreeMemory(self.device, self.memory, null);
            c.vkDestroyBuffer(self.device, self.buffer, null);
        }
    };

    const MeshSelector = @Type(.{ .Enum = .{
        .layout = .Auto,
        .tag_type = @Type(.{ .Int = .{
            .signedness = .unsigned,
            .bits = @ceil(@log2(@as(comptime_float, options.files.len))),
        } }),
        .fields = blk: {
            var fields: [options.files.len]std.builtin.Type.EnumField = undefined;
            for (options.files) |file, i| {
                fields[i] = .{ .name = file, .value = i };
            }
            break :blk &fields;
        },
        .decls = &.{},
        .is_exhaustive = true,
    } });

    const RenderObject = struct {
        mesh: MeshSelector,
        transform: Transform,
    };

    const Image = struct {
        device: c.VkDevice,
        memory: c.VkDeviceMemory,
        image: c.VkImage,
        view: c.VkImageView,
        format: c.VkFormat,

        fn init(renderer: *const Vulkan, format: c.VkFormat, usage: c.VkImageUsageFlags, extent: c.VkExtent3D, aspect: c.VkImageAspectFlags, properties: c.VkMemoryPropertyFlags) !Image {
            var result: Image = undefined;
            result.device = renderer.device;
            result.format = format;
            try vkCheck(c.vkCreateImage(renderer.device, &zi(c.VkImageCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
                .imageType = c.VK_IMAGE_TYPE_2D,
                .format = result.format,
                .extent = extent,
                .mipLevels = 1,
                .arrayLayers = 1,
                .samples = c.VK_SAMPLE_COUNT_1_BIT,
                .tiling = c.VK_IMAGE_TILING_OPTIMAL,
                .usage = usage,
            }), null, &result.image));
            var mem_req: c.VkMemoryRequirements = undefined;
            c.vkGetImageMemoryRequirements(renderer.device, result.image, &mem_req);
            try vkCheck(c.vkAllocateMemory(renderer.device, &zi(c.VkMemoryAllocateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
                .allocationSize = mem_req.size,
                .memoryTypeIndex = try renderer.find_mem_type(mem_req.memoryTypeBits, properties),
            }), null, &result.memory));
            try vkCheck(c.vkBindImageMemory(renderer.device, result.image, result.memory, 0));
            try vkCheck(c.vkCreateImageView(renderer.device, &zi(c.VkImageViewCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
                .image = result.image,
                .format = result.format,
                .subresourceRange = .{
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                    .aspectMask = aspect,
                },
            }), null, &result.view));
            return result;
        }

        fn deinit(self: Image) void {
            c.vkDestroyImageView(self.device, self.view, null);
            c.vkFreeMemory(self.device, self.memory, null);
            c.vkDestroyImage(self.device, self.image, null);
        }
    };

    fn vkCheck(result: c.VkResult) !void {
        if (result != c.VK_SUCCESS) {
            std.debug.print("VkResult({})\n", .{result});
            return error.VkError;
        }
    }

    fn vkAssert(check: bool) !void {
        if (!check) {
            return error.VkError;
        }
    }

    fn init(window: Window) !Vulkan {
        var result: Vulkan = undefined;
        result.current_frame = 0;
        result.render_objects = std.ArrayList(*const Renderer.RenderObject).init(std.heap.c_allocator);
        // createInstance()
        {
            const instance_extensions = [_][*c]const u8{ c.VK_KHR_SURFACE_EXTENSION_NAME, switch (platform.Windowing) {
                .xlib => c.VK_KHR_XLIB_SURFACE_EXTENSION_NAME,
                .win32 => c.VK_KHR_WIN32_SURFACE_EXTENSION_NAME,
            } };
            try vkCheck(c.vkCreateInstance(&zi(c.VkInstanceCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                .enabledLayerCount = 1,
                .ppEnabledLayerNames = &[_][*c]const u8{"VK_LAYER_KHRONOS_validation"},
                .enabledExtensionCount = instance_extensions.len,
                .ppEnabledExtensionNames = &instance_extensions,
            }), null, &result.instance));
        }
        // createSurface()
        try vkCheck(switch (platform.Windowing) {
            .xlib => c.vkCreateXlibSurfaceKHR(result.instance, &zi(c.VkXlibSurfaceCreateInfoKHR, .{
                .sType = c.VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
                .dpy = window.dpy,
                .window = window.win,
            }), null, &result.surface),
            .win32 => c.vkCreateWin32SurfaceKHR(result.instance, &zi(c.VkWin32SurfaceCreateInfoKHR, .{
                .sType = c.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
                .hinstance = window.inst,
                .hwnd = window.hwnd,
            }), null, &result.surface),
        });
        // selectPhysicalDevice()
        {
            var count: u32 = 1;
            try vkCheck(c.vkEnumeratePhysicalDevices(result.instance, &count, &result.physical_device));
            try vkAssert(count == 1);

            c.vkGetPhysicalDeviceMemoryProperties(result.physical_device, &result.physical_device_memory_properties);
            c.vkGetPhysicalDeviceProperties(result.physical_device, &result.physical_device_properties);
        }
        // selectSurfaceFormat()
        {
            var count: u32 = 0;
            try vkCheck(c.vkGetPhysicalDeviceSurfaceFormatsKHR(result.physical_device, result.surface, &count, null));
            try vkAssert(count > 0);
            var formats = try std.heap.c_allocator.alloc(c.VkSurfaceFormatKHR, count);
            defer std.heap.c_allocator.free(formats);
            try vkCheck(c.vkGetPhysicalDeviceSurfaceFormatsKHR(result.physical_device, result.surface, &count, formats.ptr));
            result.surface_format = formats[0];
            for (formats) |format| {
                if (format.format == c.VK_FORMAT_B8G8R8A8_UNORM and format.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
                    result.surface_format = format;
                    break;
                }
            }
        }
        // selectPresentMode()
        {
            var count: u32 = 0;
            try vkCheck(c.vkGetPhysicalDeviceSurfacePresentModesKHR(result.physical_device, result.surface, &count, null));
            try vkAssert(count > 0);
            var present_modes = try std.heap.c_allocator.alloc(c.VkPresentModeKHR, count);
            defer std.heap.c_allocator.free(present_modes);
            try vkCheck(c.vkGetPhysicalDeviceSurfacePresentModesKHR(result.physical_device, result.surface, &count, present_modes.ptr));
            result.present_mode = c.VK_PRESENT_MODE_FIFO_KHR;
            for (present_modes) |present_mode| {
                if (present_mode == c.VK_PRESENT_MODE_MAILBOX_KHR) {
                    result.present_mode = present_mode;
                    break;
                }
            }
        }
        // findQueueFamilies()
        {
            var count: u32 = 0;
            c.vkGetPhysicalDeviceQueueFamilyProperties(result.physical_device, &count, null);
            try vkAssert(count > 0);
            var queue_families = try std.heap.c_allocator.alloc(c.VkQueueFamilyProperties, count);
            defer std.heap.c_allocator.free(queue_families);
            c.vkGetPhysicalDeviceQueueFamilyProperties(result.physical_device, &count, queue_families.ptr);

            result.graphics_queue_family_index = blk: {
                for (queue_families) |family, i| {
                    if (family.queueCount == 0) continue;
                    if ((family.queueFlags & c.VK_QUEUE_GRAPHICS_BIT) != 0) {
                        break :blk @intCast(u32, i);
                    }
                }
                return error.MissingQueueFamily;
            };

            result.present_queue_family_index = blk: {
                for (queue_families) |family, i| {
                    if (family.queueCount == 0) continue;
                    var found = c.VK_FALSE;
                    try vkCheck(c.vkGetPhysicalDeviceSurfaceSupportKHR(result.physical_device, @intCast(u32, i), result.surface, &found));
                    if (found == c.VK_TRUE) {
                        break :blk @intCast(u32, i);
                    }
                }
                return error.MissingQueueFamily;
            };
        }
        // createDevice()
        {
            try vkCheck(c.vkCreateDevice(result.physical_device, &zi(c.VkDeviceCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                .queueCreateInfoCount = if (result.graphics_queue_family_index == result.present_queue_family_index) @as(u32, 1) else @as(u32, 2),
                .pQueueCreateInfos = &[_]c.VkDeviceQueueCreateInfo{
                    zi(c.VkDeviceQueueCreateInfo, .{
                        .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                        .queueFamilyIndex = result.graphics_queue_family_index,
                        .queueCount = 1,
                        .pQueuePriorities = &[_]f32{1.0},
                    }),
                    zi(c.VkDeviceQueueCreateInfo, .{
                        .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                        .queueFamilyIndex = result.present_queue_family_index,
                        .queueCount = 1,
                        .pQueuePriorities = &[_]f32{1.0},
                    }),
                },
                .pEnabledFeatures = &zi(c.VkPhysicalDeviceFeatures, .{}),
                .enabledExtensionCount = 1,
                .ppEnabledExtensionNames = &[_][*c]const u8{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME},
            }), null, &result.device));
        }
        // getQueueHandles()
        {
            c.vkGetDeviceQueue(result.device, result.graphics_queue_family_index, 0, &result.graphics_queue);
            c.vkGetDeviceQueue(result.device, result.present_queue_family_index, 0, &result.present_queue);
        }
        // createCommandPool()
        {
            try vkCheck(c.vkCreateCommandPool(result.device, &zi(c.VkCommandPoolCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
                .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
                .queueFamilyIndex = result.graphics_queue_family_index,
            }), null, &result.graphics_command_pool));
        }
        // createRenderPass()
        {
            try vkCheck(c.vkCreateRenderPass(result.device, &zi(c.VkRenderPassCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
                .attachmentCount = 2,
                .pAttachments = &[_]c.VkAttachmentDescription{
                    zi(c.VkAttachmentDescription, .{
                        .format = result.surface_format.format,
                        .samples = c.VK_SAMPLE_COUNT_1_BIT,
                        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
                        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
                        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
                        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
                        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
                        .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
                    }),
                    zi(c.VkAttachmentDescription, .{
                        .format = c.VK_FORMAT_D32_SFLOAT,
                        .samples = c.VK_SAMPLE_COUNT_1_BIT,
                        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
                        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
                        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
                        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
                        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
                        .finalLayout = c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
                    }),
                },
                .subpassCount = 1,
                .pSubpasses = &zi(c.VkSubpassDescription, .{
                    .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                    .colorAttachmentCount = 1,
                    .pColorAttachments = &zi(c.VkAttachmentReference, .{
                        .attachment = 0,
                        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                    }),
                    .pDepthStencilAttachment = &zi(c.VkAttachmentReference, .{
                        .attachment = 1,
                        .layout = c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
                    }),
                }),
                .dependencyCount = 2,
                .pDependencies = &[_]c.VkSubpassDependency{
                    zi(c.VkSubpassDependency, .{
                        .srcSubpass = c.VK_SUBPASS_EXTERNAL,
                        .dstSubpass = 0,
                        .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                        .srcAccessMask = 0,
                        .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                        .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
                    }),
                    zi(c.VkSubpassDependency, .{
                        .srcSubpass = c.VK_SUBPASS_EXTERNAL,
                        .dstSubpass = 0,
                        .srcStageMask = c.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT | c.VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
                        .srcAccessMask = 0,
                        .dstStageMask = c.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT | c.VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
                        .dstAccessMask = c.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
                    }),
                },
            }), null, &result.render_pass));
        }
        // createShaders()
        const shader_module = blk: {
            const meshspv = @embedFile("shaders/mesh.spv");
            var temp: c.VkShaderModule = undefined;
            try vkCheck(c.vkCreateShaderModule(result.device, &zi(c.VkShaderModuleCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                .codeSize = meshspv.len,
                .pCode = @ptrCast(*const u32, @alignCast(@alignOf(u32), meshspv)),
            }), null, &temp));
            break :blk temp;
        };
        defer c.vkDestroyShaderModule(result.device, shader_module, null);
        // createGraphicsPipelineLayout()
        try vkCheck(c.vkCreatePipelineLayout(result.device, &zi(c.VkPipelineLayoutCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .pushConstantRangeCount = 1,
            .pPushConstantRanges = &zi(c.VkPushConstantRange, .{
                .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
                .offset = 0,
                .size = @sizeOf(MeshPushConstants),
            }),
        }), null, &result.mesh_graphics_pipeline_layout));
        // createGraphicsPipeline()
        {
            const stages = [_]c.VkPipelineShaderStageCreateInfo{
                zi(c.VkPipelineShaderStageCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                    .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
                    .module = shader_module,
                    .pName = "main",
                }),
                zi(c.VkPipelineShaderStageCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                    .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
                    .module = shader_module,
                    .pName = "main",
                }),
            };
            const topology: c.VkPrimitiveTopology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
            const polygon_mode: c.VkPolygonMode = c.VK_POLYGON_MODE_FILL;
            const layout: c.VkPipelineLayout = result.mesh_graphics_pipeline_layout;
            try vkCheck(c.vkCreateGraphicsPipelines(result.device, null, 1, &zi(c.VkGraphicsPipelineCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
                .stageCount = stages.len,
                .pStages = &stages,
                .pVertexInputState = &zi(c.VkPipelineVertexInputStateCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
                    .vertexBindingDescriptionCount = vertex_bindings.len,
                    .pVertexBindingDescriptions = &vertex_bindings,
                    .vertexAttributeDescriptionCount = vertex_attributes.len,
                    .pVertexAttributeDescriptions = &vertex_attributes,
                }),
                .pInputAssemblyState = &zi(c.VkPipelineInputAssemblyStateCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
                    .topology = topology,
                }),
                .pViewportState = &zi(c.VkPipelineViewportStateCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
                    .viewportCount = 1,
                    .scissorCount = 1,
                }),
                .pRasterizationState = &zi(c.VkPipelineRasterizationStateCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
                    .polygonMode = polygon_mode,
                    .cullMode = c.VK_CULL_MODE_BACK_BIT,
                    .frontFace = c.VK_FRONT_FACE_COUNTER_CLOCKWISE,
                    .lineWidth = 1.0,
                }),
                .pMultisampleState = &zi(c.VkPipelineMultisampleStateCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
                    .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
                }),
                .pColorBlendState = &zi(c.VkPipelineColorBlendStateCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
                    .attachmentCount = 1,
                    .pAttachments = &zi(c.VkPipelineColorBlendAttachmentState, .{
                        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
                    }),
                }),
                .pDynamicState = &zi(c.VkPipelineDynamicStateCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
                    .dynamicStateCount = 2,
                    .pDynamicStates = &[_]c.VkDynamicState{ c.VK_DYNAMIC_STATE_VIEWPORT, c.VK_DYNAMIC_STATE_SCISSOR },
                }),
                .pDepthStencilState = &zi(c.VkPipelineDepthStencilStateCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
                    .depthTestEnable = c.VK_TRUE,
                    .depthWriteEnable = c.VK_TRUE,
                    .depthCompareOp = c.VK_COMPARE_OP_LESS_OR_EQUAL,
                    .depthBoundsTestEnable = c.VK_FALSE,
                }),
                .layout = layout,
                .renderPass = result.render_pass,
                .subpass = 0,
            }), null, &result.mesh_graphics_pipeline));
        }

        inline for (options.files) |file, i| {
            result.gpu_meshes[i] = try Mesh.init(&result, file);
        }

        try result.swapchain_init();
        // NOTE: don't put anything in between here unless you're special
        return result;
    }

    fn swapchain_init(result: *Vulkan) !void {
        try vkCheck(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(result.physical_device, result.surface, &result.surface_capabilities));
        result.image_count = std.math.max(result.surface_capabilities.minImageCount, min_image_count);
        if (result.surface_capabilities.maxImageCount > 0)
            result.image_count = std.math.min(result.image_count, result.surface_capabilities.maxImageCount);

        try vkCheck(c.vkCreateSwapchainKHR(result.device, &zi(c.VkSwapchainCreateInfoKHR, .{
            .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = result.surface,
            .minImageCount = result.image_count,
            .imageFormat = result.surface_format.format,
            .imageColorSpace = result.surface_format.colorSpace,
            .imageExtent = result.surface_capabilities.currentExtent,
            .imageArrayLayers = 1,
            .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = if (result.graphics_queue_family_index == result.present_queue_family_index) @as(c_uint, c.VK_SHARING_MODE_EXCLUSIVE) else @as(c_uint, c.VK_SHARING_MODE_CONCURRENT),
            .queueFamilyIndexCount = if (result.graphics_queue_family_index == result.present_queue_family_index) @as(u32, 0) else @as(u32, 2),
            .pQueueFamilyIndices = &[_]u32{ result.graphics_queue_family_index, result.present_queue_family_index },
            .preTransform = c.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
            .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = result.present_mode,
            .clipped = c.VK_TRUE,
        }), null, &result.swapchain));

        try vkCheck(c.vkGetSwapchainImagesKHR(result.device, result.swapchain, &result.image_count, null));
        try vkAssert(result.image_count > 0);
        result.swapchain_images = try std.heap.c_allocator.alloc(c.VkImage, result.image_count);
        try vkCheck(c.vkGetSwapchainImagesKHR(result.device, result.swapchain, &result.image_count, result.swapchain_images.ptr));

        // createDepthBuffer()
        result.depth_buffer = try Image.init(result, c.VK_FORMAT_D32_SFLOAT, c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT, c.VkExtent3D{
            .width = result.surface_capabilities.currentExtent.width,
            .height = result.surface_capabilities.currentExtent.height,
            .depth = 1,
        }, c.VK_IMAGE_ASPECT_DEPTH_BIT, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
        // createImageViews()
        {
            result.swapchain_image_views = try std.heap.c_allocator.alloc(c.VkImageView, result.image_count);
            var i: u32 = 0;
            while (i < result.image_count) : (i += 1) {
                try vkCheck(c.vkCreateImageView(result.device, &zi(c.VkImageViewCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                    .image = result.swapchain_images[i],
                    .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
                    .format = result.surface_format.format,
                    .components = .{
                        .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                        .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                        .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                        .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                    },
                    .subresourceRange = .{
                        .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                        .baseMipLevel = 0,
                        .levelCount = 1,
                        .baseArrayLayer = 0,
                        .layerCount = 1,
                    },
                }), null, &result.swapchain_image_views[i]));
            }
        }
        // createFramebuffers()
        {
            result.framebuffers = try std.heap.c_allocator.alloc(c.VkFramebuffer, result.image_count);
            var i: u32 = 0;
            while (i < result.image_count) : (i += 1) {
                try vkCheck(c.vkCreateFramebuffer(result.device, &zi(c.VkFramebufferCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                    .renderPass = result.render_pass,
                    .attachmentCount = 2,
                    .pAttachments = &[_]c.VkImageView{
                        result.swapchain_image_views[i],
                        result.depth_buffer.view,
                    },
                    .width = result.surface_capabilities.currentExtent.width,
                    .height = result.surface_capabilities.currentExtent.height,
                    .layers = 1,
                }), null, &result.framebuffers[i]));
            }
        }
        // createSyncObjects()
        {
            result.image_acquired_semaphores = try std.heap.c_allocator.alloc(c.VkSemaphore, result.image_count);
            result.image_written_semaphores = try std.heap.c_allocator.alloc(c.VkSemaphore, result.image_count);
            result.currently_rendering_fences = try std.heap.c_allocator.alloc(c.VkFence, result.image_count);
            var i: u32 = 0;
            while (i < result.image_count) : (i += 1) {
                try vkCheck(c.vkCreateSemaphore(result.device, &zi(c.VkSemaphoreCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
                }), null, &result.image_acquired_semaphores[i]));
                try vkCheck(c.vkCreateSemaphore(result.device, &zi(c.VkSemaphoreCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
                }), null, &result.image_written_semaphores[i]));
                try vkCheck(c.vkCreateFence(result.device, &zi(c.VkFenceCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
                    .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
                }), null, &result.currently_rendering_fences[i]));
            }
        }
        // createCommandBuffers()
        {
            result.graphics_command_buffers = try std.heap.c_allocator.alloc(c.VkCommandBuffer, result.image_count);
            try vkCheck(c.vkAllocateCommandBuffers(result.device, &zi(c.VkCommandBufferAllocateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
                .commandPool = result.graphics_command_pool,
                .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
                .commandBufferCount = result.image_count,
            }), result.graphics_command_buffers.ptr));
        }
    }

    fn swapchain_deinit(self: Vulkan) void {
        _ = c.vkDeviceWaitIdle(self.device);
        c.vkFreeCommandBuffers(self.device, self.graphics_command_pool, self.image_count, self.graphics_command_buffers.ptr);
        std.heap.c_allocator.free(self.graphics_command_buffers);
        var i: u32 = 0;
        while (i < self.image_count) : (i += 1) {
            c.vkDestroyFence(self.device, self.currently_rendering_fences[i], null);
            c.vkDestroySemaphore(self.device, self.image_written_semaphores[i], null);
            c.vkDestroySemaphore(self.device, self.image_acquired_semaphores[i], null);
            c.vkDestroyFramebuffer(self.device, self.framebuffers[i], null);
            c.vkDestroyImageView(self.device, self.swapchain_image_views[i], null);
        }
        std.heap.c_allocator.free(self.currently_rendering_fences);
        std.heap.c_allocator.free(self.image_written_semaphores);
        std.heap.c_allocator.free(self.image_acquired_semaphores);
        std.heap.c_allocator.free(self.framebuffers);
        std.heap.c_allocator.free(self.swapchain_image_views);
        self.depth_buffer.deinit();
        std.heap.c_allocator.free(self.swapchain_images);
        c.vkDestroySwapchainKHR(self.device, self.swapchain, null);
    }

    fn swapchain_reinit(self: *Vulkan) !void {
        self.swapchain_deinit();
        try self.swapchain_init();
    }

    fn deinit(self: Vulkan) void {
        self.swapchain_deinit();
        for (self.gpu_meshes) |mesh| {
            mesh.deinit();
        }
        c.vkDestroyPipeline(self.device, self.mesh_graphics_pipeline, null);
        c.vkDestroyPipelineLayout(self.device, self.mesh_graphics_pipeline_layout, null);
        c.vkDestroyRenderPass(self.device, self.render_pass, null);
        c.vkDestroyCommandPool(self.device, self.graphics_command_pool, null);
        c.vkDestroyDevice(self.device, null);
        c.vkDestroySurfaceKHR(self.instance, self.surface, null);
        c.vkDestroyInstance(self.instance, null);
        self.render_objects.deinit();
    }

    fn record_buffer(self: *Vulkan, buffer: c.VkCommandBuffer, image_index: u32) !void {
        try vkCheck(c.vkBeginCommandBuffer(buffer, &zi(c.VkCommandBufferBeginInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        })));
        c.vkCmdBeginRenderPass(buffer, &zi(c.VkRenderPassBeginInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = self.render_pass,
            .framebuffer = self.framebuffers[image_index],
            .renderArea = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = self.surface_capabilities.currentExtent,
            },
            .clearValueCount = 2,
            .pClearValues = &[_]c.VkClearValue{
                .{ .color = .{ .float32 = .{ 0.0, 0.0, 0.0, 1.0 } } },
                .{ .depthStencil = .{ .depth = 1.0, .stencil = 0 } },
            },
        }), c.VK_SUBPASS_CONTENTS_INLINE);
        c.vkCmdBindPipeline(buffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.mesh_graphics_pipeline);
        c.vkCmdSetViewport(buffer, 0, 1, &zi(c.VkViewport, .{
            .x = 0.0,
            .y = 0.0,
            .width = @intToFloat(f32, self.surface_capabilities.currentExtent.width),
            .height = @intToFloat(f32, self.surface_capabilities.currentExtent.height),
            .minDepth = 1.0,
            .maxDepth = 0.0,
        }));
        c.vkCmdSetScissor(buffer, 0, 1, &zi(c.VkRect2D, .{
            .offset = .{ .x = 0, .y = 0 },
            .extent = self.surface_capabilities.currentExtent,
        }));
        const vp = self.projection.mul(self.view);
        for (self.render_objects.items) |object| {
            c.vkCmdPushConstants(buffer, self.mesh_graphics_pipeline_layout, c.VK_SHADER_STAGE_VERTEX_BIT, 0, @sizeOf(MeshPushConstants), &zi(MeshPushConstants, .{
                .mvp = vp.mul(object.transform.matrix()),
            }));
            const gpu_mesh = self.gpu_meshes[@enumToInt(object.mesh)];
            c.vkCmdBindVertexBuffers(buffer, 0, 1, &gpu_mesh.vbo.buffer, &[_]c.VkDeviceSize{0});
            c.vkCmdBindIndexBuffer(buffer, gpu_mesh.ibo.buffer, 0, c.VK_INDEX_TYPE_UINT16);
            c.vkCmdDrawIndexed(buffer, gpu_mesh.draw_count, 1, 0, 0, 0);
        }
        c.vkCmdEndRenderPass(buffer);
        try vkCheck(c.vkEndCommandBuffer(buffer));
    }

    fn update(self: *Vulkan) !void {
        try vkCheck(c.vkWaitForFences(self.device, 1, &self.currently_rendering_fences[self.current_frame], c.VK_TRUE, std.math.maxInt(u64)));
        var image_index: u32 = undefined;
        var result = c.vkAcquireNextImageKHR(self.device, self.swapchain, std.math.maxInt(u64), self.image_acquired_semaphores[self.current_frame], null, &image_index);
        switch (result) {
            c.VK_ERROR_OUT_OF_DATE_KHR => return try self.swapchain_reinit(),
            c.VK_SUCCESS, c.VK_SUBOPTIMAL_KHR => {},
            else => @panic("renderer error"),
        }
        try vkCheck(c.vkResetFences(self.device, 1, &self.currently_rendering_fences[self.current_frame]));
        try self.record_buffer(self.graphics_command_buffers[self.current_frame], image_index);
        try vkCheck(c.vkQueueSubmit(self.graphics_queue, 1, &zi(c.VkSubmitInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &self.image_acquired_semaphores[self.current_frame],
            .pWaitDstStageMask = &[_]c.VkPipelineStageFlags{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT},
            .commandBufferCount = 1,
            .pCommandBuffers = &self.graphics_command_buffers[self.current_frame],
            .signalSemaphoreCount = 1,
            .pSignalSemaphores = &self.image_written_semaphores[self.current_frame],
        }), self.currently_rendering_fences[self.current_frame]));
        result = c.vkQueuePresentKHR(self.present_queue, &zi(c.VkPresentInfoKHR, .{
            .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &self.image_written_semaphores[self.current_frame],
            .swapchainCount = 1,
            .pSwapchains = &self.swapchain,
            .pImageIndices = &image_index,
        }));
        switch (result) {
            c.VK_ERROR_OUT_OF_DATE_KHR, c.VK_SUBOPTIMAL_KHR => try self.swapchain_reinit(),
            c.VK_SUCCESS => {},
            else => @panic("renderer error"),
        }
        self.current_frame = (self.current_frame + 1) % self.image_count;
    }
};

const Window = switch (platform.Windowing) {
    .xlib => Xlib,
    .win32 => Win32,
};

const Xlib = struct {
    dpy: *c.Display,
    win: c.Window,
    wm_close: c.Atom,

    fn init(args: struct { title: [:0]const u8 = "Title" }) !Xlib {
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

    fn deinit(self: Xlib) void {
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
    fn update(self: *Xlib, input: *Input) ?void {
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
};

const Win32 = struct {
    const user32 = std.os.windows.user32;

    inst: c.HINSTANCE,
    hwnd: c.HWND,

    fn init(args: struct { title: [:0]const u8 = "Title" }) !Win32 {
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

    fn deinit(self: Win32) void {
        _ = self;
    }

    fn update(self: *Win32, input: *Input) ?void {
        _ = .{ self, input };
        var msg: user32.MSG = undefined;
        while (user32.peekMessageA(&msg, null, 0, 0, user32.PM_REMOVE) catch return null) {
            _ = user32.translateMessage(&msg);
            _ = user32.dispatchMessageA(&msg);
        }
    }
};

pub fn main() !void {
    var input = Input{};
    var time = Time.init();
    var window = try Window.init(.{});
    defer window.deinit();
    var renderer = try Renderer.init(window);
    defer renderer.deinit();

    var view = Transform{};
    view.position[2] = -10.0;

    while (true) {
        window.update(&input) orelse break;
        time.tick();

        // gameUpdate()
        if (input.getKeyJustDown(.escape)) {
            break;
        }
        var direction = @splat(3, @as(f32, 0.0));
        if (input.getKeyDown(.w)) {
            direction[2] -= 1.0;
        }
        if (input.getKeyDown(.s)) {
            direction[2] += 1.0;
        }
        if (input.getKeyDown(.d)) {
            direction[0] += 1.0;
        }
        if (input.getKeyDown(.a)) {
            direction[0] -= 1.0;
        }
        const direction_len = @sqrt(@reduce(.Add, direction * direction));
        direction = if (std.math.approxEqAbs(f32, direction_len, 0.0, comptime std.math.floatEps(f32)))
            @splat(3, @as(f32, 0.0))
        else
            direction / @splat(3, direction_len);
        const speed = 5.0;
        view.position -= direction * @splat(3, @floatCast(f32, time.delta) * speed);

        try renderer.render_objects.append(&Renderer.RenderObject{
            .mesh = if (@floatToInt(u64, time.running) % 2 == 0) .cube1 else .warped_cube,
            .transform = Transform{
                // .position = .{ @floatCast(f32, @sin(time.running)) * 5.0, 0.0, 0.0 },
                .rotation = @splat(3, @floatCast(f32, time.running)),
            },
        });

        // resize()
        {
            renderer.projection = Matrix(4, 4, f32).perspective(std.math.pi / 2.0, @intToFloat(f32, renderer.surface_capabilities.currentExtent.width) / @intToFloat(f32, renderer.surface_capabilities.currentExtent.height), 0.1, 100.0);
            // renderer.projection = Matrix(4, 4, f32).orthographic(0.0, @intToFloat(f32, renderer.surface_capabilities.currentExtent.width), -@intToFloat(f32, renderer.surface_capabilities.currentExtent.height), 0.0, -1.0, 1.0);
        }
        renderer.view = view.matrix();

        try renderer.update();
        renderer.render_objects.clearRetainingCapacity();
        input.save();
    }
}
