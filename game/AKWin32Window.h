#pragma once

#include <Windows.h>

struct PlatformSpecificData {
    HWND hwnd;
    HINSTANCE inst;
};

#include "AKWindow.h"

AKWindow window_init(i32 width, i32 height)
{

}

void window_update(AKWindow *const window)
{

}

void window_deinit(const AKWindow *const window)
{

}
