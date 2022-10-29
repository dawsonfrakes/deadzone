#version 450

layout (location = 0) in vec4 a_position; // w=1
layout (location = 1) in vec3 a_normal;
layout (location = 2) in vec4 a_color; // w=1

layout (location = 0) out vec4 f_color;

layout (push_constant) uniform constants
{
    vec4 data;
    mat4 render_matrix;
} PushConstants;

void main()
{
    gl_Position = PushConstants.render_matrix * a_position;
    f_color = a_color;
}
