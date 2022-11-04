#define __main__
#include "engine.h"

static usize my_obj_i;

static b32 game_update(GameRenderer *const renderer, const GameInput input, const GameTime Time)
{
    if (input_just_pressed(input, KEY_ESCAPE) || input_just_pressed(input, KEY_Q))
        return false;

    V3 direction = V3O;
    if (input_pressed(input, KEY_W)) {
        direction.z -= 1.0f;
    }
    if (input_pressed(input, KEY_S)) {
        direction.z += 1.0f;
    }
    if (input_pressed(input, KEY_D)) {
        direction.x += 1.0f;
    }
    if (input_pressed(input, KEY_A)) {
        direction.x -= 1.0f;
    }
    direction = v3norm(direction);

    const f32 speed = 5.0;
    // -1 because view moves in opposite direction of camera
    renderer->view = m4mul(m4translate(v3mul(direction, -1.0f * speed * Time.delta)), renderer->view);

    ((RenderObject *)ArrayList_get(renderer->render_objects, my_obj_i))->transform.rotation.x += (pi32 / 2.0f) * Time.delta;
    ((RenderObject *)ArrayList_get(renderer->render_objects, my_obj_i))->transform.rotation.z += (pi32 / 2.0f) * Time.delta;
    return true;
}

int main(void)
{
    // init subsystems
    GameInput input = {0};
    GameWindow window = window_init(&input, "Hello, world!");
    GameRenderer renderer = renderer_init(&window);
    GameTime gtime; time_init(gtime);
    renderer.view = m4translate((V3) {0.0f, 0.0f, -5.0f});
    ArrayList_append(renderer.render_objects, (&(RenderObject) {
        .mesh = MESH_CUBE,
        .transform = TFI
    }));
    my_obj_i = renderer.render_objects.length;
    ArrayList_append(renderer.render_objects, (&(RenderObject) {
        .mesh = MESH_CUBE,
        .transform = {
            .position = { 5.0, 0.0, 0.0 },
            .scale = V3I
        }
    }));

    // loop until quit
    for (;;) {
        // update subsystems
        input_prepare(input);
        if (!window_update(&window)) break;
        time_update(gtime);
            // update game
            if (!game_update(&renderer, input, gtime)) break;
        renderer_update(&renderer);
    }

    // deinit subsystems
    renderer_deinit(&renderer);
    window_deinit(&window);
}