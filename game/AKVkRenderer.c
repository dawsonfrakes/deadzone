#include "AKEngine.h"

#include <stdio.h>
#include <stdlib.h>

#define AKVK_CHECK(vkresult) if ((vkresult) != VK_SUCCESS) {return result;}

static bool32 swapchain_init(AKRenderer *const renderer)
{
    const bool32 result = false;
    // getSurfaceInfo()
    {
        AKVK_CHECK(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(renderer->data.physical_device, renderer->data.surface, &renderer->data.surface_caps));
    }
    // createSwapchain()
    {
        renderer->data.image_count = MAX(renderer->data.surface_caps.minImageCount, AKVK_MAX_FRAMES_IN_FLIGHT);
        if (renderer->data.surface_caps.maxImageCount > 0 && renderer->data.image_count > renderer->data.surface_caps.maxImageCount) {
            renderer->data.image_count = renderer->data.surface_caps.maxImageCount;
        }
        const bool32 same_family = renderer->data.graphics_queue_family_index == renderer->data.present_queue_family_index;
        AKVK_CHECK(vkCreateSwapchainKHR(renderer->data.device, &(VkSwapchainCreateInfoKHR) {
            .sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = renderer->data.surface,
            .minImageCount = renderer->data.image_count,
            .imageFormat = renderer->data.surface_format.format,
            .imageColorSpace = renderer->data.surface_format.colorSpace,
            .imageExtent = renderer->data.surface_caps.currentExtent,
            .imageArrayLayers = 1,
            .imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = same_family ? VK_SHARING_MODE_EXCLUSIVE : VK_SHARING_MODE_CONCURRENT,
            .queueFamilyIndexCount = same_family ? 0 : 2,
            .pQueueFamilyIndices = (u32 []) {renderer->data.graphics_queue_family_index, renderer->data.present_queue_family_index},
            .preTransform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
            .compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = renderer->data.present_mode,
            .clipped = VK_TRUE,
            .oldSwapchain = VK_NULL_HANDLE
        }, NULL, &renderer->data.swapchain));
    }
    // getSwapchainImages()
    {
        AKVK_CHECK(vkGetSwapchainImagesKHR(renderer->data.device, renderer->data.swapchain, &renderer->data.image_count, NULL));
        // NOTE: image_count is only accurate from this point on, since vkGetSwapchainImagesKHR uses the previous value
        //       as a minimum and stores the final value into image_count
        AKAssert(renderer->data.image_count <= 10 && renderer->data.image_count > 0);
        AKVK_CHECK(vkGetSwapchainImagesKHR(renderer->data.device, renderer->data.swapchain, &renderer->data.image_count, renderer->data.swapchain_images));
        printf("Swapchain(images_count=%d)\n", renderer->data.image_count);
    }
    // createImageViews()
    {
        for (u32 i = 0; i < renderer->data.image_count; ++i) {
            AKVK_CHECK(vkCreateImageView(renderer->data.device, &(VkImageViewCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .image = renderer->data.swapchain_images[i],
                .viewType = VK_IMAGE_VIEW_TYPE_2D,
                .format = renderer->data.surface_format.format,
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
                    .layerCount = 1
                }
            }, NULL, renderer->data.swapchain_image_views+i));
        }
    }
    // createFramebuffers()
    {
        for (u32 i = 0; i < renderer->data.image_count; ++i) {
            AKVK_CHECK(vkCreateFramebuffer(renderer->data.device, &(VkFramebufferCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                .renderPass = renderer->data.render_pass,
                .attachmentCount = 1,
                .pAttachments = renderer->data.swapchain_image_views+i,
                .width = renderer->data.surface_caps.currentExtent.width,
                .height = renderer->data.surface_caps.currentExtent.height,
                .layers = 1
            }, NULL, renderer->data.framebuffers+i));
        }
    }
    return true;
}

static void swapchain_deinit(const AKRenderer *const renderer)
{
    vkDeviceWaitIdle(renderer->data.device);
    for (u32 i = 0; i < renderer->data.image_count; ++i) {
        vkDestroyFramebuffer(renderer->data.device, renderer->data.framebuffers[i], NULL);
        vkDestroyImageView(renderer->data.device, renderer->data.swapchain_image_views[i], NULL);
    }
    vkDestroySwapchainKHR(renderer->data.device, renderer->data.swapchain, NULL);
}

