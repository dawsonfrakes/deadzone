#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <float.h>

#define null ((void *)0)
#define true 1
#define false 0
#define assert(check) do { if (!(check)) { fprintf(stderr, #check "\n"); abort(); } } while (0)
#define pi32 3.141597f
#define rad(d) (d*(pi32/180.0f))
#define deg(r) (r*(180.0f/pi32))
#define min(a, b) ((a) < (b) ? (a) : (b))
#define max(a, b) ((a) > (b) ? (a) : (b))
#define len(array) (sizeof(array)/sizeof((array)[0]))

typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef uintptr_t usize;

typedef int8_t i8;
typedef int16_t i16;
typedef int32_t i32;
typedef int64_t i64;
typedef intptr_t isize;

typedef uint32_t b32;

typedef float f32;
typedef double f64;

typedef struct ArrayList {
    size_t size;
    size_t length;
    size_t capacity;
    void *data;
} ArrayList;

#define ArrayList_init(type) { .size = sizeof(type), .length = 0, .capacity = 0, .data = NULL }
#define ArrayList_resize(list, length) do { list.capacity = (length); list.data = realloc(list.data, list.size * list.capacity); } while (0)
#define ArrayList_has_space(list) (list.capacity - list.length > 0)
#define ArrayList_get(list, index) ((uint8_t *)(list.data)+(list.size * index))
#define ArrayList_append(list, element_ptr) do { if (!ArrayList_has_space(list)) ArrayList_resize(list, list.capacity + 3); memcpy(ArrayList_get(list, list.length), element_ptr, list.size); ++list.length; } while (0)
#define ArrayList_delete(list, index) do { memmove(ArrayList_get(list, index + 1), ArrayList_get(list, index), list.size * (list.length - 1 - index)); --list.length; } while (0)
#define ArrayList_deinit(list) do { free(list.data); } while (0)

typedef struct V2 { f32 x, y; } V2;
typedef struct V3 { f32 x, y, z; } V3;
typedef struct V4 { f32 x, y, z, w; } V4;

#define viterptr(v) ((f32 *) &v)
#define viterptrconst(v) ((const f32 *) &v)
#define V2O { .x = 0.0f, .y = 0.0f }
#define V2I { .x = 1.0f, .y = 1.0f }
#define V3O { .x = 0.0f, .y = 0.0f, .z = 0.0f }
#define V3I { .x = 1.0f, .y = 1.0f, .z = 1.0f }
#define V4O { .x = 0.0f, .y = 0.0f, .z = 0.0f, .w = 0.0f }
#define V4I { .x = 1.0f, .y = 1.0f, .z = 1.0f, .w = 1.0f }

typedef struct Transform {
    V3 position;
    V3 rotation;
    V3 scale;
} Transform;

#define TFI { .position = V3O, .rotation = V3O, .scale = V3I }

typedef struct M4 {
    f32 m[4][4];
} M4;

#define M4O { .m = { {0.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 0.0f} } }
#define M4I { .m = { {1.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 1.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 1.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 1.0f} } }

V3 v3mul(V3 a, f32 b);
f32 v3len(V3 v);
V3 v3norm(V3 v);
M4 m4perspective(f32 fovy, f32 aspect, f32 znear, f32 zfar);
M4 m4mul(M4 a, M4 b);
V4 m4mulv4(M4 a, V4 b);
M4 m4rotationx(f32 angle);
M4 m4rotationy(f32 angle);
M4 m4rotationz(f32 angle);
M4 m4translate(V3 t);
M4 m4rotate(V3 r);
M4 m4scale(V3 s);
M4 m4transform(Transform transform);

#ifdef __main__

V3 v3mul(V3 a, f32 b)
{
    V3 result;
    result.x = a.x * b;
    result.y = a.y * b;
    result.z = a.z * b;
    return result;
}

f32 v3len(V3 v)
{
    return sqrtf(v.x * v.x + v.y * v.y + v.z * v.z);
}

V3 v3norm(V3 v)
{
    const f32 len = v3len(v);
    if (fabsf(len) < FLT_EPSILON) return (V3) V3O;
    return v3mul(v, 1.0f / len);
}

M4 m4perspective(f32 fovy, f32 aspect, f32 znear, f32 zfar)
{
    const f32 focal_length = 1.0f / tanf(fovy / 2.0f);

    M4 result = M4O;
    // map x coordinates to clip-space
    result.m[0][0] = focal_length / aspect;
    // map y coordinates to clip-space
    result.m[1][1] = -focal_length;
    // map z coordinates to clip-space (near:1-far:0)
    result.m[2][2] = znear / (zfar - znear);
    result.m[3][2] = (znear * zfar) / (zfar - znear);
    // copy -z into w for perspective divide
    result.m[2][3] = -1.0f;
    return result;
}

M4 m4mul(M4 a, M4 b)
{
    M4 result = M4O;
    for (int col = 0; col < 4; ++col)
        for (int row = 0; row < 4; ++row)
            for (int i = 0; i < 4; ++i)
                result.m[col][row] += a.m[i][row] * b.m[col][i];
    return result;
}

V4 m4mulv4(M4 a, V4 b)
{
    V4 result = V4O;
    for (int row = 0; row < 4; ++row)
        for (int i = 0; i < 4; ++i)
            viterptr(result)[i] += a.m[i][row] * viterptrconst(b)[i];
    return result;
}

M4 m4rotationx(f32 angle)
{
    M4 result = M4I;
    const f32 c = cosf(angle);
    const f32 s = sinf(angle);
    result.m[1][1] = c;
    result.m[2][1] = -s;
    result.m[1][2] = s;
    result.m[2][2] = c;
    return result;
}

M4 m4rotationy(f32 angle)
{
    M4 result = M4I;
    const f32 c = cosf(angle);
    const f32 s = sinf(angle);
    result.m[0][0] = c;
    result.m[2][0] = s;
    result.m[0][2] = -s;
    result.m[2][2] = c;
    return result;
}

M4 m4rotationz(f32 angle)
{
    M4 result = M4I;
    const f32 c = cosf(angle);
    const f32 s = sinf(angle);
    result.m[0][0] = c;
    result.m[1][0] = -s;
    result.m[0][1] = s;
    result.m[1][1] = c;
    return result;
}

M4 m4translate(V3 t)
{
    M4 result = M4I;
    for (int i = 0; i < 3; ++i) {
        result.m[3][i] = viterptrconst(t)[i];
    }
    return result;
}

M4 m4rotate(V3 r)
{
    return m4mul(m4rotationz(r.z), m4mul(m4rotationx(r.x), m4rotationy(r.y)));
}

M4 m4scale(V3 s)
{
    M4 result = M4I;
    for (int i = 0; i < 3; ++i) {
        result.m[i][i] = viterptrconst(s)[i];
    }
    return result;
}

M4 m4transform(Transform transform)
{
    return m4mul(m4translate(transform.position), m4mul(m4rotate(transform.rotation), m4scale(transform.scale)));
}

#endif

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

#include "platform.h"
#include "window.h"
#include "renderer.h"
