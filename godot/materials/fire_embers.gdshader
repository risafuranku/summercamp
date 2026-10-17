shader_type spatial;
// The bed of a campfire: ash and charcoal (a texture, lit like everything else) with
// coals that glow through it, brighter in the middle, breathing in steps. `heat` 0-1:
// 0 a cold fireplace, ~0.3 last night's embers, 1 a fire going.
render_mode cull_disabled;

uniform sampler2D ash_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float heat : hint_range(0.0, 1.5) = 1.0;
uniform float fps = 8.0;
uniform float uv_scale = 1.6;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = floor(UV * 48.0) / 48.0;
	vec3 ash = texture(ash_tex, UV * uv_scale).rgb * tint.rgb;
	float t = floor(mod(TIME, 600.0) * fps) / fps;
	float r = length(uv - 0.5) * 2.0;
	float core = clamp(1.0 - r * 1.15, 0.0, 1.0);
	float coals = noise(uv * 11.0 + vec2(0.0, t * 0.15));
	float breathe = 0.75 + 0.25 * noise(uv * 4.0 + vec2(t * 0.9, -t * 0.6));
	float glow = smoothstep(0.42, 0.78, coals * breathe + core * 0.35) * core * heat;
	glow = floor(glow * 5.0) / 5.0;
	// Hot coals are darker ash round their glow.
	ALBEDO = ash * (1.0 - 0.55 * core * min(heat, 1.0));
	EMISSION = mix(vec3(0.55, 0.06, 0.01), vec3(1.0, 0.5, 0.08), glow) * glow * 2.4;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