static bool32 swapchain_reinit(AKRenderer *const renderer)
{
    swapchain_deinit(renderer);
    return swapchain_init(renderer);
}

static VkPipeline graphics_pipeline_create(
    VkDevice device,
    VkPipelineShaderStageCreateInfo *stages,
    size_t num_stages,
    VkPipelineVertexInputStateCreateInfo *vertex_input,
    VkPrimitiveTopology topology,
    VkPolygonMode polygon_mode,
    VkPipelineLayout pipeline_layout,
    VkRenderPass render_pass
) {
    VkPipeline result = VK_NULL_HANDLE;
    AKVK_CHECK(vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, &(VkGraphicsPipelineCreateInfo) {
        .sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = num_stages,
        .pStages = stages,
        .pVertexInputState = vertex_input,
        .pInputAssemblyState = &(VkPipelineInputAssemblyStateCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            .topology = topology,
            .primitiveRestartEnable = VK_FALSE
        },
        .pViewportState = &(VkPipelineViewportStateCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            // dynamic state
            .viewportCount = 1,
            .scissorCount = 1
        },
        .pRasterizationState = &(VkPipelineRasterizationStateCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            .depthClampEnable = VK_FALSE,
            .rasterizerDiscardEnable = VK_FALSE,
            .polygonMode = polygon_mode,
            .lineWidth = 1.0f,
            .cullMode = VK_CULL_MODE_BACK_BIT,
            .frontFace = VK_FRONT_FACE_CLOCKWISE,
            .depthBiasEnable = VK_FALSE
        },
        .pMultisampleState = &(VkPipelineMultisampleStateCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            .sampleShadingEnable = VK_FALSE,
            .rasterizationSamples = VK_SAMPLE_COUNT_1_BIT
        },
        .pDepthStencilState = NULL,
        .pColorBlendState = &(VkPipelineColorBlendStateCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            .logicOpEnable = VK_FALSE,
            .attachmentCount = 1,
            .pAttachments = &(VkPipelineColorBlendAttachmentState) {
                .colorWriteMask = VK_COLOR_COMPONENT_R_BIT|VK_COLOR_COMPONENT_G_BIT|VK_COLOR_COMPONENT_B_BIT|VK_COLOR_COMPONENT_A_BIT,
                .blendEnable = VK_FALSE
            }
        },
        .pDynamicState = &(VkPipelineDynamicStateCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
            .dynamicStateCount = 2,
            .pDynamicStates = (const VkDynamicState []) {VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR}
        },
        .layout = pipeline_layout,
        .renderPass = render_pass,
        .subpass = 0
    }, NULL, &result));
    return result;
}

static VkShaderModule shader_create(VkDevice device, const char *const filepath)
{
    VkShaderModule result = VK_NULL_HANDLE;
    char *shader_src;
    const long shader_src_len = read_binary_file(filepath, &shader_src);
    AKAssert(shader_src_len != -1 && shader_src_len % 4 == 0);
    AKVK_CHECK(vkCreateShaderModule(device, &(VkShaderModuleCreateInfo) {
        .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = shader_src_len,
        .pCode = (const u32 *) shader_src
    }, NULL, &result));
    free(shader_src);
    return result;
}

