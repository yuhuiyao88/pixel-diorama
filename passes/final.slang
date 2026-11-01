#version 450
// Final pass: add glow, vignette and chromatic aberration (R pushed out, B pulled in, half the corner shift
// each, in px at 1080p), apply the per-frame presentation floor, then encode sRGB.
#include "common.inc"
#include "vertex.inc"

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D Glow1;
layout(set = 0, binding = 4) uniform sampler2D Glow2;
layout(set = 0, binding = 5) uniform sampler2D Floor;

vec3 bilinear(sampler2D tex, vec2 pos) // pos in texel units of tex, clamped at the edges
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

vec3 scene_at(vec2 p) // p: display pixel position (centre = integer + 0.5)
{
	vec3 c = bilinear(Source, p - 0.5);
	vec2 g = p / global.OutputSize.xy * vec2(textureSize(Glow1, 0)) - 0.5;
	vec3 glow = 0.5 * (bilinear(Glow1, g) + bilinear(Glow2, g));
	return c + global.GLOW_AMOUNT * glow;
}

void main()
{
	vec2 p = vTexCoord * global.OutputSize.xy;
	vec2 centre = global.OutputSize.xy * 0.5;
	float halfDiag = length(centre);
	vec2 d = (p - centre) / halfDiag * (global.CA_PX * global.OutputSize.y / 1080.0 / 2.0);
	vec3 c = scene_at(p);
	c.r = scene_at(p - d).r;
	c.b = scene_at(p + d).b;
	if(global.VIGNETTE_K > 0.0) {
		vec2 r2 = (p - centre) / centre;
		float r = length(r2) / sqrt(2.0);
		c *= exp2(-global.VIGNETTE_K * pow(r, global.VIGNETTE_P));
	}
	// per-frame presentation floor (floor pass): restore the original's mean chroma and L* contrast if the
	// finished look fell short; both gains are 1 when it did not
	vec4 fl = texelFetch(Floor, ivec2(0, 0), 0);
	if(fl.x > 1.0 || fl.y > 1.0) {
		vec3 lab = linear_to_lab(clamp(c, 0.0, 1.0));
		lab.x = clamp(fl.z + fl.y * (lab.x - fl.z), 0.0, 100.0);
		lab.yz *= fl.x;
		c = lab_to_linear(lab);
	}
	FragColor = vec4(linear_to_srgb(c), 1.0);
}
