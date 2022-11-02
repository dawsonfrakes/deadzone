#define MAINFILE
#include "input.h"
#include "window.h"
#include "renderer.h"

static b32 game_update(const Input input)
{
    if (input_just_pressed(input, KEY_ESCAPE) || input_just_pressed(input, KEY_Q))
        return false;

    return true;
}

int main(void)
{
    // init subsystems
    Input input = {0};
    GameWindow window = window_init(&input, "Hello, world!");
    GameRenderer renderer = renderer_init(&window);

    // loop until quit
    for (;;) {
        // update subsystems
        input_prepare(&input);
        if (!window_update(&window)) break;
            // update game
            if (!game_update(input)) break;
        renderer_update(&renderer);
    }

    // deinit subsystems
    renderer_deinit(&renderer);
    window_deinit(&window);
}
