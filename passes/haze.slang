#version 450
// Depth haze. Rows above the focus centre blend toward the frame's mean colour, in proportion to
// their distance above it (the top of the screen is farthest under a tilted view).
#include "common.inc"
#include "vertex.inc"

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D Mapped;

void main()
{
	vec3 c = texture(Mapped, vTexCoord).rgb;
	vec3 mean = texelFetch(Source, ivec2(0, 0), 0).rgb;
	float y0 = max(global.HAZE_Y0, 1e-3);
	float f = clamp(global.HAZE * max(0.0, y0 - vTexCoord.y) / y0, 0.0, 1.0);
	FragColor = vec4(mix(c, mean, f), 1.0);
}
