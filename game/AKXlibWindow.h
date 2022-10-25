#pragma once

#include <X11/Xlib.h>

struct PlatformSpecificData {
    Display *dpy;
    int scr;
    Window win;
    Atom wm_delete;
};
