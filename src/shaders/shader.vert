#version 450

layout (location = 0) in vec4 a_position; // w=1
layout (location = 1) in vec4 a_color; // w=1
layout (location = 2) in vec2 a_texcoord;

layout (location = 0) out vec4 f_color;
layout (location = 1) out vec4 f_position;
layout (location = 2) out vec2 f_texcoord;

uniform mat4 mvp;

void main()
{
    gl_Position = mvp * a_position;
    f_position = a_position;
    f_color = a_color;
    f_texcoord = a_texcoord;
}
