#define __main__
#include "engine.h"
#include "platform.h"
#include "window.h"
#include "renderer.h"

int main(void)
{
    // init subsystems
    struct MemoryMapping *memory = calloc(b_per_gb, 1);
    assert(memory);
    GameInput Input = {0};
    GameWindow window = window_init(&Input, "Hello, world!");
    GameRenderer renderer = renderer_init(&window);
    GameTime Time = time_init();

    renderer.view = m4translate((V3) {0.0f, 0.0f, -5.0f});
    ArrayList_append(renderer.render_objects, (&(RenderObject) {
        .mesh = MESH_CUBE,
        .transform = TFI
    }));
    usize object_id = renderer.render_objects.length;
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
        input_prepare(&Input);
        if (!window_update(&window)) break;
        time_update(&Time);
            // update game
            if (input_just_pressed(Input, KEY_ESCAPE) || input_just_pressed(Input, KEY_Q))
                break;

            V3 direction = V3O;
            if (input_pressed(Input, KEY_W)) {
                direction.z -= 1.0f;
            }
            if (input_pressed(Input, KEY_S)) {
                direction.z += 1.0f;
            }
            if (input_pressed(Input, KEY_D)) {
                direction.x += 1.0f;
            }
            if (input_pressed(Input, KEY_A)) {
                direction.x -= 1.0f;
            }
            direction = v3norm(direction);

            const f32 speed = 5.0;
            // -1 because view moves in opposite direction of camera
            renderer.view = m4mul(m4translate(v3mul(direction, -1.0f * speed * Time.delta)), renderer.view);

            ((RenderObject *)ArrayList_get(renderer.render_objects, object_id))->transform.rotation.x += (pi32 / 2.0f) * Time.delta;
            ((RenderObject *)ArrayList_get(renderer.render_objects, object_id))->transform.rotation.z += (pi32 / 2.0f) * Time.delta;

        renderer_update(&renderer);
    }

    // deinit subsystems
    renderer_deinit(&renderer);
    window_deinit(&window);
    free(memory);
}
