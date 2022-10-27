#version 450

layout (location = 0) in vec4 a_position; // w=1
layout (location = 1) in vec3 a_normal;
layout (location = 2) in vec4 a_color; // w=1

layout (location = 0) out vec4 f_color;

void main()
{
    gl_Position = a_position;
    f_color = a_color;
}
