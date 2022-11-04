#pragma once

#if RENDERING_API == RAPI_VULKAN
#if WINDOWING_API == WAPI_WIN32
#define VK_USE_PLATFORM_WIN32_KHR
#elif WINDOWING_API == WAPI_XLIB
#define VK_USE_PLATFORM_XLIB_KHR
#else
#error Vulkan renderer does not support selected windowing API
#endif
#include <vulkan/vulkan.h>
#endif

#include "../out/comptime.h"

typedef struct Buffer {
#if RENDERING_API == RAPI_VULKAN
    VkBuffer buffer;
    VkDeviceMemory memory;
#endif
} Buffer;

typedef struct Image {
#if RENDERING_API == RAPI_VULKAN
    VkImage image;
    VkDeviceMemory memory;
    VkImageView view;
    VkFormat format;
#endif
} Image;

typedef struct MeshData {
    Buffer buffer;
    u32 draw_count;
} MeshData;

typedef struct RenderObject {
    Transform transform;
    enum Mesh mesh;
} RenderObject;

typedef struct GameRenderer {
    M4 projection;
    M4 view;
    ArrayList/*RenderObject*/ render_objects;
    MeshData gpumeshes[MESH_LENGTH]/* -> EnumArray(Mesh, MeshData) */;

#if RENDERING_API == RAPI_VULKAN
    #define max_frames_rendering_at_once 2
    #define max_swapchain_images 10
    VkInstance instance;
    VkSurfaceKHR surface;
    VkSurfaceCapabilitiesKHR surface_capabilities;
    VkSurfaceFormatKHR surface_format;
    VkPresentModeKHR surface_present_mode;
    VkPhysicalDevice physical_device;
    VkPhysicalDeviceMemoryProperties physical_device_memory_properties;
    VkPhysicalDeviceProperties physical_device_properties;
    u32 graphics_queue_family_index;
    u32 present_queue_family_index;
    VkDevice device;
    VkQueue graphics_queue;
    VkQueue present_queue;
    VkCommandPool graphics_command_pool;
    VkCommandBuffer graphics_command_buffers[max_frames_rendering_at_once];
    VkSemaphore image_acquired_semaphores[max_frames_rendering_at_once];
    VkSemaphore image_written_semaphores[max_frames_rendering_at_once];
    VkFence currently_rendering_fences[max_frames_rendering_at_once];
    VkRenderPass render_pass;
    VkPipelineLayout mesh_graphics_pipeline_layout;
    VkPipeline mesh_graphics_pipeline;
    u32 image_count;
    VkSwapchainKHR swapchain;
    VkImage swapchain_images[max_swapchain_images];
    VkImageView swapchain_image_views[max_swapchain_images];
    VkFramebuffer framebuffers[max_swapchain_images];
    Image depth_buffer;
    u32 current_frame;
#endif
} GameRenderer;

static GameRenderer renderer_init(const GameWindow *const window);
static void renderer_update(GameRenderer *const renderer);
static void renderer_deinit(const GameRenderer *const renderer);

#ifdef __main__

#if RENDERING_API == RAPI_VULKAN

#define vkCheck(check) do { if ((check) != VK_SUCCESS) { fprintf(stderr, #check"\n"); abort(); } } while (0)

static u32 find_mem_type(const GameRenderer *const renderer, u32 type_filter, VkMemoryPropertyFlags properties)
{
    for (u32 i = 0; i < renderer->physical_device_memory_properties.memoryTypeCount; ++i) {
        if ((type_filter & (1 << i)) != 0 && (renderer->physical_device_memory_properties.memoryTypes[i].propertyFlags & properties) == properties) {
            return i;
        }
    }
    assert(false);
    return UINT32_MAX;
}

static Buffer buffer_create(const GameRenderer *const renderer, VkDeviceSize size, VkBufferUsageFlags usage, VkMemoryPropertyFlags properties)
{
    Buffer result = {0};
    vkCheck(vkCreateBuffer(renderer->device, &(const VkBufferCreateInfo) {
        .sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = size,
        .usage = usage,
        .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
    }, null, &result.buffer));
    VkMemoryRequirements mem_req;
    vkGetBufferMemoryRequirements(renderer->device, result.buffer, &mem_req);
    vkCheck(vkAllocateMemory(renderer->device, &(const VkMemoryAllocateInfo) {
        .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = mem_req.size,
        .memoryTypeIndex = find_mem_type(renderer, mem_req.memoryTypeBits, properties),
    }, null, &result.memory));
    vkCheck(vkBindBufferMemory(renderer->device, result.buffer, result.memory, 0));
    return result;
}

