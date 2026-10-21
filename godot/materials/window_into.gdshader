shader_type spatial;
render_mode unshaded, cull_disabled;

// The reception's windows from the camp (building_interior.gd _update_inview): the office
// itself, rendered from where you stand by a camera in the room's own world, read here at
// the pane's own screen pixels, so the room behind the glass has its real depth, its
// lamps, the curtains and whoever is at the PC. Over it the old glass: a cold tint and
// the sky's sheen at a slant. Far off (`live` 0) the pane falls back to dark glass that
// warms with the room's lamps at night (`glow`).

uniform sampler2D room_tex : source_color, filter_nearest;
uniform float live = 0.0;
uniform float glow = 0.0;
// By day the room is darker than the day outside it (old glass, the sky in it).
uniform float bright = 1.0;
uniform vec3 glass = vec3(0.16, 0.2, 0.24);
uniform vec3 warm = vec3(0.62, 0.48, 0.3);

void fragment() {
	vec3 room = texture(room_tex, SCREEN_UV).rgb * vec3(0.84, 0.9, 0.88) * bright;
	vec3 off = mix(glass, warm, clamp(glow, 0.0, 1.0));
	float slant = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = mix(off, room, live) + vec3(0.55, 0.6, 0.66) * slant * 0.22;
}
