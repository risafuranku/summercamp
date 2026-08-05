shader_type canvas_item;

// Barrel lens distortion for FPS player POV.
// Radial chromatic aberration + vignette.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float barrel_strength   : hint_range(0.0, 0.5) = 0.145;
uniform float chroma_shift      : hint_range(0.0, 0.02) = 0.0024;
uniform float vignette_strength : hint_range(0.0, 1.0)  = 0.14;

void fragment() {
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float r2 = dot(centered, centered);

	// Barrel warp
	vec2 warped = centered * (1.0 + barrel_strength * r2);
	vec2 uv = warped * 0.5 + 0.5;
	float edge = min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y));
	// Keep barrel distortion away from the hard border to avoid stretched edge artifacts.
	float warp_mask = smoothstep(0.008, 0.075, edge);
	vec2 safe_uv = mix(SCREEN_UV, clamp(uv, vec2(0.0), vec2(1.0)), warp_mask);

	// Radial chromatic aberration (stronger toward edges)
	vec2 chroma_dir = centered * chroma_shift * sqrt(max(r2, 0.0)) * (warp_mask * warp_mask);
	float r = texture(screen_tex, clamp(safe_uv + chroma_dir, vec2(0.0), vec2(1.0))).r;
	float g = texture(screen_tex, safe_uv).g;
	float b = texture(screen_tex, clamp(safe_uv - chroma_dir, vec2(0.0), vec2(1.0))).b;

	// Vignette
	float vignette = 1.0 - smoothstep(0.34, 1.10, length(centered)) * vignette_strength;

	COLOR = vec4(vec3(r, g, b) * vignette, 1.0);
}