static void buffer_destroy(const GameRenderer *const renderer, Buffer buffer)
{
    vkFreeMemory(renderer->device, buffer.memory, null);
    vkDestroyBuffer(renderer->device, buffer.buffer, null);
}

static Image image_create(const GameRenderer *const renderer, VkFormat format, VkImageUsageFlags usage, VkExtent3D extent, VkImageAspectFlags aspect_flags, VkMemoryPropertyFlags properties)
{
    Image result;
    result.format = format;
    vkCheck(vkCreateImage(renderer->device, &(const VkImageCreateInfo) {
        .sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        .imageType = VK_IMAGE_TYPE_2D,
        .format = result.format,
        .extent = extent,
        .mipLevels = 1,
        .arrayLayers = 1,
        .samples = VK_SAMPLE_COUNT_1_BIT,
        .tiling = VK_IMAGE_TILING_OPTIMAL,
        .usage = usage,
    }, null, &result.image));
    VkMemoryRequirements mem_req;
    vkGetImageMemoryRequirements(renderer->device, result.image, &mem_req);
    vkCheck(vkAllocateMemory(renderer->device, &(const VkMemoryAllocateInfo) {
        .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = mem_req.size,
        .memoryTypeIndex = find_mem_type(renderer, mem_req.memoryTypeBits, properties),
    }, null, &result.memory));
    vkCheck(vkBindImageMemory(renderer->device, result.image, result.memory, 0));
    vkCheck(vkCreateImageView(renderer->device, &(const VkImageViewCreateInfo) {
        .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .viewType = VK_IMAGE_VIEW_TYPE_2D,
        .image = result.image,
        .format = result.format,
        .subresourceRange = {
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
            .aspectMask = aspect_flags,
        },
    }, null, &result.view));
    return result;
}

static void image_destroy(const GameRenderer *const renderer, Image image)
{
    vkDestroyImageView(renderer->device, image.view, null);
    vkFreeMemory(renderer->device, image.memory, null);
    vkDestroyImage(renderer->device, image.image, null);
}

