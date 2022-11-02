#include "renderer.h"

#include <stdio.h>
#include <stdlib.h>

#define vkCheck(check) do { if ((check) != VK_SUCCESS) { fprintf(stderr, #check"\n"); abort(); } } while (0)

// PORT
static void swapchain_init(GameRenderer *const renderer)
{
    // getSurfaceInfo()
    {
        vkCheck(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(renderer->physical_device, renderer->surface, &renderer->surface_capabilities));
    }
    // // recalculateProjectionMatrix()
    // {
    //     // TODO: Move this to a Window resize callback/event rather than relying on Vulkan swapchain reinit
    //     renderer->projection = math.Matrix(f32, 4, 4).Perspective(std.math.pi / 2.0, @intToFloat(f32, self.impl.surface_capabilities.currentExtent.width) / @intToFloat(f32, self.impl.surface_capabilities.currentExtent.height), 0.1, 100.0);
    // }
    // getMinimumImageCount()
    {
        renderer->image_count = max(renderer->surface_capabilities.minImageCount, max_frames_rendering_at_once);
        if (renderer->surface_capabilities.maxImageCount > 0) {
            renderer->image_count = min(renderer->image_count, renderer->surface_capabilities.maxImageCount);
        }
    }
    // createSwapchain()
    {
        const b32 same_family = renderer->graphics_queue_family_index == renderer->present_queue_family_index;
        vkCheck(vkCreateSwapchainKHR(renderer->device, &(const VkSwapchainCreateInfoKHR) {
            .sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = renderer->surface,
            .minImageCount = renderer->image_count,
            .imageFormat = renderer->surface_format.format,
            .imageColorSpace = renderer->surface_format.colorSpace,
            .imageExtent = renderer->surface_capabilities.currentExtent,
            .imageArrayLayers = 1,
            .imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = same_family ? VK_SHARING_MODE_EXCLUSIVE : VK_SHARING_MODE_CONCURRENT,
            .queueFamilyIndexCount = same_family ? 0 : 2,
            .pQueueFamilyIndices = (const u32 []) { renderer->graphics_queue_family_index, renderer->present_queue_family_index },
            .preTransform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
            .compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = renderer->surface_present_mode,
            .clipped = VK_TRUE,
            .oldSwapchain = VK_NULL_HANDLE,
        }, null, &renderer->swapchain));
    }
    // getSwapchainImageAndFinalImageCount()
    {
        vkCheck(vkGetSwapchainImagesKHR(renderer->device, renderer->swapchain, &renderer->image_count, null));
        assert(renderer->image_count > 0 && renderer->image_count < max_swapchain_images);
        vkCheck(vkGetSwapchainImagesKHR(renderer->device, renderer->swapchain, &renderer->image_count, renderer->swapchain_images));
        printf("Swapchain(image_count=%d)\n", renderer->image_count);
    }
    // createImageViews()
    {
        for (u32 i = 0; i < renderer->image_count; ++i) {
            vkCheck(vkCreateImageView(renderer->device, &(const VkImageViewCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .image = renderer->swapchain_images[i],
                .viewType = VK_IMAGE_VIEW_TYPE_2D,
                .format = renderer->surface_format.format,
                .components = {
                    .r = VK_COMPONENT_SWIZZLE_IDENTITY,
                    .g = VK_COMPONENT_SWIZZLE_IDENTITY,
                    .b = VK_COMPONENT_SWIZZLE_IDENTITY,
                    .a = VK_COMPONENT_SWIZZLE_IDENTITY,
                },
                .subresourceRange = {
                    .aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                },
            }, null, renderer->swapchain_image_views+i));
        }
    }
    // createDepthBuffer()
    // {
    //     self.impl.depth_buffer = try Image.create(&self.impl, c.VK_FORMAT_D32_SFLOAT, c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT, .{
    //         .width = self.impl.surface_capabilities.currentExtent.width,
    //         .height = self.impl.surface_capabilities.currentExtent.height,
    //         .depth = 1,
    //     }, c.VK_IMAGE_ASPECT_DEPTH_BIT, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
    // }
    // createFramebuffers()
    {
        for (u32 i = 0; i < renderer->image_count; ++i) {
            vkCheck(vkCreateFramebuffer(renderer->device, &(const VkFramebufferCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                .renderPass = renderer->render_pass,
                .attachmentCount = 1,
                .pAttachments = (const VkImageView []) {
                    renderer->swapchain_image_views[i],
                    // renderer->depth_buffer.view,
                },
                .width = renderer->surface_capabilities.currentExtent.width,
                .height = renderer->surface_capabilities.currentExtent.height,
                .layers = 1,
            }, null, renderer->framebuffers+i));
        }
    }
}

