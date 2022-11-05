// 2>/dev/null; cc -shared -fPIC -o out/game.so $0; exit
#include "engine.h"

struct MemoryMapping {
    usize object_id;
    u8 unused[];
};

void init(struct MemoryMapping *const memory, GameRenderer *const renderer)
{
    renderer->view = m4translate((V3) {0.0f, 0.0f, -5.0f});
    ArrayList_append(renderer->render_objects, (&(RenderObject) {
        .mesh = MESH_CUBE,
        .transform = TFI
    }));
    memory->object_id = renderer->render_objects.length;
    ArrayList_append(renderer->render_objects, (&(RenderObject) {
        .mesh = MESH_CUBE,
        .transform = {
            .position = { 5.0, 0.0, 0.0 },
            .scale = V3I
        }
    }));
}

void update(struct MemoryMapping *const memory, b32 *reload, b32 *running, GameRenderer *const renderer, const GameInput input, const GameTime Time)
{
    if (input_just_pressed(input, KEY_ESCAPE) || input_just_pressed(input, KEY_Q))
        *running = false;

    if (input_just_pressed(input, KEY_R)) {
        *reload = true;
    }

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

    ((RenderObject *)ArrayList_get(renderer->render_objects, memory->object_id))->transform.rotation.x += (pi32 / 2.0f) * Time.delta;
    ((RenderObject *)ArrayList_get(renderer->render_objects, memory->object_id))->transform.rotation.z += (pi32 / 2.0f) * Time.delta;
}