static MeshData meshdata_create(const GameRenderer *const renderer, enum Mesh mesh)
{
    const VertexSlice vertex_slice = meshes[mesh];
    const usize sizeof_vertices = sizeof(Vertex) * vertex_slice.len;
    MeshData result;
    result.draw_count = vertex_slice.len;
    result.buffer = buffer_create(renderer, sizeof_vertices, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
    void *data;
    vkCheck(vkMapMemory(renderer->device, result.buffer.memory, 0, sizeof_vertices, 0, &data));
    assert(data != null);
        memcpy(data, vertex_slice.vertices, sizeof_vertices);
    vkUnmapMemory(renderer->device, result.buffer.memory);
    return result;
}

static void meshdata_destroy(const GameRenderer *const renderer, MeshData meshdata)
{
    buffer_destroy(renderer, meshdata.buffer);
}

static void swapchain_init(GameRenderer *const renderer)
{
    // getSurfaceInfo()
    {
        vkCheck(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(renderer->physical_device, renderer->surface, &renderer->surface_capabilities));
    }
    // recalculateProjectionMatrix()
    {
        // TODO: Move this to a Window resize callback/event rather than relying on Vulkan swapchain reinit
        renderer->projection = m4perspective(pi32 / 2.0f, (f32) renderer->surface_capabilities.currentExtent.width / renderer->surface_capabilities.currentExtent.height, 0.1, 100.0);
    }
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
    {
        renderer->depth_buffer = image_create(renderer, VK_FORMAT_D32_SFLOAT, VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT, (const VkExtent3D) {
            .width = renderer->surface_capabilities.currentExtent.width,
            .height = renderer->surface_capabilities.currentExtent.height,
            .depth = 1,
        }, VK_IMAGE_ASPECT_DEPTH_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
    }
    // createFramebuffers()
    {
        for (u32 i = 0; i < renderer->image_count; ++i) {
            vkCheck(vkCreateFramebuffer(renderer->device, &(const VkFramebufferCreateInfo) {
                .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                .renderPass = renderer->render_pass,
                .attachmentCount = 2,
                .pAttachments = (const VkImageView []) {
                    renderer->swapchain_image_views[i],
                    renderer->depth_buffer.view,
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
    image_destroy(renderer, renderer->depth_buffer);
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
            .attachmentCount = 2,
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
                {
                    .format = VK_FORMAT_D32_SFLOAT,
                    .samples = VK_SAMPLE_COUNT_1_BIT,
                    .loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
                    .storeOp = VK_ATTACHMENT_STORE_OP_STORE,
                    .stencilLoadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
                    .stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
                    .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
                    .finalLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
                },
            },
            .subpassCount = 1,
            .pSubpasses = &(const VkSubpassDescription) {
                .pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
                .colorAttachmentCount = 1,
                .pColorAttachments = &(const VkAttachmentReference) {
                    .attachment = 0,
                    .layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                },
                .pDepthStencilAttachment = &(const VkAttachmentReference) {
                    .attachment = 1,
                    .layout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
                },
            },
            .dependencyCount = 2,
            .pDependencies = (const VkSubpassDependency []) {
                {
                    .srcSubpass = VK_SUBPASS_EXTERNAL,
                    .dstSubpass = 0,
                    .srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                    .srcAccessMask = 0,
                    .dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                    .dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
                },
                {
                    .srcSubpass = VK_SUBPASS_EXTERNAL,
                    .dstSubpass = 0,
                    .srcStageMask = VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT | VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
                    .srcAccessMask = 0,
                    .dstStageMask = VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT | VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
                    .dstAccessMask = VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
                },
            },
        }, null, &result.render_pass));
    }
    // createShaders()
    VkShaderModule shader_module;
    {
        const b32 modcheck = len(meshspv) % 4 == 0;
        assert(modcheck);
        vkCheck(vkCreateShaderModule(result.device, &(const VkShaderModuleCreateInfo) {
            .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            .codeSize = len(meshspv),
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
                .vertexBindingDescriptionCount = len(vertex_bindings),
                .pVertexBindingDescriptions = vertex_bindings,
                .vertexAttributeDescriptionCount = len(vertex_attributes),
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
                .frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE,
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
    };

    for (usize i = 0; i < MESH_LENGTH; ++i) {
        result.gpumeshes[i] = meshdata_create(&result, i);
    }

    swapchain_init(&result);

    vkDestroyShaderModule(result.device, shader_module, null);
    return result;
}

static void record_buffer(const GameRenderer *const renderer, VkCommandBuffer buffer, u32 image_index)
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
        .clearValueCount = 2,
        .pClearValues = (const VkClearValue []) {
            { .color = { .float32 = { 0.0f, 0.0f, 0.0f, 1.0f } } },
            { .depthStencil = { .depth = 1.0f, .stencil = 0 } },
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
    const M4 vp = m4mul(renderer->projection, renderer->view);
    for (usize i = 0; i < renderer->render_objects.length; ++i) {
        const RenderObject *object = (RenderObject *)ArrayList_get(renderer->render_objects, i);
        const MeshData *meshdata = renderer->gpumeshes+object->mesh;
        vkCmdPushConstants(buffer, renderer->mesh_graphics_pipeline_layout, VK_SHADER_STAGE_VERTEX_BIT, 0, sizeof(MeshPushConstants), &(const MeshPushConstants) {
            .mvp = m4mul(vp, m4transform(object->transform)),
        });
        vkCmdBindVertexBuffers(buffer, 0, 1, &meshdata->buffer.buffer, (VkDeviceSize []){0});
        vkCmdDraw(buffer, meshdata->draw_count, 1, 0, 0);
    }
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
    for (usize i = 0; i < MESH_LENGTH; ++i) {
        meshdata_destroy(renderer, renderer->gpumeshes[i]);
    }
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

#endif

#endif