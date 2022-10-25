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

AKWindow window_init(i32 width, i32 height)
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

static const u16 KEYTABLE[AKKEY_LENGTH] = {
    [AKKEY_A] = XK_a,XK_b,XK_c,XK_d,XK_e,XK_f,XK_g,XK_h,XK_i,XK_j,XK_k,XK_l,XK_m,
                XK_n,XK_o,XK_p,XK_q,XK_r,XK_s,XK_t,XK_u,XK_v,XK_w,XK_x,XK_y,XK_z,
    [AKKEY_0] = XK_0,XK_1,XK_2,XK_3,XK_4,XK_5,XK_6,XK_7,XK_8,XK_9,
    [AKKEY_F1] = XK_F1,XK_F2,XK_F3,XK_F4,XK_F5,XK_F6,XK_F7,XK_F8,XK_F9,XK_F10,XK_F11,XK_F12,
    [AKKEY_LEFTARROW] = XK_Left,
    [AKKEY_DOWNARROW] = XK_Down,
    [AKKEY_UPARROW] = XK_Up,
    [AKKEY_RIGHTARROW] = XK_Right,
    [AKKEY_BACKTICK] = XK_grave,
    [AKKEY_TAB] = XK_Tab,
    [AKKEY_CAPS] = XK_Caps_Lock,
    [AKKEY_DELETE] = XK_Delete,
    [AKKEY_ESCAPE] = XK_Escape,
    [AKKEY_RETURN] = XK_Return,
    [AKKEY_MINUS] = XK_minus,
    [AKKEY_EQUALS] = XK_equal,
    [AKKEY_PERIOD] = XK_period,
    [AKKEY_COMMA] = XK_comma,
    [AKKEY_SLASH] = XK_slash,
    [AKKEY_BACKSLASH] = XK_backslash,
    [AKKEY_SEMICOLON] = XK_semicolon,
    [AKKEY_APOSTROPHE] = XK_apostrophe,
    [AKKEY_LBRACKET] = XK_bracketleft,
    [AKKEY_RBRACKET] = XK_bracketright,
    [AKKEY_BACKSPACE] = XK_BackSpace,
    [AKKEY_LCTRL] = XK_Control_L,
    [AKKEY_LALT] = XK_Alt_L,
    [AKKEY_LSHIFT] = XK_Shift_L,
    [AKKEY_SPACE] = XK_space,
    [AKKEY_RCTRL] = XK_Control_R,
    [AKKEY_RALT] = XK_Alt_R,
    [AKKEY_RSHIFT] = XK_Shift_R,
};

void window_update(AKWindow *const window)
{
    memcpy(window->keys_previous, window->keys, sizeof(window->keys));
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
                for (usize i = 0; i < AKKEY_LENGTH; ++i) {
                    if (KEYTABLE[i] == sym) {
                        window->keys[i] = pressed;
                        break;
                    }
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
