shader_type spatial;
// Your breath in the cold (scripts/ambient/player_breath.gd): a puff in screen-door
// transparency, like the campfire's smoke (dither_smoke.gdshader), but lit as the world
// is (black at night, seen only in the torch or under a lamp) and coarse: the puff is
// 10 x 10 cells and the dither runs in 2 x 2 screen pixels, so it reads as the game's own
// chunky pixels, never as a soft gradient. Turns to the camera. `fade` 1 fresh, 0 gone.
render_mode cull_disabled, shadows_disabled, specular_disabled;

// Grey and thin: right in front of the torch it would light up white.
uniform vec4 color : source_color = vec4(0.36, 0.37, 0.39, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int i = q.x + q.y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = floor(UV * 10.0) / 10.0 + 0.05;
	float r = length(uv - 0.5) * 2.0;
	float n = noise(uv * 4.0 + seed * 3.1);
	float a = (1.0 - smoothstep(0.3, 1.0, r + (n - 0.5) * 0.6)) * fade * 0.5;
	if (a < bayer4(floor(FRAGCOORD.xy / 2.0))) {
		discard;
	}
	ALBEDO = color.rgb * (0.85 + 0.2 * n);
	ROUGHNESS = 1.0;
}
