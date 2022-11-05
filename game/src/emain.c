#define __main__
#include "engine.h"

int main(void)
{
    // init subsystems
    GameInput input = {0};
    GameWindow window = window_init(&input, "Hello, world!");
    GameRenderer renderer = renderer_init(&window);
    GameTime gtime; time_init(gtime);

    load_game_functions();

    init(&renderer);

    // loop until quit
    b32 running = true;
    b32 reload = false;
    for (;;) {
        // update subsystems
        input_prepare(input);
        if (!window_update(&window)) break;
        time_update(gtime);
            // update game
            update(&reload, &running, &renderer, input, gtime);
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
}
