#pragma once

#include <X11/Xlib.h>

struct PlatformSpecificData {
    Display *dpy;
    int scr;
    Window win;
    Atom wm_delete;
};

#include "AKWindow.h"

#ifdef INCLUDE_SRC

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <X11/keysym.h>

AKWindow window_init(int width, int height)
{
    AKWindow result = {
        .width = width,
        .height = height
    };

    AKAssert(result.data.dpy = XOpenDisplay(NULL));
    XAutoRepeatOff(result.data.dpy);

    result.data.scr = DefaultScreen(result.data.dpy);

    AKAssert(result.data.win = XCreateWindow(
        result.data.dpy,
        RootWindow(result.data.dpy, result.data.scr),
        0, 0,
        result.width, result.height,
        0,
        CopyFromParent,
        InputOutput,
        CopyFromParent,
        CWBackPixel|CWEventMask,
        &(XSetWindowAttributes) {
            .background_pixel = BlackPixel(result.data.dpy, result.data.scr),
            .event_mask = ExposureMask|KeyPressMask|KeyReleaseMask
        }
    ));

    XMapWindow(result.data.dpy, result.data.win);

    result.data.wm_delete = XInternAtom(result.data.dpy, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(result.data.dpy, result.data.win, &result.data.wm_delete, 1);

    XSync(result.data.dpy, False);
    result.running = true;
    return result;
}

void window_update(AKWindow *const window)
{
    memcpy(window->keys_previous, window->keys, sizeof(window->keys)); // cpy prev to keys
    while (XPending(window->data.dpy) > 0) {
        XEvent ev;
        XNextEvent(window->data.dpy, &ev);
        switch (ev.type) {
            case Expose: {
                window->width = ev.xexpose.width;
                window->height = ev.xexpose.height;
                printf("Window(w=%d, h=%d)\n", ev.xexpose.width, ev.xexpose.height);
            } break;
            case KeyPress:
            case KeyRelease: {
                const KeySym sym = XLookupKeysym(&ev.xkey, 0);
                const u8 pressed = ev.type == KeyPress;
                switch (sym) {
                    case XK_Escape: window->keys[AKKEY_ESCAPE] = pressed; break;
                }
            } break;
            case MappingNotify: {
                XRefreshKeyboardMapping(&ev.xmapping);
            } break;
            case ClientMessage: {
                if (ev.xclient.data.l[0] == (long) window->data.wm_delete)
                    window->running = false;
            } break;
            case DestroyNotify: {
                window->running = false;
            } break;
        }
    }
}

void window_deinit(const AKWindow *const window)
{
    XDestroyWindow(window->data.dpy, window->data.win);
    XAutoRepeatOn(window->data.dpy);
    XSync(window->data.dpy, False);
    XCloseDisplay(window->data.dpy);
}

#endif /* INCLUDE_SRC */
