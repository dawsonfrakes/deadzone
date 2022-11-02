#pragma once

#include "defines.h"
#include "platform.h"
#include "window.h"

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

typedef struct GameRenderer {
    f32 projection[4][4];
    f32 view[4][4];

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
    u32 current_frame;
#endif
} GameRenderer;

GameRenderer renderer_init(const GameWindow *const window);
void renderer_update(GameRenderer *const renderer);
void renderer_deinit(const GameRenderer *const renderer);
