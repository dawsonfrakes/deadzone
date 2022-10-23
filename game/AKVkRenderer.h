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
};

#include "AKRenderer.h"

#ifdef INCLUDE_SRC

#define AKRenderer_VKCheck(vkresult) if ((vkresult) != VK_SUCCESS) {return result;}

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
        .enabledExtensionCount = 2,
        .ppEnabledExtensionNames = (const char *const []) {VK_KHR_SURFACE_EXTENSION_NAME, VK_KHR_XLIB_SURFACE_EXTENSION_NAME}
    }, NULL, &result.data.instance));

    // createSurface()
    {
#if defined(AK_USE_WIN32)
        AKRenderer_VKCheck(vkCreateWin32SurfaceKHR(result.data.instance, &(VkWin32SurfaceCreateInfoKHR) {
            .sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
            .hwnd = window->data.hwnd,
            .hinstance = window->data.inst
        }, NULL, &result.data.surface));
#elif defined(AK_USE_XLIB)
        AKRenderer_VKCheck(vkCreateXlibSurfaceKHR(result.data.instance, &(VkXlibSurfaceCreateInfoKHR) {
            .sType = VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
            .dpy = window->data.dpy,
            .window = window->data.win
        }, NULL, &result.data.surface));
#else
#error Windowing system not supported by Vulkan renderer
#endif
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
        }
        AKAssert(result.data.graphics_queue_family_index != nullopt);
        AKAssert(result.data.present_queue_family_index != nullopt);
    }

    // createLogicalDevice()
    {
        const bool32 same_family = result.data.graphics_queue_family_index == result.data.present_queue_family_index;
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
                },
            },
            .pEnabledFeatures = &(VkPhysicalDeviceFeatures) {0},
            .enabledExtensionCount = 1,
            .ppEnabledExtensionNames = (const char *const []) {VK_KHR_SWAPCHAIN_EXTENSION_NAME}
        }, NULL, &result.data.device));

        vkGetDeviceQueue(result.data.device, result.data.graphics_queue_family_index, 0, &result.data.graphics_queue);
        vkGetDeviceQueue(result.data.device, result.data.present_queue_family_index, 0, &result.data.present_queue);
    }

    result.success = true;
    return result;
}

void renderer_update(AKRenderer *const renderer)
{
}

void renderer_deinit(const AKRenderer *const renderer)
{
    vkDestroyDevice(renderer->data.device, NULL);
    vkDestroySurfaceKHR(renderer->data.instance, renderer->data.surface, NULL);
    vkDestroyInstance(renderer->data.instance, NULL);
}

#endif
