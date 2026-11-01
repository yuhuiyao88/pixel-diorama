// Separable Gaussian on the quarter-size glow grid. Define BLUR_DIR (ivec2) and BLUR_SIGMA_1080 (an
// expression in px at 1080p) before the vertex stage, and include this after declaring the BLUR_INPUT sampler
// in the fragment stage.
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

void main()
{
	float sigma = max(BLUR_SIGMA_1080 * global.OriginalSize.y / 1080.0 / 4.0, 0.3);
	int radius = min(int(ceil(3.0 * sigma)), 48);
	ivec2 size = textureSize(BLUR_INPUT, 0);
	ivec2 p = ivec2(floor(vTexCoord * vec2(size)));
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	for(int k = -radius; k <= radius; k++) {
		float w = exp(-0.5 * float(k * k) / (sigma * sigma));
		acc += w * texelFetch(BLUR_INPUT, clamp(p + BLUR_DIR * k, ivec2(0), size - 1), 0).rgb;
		wsum += w;
	}
	FragColor = vec4(acc / wsum, 1.0);
}
