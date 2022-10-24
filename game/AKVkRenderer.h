#pragma once

#include <vulkan/vulkan.h>

struct APISpecificData {
    VkInstance instance;
    VkPhysicalDevice physical_device;
    optional_u32 graphics_queue_family_index;
    optional_u32 present_queue_family_index;
    VkDevice device;
    VkQueue graphics_queue;
    VkQueue present_queue;
    VkSurfaceKHR surface;
    VkSurfaceCapabilitiesKHR surface_caps;
    VkSurfaceFormatKHR surface_format;
    VkPresentModeKHR present_mode;
    VkSwapchainKHR swapchain;
    u32 image_count;
    VkImage swapchain_images[10];
    VkImageView swapchain_image_views[10];
    VkRenderPass render_pass;
    VkPipelineLayout pipeline_layout;
    VkPipeline pipeline;
    VkFramebuffer framebuffers[10];
    VkCommandPool command_pool;
    VkCommandBuffer command_buffer;
    VkSemaphore image_available_semaphore;
    VkSemaphore render_complete_semaphore;
    VkFence in_flight_fence;
};

#include "AKRenderer.h"

#ifdef INCLUDE_SRC

#include "AKUtils.h"

#define AKRenderer_VKCheck(vkresult) if ((vkresult) != VK_SUCCESS) {return result;}

