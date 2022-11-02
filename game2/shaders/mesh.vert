#version 450

// layout (location = 0) in vec4 a_position; // w=1
// layout (location = 1) in vec3 a_normal;
// layout (location = 2) in vec4 a_color; // w=1

layout (location = 0) out vec4 f_color;

// layout (push_constant) uniform constants
// {
//     mat4 mvp;
// } push;

vec3 positions[3] = {
    vec3(-1.0, 1.0, 0.0),
    vec3(1.0, 1.0, 0.0),
    vec3(0.0, -1.0, 0.0)
};

void main()
{
    // gl_Position = push.mvp * a_position;
    gl_Position = vec4(positions[gl_VertexIndex], 1.0);
    f_color = vec4(0.0, 1.0, 0.0, 1.0);
}
