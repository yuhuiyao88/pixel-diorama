#version 450
// Exact frame statistics in texel (0,0): mean linear colour (haze target) and the glow threshold
// t = mean Y + GLOW_K * std Y, both over the non-black pixels of the original frame,
// so wipes, fades and dark borders do not drag the threshold down. Other texels output 0.
#include "common.inc"
#include "vertex.inc"

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D Original;

void main()
{
	ivec2 p = ivec2(floor(vTexCoord * global.OutputSize.xy));
	if(p.x != 0 || p.y != 0) {
		FragColor = vec4(0.0);
		return;
	}
	ivec2 size = textureSize(Source, 0);
	vec3 sc = vec3(0.0);
	float sy = 0.0;
	float sy2 = 0.0;
	float n = 0.0;
	// every 4th pixel in each direction (STAT_STRIDE): a regular sample of the frame, 16x less work per frame
	for(int y = STAT_STRIDE / 2; y < size.y; y += STAT_STRIDE) {
		for(int x = STAT_STRIDE / 2; x < size.x; x += STAT_STRIDE) {
			if(lit_weight(texelFetch(Original, ivec2(x, y), 0).rgb) > 0.0) {
				vec3 c = texelFetch(Source, ivec2(x, y), 0).rgb;
				float l = luminance(c);
				sc += c;
				sy += l;
				sy2 += l * l;
				n += 1.0;
			}
		}
	}
	n = max(n, 1.0);
	float meanY = sy / n;
	float sdY = sqrt(max(sy2 / n - meanY * meanY, 0.0));
	FragColor = vec4(sc / n, meanY + global.GLOW_K * sdY);
}
