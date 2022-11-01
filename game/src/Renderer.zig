const std = @import("std");
const options = @import("options");
const platform = @import("platform.zig");
const c = @import("c.zig");
const math = @import("math.zig");
const Window = @import("Window.zig");
const Time = @import("Time.zig");

const Renderer = @This();
const Impl = switch (platform.render_lib) {
    .vulkan => VulkanRendererImpl,
};
pub usingnamespace Impl;

impl: Impl = undefined,
time: *const Time,
window: *const Window,
view: math.Matrix(f32, 4, 4) = math.Matrix(f32, 4, 4).I().translate(.{ 0.0, 0.0, -5.0 }),
projection: math.Matrix(f32, 4, 4) = math.Matrix(f32, 4, 4).I(),

// Comptime Mesh constant loader (currently receives values from .options in build.zig)
// Reads files from src/meshes/* and generates enum values based on them
// Example: Reference ./src/meshes/cube.obj with Mesh.cube
const Mesh = @Type(.{ .Enum = .{
    .layout = .Auto,
    .tag_type = @Type(.{ .Int = .{
        .signedness = .unsigned,
        .bits = @ceil(@log2(@intToFloat(comptime_float, options.files.len))),
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

const MeshPaths: std.EnumArray(Mesh, []const u8) = blk: {
    var map = std.EnumArray(Mesh, []const u8).initUndefined();
    for (@typeInfo(Mesh).Enum.fields) |field| {
        map.set(@field(Mesh, field.name), options.files_folder ++ "/" ++ field.name ++ ".obj");
    }
    break :blk map;
};

const Vertex = struct {
    position: @Vector(3, f32),
    normal: @Vector(3, f32),
    color: @Vector(3, f32),
};

const MeshPushConstants = struct {
    mvp: math.Matrix(f32, 4, 4),
};

const RenderObject = struct {
    mesh: Mesh,
    transform: math.Matrix(f32, 4, 4),
};

// TODO: use structs to make this cleaner (i.e. Faces should use names instead of an array of only brain-known values)
fn parseObj(comptime mesh: Mesh) ![]Vertex {
    @setEvalBranchQuota(100000);
    const file_data = @embedFile(MeshPaths.get(mesh));
    var stream = std.io.fixedBufferStream(file_data);
    const reader = stream.reader();

    const max_line_len = @sizeOf(@TypeOf(file_data.*)) - 1;
    var buf: [max_line_len]u8 = undefined;

    var vertices: [max_line_len]@Vector(3, f32) = undefined;
    var num_vertices: comptime_int = 0;
    var normals: [max_line_len]@Vector(3, f32) = undefined;
    var num_normals: comptime_int = 0;

    // [0] = vertex{x, y, z}, [1] = texcoord{x, y, z}, [2] = normal{x, y, z}
    var faces: [max_line_len][3]@Vector(3, u16) = undefined;
    var num_faces: comptime_int = 0;

    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var tokens = std.mem.split(u8, line, " ");
        const cmd = tokens.next().?;
        if (std.mem.eql(u8, cmd, "v")) {
            vertices[num_vertices] = .{
                try std.fmt.parseFloat(f32, tokens.next().?),
                try std.fmt.parseFloat(f32, tokens.next().?),
                try std.fmt.parseFloat(f32, tokens.next().?),
            };
            num_vertices += 1;
        } else if (std.mem.eql(u8, cmd, "vn")) {
            normals[num_normals] = .{
                try std.fmt.parseFloat(f32, tokens.next().?),
                try std.fmt.parseFloat(f32, tokens.next().?),
                try std.fmt.parseFloat(f32, tokens.next().?),
            };
            num_normals += 1;
        } else if (std.mem.eql(u8, cmd, "f")) {
            // format: v1/t1/n1 v2/t2/n2 v3/t3/n3
            var index1_tokens = std.mem.split(u8, tokens.next().?, "/");
            var index2_tokens = std.mem.split(u8, tokens.next().?, "/");
            var index3_tokens = std.mem.split(u8, tokens.next().?, "/");
            faces[num_faces] = .{
                .{ try std.fmt.parseInt(u16, index1_tokens.next().?, 10) - 1, try std.fmt.parseInt(u16, index2_tokens.next().?, 10) - 1, try std.fmt.parseInt(u16, index3_tokens.next().?, 10) - 1 },
                .{ try std.fmt.parseInt(u16, index1_tokens.next().?, 10) - 1, try std.fmt.parseInt(u16, index2_tokens.next().?, 10) - 1, try std.fmt.parseInt(u16, index3_tokens.next().?, 10) - 1 },
                .{ try std.fmt.parseInt(u16, index1_tokens.next().?, 10) - 1, try std.fmt.parseInt(u16, index2_tokens.next().?, 10) - 1, try std.fmt.parseInt(u16, index3_tokens.next().?, 10) - 1 },
            };
            num_faces += 1;
        } else {}
    }

    var result: [num_faces * 3]Vertex = undefined;
    for (faces[0..num_faces]) |face, i| {
        result[i * 3 + 0].position = vertices[face[0][0]];
        result[i * 3 + 0].normal = normals[face[2][0]];
        result[i * 3 + 0].color = .{ 1.0, 0.0, 0.0 };
        result[i * 3 + 1].position = vertices[face[0][1]];
        result[i * 3 + 1].normal = normals[face[2][1]];
        result[i * 3 + 1].color = .{ 0.0, 1.0, 0.0 };
        result[i * 3 + 2].position = vertices[face[0][2]];
        result[i * 3 + 2].normal = normals[face[2][2]];
        result[i * 3 + 2].color = .{ 0.0, 0.0, 1.0 };
    }

    return &result;
}

const VulkanRendererImpl = struct {
    const zi = std.mem.zeroInit;
    const max_frames_rendering_at_once = 2;
    const max_swapchain_images = 10;

    instance: c.VkInstance,
    physical_device: c.VkPhysicalDevice,
    physical_device_properties: c.VkPhysicalDeviceProperties,
    physical_device_memory_properties: c.VkPhysicalDeviceMemoryProperties,
    surface: c.VkSurfaceKHR,
    surface_format: c.VkSurfaceFormatKHR,
    surface_present_mode: c.VkPresentModeKHR,
    graphics_queue_family_index: u32,
    present_queue_family_index: u32,
    device: c.VkDevice,
    graphics_queue: c.VkQueue,
    present_queue: c.VkQueue,
    graphics_command_pool: c.VkCommandPool,
    graphics_command_buffers: [max_frames_rendering_at_once]c.VkCommandBuffer,
    image_acquired_semaphores: [max_frames_rendering_at_once]c.VkSemaphore,
    image_written_semaphores: [max_frames_rendering_at_once]c.VkSemaphore,
    currently_rendering_fences: [max_frames_rendering_at_once]c.VkFence,
    render_pass: c.VkRenderPass,

    // swapchain
    surface_capabilities: c.VkSurfaceCapabilitiesKHR,
    image_count: u32,
    swapchain: c.VkSwapchainKHR,
    swapchain_images: [max_swapchain_images]c.VkImage,
    swapchain_image_views: [max_swapchain_images]c.VkImageView,
    framebuffers: [max_swapchain_images]c.VkFramebuffer,
    depth_buffer: Image,

    current_frame: u32,

    // temporary
    mesh_graphics_pipeline_layout: c.VkPipelineLayout,
    mesh_graphics_pipeline: c.VkPipeline,
    render_objects: std.ArrayList(RenderObject),
    mesh_to_gpudata_map: std.EnumArray(Mesh, VulkanMesh),

    fn vkCheck(result: c.VkResult) !void {
        if (result != c.VK_SUCCESS) {
            std.debug.print("VkResult({})\n", .{result});
            return error.VkError;
        }
    }

    fn VertexInputDescription(comptime T: type) type {
        return struct {
            const Self = @This();
            const Info = @typeInfo(T).Struct;

            bindings: [1]c.VkVertexInputBindingDescription,
            attributes: [Info.fields.len]c.VkVertexInputAttributeDescription,

            fn getFormat(comptime i: comptime_int) c_uint {
                const vector = @typeInfo(Info.fields[i].field_type).Vector;
                std.debug.assert(vector.len > 0 and vector.len <= 4);
                return switch (vector.child) {
                    f32 => switch (vector.len) {
                        1 => c.VK_FORMAT_R32_SFLOAT,
                        2 => c.VK_FORMAT_R32G32_SFLOAT,
                        3 => c.VK_FORMAT_R32G32B32_SFLOAT,
                        4 => c.VK_FORMAT_R32G32B32A32_SFLOAT,
                        else => unreachable,
                    },
                    else => @compileError(@typeName(vector.child)),
                };
            }

            fn init() Self {
                var result: Self = undefined;
                inline for (result.bindings) |*binding, i| {
                    binding.* = .{
                        .binding = i,
                        .stride = @sizeOf(T),
                        .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
                    };
                }
                inline for (result.attributes) |*attribute, i| {
                    attribute.* = .{
                        .binding = 0,
                        .location = @intCast(u32, i),
                        .format = getFormat(i),
                        .offset = @offsetOf(T, Info.fields[i].name),
                    };
                }
                return result;
            }
        };
    }

    fn find_mem_type(impl: *const VulkanRendererImpl, type_filter: u32, properties: c.VkMemoryPropertyFlags) ?u32 {
        var i: u5 = 0;
        while (i < impl.physical_device_memory_properties.memoryTypeCount) : (i += 1) {
            if ((type_filter & (@as(u32, 1) << i)) != 0 and (impl.physical_device_memory_properties.memoryTypes[i].propertyFlags & properties) == properties) {
                return i;
            }
        }
        return null;
    }

    const Buffer = struct {
        const Self = @This();

        impl: *const VulkanRendererImpl,
        buffer: c.VkBuffer,
        memory: c.VkDeviceMemory,

        fn create(impl: *const VulkanRendererImpl, size: c.VkDeviceSize, usage: c.VkBufferUsageFlags, properties: c.VkMemoryPropertyFlags) !Self {
            var result: Self = undefined;
            result.impl = impl;
            try vkCheck(c.vkCreateBuffer(impl.device, &zi(c.VkBufferCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
                .size = size,
                .usage = usage,
                .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
            }), null, &result.buffer));
            errdefer c.vkDestroyBuffer(impl.device, result.buffer, null);
            var mem_req: c.VkMemoryRequirements = undefined;
            c.vkGetBufferMemoryRequirements(impl.device, result.buffer, &mem_req);
            try vkCheck(c.vkAllocateMemory(impl.device, &zi(c.VkMemoryAllocateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
                .allocationSize = mem_req.size,
                .memoryTypeIndex = impl.find_mem_type(mem_req.memoryTypeBits, properties) orelse return error.NoMemoryTypeFound,
            }), null, &result.memory));
            errdefer c.vkFreeMemory(impl.device, result.memory, null);
            try vkCheck(c.vkBindBufferMemory(impl.device, result.buffer, result.memory, 0));
            return result;
        }

        fn destroy(self: Self) void {
            c.vkFreeMemory(self.impl.device, self.memory, null);
            c.vkDestroyBuffer(self.impl.device, self.buffer, null);
        }
    };

    const Image = struct {
        const Self = @This();

        impl: *const VulkanRendererImpl,
        image: c.VkImage,
        view: c.VkImageView,
        format: c.VkFormat,
        memory: c.VkDeviceMemory,

        fn create(impl: *const VulkanRendererImpl, format: c.VkFormat, usage: c.VkImageUsageFlags, extent: c.VkExtent3D, aspect_flags: c.VkImageAspectFlags, properties: c.VkMemoryPropertyFlags) !Self {
            var result: Self = undefined;
            result.impl = impl;
            result.format = format;
            try vkCheck(c.vkCreateImage(impl.device, &zi(c.VkImageCreateInfo, .{
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
            errdefer c.vkDestroyImage(impl.device, result.image, null);
            var mem_req: c.VkMemoryRequirements = undefined;
            c.vkGetImageMemoryRequirements(impl.device, result.image, &mem_req);
            try vkCheck(c.vkAllocateMemory(impl.device, &zi(c.VkMemoryAllocateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
                .allocationSize = mem_req.size,
                .memoryTypeIndex = impl.find_mem_type(mem_req.memoryTypeBits, properties) orelse return error.NoMemoryTypeFound,
            }), null, &result.memory));
            errdefer c.vkFreeMemory(impl.device, result.memory, null);
            try vkCheck(c.vkBindImageMemory(impl.device, result.image, result.memory, 0));
            try vkCheck(c.vkCreateImageView(impl.device, &zi(c.VkImageViewCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
                .image = result.image,
                .format = result.format,
                .subresourceRange = .{
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                    .aspectMask = aspect_flags,
                },
            }), null, &result.view));
            errdefer c.vkDestroyImageView(impl.device, result.view, null);
            return result;
        }

        fn destroy(self: Self) void {
            c.vkDestroyImageView(self.impl.device, self.view, null);
            c.vkFreeMemory(self.impl.device, self.memory, null);
            c.vkDestroyImage(self.impl.device, self.image, null);
        }
    };

    const VulkanMesh = struct {
        const Self = @This();

        buffer: Buffer,
        draw_count: u32,

        fn create(impl: *const VulkanRendererImpl, vertices: []const Vertex) !Self {
            const sizeof_vertices = @sizeOf(Vertex) * vertices.len;
            var result: Self = undefined;
            result.draw_count = @intCast(u32, vertices.len);
            result.buffer = try Buffer.create(impl, sizeof_vertices, c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
            var data: ?*anyopaque = undefined;
            try vkCheck(c.vkMapMemory(impl.device, result.buffer.memory, 0, vertices.len, 0, &data));
            std.debug.assert(data != null);
            std.mem.copy(Vertex, @ptrCast([*]Vertex, @alignCast(@alignOf(Vertex), data.?))[0..vertices.len], vertices);
            c.vkUnmapMemory(impl.device, result.buffer.memory);
            return result;
        }

        fn destroy(self: Self) void {
            self.buffer.destroy();
        }
    };

    fn swapchain_init(self: *Renderer) !void {
        // getSurfaceInfo()
        {
            try vkCheck(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(self.impl.physical_device, self.impl.surface, &self.impl.surface_capabilities));
        }
        // recalculateProjectionMatrix()
        {
            // TODO: Move this to a Window resize callback/event rather than relying on Vulkan swapchain reinit
            self.projection = math.Matrix(f32, 4, 4).Perspective(std.math.pi / 2.0, @intToFloat(f32, self.impl.surface_capabilities.currentExtent.width) / @intToFloat(f32, self.impl.surface_capabilities.currentExtent.height), 0.1, 100.0);
        }
        // getMinimumImageCount()
        {
            self.impl.image_count = std.math.max(self.impl.surface_capabilities.minImageCount, max_frames_rendering_at_once);
            if (self.impl.surface_capabilities.maxImageCount > 0) {
                self.impl.image_count = std.math.min(self.impl.image_count, self.impl.surface_capabilities.maxImageCount);
            }
        }
        // createSwapchain()
        {
            const same_family = self.isSameQueueFamily();
            try vkCheck(c.vkCreateSwapchainKHR(self.impl.device, &zi(c.VkSwapchainCreateInfoKHR, .{
                .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
                .surface = self.impl.surface,
                .minImageCount = self.impl.image_count,
                .imageFormat = self.impl.surface_format.format,
                .imageColorSpace = self.impl.surface_format.colorSpace,
                .imageExtent = self.impl.surface_capabilities.currentExtent,
                .imageArrayLayers = 1,
                .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
                .imageSharingMode = if (same_family) @as(c.VkSharingMode, c.VK_SHARING_MODE_EXCLUSIVE) else @as(c.VkSharingMode, c.VK_SHARING_MODE_CONCURRENT),
                .queueFamilyIndexCount = if (same_family) @as(u32, 0) else @as(u32, 2),
                .pQueueFamilyIndices = &[_]u32{ self.impl.graphics_queue_family_index, self.impl.present_queue_family_index },
                .preTransform = c.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
                .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
                .presentMode = self.impl.surface_present_mode,
                .clipped = c.VK_TRUE,
                .oldSwapchain = @ptrCast(c.VkSwapchainKHR, c.VK_NULL_HANDLE),
            }), null, &self.impl.swapchain));
        }
        // getSwapchainImageAndFinalImageCount()
        {
            try vkCheck(c.vkGetSwapchainImagesKHR(self.impl.device, self.impl.swapchain, &self.impl.image_count, null));
            std.debug.assert(self.impl.image_count > 0 and self.impl.image_count < max_swapchain_images);
            try vkCheck(c.vkGetSwapchainImagesKHR(self.impl.device, self.impl.swapchain, &self.impl.image_count, &self.impl.swapchain_images));
            std.debug.print("Swapchain(image_count={})\n", .{self.impl.image_count});
        }
        // createImageViews()
        {
            var i: usize = 0;
            while (i < self.impl.image_count) : (i += 1) {
                try vkCheck(c.vkCreateImageView(self.impl.device, &zi(c.VkImageViewCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                    .image = self.impl.swapchain_images[i],
                    .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
                    .format = self.impl.surface_format.format,
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
                }), null, &self.impl.swapchain_image_views[i]));
            }
        }
        // createDepthBuffer()
        {
            self.impl.depth_buffer = try Image.create(&self.impl, c.VK_FORMAT_D32_SFLOAT, c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT, .{
                .width = self.impl.surface_capabilities.currentExtent.width,
                .height = self.impl.surface_capabilities.currentExtent.height,
                .depth = 1,
            }, c.VK_IMAGE_ASPECT_DEPTH_BIT, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
        }
        // createFramebuffers()
        {
            var i: usize = 0;
            while (i < self.impl.image_count) : (i += 1) {
                try vkCheck(c.vkCreateFramebuffer(self.impl.device, &zi(c.VkFramebufferCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                    .renderPass = self.impl.render_pass,
                    .attachmentCount = 2,
                    .pAttachments = &[_]c.VkImageView{
                        self.impl.swapchain_image_views[i],
                        self.impl.depth_buffer.view,
                    },
                    .width = self.impl.surface_capabilities.currentExtent.width,
                    .height = self.impl.surface_capabilities.currentExtent.height,
                    .layers = 1,
                }), null, &self.impl.framebuffers[i]));
            }
        }
    }

    fn swapchain_deinit(self: Renderer) void {
        _ = c.vkDeviceWaitIdle(self.impl.device);
        var i: usize = 0;
        while (i < self.impl.image_count) : (i += 1) {
            c.vkDestroyFramebuffer(self.impl.device, self.impl.framebuffers[i], null);
            c.vkDestroyImageView(self.impl.device, self.impl.swapchain_image_views[i], null);
        }
        self.impl.depth_buffer.destroy();
        c.vkDestroySwapchainKHR(self.impl.device, self.impl.swapchain, null);
    }

    fn swapchain_reinit(self: *Renderer) !void {
        self.swapchain_deinit();
        try self.swapchain_init();
    }

    fn isSameQueueFamily(self: Renderer) bool {
        return self.impl.graphics_queue_family_index == self.impl.present_queue_family_index;
    }

    pub fn appendStaticMesh(self: *Renderer, static_mesh: RenderObject) void {
        self.impl.render_objects.append(static_mesh) catch @panic("ran out of memory :'(");
    }

    pub fn create(window: *const Window, time: *const Time) !Renderer {
        var result = Renderer{
            .window = window,
            .time = time,
        };
        result.impl.current_frame = 0;
        result.impl.render_objects = std.ArrayList(RenderObject).init(std.heap.c_allocator);
        // createInstance()
        {
            const instance_layers = [_][*c]const u8{"VK_LAYER_KHRONOS_validation"};
            const instance_extensions = [_][*c]const u8{ c.VK_KHR_SURFACE_EXTENSION_NAME, c.VK_KHR_XLIB_SURFACE_EXTENSION_NAME };
            try vkCheck(c.vkCreateInstance(&zi(c.VkInstanceCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                .pApplicationInfo = &zi(c.VkApplicationInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
                    .apiVersion = c.VK_API_VERSION_1_0,
                }),
                .enabledLayerCount = instance_layers.len,
                .ppEnabledLayerNames = &instance_layers,
                .enabledExtensionCount = instance_extensions.len,
                .ppEnabledExtensionNames = &instance_extensions,
            }), null, &result.impl.instance));
        }
        // selectPhysicalDevice()
        {
            var count: u32 = 1;
            try vkCheck(c.vkEnumeratePhysicalDevices(result.impl.instance, &count, &result.impl.physical_device));
            std.debug.assert(count == 1);
        }
        // getPhysicalDeviceInfo()
        {
            c.vkGetPhysicalDeviceMemoryProperties(result.impl.physical_device, &result.impl.physical_device_memory_properties);
            c.vkGetPhysicalDeviceProperties(result.impl.physical_device, &result.impl.physical_device_properties);
            const v = result.impl.physical_device_properties;
            std.debug.print("{s} (Vulkan {}.{}.{})\n", .{ v.deviceName, (v.apiVersion >> 22) & 0x7F, (v.apiVersion >> 12) & 0x3F, (v.apiVersion) & 0xFFF });
        }
        // createSurface()
        switch (platform.window_lib) {
            .xlib => try vkCheck(c.vkCreateXlibSurfaceKHR(result.impl.instance, &zi(c.VkXlibSurfaceCreateInfoKHR, .{
                .sType = c.VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
                .dpy = window.impl.dpy,
                .window = window.impl.win,
            }), null, &result.impl.surface)),
            else => std.debug.print("Windowing system not supported by Vulkan\n", .{}),
        }
        // selectSurfaceFormat()
        result.impl.surface_format = blk: {
            const max_count = 128;
            var count: u32 = max_count;
            var formats: [max_count]c.VkSurfaceFormatKHR = undefined;
            try vkCheck(c.vkGetPhysicalDeviceSurfaceFormatsKHR(result.impl.physical_device, result.impl.surface, &count, &formats));
            std.debug.assert(count > 0);

            const preferred_format = c.VK_FORMAT_B8G8R8A8_UNORM;
            const preferred_color_space = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR;
            if (count == 1 and formats[0].format == c.VK_FORMAT_UNDEFINED)
                break :blk .{ .format = preferred_format, .colorSpace = preferred_color_space };
            for (formats[0..count]) |format| {
                if (format.format == preferred_format and format.colorSpace == preferred_color_space) {
                    break :blk format;
                }
            }
            break :blk formats[0];
        };
        result.impl.surface_present_mode = blk: {
            const max_count = 128;
            var count: u32 = max_count;
            var present_modes: [max_count]c.VkPresentModeKHR = undefined;
            try vkCheck(c.vkGetPhysicalDeviceSurfacePresentModesKHR(result.impl.physical_device, result.impl.surface, &count, &present_modes));
            std.debug.assert(count > 0);

            const preferred_present_mode = c.VK_PRESENT_MODE_MAILBOX_KHR;
            for (present_modes[0..count]) |present_mode| {
                if (present_mode == preferred_present_mode) {
                    break :blk present_mode;
                }
            }
            break :blk c.VK_PRESENT_MODE_FIFO_KHR;
        };
        // findQueueFamilies()
        {
            const max_count = 128;
            var count: u32 = max_count;
            var queue_families: [max_count]c.VkQueueFamilyProperties = undefined;
            c.vkGetPhysicalDeviceQueueFamilyProperties(result.impl.physical_device, &count, &queue_families);
            std.debug.assert(count > 0);

            result.impl.graphics_queue_family_index = blk: {
                for (queue_families[0..count]) |queue_family, i| {
                    if (queue_family.queueCount == 0) continue;
                    if ((queue_family.queueFlags & c.VK_QUEUE_GRAPHICS_BIT) > 0)
                        break :blk @intCast(u32, i);
                }
                return error.QueueNotFound;
            };

            result.impl.present_queue_family_index = blk: {
                for (queue_families[0..count]) |queue_family, i| {
                    if (queue_family.queueCount == 0) continue;
                    var present_supported: c.VkBool32 = c.VK_FALSE;
                    try vkCheck(c.vkGetPhysicalDeviceSurfaceSupportKHR(result.impl.physical_device, @intCast(u32, i), result.impl.surface, &present_supported));
                    if (present_supported == c.VK_TRUE)
                        break :blk @intCast(u32, i);
                }
                return error.QueueNotFound;
            };
        }
        // createDevice()
        {
            const device_extensions = [_][*c]const u8{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME};
            try vkCheck(c.vkCreateDevice(result.impl.physical_device, &zi(c.VkDeviceCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                .queueCreateInfoCount = if (result.isSameQueueFamily()) @as(u32, 1) else @as(u32, 2),
                .pQueueCreateInfos = &[_]c.VkDeviceQueueCreateInfo{
                    zi(c.VkDeviceQueueCreateInfo, .{
                        .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                        .queueFamilyIndex = result.impl.graphics_queue_family_index,
                        .queueCount = 1,
                        .pQueuePriorities = &[_]f32{1.0},
                    }),
                    zi(c.VkDeviceQueueCreateInfo, .{
                        .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                        .queueFamilyIndex = result.impl.graphics_queue_family_index,
                        .queueCount = 1,
                        .pQueuePriorities = &[_]f32{1.0},
                    }),
                },
                .pEnabledFeatures = &zi(c.VkPhysicalDeviceFeatures, .{}),
                .enabledExtensionCount = device_extensions.len,
                .ppEnabledExtensionNames = &device_extensions,
            }), null, &result.impl.device));
        }
        // getQueueHandles()
        {
            c.vkGetDeviceQueue(result.impl.device, result.impl.graphics_queue_family_index, 0, &result.impl.graphics_queue);
            c.vkGetDeviceQueue(result.impl.device, result.impl.present_queue_family_index, 0, &result.impl.present_queue);
        }
        // createCommandPool()
        {
            try vkCheck(c.vkCreateCommandPool(result.impl.device, &zi(c.VkCommandPoolCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
                .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
                .queueFamilyIndex = result.impl.graphics_queue_family_index,
            }), null, &result.impl.graphics_command_pool));
        }
        // createCommandBuffers()
        {
            try vkCheck(c.vkAllocateCommandBuffers(result.impl.device, &zi(c.VkCommandBufferAllocateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
                .commandPool = result.impl.graphics_command_pool,
                .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
                .commandBufferCount = max_frames_rendering_at_once,
            }), &result.impl.graphics_command_buffers));
        }
        // createSyncObjects()
        {
            var i: usize = 0;
            const semaphore_create_info = zi(c.VkSemaphoreCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
            });
            const fence_create_info = zi(c.VkFenceCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
                .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
            });
            while (i < max_frames_rendering_at_once) : (i += 1) {
                try vkCheck(c.vkCreateSemaphore(result.impl.device, &semaphore_create_info, null, &result.impl.image_acquired_semaphores[i]));
                try vkCheck(c.vkCreateSemaphore(result.impl.device, &semaphore_create_info, null, &result.impl.image_written_semaphores[i]));
                try vkCheck(c.vkCreateFence(result.impl.device, &fence_create_info, null, &result.impl.currently_rendering_fences[i]));
            }
        }
        // createRenderPass()
        {
            try vkCheck(c.vkCreateRenderPass(result.impl.device, &zi(c.VkRenderPassCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
                .attachmentCount = 2,
                .pAttachments = &[_]c.VkAttachmentDescription{
                    zi(c.VkAttachmentDescription, .{
                        .format = result.impl.surface_format.format,
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
            }), null, &result.impl.render_pass));
        }
        // createShaders()
        var shader_module: c.VkShaderModule = undefined;
        {
            const code = @alignCast(4, @embedFile("shaders/mesh.spv"));
            try vkCheck(c.vkCreateShaderModule(result.impl.device, &zi(c.VkShaderModuleCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                .codeSize = code.len,
                .pCode = @ptrCast(*const u32, code),
            }), null, &shader_module));
        }
        defer c.vkDestroyShaderModule(result.impl.device, shader_module, null);
        // createGraphicsPipelineLayout()
        {
            try vkCheck(c.vkCreatePipelineLayout(result.impl.device, &zi(c.VkPipelineLayoutCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
                .pushConstantRangeCount = 1,
                .pPushConstantRanges = &zi(c.VkPushConstantRange, .{
                    .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
                    .offset = 0,
                    .size = @sizeOf(MeshPushConstants),
                }),
            }), null, &result.impl.mesh_graphics_pipeline_layout));
        }
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
            const topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
            const polygon_mode = c.VK_POLYGON_MODE_FILL;
            const layout = result.impl.mesh_graphics_pipeline_layout;
            const desc = comptime VertexInputDescription(Vertex).init();
            try vkCheck(c.vkCreateGraphicsPipelines(result.impl.device, null, 1, &zi(c.VkGraphicsPipelineCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
                .stageCount = stages.len,
                .pStages = &stages,
                .pVertexInputState = &zi(c.VkPipelineVertexInputStateCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
                    .vertexBindingDescriptionCount = @intCast(u32, desc.bindings.len),
                    .pVertexBindingDescriptions = &desc.bindings,
                    .vertexAttributeDescriptionCount = @intCast(u32, desc.attributes.len),
                    .pVertexAttributeDescriptions = &desc.attributes,
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
                .renderPass = result.impl.render_pass,
                .subpass = 0,
            }), null, &result.impl.mesh_graphics_pipeline));
        }

        result.impl.mesh_to_gpudata_map = comptime std.EnumArray(Mesh, VulkanMesh).initUndefined();
        inline for (@typeInfo(Mesh).Enum.fields) |field| {
            result.impl.mesh_to_gpudata_map.set(@field(Mesh, field.name), try VulkanMesh.create(&result.impl, comptime try parseObj(@field(Mesh, field.name))));
        }

        try result.swapchain_init();

        return result;
    }

    fn recordBuffer(self: *Renderer, buffer: c.VkCommandBuffer, image_index: u32) !void {
        try vkCheck(c.vkBeginCommandBuffer(buffer, &zi(c.VkCommandBufferBeginInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        })));
        c.vkCmdBeginRenderPass(buffer, &zi(c.VkRenderPassBeginInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = self.impl.render_pass,
            .framebuffer = self.impl.framebuffers[image_index],
            .renderArea = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = self.impl.surface_capabilities.currentExtent,
            },
            .clearValueCount = 2,
            .pClearValues = &[_]c.VkClearValue{
                .{ .color = .{ .float32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 } } },
                .{ .depthStencil = .{ .depth = 1.0, .stencil = 0 } },
            },
        }), c.VK_SUBPASS_CONTENTS_INLINE);
        c.vkCmdBindPipeline(buffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.impl.mesh_graphics_pipeline);
        c.vkCmdSetViewport(buffer, 0, 1, &zi(c.VkViewport, .{
            .x = 0.0,
            .y = 0.0,
            .width = @intToFloat(f32, self.impl.surface_capabilities.currentExtent.width),
            .height = @intToFloat(f32, self.impl.surface_capabilities.currentExtent.height),
            .minDepth = 1.0,
            .maxDepth = 0.0,
        }));
        c.vkCmdSetScissor(buffer, 0, 1, &zi(c.VkRect2D, .{
            .offset = .{ .x = 0, .y = 0 },
            .extent = self.impl.surface_capabilities.currentExtent,
        }));
        // NOTE: we could choose to only update vp when view or projection changes but it's likely view will change every frame during actual gameplay
        const vp = self.projection.mul(self.view);
        for (self.impl.render_objects.items) |object| {
            c.vkCmdPushConstants(buffer, self.impl.mesh_graphics_pipeline_layout, c.VK_SHADER_STAGE_VERTEX_BIT, 0, @sizeOf(MeshPushConstants), &zi(MeshPushConstants, .{
                .mvp = vp.mul(object.transform),
            }));
            const gpumesh = self.impl.mesh_to_gpudata_map.get(object.mesh);
            c.vkCmdBindVertexBuffers(buffer, 0, 1, &gpumesh.buffer.buffer, &[_]c.VkDeviceSize{0});
            c.vkCmdDraw(buffer, gpumesh.draw_count, 1, 0, 0);
        }
        c.vkCmdEndRenderPass(buffer);
        try vkCheck(c.vkEndCommandBuffer(buffer));
    }

    pub fn update(self: *Renderer) !void {
        try vkCheck(c.vkWaitForFences(self.impl.device, 1, &self.impl.currently_rendering_fences[self.impl.current_frame], c.VK_TRUE, std.math.maxInt(u64)));
        var image_index: u32 = undefined;
        var result = c.vkAcquireNextImageKHR(self.impl.device, self.impl.swapchain, std.math.maxInt(u64), self.impl.image_acquired_semaphores[self.impl.current_frame], @ptrCast(c.VkFence, c.VK_NULL_HANDLE), &image_index);
        switch (result) {
            c.VK_ERROR_OUT_OF_DATE_KHR => return try self.swapchain_reinit(),
            c.VK_SUCCESS, c.VK_SUBOPTIMAL_KHR => {},
            else => std.debug.panic("vkAcquireNextImageKHR", .{}),
        }
        try vkCheck(c.vkResetFences(self.impl.device, 1, &self.impl.currently_rendering_fences[self.impl.current_frame]));
        try self.recordBuffer(self.impl.graphics_command_buffers[self.impl.current_frame], image_index);
        try vkCheck(c.vkQueueSubmit(self.impl.graphics_queue, 1, &zi(c.VkSubmitInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &self.impl.image_acquired_semaphores[self.impl.current_frame],
            .pWaitDstStageMask = &[_]c.VkPipelineStageFlags{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT},
            .commandBufferCount = 1,
            .pCommandBuffers = &self.impl.graphics_command_buffers[self.impl.current_frame],
            .signalSemaphoreCount = 1,
            .pSignalSemaphores = &self.impl.image_written_semaphores[self.impl.current_frame],
        }), self.impl.currently_rendering_fences[self.impl.current_frame]));
        result = c.vkQueuePresentKHR(self.impl.present_queue, &zi(c.VkPresentInfoKHR, .{
            .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &self.impl.image_written_semaphores[self.impl.current_frame],
            .swapchainCount = 1,
            .pSwapchains = &self.impl.swapchain,
            .pImageIndices = &image_index,
        }));
        switch (result) {
            c.VK_ERROR_OUT_OF_DATE_KHR, c.VK_SUBOPTIMAL_KHR => try self.swapchain_reinit(),
            c.VK_SUCCESS => {},
            else => std.debug.panic("vkQueuePresentKHR", .{}),
        }
        self.impl.current_frame = (self.impl.current_frame + 1) % max_frames_rendering_at_once;
    }

    pub fn destroy(self: Renderer) void {
        swapchain_deinit(self);
        self.impl.render_objects.deinit();
        inline for (@typeInfo(Mesh).Enum.fields) |field| {
            self.impl.mesh_to_gpudata_map.get(@field(Mesh, field.name)).destroy();
        }
        c.vkDestroyPipeline(self.impl.device, self.impl.mesh_graphics_pipeline, null);
        c.vkDestroyPipelineLayout(self.impl.device, self.impl.mesh_graphics_pipeline_layout, null);
        c.vkDestroyRenderPass(self.impl.device, self.impl.render_pass, null);
        var i: usize = 0;
        while (i < max_frames_rendering_at_once) : (i += 1) {
            c.vkDestroyFence(self.impl.device, self.impl.currently_rendering_fences[i], null);
            c.vkDestroySemaphore(self.impl.device, self.impl.image_written_semaphores[i], null);
            c.vkDestroySemaphore(self.impl.device, self.impl.image_acquired_semaphores[i], null);
        }
        c.vkDestroyCommandPool(self.impl.device, self.impl.graphics_command_pool, null);
        c.vkDestroyDevice(self.impl.device, null);
        c.vkDestroySurfaceKHR(self.impl.instance, self.impl.surface, null);
        c.vkDestroyInstance(self.impl.instance, null);
    }
};
