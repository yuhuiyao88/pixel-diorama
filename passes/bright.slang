#version 450
// Glow sources (quarter size). Each output texel averages the 4x4 native block of
// colour * max(Y - t, 0) / Y, t = the glow threshold from the stats pass.
#include "common.inc"
#include "vertex.inc"

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 3) uniform sampler2D Hazed;
layout(set = 0, binding = 4) uniform sampler2D Stats;

void main()
{
	float t = texelFetch(Stats, ivec2(0, 0), 0).a;
	ivec2 size = textureSize(Hazed, 0);
	ivec2 base = ivec2(floor(vTexCoord * global.OutputSize.xy)) * 4;
	vec3 acc = vec3(0.0);
	for(int y = 0; y < 4; y++) {
		for(int x = 0; x < 4; x++) {
			vec3 c = texelFetch(Hazed, min(base + ivec2(x, y), size - 1), 0).rgb;
			float l = luminance(c);
			acc += c * (max(l - t, 0.0) / max(l, 1e-6));
		}
	}
	FragColor = vec4(acc / 16.0, 1.0);
}
