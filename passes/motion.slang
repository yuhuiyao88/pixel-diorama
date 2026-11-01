#version 450
// Motion pass (1x1): where the picture changed since the previous frame. Over the native frame, each pixel's
// change is the absolute luma difference to the previous frame; pixels that changed by more than one 8-bit step
// count. Output: .r = change-weighted mean row (0 = top, 1 = bottom), .g = fraction of pixels that changed.
#include "common.inc"
#include "vertex.inc"

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 3) uniform sampler2D Original;
layout(set = 0, binding = 4) uniform sampler2D OriginalHistory1;

void main()
{
	ivec2 size = textureSize(Original, 0);
	float wsum = 0.0, wy = 0.0, changed = 0.0;
	// every 2nd pixel in each direction: small sprites (8-16 px) are still sampled
	for(int y = 0; y < size.y; y += 2) {
		for(int x = 0; x < size.x; x += 2) {
			vec3 a = texelFetch(Original, ivec2(x, y), 0).rgb;
			vec3 b = texelFetch(OriginalHistory1, ivec2(x, y), 0).rgb;
			float d = abs(dot(a - b, vec3(0.2126, 0.7152, 0.0722)));
			if(d > 1.0 / 255.0) {
				changed += 1.0;
				wsum += d;
				wy += d * (float(y) + 0.5) / float(size.y);
			}
		}
	}
	float n = float(((size.x + 1) / 2) * ((size.y + 1) / 2));
	FragColor = vec4(wsum > 0.0 ? wy / wsum : -1.0, changed / n, 0.0, 1.0);
}
