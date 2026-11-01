#version 450
// Glow radius 1, horizontal
#include "common.inc"
#define BLUR_INPUT Source
#define BLUR_DIR ivec2(1, 0)
#define BLUR_SIGMA_1080 global.GLOW_SIGMA1
#include "vertex.inc"

#pragma stage fragment
layout(set = 0, binding = 2) uniform sampler2D Source;
#include "blur.inc"