AKRenderer renderer_init(const AKWindow *const window)
{
    AKRenderer result = {
        .success = false
    };

    // listExtensions()
    // {
    //     u32 count = 128;
    //     VkExtensionProperties ext_props[128];
    //     vkEnumerateInstanceExtensionProperties(NULL, &count, ext_props);
    //     for (u32 i = 0; i < count; ++i) {
    //         printf("%s\n", ext_props[i].extensionName);
    //     }
    // }

    // createInstance()
    AKVK_CHECK(vkCreateInstance(&(VkInstanceCreateInfo) {
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &(VkApplicationInfo) {
            .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .apiVersion = VK_API_VERSION_1_0
        },
        .enabledLayerCount = 1,
        .ppEnabledLayerNames = (const char *const []) {"VK_LAYER_KHRONOS_validation"},
        .enabledExtensionCount = 2,
        .ppEnabledExtensionNames = (const char *const []) {VK_KHR_SURFACE_EXTENSION_NAME, AKVK_SURFACE_EXTENSION_NAME}
    }, NULL, &result.data.instance));

    // createSurface()
    {
        AKVK_CHECK(AKVK_CREATE_SURFACE());
    }
    // selectPhysicalDevice()
    {
        u32 count = 1;
        AKVK_CHECK(vkEnumeratePhysicalDevices(result.data.instance, &count, &result.data.physical_device));
        AKAssert(count == 1);
        vkGetPhysicalDeviceMemoryProperties(result.data.physical_device, &result.data.mem_props);
        vkGetPhysicalDeviceProperties(result.data.physical_device, &result.data.props);
    }
    // selectSurfaceFormat()
    {
        u32 count = 128;
        VkSurfaceFormatKHR formats[128];
        AKVK_CHECK(vkGetPhysicalDeviceSurfaceFormatsKHR(result.data.physical_device, result.data.surface, &count, formats));
        AKAssert(count > 0);
        result.data.surface_format = formats[0];
        if (count == 1 && formats[0].format == VK_FORMAT_UNDEFINED) {
            result.data.surface_format.format = VK_FORMAT_B8G8R8A8_UNORM;
            result.data.surface_format.colorSpace = VK_COLOR_SPACE_SRGB_NONLINEAR_KHR;
        }
        for (u32 i = 0; i < count; ++i) {
            if (formats[i].format == VK_FORMAT_B8G8R8A8_UNORM && formats[i].colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
                result.data.surface_format = formats[i];
                break;
            }
        }
    }
    // selectSurfacePresentMode()
    {
        u32 count = 128;
        VkPresentModeKHR present_modes[128];
        AKVK_CHECK(vkGetPhysicalDeviceSurfacePresentModesKHR(result.data.physical_device, result.data.surface, &count, present_modes));
        result.data.present_mode = VK_PRESENT_MODE_FIFO_KHR;
        for (u32 i = 0; i < count; ++i) {
            if (present_modes[i] == VK_PRESENT_MODE_MAILBOX_KHR) {
                result.data.present_mode = VK_PRESENT_MODE_MAILBOX_KHR;
                break;
            }
        }
    }
    // findQueueFamilies()
    {
        u32 count = 128;
        VkQueueFamilyProperties queue_family_props[128];
        vkGetPhysicalDeviceQueueFamilyProperties(result.data.physical_device, &count, queue_family_props);

        result.data.graphics_queue_family_index = nullopt;
        for (u32 i = 0; i < count; ++i) {
            if (queue_family_props[i].queueCount == 0)
                continue;
            if (queue_family_props[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
                result.data.graphics_queue_family_index = i;
                break;
            }
        }
        AKAssert(result.data.graphics_queue_family_index != nullopt);

        result.data.present_queue_family_index = nullopt;
        for (u32 i = 0; i < count; ++i) {
            if (queue_family_props[i].queueCount == 0)
                continue;
            VkBool32 present_supported = VK_FALSE;
            vkGetPhysicalDeviceSurfaceSupportKHR(result.data.physical_device, i, result.data.surface, &present_supported);
            if (present_supported) {
                result.data.present_queue_family_index = i;
                break;
            }
        }
        AKAssert(result.data.present_queue_family_index != nullopt);
    }
    // createLogicalDevice()
    {
        AKVK_CHECK(vkCreateDevice(result.data.physical_device, &(VkDeviceCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .queueCreateInfoCount = result.data.graphics_queue_family_index == result.data.present_queue_family_index ? 1 : 2,
            .pQueueCreateInfos = (VkDeviceQueueCreateInfo []) {
                {
                    .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                    .queueFamilyIndex = result.data.graphics_queue_family_index,
                    .queueCount = 1,
                    .pQueuePriorities = (float []) {1.0f}
                },
                {
                    .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                    .queueFamilyIndex = result.data.present_queue_family_index,
                    .queueCount = 1,
                    .pQueuePriorities = (float []) {1.0f}
                }
            },
            .pEnabledFeatures = &(VkPhysicalDeviceFeatures) {0},
            .enabledExtensionCount = 1,
            .ppEnabledExtensionNames = (const char *const []) {VK_KHR_SWAPCHAIN_EXTENSION_NAME}
        }, NULL, &result.data.device));

        vkGetDeviceQueue(result.data.device, result.data.graphics_queue_family_index, 0, &result.data.graphics_queue);
        vkGetDeviceQueue(result.data.device, result.data.present_queue_family_index, 0, &result.data.present_queue);
    }
    // createCommandPool()
    {
        AKVK_CHECK(vkCreateCommandPool(result.data.device, &(VkCommandPoolCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = result.data.graphics_queue_family_index
        }, NULL, &result.data.command_pool));
    }
    // createCommandBuffer()
    {
        AKVK_CHECK(vkAllocateCommandBuffers(result.data.device, &(VkCommandBufferAllocateInfo) {
            .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = result.data.command_pool,
            .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = AKVK_MAX_FRAMES_IN_FLIGHT
        }, result.data.command_buffers));
    }
    // createSyncObjects()
    {
        for (size_t i = 0; i < AKVK_MAX_FRAMES_IN_FLIGHT; ++i) {
            AKVK_CHECK(vkCreateSemaphore(result.data.device, &(VkSemaphoreCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
            }, NULL, result.data.image_available_semaphores+i));
            AKVK_CHECK(vkCreateSemaphore(result.data.device, &(VkSemaphoreCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
            }, NULL, result.data.render_complete_semaphores+i));
            AKVK_CHECK(vkCreateFence(result.data.device, &(VkFenceCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
                .flags = VK_FENCE_CREATE_SIGNALED_BIT
            }, NULL, result.data.in_flight_fences+i));
        }
    }
    // createGraphicsPipeline()
    {
        const VkShaderModule colored_vertex_shader_module = shader_create(result.data.device, "bin/colored_triangle.vert.spv");
        const VkShaderModule colored_fragment_shader_module = shader_create(result.data.device, "bin/colored_triangle.frag.spv");
        const VkShaderModule red_vertex_shader_module = shader_create(result.data.device, "bin/red_triangle.vert.spv");
        const VkShaderModule red_fragment_shader_module = shader_create(result.data.device, "bin/red_triangle.frag.spv");

        AKAssert(colored_vertex_shader_module);
        AKAssert(colored_fragment_shader_module);
        AKAssert(red_vertex_shader_module);
        AKAssert(red_fragment_shader_module);

        AKVK_CHECK(vkCreateRenderPass(result.data.device, &(VkRenderPassCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            .attachmentCount = 1,
            .pAttachments = &(VkAttachmentDescription) {
                .format = result.data.surface_format.format,
                .samples = VK_SAMPLE_COUNT_1_BIT,
                .loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
                .storeOp = VK_ATTACHMENT_STORE_OP_STORE,
                .stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
                .stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
                .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
                .finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
            },
            .subpassCount = 1,
            .pSubpasses = &(VkSubpassDescription) {
                .pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
                .colorAttachmentCount = 1,
                .pColorAttachments = &(VkAttachmentReference) {
                    .attachment = 0,
                    .layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
                },
            },
            .dependencyCount = 1,
            .pDependencies = &(VkSubpassDependency) {
                .srcSubpass = VK_SUBPASS_EXTERNAL,
                .dstSubpass = 0,
                .srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                .srcAccessMask = 0,
                .dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                .dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT
            }
        }, NULL, &result.data.render_pass));

        AKVK_CHECK(vkCreatePipelineLayout(result.data.device, &(VkPipelineLayoutCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
        }, NULL, &result.data.triangle_pipeline_layout));

        result.data.triangle_pipeline = graphics_pipeline_create(
            result.data.device,
            (VkPipelineShaderStageCreateInfo []) {
                {
                    .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                    .stage = VK_SHADER_STAGE_VERTEX_BIT,
                    .module = colored_vertex_shader_module,
                    .pName = "main"
                },
                {
                    .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                    .stage = VK_SHADER_STAGE_FRAGMENT_BIT,
                    .module = colored_fragment_shader_module,
                    .pName = "main"
                },
            },
            2,
            &(VkPipelineVertexInputStateCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
                .vertexBindingDescriptionCount = 0,
                .pVertexBindingDescriptions = NULL,
                .vertexAttributeDescriptionCount = 0,
                .pVertexAttributeDescriptions = NULL
            },
            VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            VK_POLYGON_MODE_FILL,
            result.data.triangle_pipeline_layout,
            result.data.render_pass
        );

        result.data.red_triangle_pipeline = graphics_pipeline_create(
            result.data.device,
            (VkPipelineShaderStageCreateInfo []) {
                {
                    .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                    .stage = VK_SHADER_STAGE_VERTEX_BIT,
                    .module = red_vertex_shader_module,
                    .pName = "main"
                },
                {
                    .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                    .stage = VK_SHADER_STAGE_FRAGMENT_BIT,
                    .module = red_fragment_shader_module,
                    .pName = "main"
                },
            },
            2,
            &(VkPipelineVertexInputStateCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
                .vertexBindingDescriptionCount = 0,
                .pVertexBindingDescriptions = NULL,
                .vertexAttributeDescriptionCount = 0,
                .pVertexAttributeDescriptions = NULL
            },
            VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            VK_POLYGON_MODE_FILL,
            result.data.triangle_pipeline_layout,
            result.data.render_pass
        );

        vkDestroyShaderModule(result.data.device, red_fragment_shader_module, NULL);
        vkDestroyShaderModule(result.data.device, red_vertex_shader_module, NULL);
        vkDestroyShaderModule(result.data.device, colored_fragment_shader_module, NULL);
        vkDestroyShaderModule(result.data.device, colored_vertex_shader_module, NULL);
    }

    AKAssert(swapchain_init(&result));

    result.success = true;
    return result;
}

static bool32 record_command_buffer(const AKRenderer *const renderer, VkCommandBuffer buffer, u32 image_index)
{
    const bool32 result = false;
    AKVK_CHECK(vkBeginCommandBuffer(buffer, &(VkCommandBufferBeginInfo) {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT
    }));
    vkCmdBeginRenderPass(buffer, &(VkRenderPassBeginInfo) {
        .sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .renderPass = renderer->data.render_pass,
        .framebuffer = renderer->data.framebuffers[image_index],
        .renderArea = {
            .offset = {0, 0},
            .extent = renderer->data.surface_caps.currentExtent
        },
        .clearValueCount = 1,
        .pClearValues = &(VkClearValue) {.color = {.float32 = {1.0f, 0.0f, 1.0f, 1.0f}}}
    }, VK_SUBPASS_CONTENTS_INLINE);
    vkCmdBindPipeline(buffer, VK_PIPELINE_BIND_POINT_GRAPHICS, !renderer->data.current_shader ? renderer->data.triangle_pipeline : renderer->data.red_triangle_pipeline);
    vkCmdSetViewport(buffer, 0, 1, &(VkViewport) {
        .x = 0.0f,
        .y = 0.0f,
        .width = renderer->data.surface_caps.currentExtent.width,
        .height = renderer->data.surface_caps.currentExtent.height,
        .minDepth = 0.0f,
        .maxDepth = 1.0f
    });
    vkCmdSetScissor(buffer, 0, 1, &(VkRect2D) {
        .offset = {0, 0},
        .extent = renderer->data.surface_caps.currentExtent
    });
    vkCmdDraw(buffer, 3, 1, 0, 0);
    vkCmdEndRenderPass(buffer);
    AKVK_CHECK(vkEndCommandBuffer(buffer));
    return true;
}

void renderer_update(AKRenderer *const renderer)
{
    if (vkWaitForFences(renderer->data.device, 1, &renderer->data.in_flight_fences[renderer->data.current_frame], VK_TRUE, UINT64_MAX) != VK_SUCCESS) {
        printf("Failed to wait for in_flight_fence\n");
        exit(EXIT_FAILURE);
    }
    u32 image_index;
    VkResult result = vkAcquireNextImageKHR(renderer->data.device, renderer->data.swapchain, UINT64_MAX, renderer->data.image_available_semaphores[renderer->data.current_frame], VK_NULL_HANDLE, &image_index);
    switch (result) {
        case VK_ERROR_OUT_OF_DATE_KHR: {
            if (!swapchain_reinit(renderer)) {
                printf("Failed to reinitialize swapchain\n");
                exit(EXIT_FAILURE);
            }
        } return;
        case VK_SUCCESS: break;
        case VK_SUBOPTIMAL_KHR: break;
        default: {
            printf("Failed to acquire swapchain image\n");
            exit(0);
        } break;
    }
    if (vkResetFences(renderer->data.device, 1, &renderer->data.in_flight_fences[renderer->data.current_frame]) != VK_SUCCESS) {
        printf("Failed to reset in_flight_fence\n");
        exit(EXIT_FAILURE);
    }
    if (!record_command_buffer(renderer, renderer->data.command_buffers[renderer->data.current_frame], image_index)) {
        printf("Failed to write a command buffer\n");
        exit(EXIT_FAILURE);
    }
    if (vkQueueSubmit(renderer->data.graphics_queue, 1, &(VkSubmitInfo) {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &renderer->data.image_available_semaphores[renderer->data.current_frame],
        .pWaitDstStageMask = (VkPipelineStageFlags []) {VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT},
        .commandBufferCount = 1,
        .pCommandBuffers = &renderer->data.command_buffers[renderer->data.current_frame],
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &renderer->data.render_complete_semaphores[renderer->data.current_frame]
    }, renderer->data.in_flight_fences[renderer->data.current_frame]) != VK_SUCCESS) {
        printf("Failed to submit to graphics queue\n");
        exit(EXIT_FAILURE);
    }
    result = vkQueuePresentKHR(renderer->data.present_queue, &(VkPresentInfoKHR) {
        .sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &renderer->data.render_complete_semaphores[renderer->data.current_frame],
        .swapchainCount = 1,
        .pSwapchains = &renderer->data.swapchain,
        .pImageIndices = &image_index
    });
    switch (result) {
        case VK_ERROR_OUT_OF_DATE_KHR:
        case VK_SUBOPTIMAL_KHR: {
            if (!swapchain_reinit(renderer)) {
                printf("Failed to reinitialize swapchain\n");
                exit(EXIT_FAILURE);
            }
        } break;
        case VK_SUCCESS: break;
        default: {
            printf("Failed to present swapchain image\n");
            exit(EXIT_FAILURE);
        } break;
    }
    renderer->data.current_frame = (renderer->data.current_frame + 1) % AKVK_MAX_FRAMES_IN_FLIGHT;
}

void renderer_deinit(const AKRenderer *const renderer)
{
    swapchain_deinit(renderer);
    vkDestroyPipeline(renderer->data.device, renderer->data.red_triangle_pipeline, NULL);
    vkDestroyPipeline(renderer->data.device, renderer->data.triangle_pipeline, NULL);
    vkDestroyPipelineLayout(renderer->data.device, renderer->data.triangle_pipeline_layout, NULL);
    vkDestroyRenderPass(renderer->data.device, renderer->data.render_pass, NULL);
    for (size_t i = 0; i < AKVK_MAX_FRAMES_IN_FLIGHT; ++i) {
        vkDestroyFence(renderer->data.device, renderer->data.in_flight_fences[i], NULL);
        vkDestroySemaphore(renderer->data.device, renderer->data.render_complete_semaphores[i], NULL);
        vkDestroySemaphore(renderer->data.device, renderer->data.image_available_semaphores[i], NULL);
    }
    vkDestroyCommandPool(renderer->data.device, renderer->data.command_pool, NULL);
    vkDestroyDevice(renderer->data.device, NULL);
    vkDestroySurfaceKHR(renderer->data.instance, renderer->data.surface, NULL);
    vkDestroyInstance(renderer->data.instance, NULL);
}