#if defined(AK_USE_WIN32)
#define AKRenderer_VKCreateSurface vkCreateWin32SurfaceKHR(result.data.instance, &(VkWin32SurfaceCreateInfoKHR) { \
    .sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR, \
    .hwnd = window->data.hwnd, \
    .hinstance = window->data.inst \
}, NULL, &result.data.surface)
static const char *const instance_extensions[] = {VK_KHR_SURFACE_EXTENSION_NAME, VK_KHR_WIN32_SURFACE_EXTENSION_NAME};
#elif defined(AK_USE_XLIB)
#define AKRenderer_VKCreateSurface vkCreateXlibSurfaceKHR(result.data.instance, &(VkXlibSurfaceCreateInfoKHR) { \
    .sType = VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR, \
    .dpy = window->data.dpy, \
    .window = window->data.win \
}, NULL, &result.data.surface)
static const char *const instance_extensions[] = {VK_KHR_SURFACE_EXTENSION_NAME, VK_KHR_XLIB_SURFACE_EXTENSION_NAME};
#else
#error Windowing system not supported by Vulkan renderer
#endif

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
    AKRenderer_VKCheck(vkCreateInstance(&(VkInstanceCreateInfo) {
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &(VkApplicationInfo) {
            .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .apiVersion = VK_API_VERSION_1_0
        },
        .enabledLayerCount = 1,
        .ppEnabledLayerNames = (const char *const []) {"VK_LAYER_KHRONOS_validation"},
        .enabledExtensionCount = LENGTH(instance_extensions),
        .ppEnabledExtensionNames = instance_extensions
    }, NULL, &result.data.instance));

    // createSurface()
    {
        AKRenderer_VKCheck(AKRenderer_VKCreateSurface);
    }

    // selectPhysicalDevice()
    {
        u32 count = 1;
        AKRenderer_VKCheck(vkEnumeratePhysicalDevices(result.data.instance, &count, &result.data.physical_device));
        AKAssert(count == 1);
    }

    // findQueueFamilies()
    {
        u32 count = 128;
        VkQueueFamilyProperties queue_family_props[128];
        vkGetPhysicalDeviceQueueFamilyProperties(result.data.physical_device, &count, queue_family_props);
        result.data.graphics_queue_family_index = nullopt;
        result.data.present_queue_family_index = nullopt;
        for (u32 i = 0; i < count; ++i) {
            if (queue_family_props[i].queueFlags & VK_QUEUE_GRAPHICS_BIT)
                result.data.graphics_queue_family_index = i;

            VkBool32 present_supported = VK_FALSE;
            vkGetPhysicalDeviceSurfaceSupportKHR(result.data.physical_device, i, result.data.surface, &present_supported);
            if (present_supported)
                result.data.present_queue_family_index = i;

            if (result.data.graphics_queue_family_index != nullopt && result.data.present_queue_family_index != nullopt)
                goto findQueueFamiliesSuccess;
        }
        AKAssert(result.data.graphics_queue_family_index != nullopt);
        AKAssert(result.data.present_queue_family_index != nullopt);
    }
    findQueueFamiliesSuccess:
        ;

    // createLogicalDevice()
    const bool32 same_family = result.data.graphics_queue_family_index == result.data.present_queue_family_index;
    {
        AKRenderer_VKCheck(vkCreateDevice(result.data.physical_device, &(VkDeviceCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .queueCreateInfoCount = same_family ? 1 : 2,
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

    //// SWAPCHAIN

    // getSwapchainInfo()
    {
        AKRenderer_VKCheck(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(result.data.physical_device, result.data.surface, &result.data.surface_caps));
    }
    {
        u32 count = 128;
        VkSurfaceFormatKHR formats[128];
        AKRenderer_VKCheck(vkGetPhysicalDeviceSurfaceFormatsKHR(result.data.physical_device, result.data.surface, &count, formats));
        AKAssert(count > 0);
        result.data.surface_format = formats[0];
        for (u32 i = 0; i < count; ++i) {
            if (formats[i].format == VK_FORMAT_B8G8R8A8_SRGB && formats[i].colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
                result.data.surface_format = formats[i];
                break;
            }
        }
    }
    {
        u32 count = 128;
        VkPresentModeKHR present_modes[128];
        AKRenderer_VKCheck(vkGetPhysicalDeviceSurfacePresentModesKHR(result.data.physical_device, result.data.surface, &count, present_modes));
        result.data.present_mode = VK_PRESENT_MODE_FIFO_KHR;
        for (u32 i = 0; i < count; ++i) {
            if (present_modes[i] == VK_PRESENT_MODE_MAILBOX_KHR) {
                result.data.present_mode = VK_PRESENT_MODE_MAILBOX_KHR;
                break;
            }
        }
    }
    // createSwapchain()
    {
        result.data.image_count = result.data.surface_caps.minImageCount + 1;
        if (result.data.surface_caps.maxImageCount > 0 && result.data.image_count > result.data.surface_caps.maxImageCount) {
            result.data.image_count = result.data.surface_caps.maxImageCount;
        }
        AKRenderer_VKCheck(vkCreateSwapchainKHR(result.data.device, &(VkSwapchainCreateInfoKHR) {
            .sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = result.data.surface,
            .minImageCount = result.data.image_count,
            .imageFormat = result.data.surface_format.format,
            .imageColorSpace = result.data.surface_format.colorSpace,
            .imageExtent = result.data.surface_caps.currentExtent,
            .imageArrayLayers = 1,
            .imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = same_family ? VK_SHARING_MODE_EXCLUSIVE : VK_SHARING_MODE_CONCURRENT,
            .queueFamilyIndexCount = same_family ? 0 : 2,
            .pQueueFamilyIndices = (u32 []) {result.data.graphics_queue_family_index, result.data.present_queue_family_index},
            .preTransform = result.data.surface_caps.currentTransform,
            .compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = result.data.present_mode,
            .clipped = VK_TRUE,
            .oldSwapchain = VK_NULL_HANDLE
        }, NULL, &result.data.swapchain));
    }
    // getSwapchainImages()
    {
        AKRenderer_VKCheck(vkGetSwapchainImagesKHR(result.data.device, result.data.swapchain, &result.data.image_count, NULL));
        // NOTE: image_count is only accurate from this point on, since vkGetSwapchainImagesKHR uses the previous value
        //       as a minimum and stores the final value into image_count
        AKAssert(result.data.image_count <= 10);
        AKRenderer_VKCheck(vkGetSwapchainImagesKHR(result.data.device, result.data.swapchain, &result.data.image_count, result.data.swapchain_images));
        printf("Swapchain(images_count=%d)\n", result.data.image_count);
    }
    // createImageViews()
    {
        for (u32 i = 0; i < result.data.image_count; ++i) {
            AKRenderer_VKCheck(vkCreateImageView(result.data.device, &(VkImageViewCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .image = result.data.swapchain_images[i],
                .viewType = VK_IMAGE_VIEW_TYPE_2D,
                .format = result.data.surface_format.format,
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
            }, NULL, result.data.swapchain_image_views+i));
        }
    }
    // createGraphicsPipeline()
    {
        VkShaderModule vertex_shader_module;
        VkShaderModule fragment_shader_module;
        {
            char *vertex_shader_src;
            const long vertex_shader_len = read_binary_file("vert.spv", &vertex_shader_src);
            AKAssert(vertex_shader_len != -1 && vertex_shader_len % 4 == 0);
            char *fragment_shader_src;
            const long fragment_shader_len = read_binary_file("frag.spv", &fragment_shader_src);
            AKAssert(fragment_shader_len != -1 && fragment_shader_len % 4 == 0);

            AKRenderer_VKCheck(vkCreateShaderModule(result.data.device, &(VkShaderModuleCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                .codeSize = vertex_shader_len,
                .pCode = (const u32 *) vertex_shader_src
            }, NULL, &vertex_shader_module));

            AKRenderer_VKCheck(vkCreateShaderModule(result.data.device, &(VkShaderModuleCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                .codeSize = fragment_shader_len,
                .pCode = (const u32 *) fragment_shader_src
            }, NULL, &fragment_shader_module));

            free(fragment_shader_src);
            free(vertex_shader_src);
        }

        AKRenderer_VKCheck(vkCreateRenderPass(result.data.device, &(VkRenderPassCreateInfo) {
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

        AKRenderer_VKCheck(vkCreatePipelineLayout(result.data.device, &(VkPipelineLayoutCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
        }, NULL, &result.data.pipeline_layout));

        AKRenderer_VKCheck(vkCreateGraphicsPipelines(result.data.device, VK_NULL_HANDLE, 1, &(VkGraphicsPipelineCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            .stageCount = 2,
            .pStages = (VkPipelineShaderStageCreateInfo []) {
                {
                    .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                    .stage = VK_SHADER_STAGE_VERTEX_BIT,
                    .module = vertex_shader_module,
                    .pName = "main"
                },
                {
                    .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                    .stage = VK_SHADER_STAGE_FRAGMENT_BIT,
                    .module = fragment_shader_module,
                    .pName = "main"
                },
            },
            .pVertexInputState = &(VkPipelineVertexInputStateCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
                .vertexBindingDescriptionCount = 0,
                .pVertexBindingDescriptions = NULL,
                .vertexAttributeDescriptionCount = 0,
                .pVertexAttributeDescriptions = NULL
            },
            .pInputAssemblyState = &(VkPipelineInputAssemblyStateCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
                .topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
                .primitiveRestartEnable = VK_FALSE
            },
            .pViewportState = &(VkPipelineViewportStateCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
                .viewportCount = 1,
                .pViewports = &(VkViewport) {
                    .x = 0.0f,
                    .y = 0.0f,
                    .width = result.data.surface_caps.currentExtent.width,
                    .height = result.data.surface_caps.currentExtent.height,
                    .minDepth = 0.0f,
                    .maxDepth = 1.0f
                },
                .scissorCount = 1,
                .pScissors = &(VkRect2D) {
                    .offset = {0, 0},
                    .extent = result.data.surface_caps.currentExtent
                }
            },
            .pRasterizationState = &(VkPipelineRasterizationStateCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
                .depthClampEnable = VK_FALSE,
                .rasterizerDiscardEnable = VK_FALSE,
                .polygonMode = VK_POLYGON_MODE_FILL,
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
            .pDynamicState = NULL,
            .layout = result.data.pipeline_layout,
            .renderPass = result.data.render_pass,
            .subpass = 0
        }, NULL, &result.data.pipeline));

        vkDestroyShaderModule(result.data.device, fragment_shader_module, NULL);
        vkDestroyShaderModule(result.data.device, vertex_shader_module, NULL);
    }
    // createFramebuffers()
    {
        for (u32 i = 0; i < result.data.image_count; ++i) {
            AKRenderer_VKCheck(vkCreateFramebuffer(result.data.device, &(VkFramebufferCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                .renderPass = result.data.render_pass,
                .attachmentCount = 1,
                .pAttachments = result.data.swapchain_image_views+i,
                .width = result.data.surface_caps.currentExtent.width,
                .height = result.data.surface_caps.currentExtent.height,
                .layers = 1
            }, NULL, result.data.framebuffers+i));
        }
    }
    // createCommandPool()
    {
        AKRenderer_VKCheck(vkCreateCommandPool(result.data.device, &(VkCommandPoolCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = result.data.graphics_queue_family_index
        }, NULL, &result.data.command_pool));
    }
    // createCommandBuffer()
    {
        AKRenderer_VKCheck(vkAllocateCommandBuffers(result.data.device, &(VkCommandBufferAllocateInfo) {
            .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = result.data.command_pool,
            .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1
        }, &result.data.command_buffer));
    }
    // createSyncObjects()
    {
        AKRenderer_VKCheck(vkCreateSemaphore(result.data.device, &(VkSemaphoreCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
        }, NULL, &result.data.image_available_semaphore));
        AKRenderer_VKCheck(vkCreateSemaphore(result.data.device, &(VkSemaphoreCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO
        }, NULL, &result.data.render_complete_semaphore));
        AKRenderer_VKCheck(vkCreateFence(result.data.device, &(VkFenceCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            .flags = VK_FENCE_CREATE_SIGNALED_BIT
        }, NULL, &result.data.in_flight_fence));
    }

    result.success = true;
    return result;
}

static bool32 record_command_buffer(const AKRenderer *const renderer, VkCommandBuffer buffer, u32 image_index)
{
    const bool32 result = false;
    AKRenderer_VKCheck(vkBeginCommandBuffer(buffer, &(VkCommandBufferBeginInfo) {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO
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
    vkCmdBindPipeline(buffer, VK_PIPELINE_BIND_POINT_GRAPHICS, renderer->data.pipeline);
    vkCmdDraw(buffer, 3, 1, 0, 0);
    vkCmdEndRenderPass(buffer);
    AKRenderer_VKCheck(vkEndCommandBuffer(buffer));
    return true;
}

void renderer_update(AKRenderer *const renderer)
{
    if (vkWaitForFences(renderer->data.device, 1, &renderer->data.in_flight_fence, VK_TRUE, UINT64_MAX) != VK_SUCCESS) {
        printf("Failed to wait for in_flight_fence\n");
        exit(EXIT_FAILURE);
    }
    if (vkResetFences(renderer->data.device, 1, &renderer->data.in_flight_fence) != VK_SUCCESS) {
        printf("Failed to reset in_flight_fence\n");
        exit(EXIT_FAILURE);
    }
    u32 image_index;
    vkAcquireNextImageKHR(renderer->data.device, renderer->data.swapchain, UINT64_MAX, renderer->data.image_available_semaphore, VK_NULL_HANDLE, &image_index);
    if (!record_command_buffer(renderer, renderer->data.command_buffer, image_index)) {
        printf("Failed to write a command buffer\n");
        exit(EXIT_FAILURE);
    }
    if (vkQueueSubmit(renderer->data.graphics_queue, 1, &(VkSubmitInfo) {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &renderer->data.image_available_semaphore,
        .pWaitDstStageMask = (VkPipelineStageFlags []) {VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT},
        .commandBufferCount = 1,
        .pCommandBuffers = &renderer->data.command_buffer,
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &renderer->data.render_complete_semaphore
    }, renderer->data.in_flight_fence) != VK_SUCCESS) {
        printf("Failed to submit to graphics queue\n");
        exit(EXIT_FAILURE);
    }
    vkQueuePresentKHR(renderer->data.present_queue, &(VkPresentInfoKHR) {
        .sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &renderer->data.render_complete_semaphore,
        .swapchainCount = 1,
        .pSwapchains = &renderer->data.swapchain,
        .pImageIndices = &image_index
    });
}

void renderer_deinit(const AKRenderer *const renderer)
{
    vkDeviceWaitIdle(renderer->data.device);
    vkDestroyFence(renderer->data.device, renderer->data.in_flight_fence, NULL);
    vkDestroySemaphore(renderer->data.device, renderer->data.render_complete_semaphore, NULL);
    vkDestroySemaphore(renderer->data.device, renderer->data.image_available_semaphore, NULL);
    vkDestroyCommandPool(renderer->data.device, renderer->data.command_pool, NULL);
    for (u32 i = 0; i < renderer->data.image_count; ++i)
        vkDestroyFramebuffer(renderer->data.device, renderer->data.framebuffers[i], NULL);
    vkDestroyPipeline(renderer->data.device, renderer->data.pipeline, NULL);
    vkDestroyPipelineLayout(renderer->data.device, renderer->data.pipeline_layout, NULL);
    vkDestroyRenderPass(renderer->data.device, renderer->data.render_pass, NULL);
    for (u32 i = 0; i < renderer->data.image_count; ++i)
        vkDestroyImageView(renderer->data.device, renderer->data.swapchain_image_views[i], NULL);
    vkDestroySwapchainKHR(renderer->data.device, renderer->data.swapchain, NULL);
    vkDestroyDevice(renderer->data.device, NULL);
    vkDestroySurfaceKHR(renderer->data.instance, renderer->data.surface, NULL);
    vkDestroyInstance(renderer->data.instance, NULL);
}

#endif /* INCLUDE_SRC */
