shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.22, 0.14, 0.18, 1.0);
uniform vec4 glow_color : source_color = vec4(0.62, 0.16, 0.34, 1.0);
uniform float distortion_strength : hint_range(0.0, 0.4) = 0.08;
uniform float noise_scale : hint_range(0.5, 12.0) = 4.0;
uniform float noise_speed : hint_range(0.0, 6.0) = 1.4;
uniform float edge_pulse_strength : hint_range(0.0, 2.0) = 0.45;
uniform float edge_power : hint_range(0.5, 8.0) = 3.6;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = value_noise(world_pos.xz * noise_scale + vec2(TIME * noise_speed, TIME * noise_speed * 0.62));
	float offset = (n - 0.5) * distortion_strength;
	VERTEX += NORMAL * offset;
}

void fragment() {
	vec3 col = base_color.rgb;
	float n = value_noise(UV * noise_scale * 2.0 + vec2(TIME * noise_speed, -TIME * noise_speed));
	col += (n - 0.5) * distortion_strength * 1.6;
	ALBEDO = clamp(col, 0.0, 1.0);

	float fres = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), edge_power);
	EMISSION = glow_color.rgb * fres * edge_pulse_strength;
	ROUGHNESS = 0.84;
	SPECULAR = 0.0;
}
