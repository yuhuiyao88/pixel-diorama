#version 450
// Floor pass (1x1): per-frame presentation floor. Over the non-black pixels of the original frame, compare the
// original with the finished look (colour look + haze + glow + vignette, estimated at native resolution):
// chroma gain = max(1, mean C*_original / mean C*_finished), contrast gain = max(1, sd L*_original /
// sd L*_finished). The final pass applies them, so no frame ends up duller or flatter than the game.
#include "common.inc"
#include "vertex.inc"

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 3) uniform sampler2D Original;
layout(set = 0, binding = 4) uniform sampler2D Hazed;
layout(set = 0, binding = 5) uniform sampler2D Glow1;
layout(set = 0, binding = 6) uniform sampler2D Glow2;

vec3 bilinear(sampler2D tex, vec2 pos)
{
	ivec2 size = textureSize(tex, 0);
	pos = clamp(pos, vec2(0.0), vec2(size - 1));
	ivec2 i0 = ivec2(floor(pos));
	ivec2 i1 = min(i0 + 1, size - 1);
	vec2 f = pos - vec2(i0);
	vec3 a = mix(texelFetch(tex, i0, 0).rgb, texelFetch(tex, ivec2(i1.x, i0.y), 0).rgb, f.x);
	vec3 b = mix(texelFetch(tex, ivec2(i0.x, i1.y), 0).rgb, texelFetch(tex, i1, 0).rgb, f.x);
	return mix(a, b, f.y);
}

void main()
{
	ivec2 size = textureSize(Original, 0);
	ivec2 gsize = textureSize(Glow1, 0);
	float n = 0.0, c0 = 0.0, c1 = 0.0, l0 = 0.0, l1 = 0.0, q0 = 0.0, q1 = 0.0;
	// every 4th pixel in each direction (STAT_STRIDE): a regular sample of the frame, 16x less work per frame
	for(int y = STAT_STRIDE / 2; y < size.y; y += STAT_STRIDE) {
		for(int x = STAT_STRIDE / 2; x < size.x; x += STAT_STRIDE) {
			vec3 srgb = texelFetch(Original, ivec2(x, y), 0).rgb;
			if(lit_weight(srgb) <= 0.0) {
				continue;
			}
			vec2 uv = (vec2(x, y) + 0.5) / vec2(size);
			vec2 g = uv * vec2(gsize) - 0.5;
			vec3 fin = texelFetch(Hazed, ivec2(x, y), 0).rgb
				+ global.GLOW_AMOUNT * 0.5 * (bilinear(Glow1, g) + bilinear(Glow2, g));
			fin *= vignette_gain(uv);
			vec3 a = linear_to_lab(srgb_to_linear(srgb));
			vec3 b = linear_to_lab(clamp(fin, 0.0, 1.0));
			n += 1.0;
			c0 += length(a.yz);
			c1 += length(b.yz);
			l0 += a.x;
			l1 += b.x;
			q0 += a.x * a.x;
			q1 += b.x * b.x;
		}
	}
	n = max(n, 1.0);
	float m0 = l0 / n, m1 = l1 / n;
	float sd0 = sqrt(max(q0 / n - m0 * m0, 0.0));
	float sd1 = sqrt(max(q1 / n - m1 * m1, 0.0));
	float chromaGain = max(1.0, (c0 / n) / max(c1 / n, 1e-3));
	float contrastGain = max(1.0, sd0 / max(sd1, 1e-3));
	FragColor = vec4(chromaGain, contrastGain, m1, 1.0);
}
