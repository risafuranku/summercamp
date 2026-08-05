shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, unshaded;

uniform vec3 bottom_color : source_color = vec3(0.14, 0.30, 0.12);
uniform vec3 top_color : source_color = vec3(0.40, 0.66, 0.30);
uniform float wind_strength : hint_range(0.0, 0.6) = 0.10;
uniform float wind_speed : hint_range(0.0, 8.0) = 1.4;
uniform float wind_scale : hint_range(0.1, 6.0) = 1.2;
uniform float blade_curve : hint_range(-0.2, 0.6) = 0.08;
uniform float roughness : hint_range(0.0, 1.0) = 0.92;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = INSTANCE_CUSTOM.r * 6.2831853;
	float gust = sin(dot(world_pos.xz, vec2(1.0, 0.7) * wind_scale) + TIME * wind_speed + phase);
	float sway = gust * wind_strength * UV.y;
	VERTEX.x += sway;
	VERTEX.z += cos(gust + phase) * wind_strength * 0.35 * UV.y;
	VERTEX.y += UV.y * UV.y * blade_curve;
}

void fragment() {
	vec3 col = mix(bottom_color, top_color, clamp(pow(UV.y, 1.12), 0.0, 1.0));
	float hue_shift = (INSTANCE_CUSTOM.g - 0.5) * 0.14;
	col += vec3(-hue_shift * 0.2, hue_shift, -hue_shift * 0.25);
	float edge = abs(UV.x - 0.5) * 2.0;
	col *= (1.0 - edge * 0.28);
	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = roughness;
	SPECULAR = 0.0;
}
