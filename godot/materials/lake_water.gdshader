shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

// The forest lake (scripts/camp_lake.gd): the camp's water texture panned two ways in
// world space, Build-engine style (sharp texels, no reflections), darker out in the deep.

uniform sampler2D water_tex : filter_nearest, repeat_enable;  // raw sRGB values: the mean below is measured in them
uniform float tex_scale = 0.09;
uniform vec2 pan = vec2(0.010, 0.004);
uniform vec3 tint : source_color = vec3(0.40, 0.52, 0.60);
uniform vec3 deep : source_color = vec3(0.16, 0.24, 0.26);
uniform vec2 shore_z = vec2(0.0, 40.0);   // world z of the camp shore and of the far side

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz * tex_scale;
	vec3 a = texture(water_tex, uv + TIME * pan).rgb;
	vec3 b = texture(water_tex, uv * 0.73 + vec2(0.37, 0.11) - TIME * pan * 1.4).rgb;
	// The texture is dark and soft: measure each texel against its average (mean and
	// spread measured from lake_water.png) and turn that into ripples and a few glints.
	vec3 m = vec3(0.108, 0.145, 0.073);
	float la = dot(a - m, vec3(0.333)) / 0.028;
	float lb = dot(b - m, vec3(0.333)) / 0.028;
	float ripple = clamp((la + lb) * 0.09, -0.3, 0.4);
	vec3 c = tint * (0.85 + ripple);
	c += vec3(0.22, 0.24, 0.22) * step(1.6, la) * step(1.6, lb);
	float depth = clamp((wpos.z - shore_z.x) / max(1.0, shore_z.y - shore_z.x), 0.0, 1.0);
	ALBEDO = mix(c, c * deep * 2.2, smoothstep(0.05, 0.8, depth));
	ROUGHNESS = 0.3;
	SPECULAR = 0.35;
}
