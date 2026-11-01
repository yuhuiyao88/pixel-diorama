// Pixel Diorama: shared parameters and helpers for all passes. Every parameter is a slider in RetroArch's
// shader menu (Quick Menu > Shaders > Shader Parameters).
#pragma parameter LOOK_STRENGTH "Colour look strength" 1.5 0.0 2.0 0.05
#pragma parameter HAZE "Depth haze" 0.0 0.0 1.0 0.05
#pragma parameter HAZE_Y0 "Haze/focus centre (screen height)" 0.39 0.0 1.0 0.01
#pragma parameter GLOW_AMOUNT "Glow amount" 2.0 0.0 40.0 0.5
#pragma parameter GLOW_K "Glow threshold (std above mean brightness)" 2.0 0.0 6.0 0.25
#pragma parameter GLOW_SIGMA1 "Glow radius 1 (px at 1080p)" 8.0 1.0 64.0 1.0
#pragma parameter GLOW_SIGMA2 "Glow radius 2 (px at 1080p)" 32.0 1.0 128.0 1.0
#pragma parameter DOF "Depth of field strength" 3.0 0.0 8.0 0.05
#pragma parameter DOF_W "Depth of field: sharp half-width" 0.2 0.0 0.6 0.01
#pragma parameter DOF_SLOPE "Depth of field: blur slope (px at 1080p per screen)" 6.28 0.0 30.0 0.1
#pragma parameter DOF_BASE "Depth of field: base blur (px at 1080p)" 0.03 0.0 4.0 0.01
#pragma parameter VIGNETTE_K "Vignette strength" 1.0 0.0 8.0 0.1
#pragma parameter VIGNETTE_P "Vignette falloff power" 2.2 0.5 6.0 0.1
#pragma parameter CA_PX "Chromatic aberration at corner (px at 1080p)" 0.0 0.0 8.0 0.05
#pragma parameter FOCUS_FOLLOW "Depth of field follows the moving characters (1 = on)" 1.0 0.0 1.0 1.0
#pragma parameter FOCUS_TIME "Focus follow time constant (s)" 0.5 0.05 3.0 0.05

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	float LOOK_STRENGTH;
	float HAZE;
	float HAZE_Y0;
	float GLOW_AMOUNT;
	float GLOW_K;
	float GLOW_SIGMA1;
	float GLOW_SIGMA2;
	float DOF;
	float DOF_W;
	float DOF_SLOPE;
	float DOF_BASE;
	float VIGNETTE_K;
	float VIGNETTE_P;
	float CA_PX;
	float FOCUS_FOLLOW;
	float FOCUS_TIME;
} global;

// Frame statistics (stats, floor passes) use every STAT_STRIDE-th pixel in each direction
const int STAT_STRIDE = 4;

vec3 srgb_to_linear(vec3 c)
{
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 linear_to_srgb(vec3 c)
{
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

float lab_f(float t)
{
	const float d = 6.0 / 29.0;
	return t > d * d * d ? pow(t, 1.0 / 3.0) : t / (3.0 * d * d) + 4.0 / 29.0;
}

vec3 linear_to_lab(vec3 c)
{
	float x = dot(vec3(0.4124564, 0.3575761, 0.1804375), c) / 0.95047;
	float y = dot(vec3(0.2126729, 0.7151522, 0.0721750), c);
	float z = dot(vec3(0.0193339, 0.1191920, 0.9503041), c) / 1.08883;
	float fx = lab_f(x), fy = lab_f(y), fz = lab_f(z);
	return vec3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz));
}

float lab_finv(float f)
{
	const float d = 6.0 / 29.0;
	return f > d ? f * f * f : 3.0 * d * d * (f - 4.0 / 29.0);
}

vec3 lab_to_linear(vec3 lab)
{
	float fy = (lab.x + 16.0) / 116.0;
	float x = lab_finv(fy + lab.y / 500.0) * 0.95047;
	float y = lab_finv(fy);
	float z = lab_finv(fy - lab.z / 200.0) * 1.08883;
	return max(vec3(3.2404542 * x - 1.5371385 * y - 0.4985314 * z,
	                -0.9692660 * x + 1.8760108 * y + 0.0415560 * z,
	                0.0556434 * x - 0.2040259 * y + 1.0572252 * z), vec3(0.0));
}

float vignette_gain(vec2 uv)
{
	if(global.VIGNETTE_K <= 0.0) {
		return 1.0;
	}
	vec2 r2 = (uv - 0.5) / 0.5;
	return exp2(-global.VIGNETTE_K * pow(length(r2) / sqrt(2.0), global.VIGNETTE_P));
}

float luminance(vec3 c)
{
	return dot(vec3(0.2126729, 0.7151522, 0.0721750), c);
}

// Non-black weight: exact black (borders, wipes, fades) is left out of the frame statistics
float lit_weight(vec3 srgb)
{
	return max(max(srgb.r, srgb.g), srgb.b) > 0.0 ? 1.0 : 0.0;
}
