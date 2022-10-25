#pragma once

#if defined(AK_USE_WIN32)
#define VK_USE_PLATFORM_WIN32_KHR
#define AKVK_CREATE_SURFACE() vkCreateWin32SurfaceKHR(result.data.instance, &(VkWin32SurfaceCreateInfoKHR) { \
    .sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR, \
    .hwnd = window->data.hwnd, \
    .hinstance = window->data.inst \
}, NULL, &result.data.surface)
#define AKVK_SURFACE_EXTENSION_NAME VK_KHR_WIN32_SURFACE_EXTENSION_NAME
#elif defined(AK_USE_XLIB)
#define VK_USE_PLATFORM_XLIB_KHR
#define AKVK_CREATE_SURFACE() vkCreateXlibSurfaceKHR(result.data.instance, &(VkXlibSurfaceCreateInfoKHR) { \
    .sType = VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR, \
    .dpy = window->data.dpy, \
    .window = window->data.win \
}, NULL, &result.data.surface)
#define AKVK_SURFACE_EXTENSION_NAME VK_KHR_XLIB_SURFACE_EXTENSION_NAME
#else
#error Windowing system not supported by Vulkan renderer
#endif
#include <vulkan/vulkan.h>

#define AKVK_MAX_FRAMES_IN_FLIGHT 2

struct APISpecificData {
    VkInstance instance;
    VkPhysicalDevice physical_device;
    VkPhysicalDeviceMemoryProperties mem_props;
    VkPhysicalDeviceProperties props;
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
    VkCommandBuffer command_buffers[AKVK_MAX_FRAMES_IN_FLIGHT];
    VkSemaphore image_available_semaphores[AKVK_MAX_FRAMES_IN_FLIGHT];
    VkSemaphore render_complete_semaphores[AKVK_MAX_FRAMES_IN_FLIGHT];
    VkFence in_flight_fences[AKVK_MAX_FRAMES_IN_FLIGHT];
    u32 current_frame;
};
