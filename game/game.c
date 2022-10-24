// 2>/dev/null; for FILE in shader.*; do glslc $FILE -o ${FILE##*.}.spv; done; gcc -std=c99 -Wall -Wextra -pedantic $0 -lX11 -lvulkan && ./a.out; exit
// Dawson, 10/23/22:
//  I had just thrown this together in C++ but it wouldn't let me do what I
//  wanted with designated initializers and references to temporary rvalues,
//  so I ditched it for good ole C. However, the structure of the program
//  was easy to lay out in C++, so I attempted to copy that abstraction into C.

#define INCLUDE_SRC
// NOTE: for debugging
#define AK_USE_XLIB
#define AK_USE_VULKAN

#if defined(AK_USE_WIN32)
#include "AKWin32Window.h"
#define VK_USE_PLATFORM_WIN32_KHR
#elif defined(AK_USE_XLIB)
#include "AKX11Window.h"
#define VK_USE_PLATFORM_XLIB_KHR
#else
#error No windowing system selected
#endif

#if defined(AK_USE_VULKAN)
#include "AKVkRenderer.h"
#else
#error No rendering system selected
#endif

int main(void)
{
    AKWindow window = window_init(800, 600);
    if (!window.running) return 1;
    AKRenderer renderer = renderer_init(&window);
    if (!renderer.success) return 1;
    while (window.running) {
        window_update(&window);
        if (window.keys[AKKEY_ESCAPE])
            window.running = false;
        renderer_update(&renderer);
    }
    renderer_deinit(&renderer);
    window_deinit(&window);
}
