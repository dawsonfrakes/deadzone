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

typedef struct MeshData {
    u16 draw_count;

#if RENDERING_API == RAPI_VULKAN
    VkBuffer buffer;
#endif
} MeshData;

// TODO: gen this at comptime based on files
typedef struct Vertex {
    V3 position;
    V3 normal;
    V2 texcoord;
} Vertex;

typedef struct MeshPushConstants {
    M4 mvp;
} MeshPushConstants;
static const VkVertexInputBindingDescription vertex_bindings[] = {
    {
        .binding = 0,
        .inputRate = VK_VERTEX_INPUT_RATE_VERTEX,
        .stride = sizeof(Vertex),
    }
};
static const usize vertex_bindings_len = len(vertex_bindings);

static const VkVertexInputAttributeDescription vertex_attributes[] = {
    {
        .binding = 0,
        .location = 0,
        .format = VK_FORMAT_R32G32B32_SFLOAT,
        .offset = offsetof(Vertex, position),
    },
    {
        .binding = 0,
        .location = 1,
        .format = VK_FORMAT_R32G32B32_SFLOAT,
        .offset = offsetof(Vertex, normal),
    },
    {
        .binding = 0,
        .location = 2,
        .format = VK_FORMAT_R32G32_SFLOAT,
        .offset = offsetof(Vertex, texcoord),
    },
};
static const usize vertex_attributes_len = len(vertex_attributes);

enum Mesh {
    MESH_CUBE,
    MESH_TRIANGLE,
    MESH_LENGTH,
};

static const char *mesh_filename[MESH_LENGTH] = {
    [MESH_CUBE] = "meshes/cube.obj",
    [MESH_TRIANGLE] = "meshes/triangle.obj",
};
// ENDTODO

typedef struct RenderObject {
    Transform transform;
    enum Mesh mesh;
} RenderObject;

typedef struct GameRenderer {
    M4 projection;
    M4 view;
    ArrayList/*RenderObject*/ render_objects;
    MeshData meshes[MESH_LENGTH]/* -> EnumArray(Mesh, MeshData) */;

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
