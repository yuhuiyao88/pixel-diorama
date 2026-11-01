#version 450
// Glow radius 2, horizontal (from the glow sources)
#include "common.inc"
#define BLUR_INPUT Bright
#define BLUR_DIR ivec2(1, 0)
#define BLUR_SIGMA_1080 global.GLOW_SIGMA2
#include "vertex.inc"

#pragma stage fragment
layout(set = 0, binding = 3) uniform sampler2D Bright;
#include "blur.inc"
