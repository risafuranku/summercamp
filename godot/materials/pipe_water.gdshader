shader_type spatial;
// The trickle along the bottom of the sewer pipes (scripts/sewer_pipe_minigame.gd): brown
// water with scum on it, flowing along the strip's +V (away from the leak), moving in
// steps like the rest of the game. Lit by the torch, so it is only seen where you shine.
render_mode cull_disabled, specular_schlick_ggx;

uniform sampler2D scum : source_color, filter_nearest, repeat_enable;
uniform bool has_scum = false;
uniform vec4 deep : source_color = vec4(0.24, 0.21, 0.11, 1.0);
uniform vec4 light : source_color = vec4(0.58, 0.52, 0.3, 1.0);
uniform float speed = 0.35;
uniform float tiles = 2.0;
uniform float strength = 1.0;    // how much water (more near the leak)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 13758.5453);
}

void fragment() {
	float t = floor(TIME * 12.0) / 12.0;
	vec2 uv = vec2(UV.x, UV.y * tiles - t * speed);
	float n;
	if (has_scum) {
		n = texture(scum, uv).r;
	} else {
		vec2 c = floor(uv * vec2(16.0, 16.0));
		n = hash(c);
	}
	// Narrow at the edges of the strip: the water lies in the curve of the pipe.
	float edge = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
	ALBEDO = mix(deep.rgb, light.rgb, n * 0.8);
	ROUGHNESS = 0.1;
	SPECULAR = 0.9;
	METALLIC = 0.15;
	ALPHA = edge * clamp(0.55 + 0.35 * strength, 0.0, 0.95);
}
