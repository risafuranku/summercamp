shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, specular_disabled;

// A lodging's window from the camp, near or far, day and night (scripts/ambient/window_lights.gd;
// the user 4. 11.: "the interiors must show through the windows from far off too, now they
// pop in when you come near"). The ray from your eye through the pane goes on into the
// room's box and takes the colour of the room drawn once from its middle into six pictures
// (scripts/ui/room_cube.gd): its real walls, floor, ceiling and things, in depth that moves
// as you walk by, lit as the hour and the lamp have it (`light`, `energy`). Near, the room
// itself is drawn from your eye (cabin_interior / caravan_interior _update_inview) and
// fades in over it (`live`, `room_tex` at the pane's screen pixels, as window_into). Over it
// all the old glass: its cold tint and the sky's sheen at a slant.

uniform sampler2D face_px : source_color, filter_nearest;
uniform sampler2D face_nx : source_color, filter_nearest;
uniform sampler2D face_py : source_color, filter_nearest;
uniform sampler2D face_ny : source_color, filter_nearest;
uniform sampler2D face_pz : source_color, filter_nearest;
uniform sampler2D face_nz : source_color, filter_nearest;
// The camp -> the room (its basis' columns and origin: a mat4 came in the wrong way round),
// the room's inside (room space), where the pictures were drawn from.
uniform vec3 w2r_x = vec3(1.0, 0.0, 0.0);
uniform vec3 w2r_y = vec3(0.0, 1.0, 0.0);
uniform vec3 w2r_z = vec3(0.0, 0.0, 1.0);
uniform vec3 w2r_o = vec3(0.0);
uniform vec3 box_min = vec3(-1.6, 0.0, -1.6);
uniform vec3 box_max = vec3(1.6, 2.4, 1.6);
uniform vec3 eye = vec3(0.0, 1.3, 0.0);
uniform vec3 light : source_color = vec3(1.0);
uniform float energy = 0.62;
uniform sampler2D room_tex : source_color, filter_nearest;
uniform float live = 0.0;
// The live room darker than the day outside (as window_into's).
uniform float bright = 1.0;
uniform vec3 tint = vec3(0.84, 0.9, 0.88);
uniform float sheen = 1.0;
// Pulled toward the eye like the panes the retro look pulls (window_into's depth_pull).
uniform float depth_pull = 0.0;
// The curtains at the glass (the room's own hang right inside it, where no picture from the
// middle of the room can show them): drawn in from both sides by this share of the pane,
// the pane's size for their texture (as window_room's).
uniform sampler2D curtain_tex : source_color, filter_nearest, repeat_enable;
uniform float curtain = 0.0;
// Each pane its own (window_lights): how far its curtains are pulled across, 0 as they hang,
// 1 shut, over the live view too; and somebody in the room, x across the pane, height in
// panes, how dark: their shape on the curtain or against the lamp.
instance uniform float shut = 0.0;
instance uniform vec3 figure = vec3(0.0);
uniform sampler2D figure_tex : filter_nearest;
uniform vec2 pane = vec2(0.7, 0.6);
// (Tools: 1 the room's picture alone, 2 which face, 3 where the ray left the box.)
uniform int debug = 0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 vpos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vpos.xyz *= 1.0 - depth_pull;
	POSITION = PROJECTION_MATRIX * vpos;
}

vec2 face_uv(vec3 d, vec3 f, vec3 u) {
	vec3 r = cross(f, u);
	float z = dot(d, f);
	return vec2(dot(d, r) / z, -dot(d, u) / z) * 0.5 + 0.5;
}

vec3 cube(vec3 d) {
	vec3 a = abs(d);
	if (a.x >= a.y && a.x >= a.z) {
		return d.x > 0.0 ? texture(face_px, face_uv(d, vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0))).rgb
			: texture(face_nx, face_uv(d, vec3(-1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0))).rgb;
	}
	if (a.y >= a.z) {
		return d.y > 0.0 ? texture(face_py, face_uv(d, vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0))).rgb
			: texture(face_ny, face_uv(d, vec3(0.0, -1.0, 0.0), vec3(0.0, 0.0, -1.0))).rgb;
	}
	return d.z > 0.0 ? texture(face_pz, face_uv(d, vec3(0.0, 0.0, 1.0), vec3(0.0, 1.0, 0.0))).rgb
		: texture(face_nz, face_uv(d, vec3(0.0, 0.0, -1.0), vec3(0.0, 1.0, 0.0))).rgb;
}

void fragment() {
	vec3 ro = w2r_x * wpos.x + w2r_y * wpos.y + w2r_z * wpos.z + w2r_o;
	vec3 cw = CAMERA_POSITION_WORLD;
	vec3 co = w2r_x * cw.x + w2r_y * cw.y + w2r_z * cw.z + w2r_o;
	vec3 rd = normalize(ro - co);
	// Where the ray leaves the room's box: the wall, floor or ceiling it meets.
	vec3 t1 = (box_min - ro) / rd;
	vec3 t2 = (box_max - ro) / rd;
	vec3 tf = max(t1, t2);
	float t = max(min(min(tf.x, tf.y), tf.z), 0.0);
	vec3 hitp = ro + rd * t;
	vec3 col = cube(hitp - eye) * light * energy;
	float u = UV.x;
	float c = curtain * 0.5;
	if (curtain > 0.0 && (u < c || u > 1.0 - c)) {
		vec2 cuv = vec2((u < c ? u : 1.0 - u) * pane.x / 0.35, UV.y * pane.y / 0.5);
		col = texture(curtain_tex, cuv).rgb * light * energy * 0.85;
	}
	if (live > 0.0) {
		col = mix(col, texture(room_tex, SCREEN_UV).rgb * bright, live);
	}
	float drawn = max(c, shut * 0.5);
	if (shut > 0.0 && (u < drawn || u > 1.0 - drawn)) {
		vec2 cuv = vec2((u < drawn ? u : 1.0 - u) * pane.x / 0.35, UV.y * pane.y / 0.5);
		col = texture(curtain_tex, cuv).rgb * light * energy * 0.85;
	}
	if (figure.z > 0.0) {
		float fw = figure.y * 0.5 * pane.y / pane.x;
		vec2 fuv = vec2((u - figure.x) / fw + 0.5, (UV.y - 0.1) / figure.y);
		if (fuv.x > 0.0 && fuv.x < 1.0 && fuv.y > 0.0 && fuv.y < 1.0 && texture(figure_tex, fuv).a > 0.5) {
			col *= 1.0 - figure.z;
		}
	}
	float slant = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	vec3 outc = col * tint + vec3(0.55, 0.6, 0.66) * slant * 0.22 * sheen;
	vec3 d = hitp - eye;
	vec3 a = abs(d);
	if (debug == 1) {
		outc = cube(d);
	} else if (debug == 2) {
		outc = a.x >= a.y && a.x >= a.z ? vec3(d.x > 0.0 ? 1.0 : 0.5, 0.0, 0.0) : (a.y >= a.z ? vec3(0.0, d.y > 0.0 ? 1.0 : 0.5, 0.0) : vec3(0.0, 0.0, d.z > 0.0 ? 1.0 : 0.5));
	} else if (debug == 3) {
		outc = clamp((hitp - box_min) / (box_max - box_min), 0.0, 1.0);
	}
	ALBEDO = outc;
}
