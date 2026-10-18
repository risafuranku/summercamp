shader_type spatial;
render_mode cull_disabled, specular_disabled, depth_draw_opaque;

// Washing on a line (scripts/town/town_dressing.gd): the quad's lower edge flaps in the
// wind, the top stays pegged. In steps like the rest of the Build world (12 a second).

uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
uniform float strength = 0.18;
uniform float speed = 2.4;
uniform float steps = 12.0;

void vertex() {
	float t = floor(TIME * steps) / steps;
	// UV.y 0 at the top (pegged), 1 at the bottom (free).
	float free = UV.y * UV.y;
	float wave = sin(t * speed + UV.x * 7.0 + VERTEX.x * 1.3) * 0.6 + sin(t * speed * 1.9 + UV.x * 13.0) * 0.4;
	VERTEX.z += wave * strength * free;
	VERTEX.y += abs(wave) * strength * 0.25 * free;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * tint;
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
}
