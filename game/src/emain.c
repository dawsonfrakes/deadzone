#define __main__
#include "engine.h"

int main(void)
{
    // init subsystems
    struct MemoryMapping *memory = calloc(b_per_gb, 1);
    assert(memory);
    GameInput input = {0};
    GameWindow window = window_init(&input, "Hello, world!");
    GameRenderer renderer = renderer_init(&window);
    GameTime gtime; time_init(gtime);

    load_game_functions();

    init(memory, &renderer);

    // loop until quit
    b32 running = true;
    b32 reload = false;
    for (;;) {
        // update subsystems
        input_prepare(input);
        if (!window_update(&window)) break;
        time_update(gtime);
            // update game
            update(memory, &reload, &running, &renderer, input, gtime);
            if (!running) break;
            if (reload) {
                reload = false;
                reload_game_functions();
            }
        renderer_update(&renderer);
    }

    // deinit subsystems
    renderer_deinit(&renderer);
    window_deinit(&window);
    free(memory);
}
