#pragma once

#define K(KEY) KEY_##KEY

typedef enum Keys {
    K(A), K(B), K(C), K(D), K(E), K(F), K(G), K(H), K(I), K(J), K(K), K(L), K(M), K(N), K(O), K(P), K(Q), K(R), K(S), K(T), K(U), K(V), K(W), K(X), K(Y), K(Z),
    K(F1), K(F2), K(F3), K(F4), K(F5), K(F6), K(F7), K(F8), K(F9), K(F10), K(F11), K(F12),
    K(LEFT_ARROW), K(DOWN_ARROW), K(UP_ARROW), K(RIGHT_ARROW),
    K(BACKTICK), K(MINUS), K(EQUALS), K(PERIOD), K(COMMA), K(SLASH), K(BACKSLASH), K(SEMICOLON), K(APOSTROPHE), K(LEFT_BRACKET), K(RIGHT_BRACKET),
    K(BACKSPACE), K(TAB), K(CAPS), K(SPACE), K(ESCAPE), K(RETURN), K(DELETE),
    K(LEFT_CONTROL), K(LEFT_ALT), K(LEFT_SHIFT), K(RIGHT_CONTROL), K(RIGHT_ALT), K(RIGHT_SHIFT),
    KEYS_LENGTH
} Keys;

#undef K

typedef struct Input {
    u8 keys[KEYS_LENGTH];
    u8 keys_previous[KEYS_LENGTH];
} Input;

#ifndef input_accessor
#define input_accessor input.
#endif
#define input_pressed(key) input_accessor keys[key]
#define input_released(key) !input_accessor keys[key]
#define input_just_pressed(key) (input_accessor keys[key] && !input_accessor keys_previous[key])
#define input_just_released(key) (!input_accessor keys[key] && input_accessor keys_previous[key])
#define input_prepare() do { for (usize i = 0; i < KEYS_LENGTH; ++i) input_accessor keys_previous[i] = input_accessor keys[i]; } while (0)
