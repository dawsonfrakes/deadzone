#pragma once

typedef struct AKRenderer {
    bool32 success;
    struct APISpecificData data;
} AKRenderer;

AKRenderer renderer_init(const AKWindow *const window);
void renderer_update(AKRenderer *const renderer);
void renderer_deinit(const AKRenderer *const renderer);
