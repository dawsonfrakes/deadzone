#define __main__
#include "engine.h"

// REMAINING ELEMENTS OF PORT
// Time

static usize my_obj_i;

static b32 game_update(GameRenderer *const renderer, const Input input)
{
    if (input_just_pressed(KEY_ESCAPE) || input_just_pressed(KEY_Q))
        return false;


    V3 direction = V3O;
    if (input_pressed(KEY_W)) {
        direction.z -= 1.0f;
    }
    if (input_pressed(KEY_S)) {
        direction.z += 1.0f;
    }
    if (input_pressed(KEY_D)) {
        direction.x += 1.0f;
    }
    if (input_pressed(KEY_A)) {
        direction.x -= 1.0f;
    }
    direction = v3norm(direction);

    const f32 speed = 5.0;
    const f32 delta_time = 1.0f/300;
    // -1 because view moves in opposite direction of camera
    renderer->view = m4mul(m4translate(v3mul(direction, -1.0f * speed * delta_time)), renderer->view);

    ((RenderObject *)ArrayList_get(renderer->render_objects, my_obj_i))->transform.rotation.y += pi32 / 1000.0f;
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
    my_obj_i = renderer.render_objects.length;
    ArrayList_append(renderer.render_objects, (&(RenderObject) {
        .mesh = MESH_CUBE,
        .transform = {
            .position = { 0.0, 0.0, -5.0 },
            .scale = V3I
        }
    }));

    // loop until quit
    for (;;) {
        // update subsystems
        input_prepare();
        if (!window_update(&window)) break;
            // update game
            if (!game_update(&renderer, input)) break;
        renderer_update(&renderer);
    }

    // deinit subsystems
    renderer_deinit(&renderer);
    window_deinit(&window);
}
