shader_type sky;

// Two pairs of panoramas (weather_visuals.gd _sky_pair): each pair blends with the clock
// (day -> evening -> dusk -> night), and `blend` cross-fades from the old pair to the new
// one when the weather changes.
uniform sampler2D from_a : filter_linear, source_color;
uniform sampler2D from_b : filter_linear, source_color;
uniform float from_t : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D to_a : filter_linear, source_color;
uniform sampler2D to_b : filter_linear, source_color;
uniform float to_t : hint_range(0.0, 1.0) = 0.0;
uniform float blend : hint_range(0.0, 1.0) = 1.0;
// How much of the sky now is the clear night: its stars are drawn here, points the size of the
// render's own pixel wherever they stand. (In the panorama they were blocky crosses, drawn out
// sideways toward the top: squares and bars on the screen, like confetti.)
uniform float stars : hint_range(0.0, 1.0) = 0.0;
// The size of the render's pixel on the sky (radians): from the camera's lens and the render's
// lines (weather_visuals).
uniform float pixel_rad = 0.0036;

const float STAR_CELLS = 72.0;

float star_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// A cell of a cube round the sky holds a star or not; the stars stand still on the sky and
// are the same size everywhere on it.
vec3 star_at(vec3 d) {
	vec3 a = abs(d);
	vec2 uv;
	float face;
	if (a.x >= a.y && a.x >= a.z) {
		uv = d.yz / a.x;
		face = d.x > 0.0 ? 0.0 : 1.0;
	} else if (a.y >= a.z) {
		uv = d.xz / a.y;
		face = d.y > 0.0 ? 2.0 : 3.0;
	} else {
		uv = d.xy / a.z;
		face = d.z > 0.0 ? 4.0 : 5.0;
	}
	vec2 g = (uv * 0.5 + 0.5) * STAR_CELLS;
	vec2 cell = floor(g);
	vec2 key = cell + face * 131.0;
	float h = star_hash(key);
	if (h >= 0.13) {
		return vec3(0.0);
	}
	vec2 at = cell + 0.15 + 0.7 * vec2(star_hash(key + 7.3), star_hash(key + 19.1));
	float mag = star_hash(key + 31.7);
	mag = mag * mag * mag;
	// Where it stands on the sky, measured there: on the cube's face a round point toward a
	// corner came out a bar.
	vec2 suv = at / STAR_CELLS * 2.0 - 1.0;
	vec3 star;
	if (face < 2.0) {
		star = vec3(face < 0.5 ? 1.0 : -1.0, suv.x, suv.y);
	} else if (face < 4.0) {
		star = vec3(suv.x, face < 2.5 ? 1.0 : -1.0, suv.y);
	} else {
		star = vec3(suv.x, suv.y, face < 4.5 ? 1.0 : -1.0);
	}
	float dist = length(normalize(star) - d);
	// Never under half a pixel's diagonal: a point between two pixels is on one of them.
	float r = pixel_rad * (0.72 + 0.5 * step(0.8, mag));
	if (dist > r) {
		return vec3(0.0);
	}
	vec3 tint = mix(vec3(0.72, 0.8, 1.0), vec3(1.0, 0.9, 0.78), star_hash(key + 43.9));
	return tint * mix(0.1, 1.0, mag);
}

void sky() {
	vec3 col_from = mix(texture(from_a, SKY_COORDS).rgb, texture(from_b, SKY_COORDS).rgb, from_t);
	vec3 col_to = mix(texture(to_a, SKY_COORDS).rgb, texture(to_b, SKY_COORDS).rgb, to_t);
	COLOR = mix(col_from, col_to, blend);
	if (stars > 0.001 && !AT_CUBEMAP_PASS && EYEDIR.y > 0.0) {
		float low = smoothstep(0.02, 0.16, EYEDIR.y);
		// They go out as the sky behind them lightens.
		float dim = 1.0 - smoothstep(0.03, 0.22, max(COLOR.r, max(COLOR.g, COLOR.b)));
		COLOR += star_at(EYEDIR) * stars * low * dim;
	}
}
