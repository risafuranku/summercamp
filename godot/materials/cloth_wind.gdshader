shader_type spatial;
render_mode cull_disabled, specular_disabled, depth_draw_opaque;

// Washing on a line (scripts/town/town_dressing.gd): the quad's lower edge flaps in the
// wind, the top stays pegged. In steps like the rest of the Build world (12 a second).

uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
uniform float strength = 0.18;
uniform float speed = 2.4;
uniform float steps = 12.0;
// The world's wind (weather_visuals: 0.15 still, 0.75 windy, 1.6 a gale): a stir on a still
// day in slower steps; in a gale it cracks about, every step a new pose (the user 5. 11.).
global uniform float wind_strength;

void vertex() {
	float w = clamp(wind_strength / 1.6, 0.0, 1.0);
	float st = mix(steps * 0.5, steps, w);
	float t = floor(TIME * st) / st;
	// UV.y 0 at the top (pegged), 1 at the bottom (free).
	float free = UV.y * UV.y;
	float sp = speed * (0.55 + 1.6 * w);
	float wave = sin(t * sp + UV.x * 7.0 + VERTEX.x * 1.3) * 0.6 + sin(t * sp * 1.9 + UV.x * 13.0) * 0.4;
	float amp = strength * (0.3 + 1.7 * w);
	VERTEX.z += wave * amp * free;
	VERTEX.y += abs(wave) * amp * 0.25 * free;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * tint;
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
}
