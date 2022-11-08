#version 450

layout (location = 0) in vec3 a_position; // w=1.0
layout (location = 1) in vec3 a_normal;
layout (location = 2) in vec2 a_texcoord;

layout (location = 0) out vec3 f_color;

vec3[] positions = {
    vec3( 0.0,  1.0, 0.0),
    vec3(-1.0, -1.0, 0.0),
    vec3( 1.0, -1.0, 0.0),
};

layout (push_constant) uniform constants
{
    mat4 mvp;
} push;

void main()
{
    gl_Position = push.mvp * vec4(positions[gl_VertexIndex], 1.0);
    f_color = vec3(1.0, 0.0, 1.0);
}
