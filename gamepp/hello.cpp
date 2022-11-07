// 2>/dev/null; set -e; tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT; clang++ -std=c++20 -Wall -Wextra -pedantic -o "$tmp" "$0" -lvulkan && "$tmp" $@; exit

#include <array>
#include <iostream>
#include <vulkan/vulkan.h>

struct Renderer {
    virtual void update() = 0;
};

struct VulkanRenderer : Renderer {
    VkInstance instance;

    VulkanRenderer()
    {
        const auto layers = std::to_array({"VK_LAYER_KHRONOS_validation"});
        const VkInstanceCreateInfo info {
            .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .enabledLayerCount = layers.size(),
            .ppEnabledLayerNames = layers.data(),
        };
        VkResult r= vkCreateInstance(&info, nullptr, &instance);
        std::cout << r << std::endl;
    }

    ~VulkanRenderer()
    {
        vkDestroyInstance(instance, nullptr);
    }

    void update() final override
    {

    }
};

using GameRenderer = VulkanRenderer;

int main()
{
    GameRenderer renderer{};

    for (auto x : {5, 10, 15, 20}) {
        std::cout << x << std::endl;
    }
}
