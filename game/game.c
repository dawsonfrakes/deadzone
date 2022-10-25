#include "AKEngine.h"

#include <stdlib.h>

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
        if (AKKEY_JUST_PRESSED(SPACE)) {
            renderer.data.current_shader = !renderer.data.current_shader;
        }
        renderer_update(&renderer);
    }
    renderer_deinit(&renderer);
    window_deinit(&window);
}
