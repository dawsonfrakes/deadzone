#define __main__
#include "core.h"

// REMAINING ELEMENTS OF PORT
// Comptime enum & variable data generaton from ./shaders/* and ./meshes/*
// OBJ Parsing
// Buffer Creation
// Image Creation -> Depth Buffer

static b32 game_update(const Input input)
{
    if (input_just_pressed(KEY_ESCAPE) || input_just_pressed(KEY_Q))
        return false;

    return true;
}

int main(void)
{
    // init subsystems
    Input input = {0};
    GameWindow window = window_init(&input, "Hello, world!");
    GameRenderer renderer = renderer_init(&window);
    renderer.view = m4translate((V3) {0.0f, 0.0f, -5.0f});
    ArrayList_append(renderer.render_objects, (&(RenderObject) {
        .mesh = MESH_CUBE,
        .transform = TFI
    }));

    // loop until quit
    for (;;) {
        // update subsystems
        input_prepare();
        if (!window_update(&window)) break;
            // update game
            if (!game_update(input)) break;
        renderer_update(&renderer);
    }

    // deinit subsystems
    renderer_deinit(&renderer);
    window_deinit(&window);
}
