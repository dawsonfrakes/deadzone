const std = @import("std");
const platform = @import("platform.zig");
const c = @import("c.zig");
const Window = @import("Window.zig");

const Renderer = @This();
const Impl = switch (platform.RENDER_LIBRARY) {
    .vulkan => VulkanRendererImpl,
};

impl: Impl,

pub const CreateConfig = struct {
    window: *const Window,
};

pub fn create(config: CreateConfig) !Renderer {
    const impl = try Impl.create(config);
    return Renderer{ .impl = impl };
}

pub fn update(self: *Renderer) ?void {
    return self.impl.update();
}

pub fn destroy(self: Renderer) void {
    return self.impl.destroy();
}

/// We can't compile error in the `Impl` switch statement as its eagerly evaluated.
/// So instead, we compile-error on the methods themselves for platforms which don't support rendering.
const UnsupportedImpl = struct {
    fn create(config: CreateConfig) !Impl {
        return unsupported(config);
    }

    fn update(self: *Impl) ?void {
        return unsupported(self);
    }

    fn destroy(self: Impl) void {
        return unsupported(self);
    }

    fn unsupported(unusued: anytype) noreturn {
        @compileLog("Unsupported operating system", platform.RENDER_LIBRARY);
        _ = unusued;
        unreachable;
    }
};

const VulkanRendererImpl = struct {
    const max_frames_in_render_queue = 2;

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
    graphics_command_buffers: [max_frames_in_render_queue]c.VkCommandBuffer,

    fn vkCheck(result: c.VkResult) !void {
        if (result != c.VK_SUCCESS) {
            std.debug.print("VkResult({})\n", .{result});
            return error.VkError;
        }
    }

    fn create(config: CreateConfig) !Impl {
        const zi = std.mem.zeroInit;
        var result: VulkanRendererImpl = undefined;
        // createInstance()
        {
            const instance_layers = [_][*c]const u8{"VK_LAYER_KHRONOS_validation"};
            const instance_extensions = [_][*c]const u8{c.VK_KHR_SURFACE_EXTENSION_NAME, c.VK_KHR_XLIB_SURFACE_EXTENSION_NAME};
            try vkCheck(c.vkCreateInstance(&zi(c.VkInstanceCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                .pApplicationInfo = &zi(c.VkApplicationInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
                    .apiVersion = c.VK_API_VERSION_1_0
                }),
                .enabledLayerCount = instance_layers.len,
                .ppEnabledLayerNames = &instance_layers,
                .enabledExtensionCount = instance_extensions.len,
                .ppEnabledExtensionNames = &instance_extensions,
            }), null, &result.instance));
        }
        // selectPhysicalDevice()
        {
            var count: u32 = 1;
            try vkCheck(c.vkEnumeratePhysicalDevices(result.instance, &count, &result.physical_device));
            std.debug.assert(count == 1);
        }
        // getPhysicalDeviceInfo()
        {
            c.vkGetPhysicalDeviceMemoryProperties(result.physical_device, &result.physical_device_memory_properties);
            c.vkGetPhysicalDeviceProperties(result.physical_device, &result.physical_device_properties);
            const v = result.physical_device_properties;
            std.debug.print("{s} (Vulkan {}.{}.{})\n", .{v.deviceName, (v.apiVersion >> 22) & 0x7F, (v.apiVersion >> 12) & 0x3F, (v.apiVersion) & 0xFFF});
        }
        // createSurface()
        switch (platform.WINDOW_LIBRARY) {
            .xlib => try vkCheck(c.vkCreateXlibSurfaceKHR(result.instance, &zi(c.VkXlibSurfaceCreateInfoKHR, .{
                .sType = c.VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
                .dpy = config.window.impl.dpy,
                .window = config.window.impl.win,
            }), null, &result.surface)),
            else => std.debug.print("Windowing system not supported by Vulkan\n", .{}),
        }
        // selectSurfaceFormat()
        result.surface_format = blk: {
            const max_count = 128;
            var count: u32 = max_count;
            var formats: [max_count]c.VkSurfaceFormatKHR = undefined;
            try vkCheck(c.vkGetPhysicalDeviceSurfaceFormatsKHR(result.physical_device, result.surface, &count, &formats));
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
        result.surface_present_mode = blk: {
            const max_count = 128;
            var count: u32 = max_count;
            var present_modes: [max_count]c.VkPresentModeKHR = undefined;
            try vkCheck(c.vkGetPhysicalDeviceSurfacePresentModesKHR(result.physical_device, result.surface, &count, &present_modes));
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
            c.vkGetPhysicalDeviceQueueFamilyProperties(result.physical_device, &count, &queue_families);
            std.debug.assert(count > 0);

            result.graphics_queue_family_index = blk: {
                for (queue_families[0..count]) |queue_family, i| {
                    if (queue_family.queueCount == 0) continue;
                    if ((queue_family.queueFlags & c.VK_QUEUE_GRAPHICS_BIT) > 0)
                        break :blk @intCast(u32, i);
                }
                return error.QueueNotFound;
            };

            result.present_queue_family_index = blk: {
                for (queue_families[0..count]) |queue_family, i| {
                    if (queue_family.queueCount == 0) continue;
                    var present_supported: c.VkBool32 = c.VK_FALSE;
                    try vkCheck(c.vkGetPhysicalDeviceSurfaceSupportKHR(result.physical_device, @intCast(u32, i), result.surface, &present_supported));
                    if (present_supported == c.VK_TRUE)
                        break :blk @intCast(u32, i);
                }
                return error.QueueNotFound;
            };
        }
        // createDevice()
        {
            const device_extensions = [_][*c]const u8{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME};
            const same_queue_family = result.graphics_queue_family_index == result.present_queue_family_index;
            try vkCheck(c.vkCreateDevice(result.physical_device, &zi(c.VkDeviceCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                .queueCreateInfoCount = if (same_queue_family) @as(u32, 1) else @as(u32, 2),
                .pQueueCreateInfos = &[_]c.VkDeviceQueueCreateInfo{
                    zi(c.VkDeviceQueueCreateInfo, .{
                        .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                        .queueFamilyIndex = result.graphics_queue_family_index,
                        .queueCount = 1,
                        .pQueuePriorities = &[_]f32{1.0}
                    }),
                    zi(c.VkDeviceQueueCreateInfo, .{
                        .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                        .queueFamilyIndex = result.graphics_queue_family_index,
                        .queueCount = 1,
                        .pQueuePriorities = &[_]f32{1.0}
                    }),
                },
                .pEnabledFeatures = &zi(c.VkPhysicalDeviceFeatures, .{}),
                .enabledExtensionCount = device_extensions.len,
                .ppEnabledExtensionNames = &device_extensions,
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
        // createCommandBuffers()
        {
            try vkCheck(c.vkAllocateCommandBuffers(result.device, &zi(c.VkCommandBufferAllocateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
                .commandPool = result.graphics_command_pool,
                .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
                .commandBufferCount = max_frames_in_render_queue
            }), &result.graphics_command_buffers));
        }

        return result;
    }

    fn update(self: *Impl) ?void {
        _ = self;
    }

    fn destroy(self: Impl) void {
        c.vkDestroyCommandPool(self.device, self.graphics_command_pool, null);
        c.vkDestroyDevice(self.device, null);
        c.vkDestroySurfaceKHR(self.instance, self.surface, null);
        c.vkDestroyInstance(self.instance, null);
    }
};
