shader_type canvas_item;
render_mode unshaded;

// The night's screen (scripts/night/nightmare_fx.gd): when something is close, the
// picture itself goes wrong. `dread` (0-1, how close the nearest thing is) is always on
// a little: grain, colour bleeding apart, the colour draining towards rust; `amount` is
// a hit (the strike, a scare): the frame tears into bands that slide, the channels split
// wide, the grain roars. Both in whole game pixels.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float amount = 0.0;
uniform float dread = 0.0;
uniform float time_s = 0.0;
uniform float cell = 4.0;
// Presence (the Silent Man's sixth sense): the edges of the picture close in, in a few
// hard shades, and pulse with the heart; 0 off, 1 he is at your neck.
uniform float squeeze = 0.0;
uniform float beat = 0.0;
uniform float aspect = 1.333;
// Spores (the granny near you, scripts/enemies/basket_brain.gd): a sour yellow haze over
// the picture and motes drifting through it, in whole game pixels; 0 off, 1 at your face.
uniform float spores = 0.0;
// Her interference (the Girl: nightmare_fx.set_jam): the picture loses its signal from where
// she is: the rows there lean her way, it goes dark and TV snow creeps in, in whole game
// pixels. `jam_at`: where she is on the picture (-1..1, y down; out of the frame, on its
// edge). `jam`: 0 off, 1 she is on you.
uniform float jam = 0.0;
uniform vec2 jam_at = vec2(1.0, 0.0);
// Found (nightmare_fx.lock): the set catches its picture. `hold`: the frame's roll, in frame
// heights, a black bar where it wraps. `clean`: the night's grain and tears gone from it for
// a moment. `punch`: the picture a little nearer.
uniform float hold = 0.0;
uniform float clean = 0.0;
uniform float punch = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE * cell;
	uv = 0.5 + (uv - 0.5) * (1.0 - punch);
	float bar = 0.0;
	if (abs(hold) > 0.0001) {
		float y = fract(uv.y + hold);
		bar = step(y, 0.035);
		uv.y = y;
	}
	// Where her interference is on this game pixel (cells of two: coarser than the world).
	float jm = clamp(jam, 0.0, 1.0);
	float her = 0.0;
	vec2 jsize = px * vec2(5.0, 1.0);
	vec2 jcell = floor(SCREEN_UV / jsize);
	if (jm > 0.001) {
		vec2 box = (jcell * jsize - 0.5) * 2.0;
		vec2 dd = (box - jam_at) * vec2(aspect, 1.0);
		her = clamp(1.0 - length(dd) / mix(0.42, 1.6, jm), 0.0, 1.0);
		// The rows near her lean her way.
		float lean = hash(vec2(floor(uv.y / (px.y * 2.0)), floor(time_s * 12.0)));
		uv.x += (jam_at.x < 0.0 ? 1.0 : -1.0) * floor(lean * her * her * 9.0) * px.x;
	}
	// Presence: the world bends. A slow wave runs through the picture in whole game
	// pixels, and the view narrows towards the middle (tunnel vision), both with the dread
	// that is in you, not with anything you see.
	float pr = clamp(squeeze, 0.0, 1.0);
	if (pr > 0.2) {
		float w = (pr - 0.2) / 0.8;
		float wave = sin(uv.y * 9.0 + floor(time_s * 6.0) * 0.55) * 0.5 + sin(uv.y * 23.0 - floor(time_s * 6.0) * 0.9) * 0.25;
		uv.x += floor(wave * w * 3.0) * px.x;
		uv = 0.5 + (uv - 0.5) * (1.0 - 0.045 * w * w - beat * 0.006 * w);
	}
	float a = clamp(amount, 0.0, 1.0);
	float q = 1.0 - clamp(clean, 0.0, 1.0);
	float d = clamp(dread, 0.0, 1.0) * q;
	float tick = floor(time_s * 12.0);
	// Tears: bands of the frame slide sideways, more and wider with a hit.
	float row = floor(uv.y / (px.y * 6.0));
	float tear = step(1.0 - (a * 0.45 + d * 0.06), hash(vec2(row, tick)));
	uv.x += tear * (hash(vec2(row * 1.7, tick + 3.0)) - 0.5) * (0.02 + 0.12 * a);
	// The channels drift apart.
	float ca = px.x * (1.4 * d * d + 6.0 * a);
	vec3 c;
	c.r = texture(screen, uv + vec2(ca, 0.0)).r;
	c.g = texture(screen, uv).g;
	c.b = texture(screen, uv - vec2(ca, 0.0)).b;
	// Grain on the game-pixel grid, twelve times a second.
	vec2 g = floor(uv / px);
	float n = hash(g + tick * 7.13);
	c += (n - 0.5) * (0.03 * q + 0.12 * d + 0.35 * a);
	// The colour drains towards rust and black.
	float drain = d * 0.35 + a * 0.6;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(lum * 1.25, lum * 0.42, lum * 0.36), drain);
	// Spores: the colour goes sour and thick, motes drift up through it.
	float sp = clamp(spores, 0.0, 1.0);
	if (sp > 0.001) {
		vec3 haze = vec3(0.42, 0.38, 0.17);
		float l2 = dot(c, vec3(0.3, 0.59, 0.11));
		c = mix(c, vec3(l2) * vec3(1.04, 1.0, 0.64) + haze * 0.12, sp * 0.62);
		// Dull motes, few, drifting up: dust in the air, not sparks.
		float drift = floor(time_s * 12.0) / 12.0;
		vec2 mg = floor((uv + vec2(drift * 0.004, -drift * 0.012)) / (px * 2.0));
		float mote = step(1.0 - 0.0025 * sp, hash(mg * 1.31 + 17.0));
		c = mix(c, haze * 0.75, mote * 0.5 * sp);
	}
	// The edges close in, banded (the palette's few shades), pulsing with the heart.
	float sq = clamp(squeeze, 0.0, 1.0);
	if (sq > 0.001) {
		vec2 q = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
		float r = length(q) / (0.5 * length(vec2(aspect, 1.0)));
		float edge = 1.0 - sq * 0.62 - beat * sq * 0.07;
		float v = clamp((r - edge) / 0.28, 0.0, 1.0);
		v = floor(v * 6.0) / 6.0;
		c *= 1.0 - v * (0.55 + 0.4 * sq);
		c = mix(c, c * vec3(1.05, 0.82, 0.8), v * sq);
	}
	// Her snow: dashes of a lost signal over a dark that comes with it, in a few hard shades,
	// the nearer the denser, ragged, twelve a second.
	if (her > 0.0) {
		float grainy = hash(jcell + tick * 3.1);
		float density = her * her * (0.1 + 0.42 * jm);
		float snow = step(1.0 - density, hash(jcell * 1.7 + tick * 11.3));
		c *= 1.0 - floor(her * 6.0) / 6.0 * (0.45 + 0.5 * jm);
		c = mix(c, mix(vec3(0.1, 0.1, 0.12), vec3(0.62, 0.6, 0.54), grainy * grainy), snow * 0.85);
	}
	c *= 1.0 - bar;
	COLOR = vec4(c, 1.0);
}
