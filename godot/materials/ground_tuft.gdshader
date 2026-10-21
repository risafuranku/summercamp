shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_disabled;

// A tuft of the ground's cover (scripts/ambient/ground_cover.gd): a Grok sprite on a
// quad turned to the camera round its upright axis, its foot on the ground; the top
// leans with the wind, in steps of twelve a second like the rest of the game's motion,
// each tuft a little out of time with its neighbours. Lit as the world is (the torch,
// the lamps, the night). The wind and the season are the world's (the trees' global
// uniforms): the grass yellows with the leaves, and snow lies on it at the end.

uniform sampler2D tex : source_color, filter_nearest;
uniform float sway = 0.07;         // how far the top goes in a breeze (m)
// How much of the autumn's tint it takes (grass yes, stones no).
uniform float seasonal = 0.5;
// The ground's colour (scripts/ambient/ground_cover.gd): the picture times this has the
// ground picture's average (ground_ratio), taken this far (grass most, stones not at all).
uniform vec3 ground_ratio = vec3(1.0);
uniform float ground_match = 0.0;
// How far it gives way to feet walking through it (0 for stones, stumps, mushrooms).
uniform float push = 1.0;
global uniform float wind_strength;
global uniform vec2 wind_dir;
global uniform vec3 season_leaf_tint;
global uniform float season_snow;
// Where the wardens' feet are (scripts/ambient/body_world.gd): x, z, the ground's
// height, how hard (0 an empty slot).
global uniform vec4 body_0;
global uniform vec4 body_1;
global uniform vec4 body_2;
global uniform vec4 body_3;

varying float v_front;

// Away from every foot within reach: the more, the nearer (the brief of 21. 10.: "the
// grass parts round your legs and comes back").
vec2 body_push(vec3 o) {
	vec4 bodies[4] = vec4[4](body_0, body_1, body_2, body_3);
	vec2 total = vec2(0.0);
	for (int i = 0; i < 4; i++) {
		vec4 b = bodies[i];
		if (b.w <= 0.0 || abs(o.y - b.z) > 1.2) {
			continue;
		}
		vec2 d = o.xz - b.xy;
		float l = length(d);
		float r = 0.62 + 0.25 * b.w;
		if (l < r) {
			float k = 1.0 - l / r;
			total += (l > 0.001 ? d / l : vec2(1.0, 0.0)) * k * b.w;
		}
	}
	return total;
}

// A gust's front running over the ground with the wind (the user 21. 10.: "polishnout vitr
// huste"): bands some forty metres apart, bent a little, going downwind faster the
// harder it blows; 0 between them, 1 in one.
float gust_front(vec2 p, float t) {
	vec2 side = vec2(-wind_dir.y, wind_dir.x);
	float s = dot(p, wind_dir) * 0.16 - t * (1.4 + wind_strength * 1.6) + sin(dot(p, side) * 0.05) * 1.5;
	float band = 0.5 + 0.5 * sin(s);
	return band * band * band;
}

void vertex() {
	// Turned to the camera round Y (the quad is built in its XY plane, foot at y 0).
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	to_cam.y = 0.0;
	to_cam = length(to_cam) > 0.001 ? normalize(to_cam) : vec3(0.0, 0.0, 1.0);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 world = origin + right * VERTEX.x * sx + vec3(0.0, VERTEX.y * sy, 0.0);
	// The wind, in steps, on the top of the tuft only.
	float t = floor(TIME * 12.0) / 12.0;
	float phase = origin.x * 0.37 + origin.z * 0.23;
	float gust = sin(t * (1.6 + wind_strength * 2.4) + phase) * 0.6 + sin(t * 3.7 + phase * 1.7) * 0.25;
	float lean = (0.25 + wind_strength * 1.2) * (0.6 + 0.4 * gust);
	// A gust's front going over: flattened further, its pale side up (the meadow shows the
	// gusts running across it).
	float front = gust_front(origin.xz, t) * clamp(wind_strength, 0.0, 1.4);
	lean *= 0.7 + 0.9 * front;
	v_front = front;
	float top = clamp(VERTEX.y, 0.0, 1.0);
	world.xz += wind_dir * sway * lean * top * top;
	// Parted by the feet in it: the top pushed away and down, the foot stays.
	vec2 pushed = body_push(origin) * push;
	float tall = clamp(VERTEX.y * sy, 0.0, 1.2);
	world.xz += pushed * 0.42 * tall;
	world.y -= length(pushed) * 0.3 * tall * top;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	NORMAL = (inverse(MODEL_MATRIX) * vec4(to_cam.x, 0.6, to_cam.z, 0.0)).xyz;
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) {
		discard;
	}
	vec3 col = mix(c.rgb, c.rgb * season_leaf_tint, seasonal * (1.0 - ground_match));
	col = mix(col, c.rgb * ground_ratio, ground_match);
	// Paler where a gust's front lies it over, in a step or two.
	col *= 1.0 + floor(v_front * (1.0 - UV.y) * 3.0) / 3.0 * 0.16;
	// Snow: from the top down, and the small ones under it.
	col = mix(col, vec3(0.88, 0.90, 0.95), clamp(season_snow * (0.4 + (1.0 - UV.y) * 0.7), 0.0, 0.9));
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
