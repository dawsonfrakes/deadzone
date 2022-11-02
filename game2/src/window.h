#pragma once

#include "defines.h"
#include "platform.h"
#include "input.h"

#if WINDOWING_API == WAPI_WIN32
    #include <windows.h>
#elif WINDOWING_API == WAPI_XLIB
    #include <X11/Xlib.h>
#endif

typedef struct GameWindow {
    Input *input;

#if WINDOWING_API == WAPI_WIN32
    HINSTANCE inst;
    HWND hwnd;
#elif WINDOWING_API == WAPI_XLIB
    Display *dpy;
    Window win;
    Atom wm_close;
#endif
} GameWindow;

GameWindow window_init(Input *const input, const char *const title);
b32 window_update(GameWindow *const window);
void window_deinit(const GameWindow *const window);
