#pragma once

#include "AKDefines.h"

typedef enum AKKeys {
    AKKEY_ESCAPE,
    AKKEY_LENGTH
} AKKeys;

typedef struct AKWindow {
    int width, height;
    bool32 running;
    u8 keys[AKKEY_LENGTH];
    u8 keys_previous[AKKEY_LENGTH];
    struct PlatformSpecificData data;
} AKWindow;

AKWindow window_init(int width, int height);
void window_update(AKWindow *const window);
void window_deinit(const AKWindow *const window);
