#pragma once

#include <Windows.h>

struct PlatformSpecificData {
    HWND hwnd;
    HINSTANCE inst;
};

#include "AKWindow.h"
