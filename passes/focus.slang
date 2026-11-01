#version 450
// Focus pass (1x1, with feedback): the screen row the depth of field keeps sharp.
// Target, from the motion pass:
//   - when part of the picture moves (changed fraction below one half): the change-weighted mean row, i.e. the
//     characters moving over a still background;
//   - when most of the picture changes (the camera scrolls, as it does to follow the player): the screen centre;
//   - when nothing changes: the current focus (no target).
// The focus moves toward the target with time constant FOCUS_TIME seconds (exponential smoothing at 60 fps),
// starting from HAZE_Y0. FOCUS_FOLLOW = 0 keeps it fixed at HAZE_Y0.
#include "common.inc"
#include "vertex.inc"

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D FocusFeedback;

void main()
{
	vec4 prev = texelFetch(FocusFeedback, ivec2(0, 0), 0);
	// .g marks an initialised focus (the feedback texture starts at zero). The first frame only initialises:
	// it has no real previous frame to compare with.
	if(prev.g < 0.5 || global.FOCUS_FOLLOW < 0.5) {
		FragColor = vec4(global.HAZE_Y0, 1.0, 0.0, 1.0);
		return;
	}
	float focus = prev.r;
	vec4 m = texelFetch(Source, ivec2(0, 0), 0);
	float target = focus;
	if(m.g >= 0.5) {
		target = 0.5;
	} else if(m.r >= 0.0) {
		target = m.r;
	}
	float k = 1.0 - exp(-1.0 / (60.0 * max(global.FOCUS_TIME, 1e-3)));
	FragColor = vec4(focus + k * (target - focus), 1.0, 0.0, 1.0);
}
