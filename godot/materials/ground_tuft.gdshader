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
global uniform float wind_strength;
global uniform vec2 wind_dir;
global uniform vec3 season_leaf_tint;
global uniform float season_snow;

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
	float top = clamp(VERTEX.y, 0.0, 1.0);
	world.xz += wind_dir * sway * lean * top * top;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	NORMAL = (inverse(MODEL_MATRIX) * vec4(to_cam.x, 0.6, to_cam.z, 0.0)).xyz;
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) {
		discard;
	}
	vec3 col = mix(c.rgb, c.rgb * season_leaf_tint, seasonal);
	// Snow: from the top down, and the small ones under it.
	col = mix(col, vec3(0.88, 0.90, 0.95), clamp(season_snow * (0.4 + (1.0 - UV.y) * 0.7), 0.0, 0.9));
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
