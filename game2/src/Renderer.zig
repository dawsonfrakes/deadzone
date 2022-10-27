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

pub fn update(self: *Renderer) !void {
    try self.impl.update();
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

    fn update(self: *Impl) !void {
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

    current_frame: u32,

    // temporary
    triangle_graphics_pipeline_layout: c.VkPipelineLayout,
    triangle_graphics_pipeline: c.VkPipeline,

    const zi = std.mem.zeroInit;

    const Vertex = struct {
        position: @Vector(3, f32),
        normal: @Vector(3, f32),
        color: @Vector(3, f32),

        const VertexInputDescription = struct {
            bindings: []c.VkVertexInputBindingDescription,
            attributes: []c.VkVertexInputAttributeDescription
        };

        fn getDescription() !VertexInputDescription {
            var bindings = std.ArrayList(c.VkVertexInputBindingDescription).init(std.heap.c_allocator);
            var attributes = std.ArrayList(c.VkVertexInputAttributeDescription).init(std.heap.c_allocator);
            try bindings.append(zi(c.VkVertexInputBindingDescription, .{
                .binding = 0,
                .stride = @sizeOf(Vertex),
                .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX
            }));
            try attributes.append(zi(c.VkVertexInputAttributeDescription, .{
                .binding = 0,
                .location = 0,
                .format = c.VK_FORMAT_R32G32B32_SFLOAT,
                .offset = @offsetOf(Vertex, "position")
            }));
            try attributes.append(zi(c.VkVertexInputAttributeDescription, .{
                .binding = 0,
                .location = 1,
                .format = c.VK_FORMAT_R32G32B32_SFLOAT,
                .offset = @offsetOf(Vertex, "normal")
            }));
            try attributes.append(zi(c.VkVertexInputAttributeDescription, .{
                .binding = 0,
                .location = 2,
                .format = c.VK_FORMAT_R32G32B32_SFLOAT,
                .offset = @offsetOf(Vertex, "color")
            }));
            return VertexInputDescription{
                .bindings = bindings.toOwnedSlice(),
                .attributes = attributes.toOwnedSlice()
            };
        }
    };

    fn vkCheck(result: c.VkResult) !void {
        if (result != c.VK_SUCCESS) {
            std.debug.print("VkResult({})\n", .{result});
            return error.VkError;
        }
    }

    fn swapchain_init(self: *VulkanRendererImpl) !void {
        // getSurfaceInfo()
        {
            try vkCheck(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(self.physical_device, self.surface, &self.surface_capabilities));
        }
        // getMinimumImageCount()
        {
            self.image_count = std.math.max(self.surface_capabilities.minImageCount, max_frames_rendering_at_once);
            if (self.surface_capabilities.maxImageCount > 0) {
                self.image_count = std.math.min(self.image_count, self.surface_capabilities.maxImageCount);
            }
        }
        // createSwapchain()
        {
            const same_family = self.isSameQueueFamily();
            try vkCheck(c.vkCreateSwapchainKHR(self.device, &zi(c.VkSwapchainCreateInfoKHR, .{
                .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
                .surface = self.surface,
                .minImageCount = self.image_count,
                .imageFormat = self.surface_format.format,
                .imageColorSpace = self.surface_format.colorSpace,
                .imageExtent = self.surface_capabilities.currentExtent,
                .imageArrayLayers = 1,
                .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
                .imageSharingMode = if (same_family) @as(c.VkSharingMode, c.VK_SHARING_MODE_EXCLUSIVE) else @as(c.VkSharingMode, c.VK_SHARING_MODE_CONCURRENT),
                .queueFamilyIndexCount = if (same_family) @as(u32, 0) else @as(u32, 2),
                .pQueueFamilyIndices = &[_]u32{self.graphics_queue_family_index, self.present_queue_family_index},
                .preTransform = c.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
                .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
                .presentMode = self.surface_present_mode,
                .clipped = c.VK_TRUE,
                .oldSwapchain = @ptrCast(c.VkSwapchainKHR, c.VK_NULL_HANDLE)
            }), null, &self.swapchain));
        }
        // getSwapchainImageAndFinalImageCount()
        {
            try vkCheck(c.vkGetSwapchainImagesKHR(self.device, self.swapchain, &self.image_count, null));
            std.debug.assert(self.image_count > 0 and self.image_count < max_swapchain_images);
            try vkCheck(c.vkGetSwapchainImagesKHR(self.device, self.swapchain, &self.image_count, &self.swapchain_images));
            std.debug.print("Swapchain(image_count={})\n", .{self.image_count});
        }
        // createImageViews()
        {
            var i: usize = 0;
            while (i < self.image_count) : (i += 1) {
                try vkCheck(c.vkCreateImageView(self.device, &zi(c.VkImageViewCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                    .image = self.swapchain_images[i],
                    .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
                    .format = self.surface_format.format,
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
                        .layerCount = 1
                    }
                }), null, &self.swapchain_image_views[i]));
            }
        }
        // createFramebuffers()
        {
            var i: usize = 0;
            while (i < self.image_count) : (i += 1) {
                try vkCheck(c.vkCreateFramebuffer(self.device, &zi(c.VkFramebufferCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                    .renderPass = self.render_pass,
                    .attachmentCount = 1,
                    .pAttachments = &self.swapchain_image_views[i],
                    .width = self.surface_capabilities.currentExtent.width,
                    .height = self.surface_capabilities.currentExtent.height,
                    .layers = 1
                }), null, &self.framebuffers[i]));
            }
        }
    }

    fn swapchain_deinit(self: VulkanRendererImpl) void {
        _ = c.vkDeviceWaitIdle(self.device);
        var i: usize = 0;
        while (i < self.image_count) : (i += 1) {
            c.vkDestroyFramebuffer(self.device, self.framebuffers[i], null);
            c.vkDestroyImageView(self.device, self.swapchain_image_views[i], null);
        }
        c.vkDestroySwapchainKHR(self.device, self.swapchain, null);
    }

    fn swapchain_reinit(self: *VulkanRendererImpl) !void {
        self.swapchain_deinit();
        try self.swapchain_init();
    }

    fn isSameQueueFamily(self: VulkanRendererImpl) bool {
        return self.graphics_queue_family_index == self.present_queue_family_index;
    }

    fn create(config: CreateConfig) !VulkanRendererImpl {
        var result: VulkanRendererImpl = undefined;
        result.current_frame = 0;
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
            try vkCheck(c.vkCreateDevice(result.physical_device, &zi(c.VkDeviceCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                .queueCreateInfoCount = if (result.isSameQueueFamily()) @as(u32, 1) else @as(u32, 2),
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
                .commandBufferCount = max_frames_rendering_at_once
            }), &result.graphics_command_buffers));
        }
        // createSyncObjects()
        {
            var i: usize = 0;
            const semaphore_create_info = zi(c.VkSemaphoreCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
            });
            const fence_create_info = zi(c.VkFenceCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
                .flags = c.VK_FENCE_CREATE_SIGNALED_BIT
            });
            while (i < max_frames_rendering_at_once) : (i += 1) {
                try vkCheck(c.vkCreateSemaphore(result.device, &semaphore_create_info, null, &result.image_acquired_semaphores[i]));
                try vkCheck(c.vkCreateSemaphore(result.device, &semaphore_create_info, null, &result.image_written_semaphores[i]));
                try vkCheck(c.vkCreateFence(result.device, &fence_create_info, null, &result.currently_rendering_fences[i]));
            }
        }
        // createRenderPass()
        {
            try vkCheck(c.vkCreateRenderPass(result.device, &zi(c.VkRenderPassCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
                .attachmentCount = 1,
                .pAttachments = &zi(c.VkAttachmentDescription, .{
                    .format = result.surface_format.format,
                    .samples = c.VK_SAMPLE_COUNT_1_BIT,
                    .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
                    .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
                    .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
                    .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
                    .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
                    .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
                }),
                .subpassCount = 1,
                .pSubpasses = &zi(c.VkSubpassDescription, .{
                    .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
                    .colorAttachmentCount = 1,
                    .pColorAttachments = &zi(c.VkAttachmentReference, .{
                        .attachment = 0,
                        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
                    }),
                }),
                .dependencyCount = 1,
                .pDependencies = &zi(c.VkSubpassDependency, .{
                    .srcSubpass = c.VK_SUBPASS_EXTERNAL,
                    .dstSubpass = 0,
                    .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                    .srcAccessMask = 0,
                    .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                    .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT
                })
            }), null, &result.render_pass));
        }
        var vertex_shader_module: c.VkShaderModule = undefined;
        var fragment_shader_module: c.VkShaderModule = undefined;
        // createShaders()
        {
            const vertex_shader_code = @alignCast(4, @embedFile("shaders/mesh.vert.spv"));
            try vkCheck(c.vkCreateShaderModule(result.device, &zi(c.VkShaderModuleCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                .codeSize = vertex_shader_code.len,
                .pCode = @ptrCast(*const u32, vertex_shader_code)
            }), null, &vertex_shader_module));

            const fragment_shader_code = @alignCast(4, @embedFile("shaders/mesh.frag.spv"));
            try vkCheck(c.vkCreateShaderModule(result.device, &zi(c.VkShaderModuleCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                .codeSize = fragment_shader_code.len,
                .pCode = @ptrCast(*const u32, fragment_shader_code),
            }), null, &fragment_shader_module));
        }
        defer c.vkDestroyShaderModule(result.device, vertex_shader_module, null);
        defer c.vkDestroyShaderModule(result.device, fragment_shader_module, null);
        // createGraphicsPipelineLayout()
        {
            try vkCheck(c.vkCreatePipelineLayout(result.device, &zi(c.VkPipelineLayoutCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
            }), null, &result.triangle_graphics_pipeline_layout));
        }
        // createGraphicsPipeline()
        {
            const stages = [_]c.VkPipelineShaderStageCreateInfo{
                zi(c.VkPipelineShaderStageCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                    .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
                    .module = vertex_shader_module,
                    .pName = "main"
                }),
                zi(c.VkPipelineShaderStageCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                    .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
                    .module = fragment_shader_module,
                    .pName = "main"
                })
            };
            const topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
            const polygon_mode = c.VK_POLYGON_MODE_FILL;
            const layout = result.triangle_graphics_pipeline_layout;
            const desc = try Vertex.getDescription();
            try vkCheck(c.vkCreateGraphicsPipelines(result.device, null, 1, &zi(c.VkGraphicsPipelineCreateInfo, .{
                .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
                .stageCount = stages.len,
                .pStages = &stages,
                .pVertexInputState = &zi(c.VkPipelineVertexInputStateCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
                    .vertexBindingDescriptionCount = @intCast(u32, desc.bindings.len),
                    .pVertexBindingDescriptions = desc.bindings.ptr,
                    .vertexAttributeDescriptionCount = @intCast(u32, desc.attributes.len),
                    .pVertexAttributeDescriptions = desc.attributes.ptr
                }),
                .pInputAssemblyState = &zi(c.VkPipelineInputAssemblyStateCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
                    .topology = topology
                }),
                .pViewportState = &zi(c.VkPipelineViewportStateCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
                    .viewportCount = 1,
                    .scissorCount = 1
                }),
                .pRasterizationState = &zi(c.VkPipelineRasterizationStateCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
                    .polygonMode = polygon_mode,
                    .cullMode = c.VK_CULL_MODE_BACK_BIT,
                    .frontFace = c.VK_FRONT_FACE_CLOCKWISE,
                    .lineWidth = 1.0
                }),
                .pMultisampleState = &zi(c.VkPipelineMultisampleStateCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
                    .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT
                }),
                .pColorBlendState = &zi(c.VkPipelineColorBlendStateCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
                    .attachmentCount = 1,
                    .pAttachments = &zi(c.VkPipelineColorBlendAttachmentState, .{
                        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT|c.VK_COLOR_COMPONENT_G_BIT|c.VK_COLOR_COMPONENT_B_BIT|c.VK_COLOR_COMPONENT_A_BIT
                    })
                }),
                .pDynamicState = &zi(c.VkPipelineDynamicStateCreateInfo, .{
                    .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
                    .dynamicStateCount = 2,
                    .pDynamicStates = &[_]c.VkDynamicState{c.VK_DYNAMIC_STATE_VIEWPORT, c.VK_DYNAMIC_STATE_SCISSOR}
                }),
                .layout = layout,
                .renderPass = result.render_pass,
                .subpass = 0
            }), null, &result.triangle_graphics_pipeline));
        }

        try result.swapchain_init();

        return result;
    }

    fn recordBuffer(self: *VulkanRendererImpl, buffer: c.VkCommandBuffer, image_index: u32) !void {
        try vkCheck(c.vkBeginCommandBuffer(buffer, &zi(c.VkCommandBufferBeginInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT
        })));
        c.vkCmdBeginRenderPass(buffer, &zi(c.VkRenderPassBeginInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = self.render_pass,
            .framebuffer = self.framebuffers[image_index],
            .renderArea = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = self.surface_capabilities.currentExtent
            },
            .clearValueCount = 1,
            .pClearValues = &c.VkClearValue{.color = .{.float32 = [_]f32{1.0, 0.0, 1.0, 1.0}}}
        }), c.VK_SUBPASS_CONTENTS_INLINE);
        c.vkCmdBindPipeline(buffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.triangle_graphics_pipeline);
        c.vkCmdSetViewport(buffer, 0, 1, &zi(c.VkViewport, .{
            .x = 0.0,
            .y = 0.0,
            .width = @intToFloat(f32, self.surface_capabilities.currentExtent.width),
            .height = @intToFloat(f32, self.surface_capabilities.currentExtent.height),
            .minDepth = 0.0,
            .maxDepth = 1.0
        }));
        c.vkCmdSetScissor(buffer, 0, 1, &zi(c.VkRect2D, .{
            .offset = .{ .x = 0, .y = 0 },
            .extent = self.surface_capabilities.currentExtent
        }));
        // c.vkCmdBindVertexBuffers(buffer, 0, 1, &self.triangle_mesh.buffer, &[_]c.VkDeviceSize{0});
        // c.vkCmdDraw(buffer, self.triangle_mesh.vertices.len, 1, 0, 0);
        c.vkCmdEndRenderPass(buffer);
        try vkCheck(c.vkEndCommandBuffer(buffer));
    }

    fn update(self: *VulkanRendererImpl) !void {
        try vkCheck(c.vkWaitForFences(self.device, 1, &self.currently_rendering_fences[self.current_frame], c.VK_TRUE, std.math.maxInt(u64)));
        var image_index: u32 = undefined;
        var result = c.vkAcquireNextImageKHR(self.device, self.swapchain, std.math.maxInt(u64), self.image_acquired_semaphores[self.current_frame], @ptrCast(c.VkFence, c.VK_NULL_HANDLE), &image_index);
        switch (result) {
            c.VK_ERROR_OUT_OF_DATE_KHR => return try self.swapchain_reinit(),
            c.VK_SUCCESS, c.VK_SUBOPTIMAL_KHR => {},
            else => @panic("vkAcquireNextImageKHR"),
        }
        try vkCheck(c.vkResetFences(self.device, 1, &self.currently_rendering_fences[self.current_frame]));
        try self.recordBuffer(self.graphics_command_buffers[self.current_frame], image_index);
        try vkCheck(c.vkQueueSubmit(self.graphics_queue, 1, &zi(c.VkSubmitInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &self.image_acquired_semaphores[self.current_frame],
            .pWaitDstStageMask = &[_]c.VkPipelineStageFlags{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT},
            .commandBufferCount = 1,
            .pCommandBuffers = &self.graphics_command_buffers[self.current_frame],
            .signalSemaphoreCount = 1,
            .pSignalSemaphores = &self.image_written_semaphores[self.current_frame]
        }), self.currently_rendering_fences[self.current_frame]));
        result = c.vkQueuePresentKHR(self.present_queue, &zi(c.VkPresentInfoKHR, .{
            .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &self.image_written_semaphores[self.current_frame],
            .swapchainCount = 1,
            .pSwapchains = &self.swapchain,
            .pImageIndices = &image_index
        }));
        switch (result) {
            c.VK_ERROR_OUT_OF_DATE_KHR, c.VK_SUBOPTIMAL_KHR => try self.swapchain_reinit(),
            c.VK_SUCCESS => {},
            else => @panic("vkQueuePresentKHR"),
        }
        self.current_frame = (self.current_frame + 1) % max_frames_rendering_at_once;
    }

    fn destroy(self: VulkanRendererImpl) void {
        swapchain_deinit(self);
        c.vkDestroyPipeline(self.device, self.triangle_graphics_pipeline, null);
        c.vkDestroyPipelineLayout(self.device, self.triangle_graphics_pipeline_layout, null);
        c.vkDestroyRenderPass(self.device, self.render_pass, null);
        var i: usize = 0;
        while (i < max_frames_rendering_at_once) : (i += 1) {
            c.vkDestroyFence(self.device, self.currently_rendering_fences[i], null);
            c.vkDestroySemaphore(self.device, self.image_written_semaphores[i], null);
            c.vkDestroySemaphore(self.device, self.image_acquired_semaphores[i], null);
        }
        c.vkDestroyCommandPool(self.device, self.graphics_command_pool, null);
        c.vkDestroyDevice(self.device, null);
        c.vkDestroySurfaceKHR(self.instance, self.surface, null);
        c.vkDestroyInstance(self.instance, null);
    }
};
