// 2>/dev/null; for FILE in shader.*; do glslc $FILE -o ${FILE##*.}.spv; done; gcc -std=c99 -Wall -Wextra -pedantic $0 -lX11 -lvulkan -lm -D_POSIX_C_SOURCE=200809L && ./a.out; exit
// Dawson, 10/23/22:
//  I had just thrown this together in C++ but it wouldn't let me do what I
//  wanted with designated initializers and references to temporary rvalues,
//  so I ditched it for good ole C. However, the structure of the program
//  was easy to lay out in C++, so I attempted to copy that abstraction into C.
// Dawson, 10/23/22:
//  I should probably note the way I run these projects is with `sh game.c` so I can avoid using a make program.

#define INCLUDE_SRC
// NOTE: for debugging
#define AK_USE_XLIB
#define AK_USE_VULKAN

#if defined(AK_USE_WIN32)
#include "AKWin32Window.h"
#elif defined(AK_USE_XLIB)
#include "AKX11Window.h"
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
    if (!window.running) return EXIT_FAILURE;
    AKRenderer renderer = renderer_init(&window);
    if (!renderer.success) return EXIT_FAILURE;
    while (window.running) {
        window_update(&window);
        if (AKKEY_JUST_PRESSED(ESCAPE) || AKKEY_JUST_PRESSED(Q))
            window.running = false;
        renderer_update(&renderer);
    }
    renderer_deinit(&renderer);
    window_deinit(&window);
}
