shader_type spatial;
// A lit window of a lodging at night, seen from the camp (scripts/ambient/window_lights.gd;
// the user 20. 10.: the lit windows were a flat picture of a window, there must be depth
// that moves as you do). Interior mapping, Build style: the ray from your eye through the
// pane goes on into a box of a room behind it (its walls, floor and ceiling the camp's own
// textures, nearest filtered, in the world's pixels), its things standing half way in
// (`props`, a cut-out picture: they slide against the back wall as you walk by), lit by a
// lamp in the middle of the room in steps, the curtains drawn in from both sides at the
// glass and lit through from behind. On a QuadMesh facing +Z (out of the building), its
// size `pane` in metres.
render_mode unshaded, cull_back, depth_draw_opaque, specular_disabled;

uniform sampler2D wall_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D floor_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D ceil_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D curtain_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D props : source_color, filter_nearest;
uniform bool has_props = false;
uniform vec2 pane = vec2(0.78, 0.56);
// The room behind: how deep, how wide and high, how high the pane's middle is off its floor.
uniform float depth = 2.4;
uniform float room_w = 2.6;
uniform float room_h = 2.3;
uniform float sill = 1.25;
// Where the props stand (share of the depth) and how big their picture is (m).
uniform float props_at = 0.55;
uniform vec2 props_size = vec2(2.4, 1.3);
uniform float props_x = 0.0;
// One texture repeat (m).
uniform float tex_m = 1.2;
uniform vec3 light : source_color = vec3(1.0, 0.72, 0.42);
uniform float energy = 1.0;
// How far each curtain is drawn in (share of the pane from its side).
uniform float curtain = 0.28;

varying vec3 vpos;
varying vec3 vcam;

void vertex() {
	vpos = VERTEX;
	vcam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

float lamp_at(vec3 p) {
	// The lamp hangs in the middle of the room, under the ceiling; its light falls off in
	// steps (the game's lighting has six).
	vec3 lamp = vec3(0.0, room_h - sill - 0.45, -depth * 0.5);
	float k = clamp(1.32 - length(p - lamp) * 0.46, 0.3, 1.0);
	// The corners darker still: where the walls meet the floor and the ceiling.
	float edge = min(min(p.y + sill, room_h - sill - p.y), room_w * 0.5 - abs(p.x));
	k *= mix(0.72, 1.0, smoothstep(0.0, 0.45, edge));
	return floor(k * 6.0 + 0.5) / 6.0;
}

void fragment() {
	vec3 ro = vpos;
	vec3 rd = normalize(vpos - vcam);
	// From inside (or edge on) the pane shows nothing: the glass is lit, plain.
	if (rd.z >= -0.001) {
		ALBEDO = light * energy * 0.5;
	} else {
		float hx = room_w * 0.5;
		float tx = rd.x > 0.0 ? (hx - ro.x) / rd.x : (-hx - ro.x) / rd.x;
		float ty = rd.y > 0.0 ? ((room_h - sill) - ro.y) / rd.y : (-sill - ro.y) / rd.y;
		float tz = (-depth - ro.z) / rd.z;
		float t = min(tx, min(ty, tz));
		vec3 hit = ro + rd * t;
		vec3 col;
		float shade = 1.0;
		if (t == tz) {
			col = texture(wall_tex, vec2(hit.x, -hit.y) / tex_m).rgb;
			shade = 0.95;
		} else if (t == ty) {
			if (rd.y < 0.0) {
				col = texture(floor_tex, hit.xz / tex_m).rgb;
				shade = 0.8;
			} else {
				col = texture(ceil_tex, hit.xz / tex_m).rgb;
				shade = 0.62;
			}
		} else {
			col = texture(wall_tex, vec2(hit.z, -hit.y) / tex_m).rgb;
			shade = 0.78;
		}
		col *= shade * lamp_at(hit);
		// The things in the room, on their plane half way in, in front of what is behind.
		if (has_props) {
			float tp = (-depth * props_at - ro.z) / rd.z;
			if (tp > 0.0 && tp < t) {
				vec3 pp = ro + rd * tp;
				vec2 puv = vec2((pp.x - props_x) / props_size.x + 0.5, 1.0 - (pp.y + sill) / props_size.y);
				if (puv.x > 0.0 && puv.x < 1.0 && puv.y > 0.0 && puv.y < 1.0) {
					vec4 pc = texture(props, puv);
					if (pc.a > 0.5) {
						col = pc.rgb * 0.92 * lamp_at(pp);
					}
				}
			}
		}
		col *= light * energy;
		// The curtains at the glass, drawn in from both sides, the lamp through them.
		float u = UV.x;
		float c = curtain * 0.5;
		if (u < c || u > 1.0 - c) {
			vec2 cuv = vec2((u < c ? u : 1.0 - u) * pane.x / 0.35, UV.y * pane.y / 0.5);
			col = texture(curtain_tex, cuv).rgb * light * energy * 0.85;
		}
		ALBEDO = col;
	}
}
