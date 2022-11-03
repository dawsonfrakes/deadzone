#pragma once

typedef struct V2 { f32 x, y; } V2;
typedef struct V3 { f32 x, y, z; } V3;
typedef struct V4 { f32 x, y, z, w; } V4;

#define viterptr(v) ((f32 *) &v)
#define viterptrconst(v) ((const f32 *) &v)
#define V40 { .x = 0.0f, .y = 0.0f, .z = 0.0f, .w = 0.0f }

typedef struct Transform {
    V3 position;
    V3 rotation;
    V3 scale;
} Transform;

typedef struct M4 {
    f32 m[4][4];
} M4;

#define M4O { .m = { {0.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 0.0f} } }
#define M4I { .m = { {1.0f, 0.0f, 0.0f, 0.0f}, {0.0f, 1.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 1.0f, 0.0f}, {0.0f, 0.0f, 0.0f, 1.0f} } }

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
    V4 result = V40;
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
