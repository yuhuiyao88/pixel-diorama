// Depth of field at display resolution, one direction per pass. The blur sigma depends on the screen row:
// sigma = DOF * (DOF_BASE + DOF_SLOPE * max(0, |y - focus| - DOF_W)) px at 1080p, focus = the focus pass's row
// (follows the moving characters; HAZE_Y0 when following is off).
// Define DOF_HORIZONTAL (1 or 0) before including. The horizontal pass reads the native image (Hazed) with
// nearest-neighbour sampling, i.e. the pixel art enlarged without smoothing; the vertical pass reads it back.
#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D Hazed;
layout(set = 0, binding = 4) uniform sampler2D Focus;

vec3 fetch_display(ivec2 q)
{
#if DOF_HORIZONTAL
	ivec2 nsize = textureSize(Hazed, 0);
	vec2 scale = global.OutputSize.xy / vec2(nsize);
	ivec2 n = ivec2(floor((vec2(q) + 0.5) / scale));
	return texelFetch(Hazed, clamp(n, ivec2(0), nsize - 1), 0).rgb;
#else
	ivec2 size = textureSize(Source, 0);
	return texelFetch(Source, clamp(q, ivec2(0), size - 1), 0).rgb;
#endif
}

void main()
{
	ivec2 p = ivec2(floor(vTexCoord * global.OutputSize.xy));
	float yn = vTexCoord.y;
	float focus = texelFetch(Focus, ivec2(0, 0), 0).r;
	float s1080 = global.DOF * (global.DOF_BASE + global.DOF_SLOPE * max(0.0, abs(yn - focus) - global.DOF_W));
	float sigma = s1080 * global.OutputSize.y / 1080.0;
	if(sigma < 0.05) {
		FragColor = vec4(fetch_display(p), 1.0);
		return;
	}
	int radius = min(int(ceil(3.0 * sigma)), 64);
#if DOF_HORIZONTAL
	ivec2 dir = ivec2(1, 0);
#else
	ivec2 dir = ivec2(0, 1);
#endif
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	for(int k = -radius; k <= radius; k++) {
		float w = exp(-0.5 * float(k * k) / (sigma * sigma));
		acc += w * fetch_display(p + dir * k);
		wsum += w;
	}
	FragColor = vec4(acc / wsum, 1.0);
}
