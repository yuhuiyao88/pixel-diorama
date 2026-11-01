#version 450
// Glow radius 2, vertical
#include "common.inc"
#define BLUR_INPUT Source
#define BLUR_DIR ivec2(0, 1)
#define BLUR_SIGMA_1080 global.GLOW_SIGMA2
#include "vertex.inc"

#pragma stage fragment
layout(set = 0, binding = 2) uniform sampler2D Source;
#include "blur.inc"
