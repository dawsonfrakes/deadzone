#version 450

layout (location = 0) in vec4 a_position; // w=1
layout (location = 1) in vec3 a_normal;
layout (location = 2) in vec2 a_texcoord;

layout (location = 0) out vec4 f_color;

layout (push_constant) uniform constants
{
    mat4 mvp;
} push;

void main()
{
    gl_Position = push.mvp * a_position;
    vec2 uv = normalize(a_position).xy;
    f_color = vec4(uv.x + 0.5, 0.0, uv.y + 0.5, 1.0);
}