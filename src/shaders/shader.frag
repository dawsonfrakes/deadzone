#version 450

layout (location = 0) in vec4 f_color;
layout (location = 1) in vec4 f_position;
layout (location = 2) in vec2 f_texcoord;

layout (location = 0) out vec4 color;

uniform vec2 u_lightpos;
uniform sampler2D t1;

void main()
{
    const float intensity = 1.0 / length(u_lightpos - f_position.xy);
    color = texture(t1, f_texcoord) * intensity;
}
