#pragma once

#include "AKDefines.h"

#if !defined(AKKEY_WINDOW_ACCESSOR)
#define AKKEY_WINDOW_ACCESSOR window.
#endif
#define AKKEY_JUST_PRESSED(KEY) (AKKEY_WINDOW_ACCESSOR keys[AKKEY_##KEY] && !AKKEY_WINDOW_ACCESSOR keys_previous[AKKEY_##KEY])
#define AKKEY_JUST_RELEASED(KEY) (!AKKEY_WINDOW_ACCESSOR keys[AKKEY_##KEY] && AKKEY_WINDOW_ACCESSOR keys_previous[AKKEY_##KEY])
#define k(KEY) AKKEY_##KEY
typedef enum AKKeys {
    k(A),k(B),k(C),k(D),k(E),k(F),k(G),k(H),k(I),k(J),k(K),k(L),k(M),
    k(N),k(O),k(P),k(Q),k(R),k(S),k(T),k(U),k(V),k(W),k(X),k(Y),k(Z),
    k(0),k(1),k(2),k(3),k(4),k(5),k(6),k(7),k(8),k(9),
    k(F0),k(F1),k(F2),k(F3),k(F4),k(F5),k(F6),k(F7),k(F8),k(F9),k(F10),k(F11),k(F12),
    k(LEFTARROW),k(DOWNARROW),k(UPARROW),k(RIGHTARROW),
    k(BACKTICK),k(TAB),k(CAPS),k(DELETE),k(ESCAPE),k(RETURN),
    k(MINUS),k(EQUALS),k(PERIOD),k(COMMA),k(SLASH),k(BACKSLASH),
    k(SEMICOLON),k(APOSTROPHE),k(LBRACKET),k(RBRACKET),k(BACKSPACE),
    k(LCTRL),k(LALT),k(LSHIFT),k(SPACE),k(RCTRL),k(RALT),k(RSHIFT),
    AKKEY_LENGTH
} AKKeys;
#undef k

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
