shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float color_steps : hint_range(2.0, 20.0) = 5.0;
uniform float saturation_boost : hint_range(0.0, 2.5) = 1.08;
uniform float value_lift : hint_range(-0.2, 0.4) = 0.05;
uniform float gamma_shape : hint_range(0.6, 2.2) = 0.95;
uniform float vertex_snap : hint_range(2.0, 120.0) = 16.0;
uniform float vertex_wobble_strength : hint_range(0.0, 0.4) = 0.08;
uniform float wobble_speed : hint_range(0.0, 8.0) = 0.5;
uniform float wobble_scale : hint_range(0.1, 6.0) = 0.5;
uniform float wobble_phase : hint_range(0.0, 6.28318) = 0.0;
uniform vec2 wind_direction = vec2(0.92, 0.38);
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform float wind_alignment : hint_range(0.0, 1.0) = 1.0;
uniform bool use_albedo_texture = false;
uniform sampler2D albedo_tex : source_color, repeat_enable, filter_nearest;
uniform float texture_influence : hint_range(0.0, 1.0) = 0.30;
uniform float uv_quantize : hint_range(1.0, 256.0) = 64.0;
uniform float affine_uv_strength : hint_range(0.0, 0.2) = 0.03;
uniform float light_steps : hint_range(2.0, 12.0) = 5.0;
uniform float light_dither_strength : hint_range(0.0, 1.0) = 0.04;
uniform float min_light : hint_range(0.0, 1.0) = 0.34;
uniform float corrosion_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 corrosion_tint = vec3(0.28, 0.42, 0.30);
uniform float corrosion_scale : hint_range(0.5, 12.0) = 3.2;
uniform float corrosion_contrast : hint_range(0.5, 3.0) = 1.6;

varying vec3 v_world_pos;
varying float v_clip_w;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float bayer4(vec2 p) {
	vec2 m = mod(floor(p), 4.0);
	float x = m.x;
	float y = m.y;
	if (y < 0.5) {
		if (x < 0.5) return 0.0 / 16.0;
		if (x < 1.5) return 8.0 / 16.0;
		if (x < 2.5) return 2.0 / 16.0;
		return 10.0 / 16.0;
	}
	if (y < 1.5) {
		if (x < 0.5) return 12.0 / 16.0;
		if (x < 1.5) return 4.0 / 16.0;
		if (x < 2.5) return 14.0 / 16.0;
		return 6.0 / 16.0;
	}
	if (y < 2.5) {
		if (x < 0.5) return 3.0 / 16.0;
		if (x < 1.5) return 11.0 / 16.0;
		if (x < 2.5) return 1.0 / 16.0;
		return 9.0 / 16.0;
	}
	if (x < 0.5) return 15.0 / 16.0;
	if (x < 1.5) return 7.0 / 16.0;
	if (x < 2.5) return 13.0 / 16.0;
	return 5.0 / 16.0;
}

float corrosion_noise(vec2 p) {
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
	VERTEX = floor(VERTEX * vertex_snap) / vertex_snap;

	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wind_dir = wind_direction;
	if (length(wind_dir) < 0.0001) {
		wind_dir = vec2(1.0, 0.0);
	}
	wind_dir = normalize(wind_dir);
	vec2 varied_dir = normalize(vec2(cos(wobble_phase), sin(wobble_phase)));
	vec2 final_dir = normalize(mix(varied_dir, wind_dir, wind_alignment));

	float wave = sin(dot(world_pos.xz, final_dir * wobble_scale) + (TIME * wobble_speed) + wobble_phase);
	VERTEX.y += wave * vertex_wobble_strength;

	vec4 world_pos4 = MODEL_MATRIX * vec4(VERTEX, 1.0);
	v_world_pos = world_pos4.xyz;
	vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v_clip_w = max(abs(clip_pos.w), 0.0001);
}

void fragment() {
	vec2 uv = UV * uv_scale;
	float uv_steps = max(1.0, uv_quantize);
	uv = (floor(uv * uv_steps) + vec2(0.5)) / uv_steps;
	if (affine_uv_strength > 0.0) {
		float affine_jitter = clamp((1.0 / v_clip_w) * affine_uv_strength, 0.0, 0.2);
		uv += vec2(affine_jitter, -affine_jitter * 0.65);
	}

	vec3 col = base_color.rgb;
	if (use_albedo_texture) {
		vec4 texel = texture(albedo_tex, uv);
		vec3 tex_rgb = texel.rgb;
		vec3 textured = mix(col, tex_rgb, 0.90);
		col = mix(col, textured, texture_influence);
	}
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation_boost);
	col = clamp(col + vec3(value_lift), 0.0, 1.0);
	col = pow(col, vec3(gamma_shape));

	float rust = corrosion_noise(v_world_pos.xz * corrosion_scale);
	rust = pow(clamp(rust, 0.0, 1.0), corrosion_contrast);
	float rust_mask = smoothstep(1.0 - corrosion_amount, 1.0, rust);
	col = mix(col, corrosion_tint, rust_mask * corrosion_amount);

	col = floor(clamp(col, 0.0, 1.0) * color_steps) / color_steps;
	ALBEDO = clamp(col, 0.0, 1.0);
	ROUGHNESS = mix(0.78, 0.98, corrosion_amount);
	SPECULAR = 0.0;
}

void light() {
	float lambert = max(dot(normalize(NORMAL), normalize(LIGHT)), 0.0);
	float dither = (bayer4(UV * 512.0) - 0.5) * light_dither_strength;
	float stepped = floor(clamp(lambert + dither, 0.0, 1.0) * light_steps) / max(light_steps - 1.0, 1.0);
	float lit = max(min_light, clamp(stepped, 0.0, 1.0));
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * lit;
}
