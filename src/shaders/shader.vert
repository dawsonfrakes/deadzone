#version 450

layout (location = 0) in vec4 a_position; // w=1
layout (location = 1) in vec4 a_color; // w=1

layout (location = 0) out vec4 f_color;

uniform mat4 mvp;

void main()
{
    gl_Position = mvp * a_position;
    f_color = a_color;
}