static void swapchain_deinit(const GameRenderer *const renderer)
{
    vkDeviceWaitIdle(renderer->device);
    for (u32 i = 0; i < renderer->image_count; ++i) {
        vkDestroyFramebuffer(renderer->device, renderer->framebuffers[i], null);
        vkDestroyImageView(renderer->device, renderer->swapchain_image_views[i], null);
    }
    // renderer->depth_buffer.destroy();
    vkDestroySwapchainKHR(renderer->device, renderer->swapchain, null);
}

static void swapchain_reinit(GameRenderer *const renderer)
{
    swapchain_deinit(renderer);
    swapchain_init(renderer);
}

GameRenderer renderer_init(const GameWindow *const window)
{
    GameRenderer result = {
        .render_objects = ArrayList_init(RenderObject),
    };
    // createInstance()
    {
        const char window_extension[] =
#if (WINDOWING_API == WAPI_XLIB)
            VK_KHR_XLIB_SURFACE_EXTENSION_NAME;
#elif (WINDOWING_API == WAPI_WIN32)
            VK_KHR_WIN32_SURFACE_EXTENSION_NAME;
#else
            null;
#error missing case
#endif
        vkCheck(vkCreateInstance(&(const VkInstanceCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &(const VkApplicationInfo) {
                .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
                .apiVersion = VK_API_VERSION_1_0,
            },
            .enabledLayerCount = 1,
            .ppEnabledLayerNames = (const char *const []){ "VK_LAYER_KHRONOS_validation" },
            .enabledExtensionCount = 2,
            .ppEnabledExtensionNames = (const char *const []){ VK_KHR_SURFACE_EXTENSION_NAME, window_extension },
        }, null, &result.instance));
    }
    // selectPhysicalDevice()
    {
        u32 count = 1;
        vkCheck(vkEnumeratePhysicalDevices(result.instance, &count, &result.physical_device));
        assert(count == 1);
    }
    // getPhysicalDeviceInfo()
    {
        vkGetPhysicalDeviceMemoryProperties(result.physical_device, &result.physical_device_memory_properties);
        vkGetPhysicalDeviceProperties(result.physical_device, &result.physical_device_properties);
        printf("%s (Vulkan %d.%d.%d)\n", result.physical_device_properties.deviceName, VK_API_VERSION_MAJOR(result.physical_device_properties.apiVersion), VK_API_VERSION_MINOR(result.physical_device_properties.apiVersion), VK_API_VERSION_PATCH(result.physical_device_properties.apiVersion));
    }
    // createSurface()
#if WINDOWING_API == WAPI_XLIB
        vkCheck(vkCreateXlibSurfaceKHR(result.instance, &(const VkXlibSurfaceCreateInfoKHR) {
            .sType = VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
            .dpy = window->dpy,
            .window = window->win,
        }, null, &result.surface));
#elif WINDOWING_API == WAPI_WIN32
        vkCheck(vkCreateWin32SurfaceKHR(result.instance, &(const VkWin32SurfaceCreateInfoKHR) {
            .sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
            .hinstance = window->inst,
            .hwnd = window->hwnd,
        }, null, &result.surface));
#else
#error missing case
#endif
    // selectSurfaceFormat()
    {
        #define max_count 128
        u32 count = max_count;
        VkSurfaceFormatKHR formats[max_count];
        #undef max_count
        vkCheck(vkGetPhysicalDeviceSurfaceFormatsKHR(result.physical_device, result.surface, &count, formats));
        assert(count > 0);

        const VkFormat preferred_format = VK_FORMAT_B8G8R8A8_UNORM;
        const VkColorSpaceKHR preferred_color_space = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR;
        result.surface_format = formats[0];
        for (u32 i = 0; i < count; ++i) {
            if (formats[i].format == preferred_format && formats[i].colorSpace == preferred_color_space) {
                result.surface_format = formats[i];
                break;
            }
        }
    }
    // selectPresentMode()
    {
        #define max_count 128
        u32 count = max_count;
        VkPresentModeKHR present_modes[max_count];
        #undef max_count
        vkCheck(vkGetPhysicalDeviceSurfacePresentModesKHR(result.physical_device, result.surface, &count, present_modes));
        assert(count > 0);

        const VkPresentModeKHR preferred_present_mode = VK_PRESENT_MODE_MAILBOX_KHR;
        result.surface_present_mode = VK_PRESENT_MODE_FIFO_KHR;
        for (u32 i = 0; i < count; ++i) {
            if (present_modes[i] == preferred_present_mode) {
                result.surface_present_mode = preferred_present_mode;
                break;
            }
        }
    }
    // findQueueFamilies()
    {
        #define max_count 128
        u32 count = max_count;
        VkQueueFamilyProperties queue_families[max_count];
        #undef max_count
        vkGetPhysicalDeviceQueueFamilyProperties(result.physical_device, &count, queue_families);
        assert(count > 0);

        VkBool32 graphics_found = false;
        for (u32 i = 0; i < count; ++i) {
            if (queue_families[i].queueCount == 0) continue;
            if (queue_families[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
                result.graphics_queue_family_index = i;
                graphics_found = true;
                break;
            }
        }
        assert(graphics_found);

        VkBool32 present_found = false;
        for (u32 i = 0; i < count; ++i) {
            if (queue_families[i].queueCount == 0) continue;
            vkCheck(vkGetPhysicalDeviceSurfaceSupportKHR(result.physical_device, i, result.surface, &present_found));
            if (present_found) {
                result.present_queue_family_index = i;
                break;
            }
        }
        assert(present_found);
    }
    // createDevice()
    {
        const b32 same_family = result.graphics_queue_family_index == result.present_queue_family_index;
        vkCheck(vkCreateDevice(result.physical_device, &(const VkDeviceCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .queueCreateInfoCount = same_family ? 1 : 2,
            .pQueueCreateInfos = (const VkDeviceQueueCreateInfo []) {
                {
                    .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                    .queueFamilyIndex = result.graphics_queue_family_index,
                    .queueCount = 1,
                    .pQueuePriorities = (const f32 []){ 1.0f },
                },
                {
                    .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                    .queueFamilyIndex = result.graphics_queue_family_index,
                    .queueCount = 1,
                    .pQueuePriorities = (const f32 []){ 1.0f },
                },
            },
            .pEnabledFeatures = &(const VkPhysicalDeviceFeatures) {0},
            .enabledExtensionCount = 1,
            .ppEnabledExtensionNames = (const char *const []){ VK_KHR_SWAPCHAIN_EXTENSION_NAME },
        }, null, &result.device));
    }
    // getQueueHandles()
    {
        vkGetDeviceQueue(result.device, result.graphics_queue_family_index, 0, &result.graphics_queue);
        vkGetDeviceQueue(result.device, result.present_queue_family_index, 0, &result.present_queue);
    }
    // createCommandPool()
    {
        vkCheck(vkCreateCommandPool(result.device, &(const VkCommandPoolCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = result.graphics_queue_family_index,
        }, null, &result.graphics_command_pool));
    }
    // createCommandBuffers()
    {
        vkCheck(vkAllocateCommandBuffers(result.device, &(const VkCommandBufferAllocateInfo) {
            .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = result.graphics_command_pool,
            .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = max_frames_rendering_at_once,
        }, result.graphics_command_buffers));
    }
    // createSyncObjects()
    {
        const VkSemaphoreCreateInfo semaphore_create_info = {
            .sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        };
        const VkFenceCreateInfo fence_create_info =  {
            .sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            .flags = VK_FENCE_CREATE_SIGNALED_BIT,
        };
        for (u32 i = 0; i < max_frames_rendering_at_once; ++i) {
            vkCheck(vkCreateSemaphore(result.device, &semaphore_create_info, null, result.image_acquired_semaphores+i));
            vkCheck(vkCreateSemaphore(result.device, &semaphore_create_info, null, result.image_written_semaphores+i));
            vkCheck(vkCreateFence(result.device, &fence_create_info, null, result.currently_rendering_fences+i));
        }
    }
    // createRenderPass()
    {
        vkCheck(vkCreateRenderPass(result.device, &(const VkRenderPassCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            .attachmentCount = 1,
            .pAttachments = (const VkAttachmentDescription []) {
                {
                    .format = result.surface_format.format,
                    .samples = VK_SAMPLE_COUNT_1_BIT,
                    .loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
                    .storeOp = VK_ATTACHMENT_STORE_OP_STORE,
                    .stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
                    .stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
                    .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
                    .finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
                },
                // {
                //     .format = VK_FORMAT_D32_SFLOAT,
                //     .samples = VK_SAMPLE_COUNT_1_BIT,
                //     .loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
                //     .storeOp = VK_ATTACHMENT_STORE_OP_STORE,
                //     .stencilLoadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
                //     .stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
                //     .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
                //     .finalLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
                // },
            },
            .subpassCount = 1,
            .pSubpasses = &(const VkSubpassDescription) {
                .pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
                .colorAttachmentCount = 1,
                .pColorAttachments = &(const VkAttachmentReference) {
                    .attachment = 0,
                    .layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                },
                // .pDepthStencilAttachment = &(const VkAttachmentReference) {
                //     .attachment = 1,
                //     .layout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
                // },
            },
            .dependencyCount = 1,
            .pDependencies = (const VkSubpassDependency []) {
                {
                    .srcSubpass = VK_SUBPASS_EXTERNAL,
                    .dstSubpass = 0,
                    .srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                    .srcAccessMask = 0,
                    .dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                    .dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
                },
                // {
                //     .srcSubpass = VK_SUBPASS_EXTERNAL,
                //     .dstSubpass = 0,
                //     .srcStageMask = VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT | VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
                //     .srcAccessMask = 0,
                //     .dstStageMask = VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT | VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
                //     .dstAccessMask = VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
                // },
            },
        }, null, &result.render_pass));
    }
    // createShaders()
    #include "../out/mesh.spv.h"
    VkShaderModule shader_module;
    {
        const b32 modcheck = meshspv_len % 4 == 0;
        assert(modcheck);
        vkCheck(vkCreateShaderModule(result.device, &(const VkShaderModuleCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            .codeSize = meshspv_len,
            .pCode = (const u32 *) meshspv,
        }, null, &shader_module));
    }
    // createGraphicsPipelineLayout()
    {
        vkCheck(vkCreatePipelineLayout(result.device, &(const VkPipelineLayoutCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .pushConstantRangeCount = 1,
            .pPushConstantRanges = &(const VkPushConstantRange) {
                .stageFlags = VK_SHADER_STAGE_VERTEX_BIT,
                .offset = 0,
                .size = sizeof(MeshPushConstants),
            },
        }, null, &result.mesh_graphics_pipeline_layout));
    }
    // createGraphicsPipeline()
    {
        const VkPipelineShaderStageCreateInfo stages[] = {
            {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .stage = VK_SHADER_STAGE_VERTEX_BIT,
                .module = shader_module,
                .pName = "main",
            },
            {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .stage = VK_SHADER_STAGE_FRAGMENT_BIT,
                .module = shader_module,
                .pName = "main",
            },
        };
        const VkPrimitiveTopology topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
        const VkPolygonMode polygon_mode = VK_POLYGON_MODE_FILL;
        const VkPipelineLayout layout = result.mesh_graphics_pipeline_layout;
        vkCheck(vkCreateGraphicsPipelines(result.device, null, 1, &(const VkGraphicsPipelineCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            .stageCount = len(stages),
            .pStages = stages,
            .pVertexInputState = &(const VkPipelineVertexInputStateCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
                .vertexBindingDescriptionCount = vertex_bindings_len,
                .pVertexBindingDescriptions = vertex_bindings,
                .vertexAttributeDescriptionCount = vertex_attributes_len,
                .pVertexAttributeDescriptions = vertex_attributes,
            },
            .pInputAssemblyState = &(const VkPipelineInputAssemblyStateCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
                .topology = topology,
            },
            .pViewportState = &(const VkPipelineViewportStateCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
                .viewportCount = 1,
                .scissorCount = 1,
            },
            .pRasterizationState = &(const VkPipelineRasterizationStateCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
                .polygonMode = polygon_mode,
                .cullMode = VK_CULL_MODE_BACK_BIT,
                .frontFace = VK_FRONT_FACE_CLOCKWISE,
                .lineWidth = 1.0f,
            },
            .pMultisampleState = &(const VkPipelineMultisampleStateCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
                .rasterizationSamples = VK_SAMPLE_COUNT_1_BIT,
            },
            .pColorBlendState = &(const VkPipelineColorBlendStateCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
                .attachmentCount = 1,
                .pAttachments = &(const VkPipelineColorBlendAttachmentState) {
                    .colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT,
                },
            },
            .pDynamicState = &(const VkPipelineDynamicStateCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
                .dynamicStateCount = 2,
                .pDynamicStates = (const VkDynamicState []){ VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR },
            },
            .pDepthStencilState = &(const VkPipelineDepthStencilStateCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
                .depthTestEnable = VK_TRUE,
                .depthWriteEnable = VK_TRUE,
                .depthCompareOp = VK_COMPARE_OP_LESS_OR_EQUAL,
                .depthBoundsTestEnable = VK_FALSE,
            },
            .layout = layout,
            .renderPass = result.render_pass,
            .subpass = 0,
        }, null, &result.mesh_graphics_pipeline));
    }

    // result.impl.mesh_to_gpudata_map = comptime std.EnumArray(Mesh, VulkanMesh).initUndefined();
    // inline for (@typeInfo(Mesh).Enum.fields) |field| {
    //     result.impl.mesh_to_gpudata_map.set(@field(Mesh, field.name), try VulkanMesh.create(&result.impl, comptime try parseObj(@field(Mesh, field.name))));
    // }

    swapchain_init(&result);

    vkDestroyShaderModule(result.device, shader_module, null);
    return result;
}

void record_buffer(const GameRenderer *const renderer, VkCommandBuffer buffer, u32 image_index)
{
    vkCheck(vkBeginCommandBuffer(buffer, &(const VkCommandBufferBeginInfo) {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    }));
    vkCmdBeginRenderPass(buffer, &(const VkRenderPassBeginInfo) {
        .sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .renderPass = renderer->render_pass,
        .framebuffer = renderer->framebuffers[image_index],
        .renderArea = {
            .offset = { .x = 0, .y = 0 },
            .extent = renderer->surface_capabilities.currentExtent,
        },
        .clearValueCount = 1,
        .pClearValues = (const VkClearValue []) {
            { .color = { .float32 = { 0.0f, 0.0f, 0.0f, 1.0f } } },
            // { .depthStencil = { .depth = 1.0f, .stencil = 0 } },
        },
    }, VK_SUBPASS_CONTENTS_INLINE);
    vkCmdBindPipeline(buffer, VK_PIPELINE_BIND_POINT_GRAPHICS, renderer->mesh_graphics_pipeline);
    vkCmdSetViewport(buffer, 0, 1, &(const VkViewport) {
        .x = 0.0f,
        .y = 0.0f,
        .width = (f32) renderer->surface_capabilities.currentExtent.width,
        .height = (f32) renderer->surface_capabilities.currentExtent.height,
        .minDepth = 1.0f,
        .maxDepth = 0.0f,
    });
    vkCmdSetScissor(buffer, 0, 1, &(const VkRect2D) {
        .offset = { .x = 0, .y = 0 },
        .extent = renderer->surface_capabilities.currentExtent,
    });
    vkCmdPushConstants(buffer, renderer->mesh_graphics_pipeline_layout, VK_SHADER_STAGE_VERTEX_BIT, 0, sizeof(MeshPushConstants), &(const MeshPushConstants) {
        .mvp = {
            { 1.0f, 0.0f, 0.0f, 0.0f },
            { 0.0f, 1.0f, 0.0f, 0.0f },
            { 0.0f, 0.0f, 1.0f, 0.0f },
            { 0.0f, 0.0f, 0.0f, 1.0f },
        },
    });
    // for (usize i = 0; renderer->render_objects.length; ++i) {
    //     const MeshData *meshdata = renderer->meshes+((RenderObject *)ArrayList_get(renderer->render_objects, i))->mesh;
    //     vkCmdBindVertexBuffers(buffer, 0, 1, &meshdata->buffer, (VkDeviceSize []){0});
    //     vkCmdDraw(buffer, meshdata->draw_count, 1, 0, 0);
    // }
    vkCmdEndRenderPass(buffer);
    vkCheck(vkEndCommandBuffer(buffer));
}

void renderer_update(GameRenderer *const renderer)
{
    vkCheck(vkWaitForFences(renderer->device, 1, renderer->currently_rendering_fences+renderer->current_frame, VK_TRUE, UINT64_MAX));
    u32 image_index;
    VkResult result = vkAcquireNextImageKHR(renderer->device, renderer->swapchain, UINT64_MAX, renderer->image_acquired_semaphores[renderer->current_frame], VK_NULL_HANDLE, &image_index);
    switch (result) {
        case VK_ERROR_OUT_OF_DATE_KHR: {
            swapchain_reinit(renderer);
        } return;
        case VK_SUCCESS:
        case VK_SUBOPTIMAL_KHR: {
        } break;
        default: {
            assert(false);
        } break;
    }
    vkCheck(vkResetFences(renderer->device, 1, &renderer->currently_rendering_fences[renderer->current_frame]));
    record_buffer(renderer, renderer->graphics_command_buffers[renderer->current_frame], image_index);
    vkCheck(vkQueueSubmit(renderer->graphics_queue, 1, &(const VkSubmitInfo) {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = renderer->image_acquired_semaphores+renderer->current_frame,
        .pWaitDstStageMask = (const VkPipelineStageFlags []){VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT},
        .commandBufferCount = 1,
        .pCommandBuffers = renderer->graphics_command_buffers+renderer->current_frame,
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = renderer->image_written_semaphores+renderer->current_frame,
    }, renderer->currently_rendering_fences[renderer->current_frame]));
    result = vkQueuePresentKHR(renderer->present_queue, &(const VkPresentInfoKHR) {
        .sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = renderer->image_written_semaphores+renderer->current_frame,
        .swapchainCount = 1,
        .pSwapchains = &renderer->swapchain,
        .pImageIndices = &image_index,
    });
    switch (result) {
        case VK_ERROR_OUT_OF_DATE_KHR:
        case VK_SUBOPTIMAL_KHR: {
            swapchain_reinit(renderer);
        } break;
        case VK_SUCCESS: {
        } break;
        default: {
            assert(false);
        } break;
    }
    renderer->current_frame = (renderer->current_frame + 1) % max_frames_rendering_at_once;
}

void renderer_deinit(const GameRenderer *const renderer)
{
    swapchain_deinit(renderer);
    ArrayList_deinit(renderer->render_objects);
    // inline for (@typeInfo(Mesh).Enum.fields) |field| {
    //     self.impl.mesh_to_gpudata_map.get(@field(Mesh, field.name)).destroy();
    // }
    vkDestroyPipeline(renderer->device, renderer->mesh_graphics_pipeline, null);
    vkDestroyPipelineLayout(renderer->device, renderer->mesh_graphics_pipeline_layout, null);
    vkDestroyRenderPass(renderer->device, renderer->render_pass, null);
    for (u32 i = 0; i < max_frames_rendering_at_once; ++i) {
        vkDestroyFence(renderer->device, renderer->currently_rendering_fences[i], null);
        vkDestroySemaphore(renderer->device, renderer->image_written_semaphores[i], null);
        vkDestroySemaphore(renderer->device, renderer->image_acquired_semaphores[i], null);
    }
    vkDestroyCommandPool(renderer->device, renderer->graphics_command_pool, null);
    vkDestroyDevice(renderer->device, null);
    vkDestroySurfaceKHR(renderer->instance, renderer->surface, null);
    vkDestroyInstance(renderer->instance, null);
}
