#include "window.h"

#include <stdio.h>
#include <stdlib.h>
#include <X11/keysym.h>

GameWindow window_init(Input *const input, const char *const title)
{
    GameWindow result = {0};
    result.input = input;
    assert(result.dpy = XOpenDisplay(null));
    XAutoRepeatOff(result.dpy);
    const int scr = DefaultScreen(result.dpy);
    const Window root = RootWindow(result.dpy, scr);
    result.win = XCreateWindow(
        result.dpy,
        root,
        0, 0,
        800, 600,
        0,
        CopyFromParent,
        InputOutput,
        CopyFromParent,
        CWEventMask,
        &(XSetWindowAttributes) {
            .event_mask = ExposureMask|KeyPressMask|KeyReleaseMask
        }
    );
    result.wm_close = XInternAtom(result.dpy, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(result.dpy, result.win, &result.wm_close, 1);
    if (title)
        XStoreName(result.dpy, result.win, title);
    XMapWindow(result.dpy, result.win);
    return result;
}

static const u16 Keymap[KEYS_LENGTH] = {
    [KEY_A] = XK_a, XK_b, XK_c, XK_d, XK_e, XK_f, XK_g, XK_h, XK_i, XK_j, XK_k, XK_l, XK_m, XK_n, XK_o, XK_p, XK_q, XK_r, XK_s, XK_t, XK_u, XK_v, XK_w, XK_x, XK_y, XK_z,
    [KEY_F1] = XK_F1, XK_F2, XK_F3, XK_F4, XK_F5, XK_F6, XK_F7, XK_F8, XK_F9, XK_F10, XK_F11, XK_F12,
    [KEY_LEFT_ARROW] = XK_Left, XK_Down, XK_Up, XK_Right,
    [KEY_ESCAPE] = XK_Escape,
};

b32 window_update(GameWindow *const window)
{
    while (XPending(window->dpy) > 0) {
        XEvent ev;
        XNextEvent(window->dpy, &ev);
        switch (ev.type) {
            case Expose: {
                printf("Window(w=%d, h=%d)\n", ev.xexpose.width, ev.xexpose.height);
            } break;
            case KeyPress:
            case KeyRelease: {
                const KeySym sym = XLookupKeysym(&ev.xkey, 0);
                const u8 pressed = ev.type == KeyPress;
                for (usize i = 0; i < KEYS_LENGTH; ++i) {
                    if (Keymap[i] == sym)
                        window->input->keys[i] = pressed;
                }
            } break;
            case MappingNotify: {
                XRefreshKeyboardMapping(&ev.xmapping);
            } break;
            case ClientMessage: {
                if (ev.xclient.data.l[0] == (long) window->wm_close) {
                    return false;
                }
            } break;
            case DestroyNotify: {
                return false;
            } break;
        }
    }
    return true;
}

void window_deinit(const GameWindow *const window)
{
    XAutoRepeatOn(window->dpy);
    XCloseDisplay(window->dpy);
}
