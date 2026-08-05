shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float barrel_strength : hint_range(0.0, 0.35) = 0.11;
uniform float vignette_strength : hint_range(0.0, 0.7) = 0.16;
uniform float chroma_shift : hint_range(0.0, 0.01) = 0.0012;

void fragment() {
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float r2 = dot(centered, centered);
	vec2 warped = centered * (1.0 + barrel_strength * r2);
	vec2 uv = (warped * 0.5) + 0.5;
	float in_bounds = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	vec2 chroma = vec2(chroma_shift, 0.0);
	vec3 col = vec3(
		texture(screen_tex, clamp(uv + chroma, vec2(0.0), vec2(1.0))).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, clamp(uv - chroma, vec2(0.0), vec2(1.0))).b
	);

	float vignette = 1.0 - smoothstep(0.32, 1.26, length(centered)) * vignette_strength;
	COLOR = vec4(col * vignette * in_bounds, 1.0);
}
