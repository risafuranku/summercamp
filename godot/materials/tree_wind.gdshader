shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

// Trees in the wind. The whole tree leans with the wind, more the higher up (height²),
// breathing with slow gusts; crowns add a fast flutter. Strength and direction are
// global (weather_visuals.gd sets them): a still clear day barely moves, a storm bends
// the spruces and whips even the dead trunks. On the anomalous weather the wind stops.

// (Nearest, from a smaller picture far off where there is one: a spruce's boughs glittered
// at every step from a distance.)
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform float sway = 1.0;
uniform float flutter = 0.0;
uniform float height = 5.0;
// 1 on the crowns of the birches and the other leaf trees: they turn and fall.
uniform float seasonal = 0.0;
// Cards of leaves (a birch's crown): the picture's holes are holes.
uniform bool alpha_cut = false;
// A card lit by the normals it was made with, seen from either side (a spruce's boughs: the
// engine turns a back face's normal round, and half the boughs went black).
uniform bool own_normal = false;

global uniform float wind_strength;
global uniform vec2 wind_dir;
// The autumn (scripts/season_look.gd): the leaves' colour, how many are left (1 all,
// 0 bare), the snow lying on top of everything.
global uniform vec3 season_leaf_tint;
global uniform float season_leaves;
global uniform float season_snow;

const float BAYER[16] = { 0.03, 0.53, 0.16, 0.66, 0.78, 0.28, 0.91, 0.41, 0.22, 0.72, 0.09, 0.59, 0.97, 0.47, 0.84, 0.34 };

varying vec3 v_wpos;
varying float v_up;
varying vec3 v_normal;

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
	// The sun's shadow pass (its view is orthographic): the tree as it stands, no sway and
	// no shiver. Snapped to a 150-line grid in the light's view, and that view going with
	// you, every shadow under the trees jumped and twisted as you walked (the playtest of
	// 30. 10.: "the shadows must not wobble"; retro_materials.gd had it already).
	bool shadow_pass = PROJECTION_MATRIX[3][3] > 0.5;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = clamp(VERTEX.y / height, 0.0, 1.6);
	float phase = origin.x * 0.37 + origin.z * 0.29;
	float gust = 0.55 + 0.45 * sin(TIME * 0.6 + phase * 0.5);
	// (Calmer from 21. 10.: the trees' play in the wind was too much; a little over half
	// the bend, slower to and fro, the crowns' flutter smaller.)
	float wave = sin(TIME * (0.8 + wind_strength * 0.5) + phase);
	float lean = wind_strength * (0.55 + 0.45 * gust) * 0.28;
	float bend = (lean + wave * wind_strength * gust * 0.12) * h * h * sway;
	// A gust's front going through the wood: the trees it reaches bow further.
	bend += gust_front(origin.xz, TIME) * wind_strength * 0.12 * h * h * sway;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float f = flutter * wind_strength * sin(TIME * 6.0 + wp.x * 3.1 + wp.y * 2.3 + wp.z * 2.7) * 0.05 * h;
	vec3 off_world = vec3(wind_dir.x * bend + f, -abs(bend) * 0.12, wind_dir.y * bend + f * 0.6);
	v_wpos = wp;
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
	v_normal = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
	if (!shadow_pass) {
		VERTEX += inverse(mat3(MODEL_MATRIX)) * off_world;
	}
	// The PS1's shiver: vertices on a coarse screen grid (scripts/retro_materials.gd).
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (clip.w > 0.05 && !shadow_pass) {
		vec2 grid = vec2(150.0 * VIEWPORT_SIZE.x / max(VIEWPORT_SIZE.y, 1.0), 150.0) * 0.5;
		vec2 ndc = floor(clip.xy / clip.w * grid + 0.5) / grid;
		clip.xy = ndc * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	// The lake's mirror (camp_lake.gd) looks from under the water: nothing below the water
	// is drawn for it (the ground's underside was a ceiling over everything it saw).
	if (CAMERA_POSITION_WORLD.y < -0.4 && (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y < 0.1) {
		discard;
	}
	vec4 t = texture(albedo_tex, UV * uv_scale);
	if (alpha_cut && t.a < 0.5) {
		discard;
	}
	// Right at your eye a card's picture is a wall of squares a hand wide: it comes apart in steps
	// there and you look through it, as you would hold a bough aside.
	if (alpha_cut) {
		float keep = (length(VERTEX) - 0.25) / 0.5;
		if (keep < BAYER[(int(FRAGCOORD.x) % 4) + (int(FRAGCOORD.y) % 4) * 4]) {
			discard;
		}
	}
	vec3 c = t.rgb * albedo_color.rgb;
	if (seasonal > 0.5) {
		c *= season_leaf_tint;
		// The crown thins in chunky clumps as the leaves come down.
		vec3 q = floor(v_wpos * 5.0);
		float n = fract(sin(dot(q, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		if (n > season_leaves) {
			discard;
		}
	}
	// Snow lies on whatever faces up.
	c = mix(c, vec3(0.88, 0.90, 0.95), clamp(season_snow * smoothstep(-0.05, 0.45, v_up) * 1.1, 0.0, 0.92));
	ALBEDO = c;
	ROUGHNESS = 1.0;
	if (own_normal) {
		NORMAL = normalize(v_normal);
	}
}
