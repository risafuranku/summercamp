shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// The rain's streaks (scripts/weather_visuals.gd, _rain_layer): the streak's picture, its
// tint, gone within `fade_from` of the eye, and never drawn inside a room. A room built in
// the camp's one world keeps the rain out with its dry box (hide on contact), but a drop is
// hidden only a step after it has gone in, and its streak hangs half its length round it:
// streaks stood in the cabin for a step (X1 of 5. 11., "it rains inside"). The rooms' dry
// boxes (up to 8, world -> the unit box) cut the streak where it is inside one.

uniform sampler2D streak : source_color, filter_nearest;
uniform vec4 albedo : source_color = vec4(0.84, 0.88, 0.92, 0.5);
uniform float fade_from = 0.6;
uniform float fade_to = 2.2;
uniform int dry_count = 0;
uniform mat4 dry_inv[8];

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	for (int i = 0; i < 8; i++) {
		if (i >= dry_count) {
			break;
		}
		vec3 p = (dry_inv[i] * vec4(world_pos, 1.0)).xyz;
		if (abs(p.x) < 0.5 && abs(p.y) < 0.5 && abs(p.z) < 0.5) {
			discard;
		}
	}
	vec4 c = texture(streak, UV) * albedo * COLOR;
	c.a *= smoothstep(fade_from, fade_to, distance(world_pos, CAMERA_POSITION_WORLD));
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
