#version 450
// Colour look: a 3D lookup table (64^3, sRGB in -> sRGB out, luts/look.png) applied to the original colour,
// mixed with the original by LOOK_STRENGTH. Output: linear RGB, alpha = Y^2 (for the frame statistics).
#include "common.inc"
#include "vertex.inc"

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 3) uniform sampler2D Original;
layout(set = 0, binding = 4) uniform sampler2D LookLUT;

const int N = 64; // LUT size per axis; layout: x = blue slice * N + red, y = green

vec3 lut_texel(int r, int g, int b)
{
	return texelFetch(LookLUT, ivec2(b * N + r, g), 0).rgb;
}

vec3 apply_lut(vec3 c)
{
	vec3 p = clamp(c, 0.0, 1.0) * float(N - 1);
	ivec3 i0 = ivec3(floor(p));
	ivec3 i1 = min(i0 + 1, ivec3(N - 1));
	vec3 f = p - vec3(i0);
	vec3 c00 = mix(lut_texel(i0.r, i0.g, i0.b), lut_texel(i1.r, i0.g, i0.b), f.r);
	vec3 c10 = mix(lut_texel(i0.r, i1.g, i0.b), lut_texel(i1.r, i1.g, i0.b), f.r);
	vec3 c01 = mix(lut_texel(i0.r, i0.g, i1.b), lut_texel(i1.r, i0.g, i1.b), f.r);
	vec3 c11 = mix(lut_texel(i0.r, i1.g, i1.b), lut_texel(i1.r, i1.g, i1.b), f.r);
	return mix(mix(c00, c10, f.g), mix(c01, c11, f.g), f.b);
}

void main()
{
	vec3 srgb = texture(Original, vTexCoord).rgb;
	// exact black stays black: on the SNES it is the backdrop of borders, wipes and fades, not scene colour
	vec3 lin = lit_weight(srgb) > 0.0
		? mix(srgb_to_linear(srgb), srgb_to_linear(apply_lut(srgb)), global.LOOK_STRENGTH)
		: vec3(0.0);
	float y = luminance(lin);
	FragColor = vec4(lin, y * y);
}
