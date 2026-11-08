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
// Their marks on the picture (nightmare_fx.set_mark), each from where the thing is as her
// jamming is; `*_at` as `jam_at`.
// The Whistler's strings: six guitar strings stretched over the picture from where he is.
// `strings_vib`: how they tremble with his song (0 dead still).
uniform float strings = 0.0;
uniform vec2 strings_at = vec2(1.0, 0.0);
uniform float strings_vib = 0.0;
// The granny's mould: white threads creeping in from the frame's edges, her side first.
// `mould_hold`: she is up and looking, the colour goes sick.
uniform float mould = 0.0;
uniform vec2 mould_at = vec2(1.0, 0.0);
uniform float mould_hold = 0.0;
// The Photographer's film: light leaking in from his side; `finder`, the viewfinder's corners
// closing on you while the shot would have you.
uniform float leak = 0.0;
uniform vec2 leak_at = vec2(1.0, 0.0);
uniform float finder = 0.0;
// The boy's hot and cold (nightmare_fx.set_heat): -1 cold and blue .. 1 burning.
uniform float heat = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
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
	// Burning: the air shimmers, rows sliding a pixel or two.
	if (heat > 0.6) {
		float rowh = floor(uv.y / (px.y * 2.0));
		uv.x += floor(sin(rowh * 0.7 + floor(time_s * 12.0) * 1.3) * (heat - 0.6) * 2.5) * px.x;
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
	// Hot and cold: the picture goes the way he says.
	float ht = clamp(heat, -1.0, 1.0);
	if (abs(ht) > 0.005) {
		float l3 = dot(c, vec3(0.3, 0.59, 0.11));
		if (ht < 0.0) {
			c = mix(c, vec3(l3) * vec3(0.7, 0.86, 1.18), -ht * 0.72);
		} else {
			c = mix(c, c * vec3(1.32, 0.84, 0.5) + vec3(0.03, 0.005, 0.0), ht * 0.7);
		}
	}
	// Her threads: static (they grow, they do not flicker), a game pixel each, thicker toward
	// the frame's edge, and first on her side.
	float mo = clamp(mould, 0.0, 1.0);
	if (mo > 0.004) {
		vec2 cellp = floor(SCREEN_UV / px);
		vec2 q2 = (SCREEN_UV - 0.5) * 2.0;
		float edge_d = 1.0 - max(abs(q2.x), abs(q2.y));
		float side = clamp(dot(normalize(q2 + vec2(0.001)), normalize(mould_at + vec2(0.001))), 0.0, 1.0);
		float reach = mo * (0.12 + 0.36 * side * side);
		float grown = clamp(1.0 - edge_d / max(reach, 0.0001), 0.0, 1.0);
		float ridge = 1.0 - abs(vnoise(cellp * 0.085) * 2.0 - 1.0);
		float ridge2 = 1.0 - abs(vnoise(cellp * 0.21 + 7.1) * 2.0 - 1.0);
		float vein = max(pow(ridge, 5.0), pow(ridge2, 7.0) * 0.85);
		float thread = step(0.95 - 0.55 * grown, vein) * step(0.001, grown);
		vec3 mc = mix(vec3(0.76, 0.74, 0.64), vec3(0.42, 0.44, 0.34), hash(cellp));
		c = mix(c, mc, thread * (0.25 + 0.4 * grown));
		float l4 = dot(c, vec3(0.3, 0.59, 0.11));
		c = mix(c, vec3(l4) * vec3(1.05, 0.98, 0.55), clamp(mould_hold, 0.0, 1.0) * 0.55);
	}
	// His film: the light leaks in from his side, ragged, in a few hard shades.
	float lk = clamp(leak, 0.0, 1.0);
	if (lk > 0.004) {
		vec2 lv = ((SCREEN_UV - 0.5) * 2.0 - leak_at) * vec2(aspect, 1.0);
		float n3 = vnoise(floor(SCREEN_UV / (px * 6.0)) * 0.7 + vec2(0.0, floor(time_s * 4.0) * 0.37));
		float burn = pow(clamp(1.0 - length(lv) / (0.5 + 1.15 * lk), 0.0, 1.0), 1.6) * (0.75 + 0.5 * n3);
		burn = floor(burn * 7.0) / 7.0;
		c += mix(vec3(0.85, 0.28, 0.08), vec3(1.0, 0.72, 0.35), burn) * burn * lk * 0.9;
	}
	// His finder's four corners, closing on you, a game pixel thick, and its dot.
	float fi = clamp(finder, 0.0, 1.0);
	if (fi > 0.01) {
		vec2 q3 = (SCREEN_UV - 0.5) * 2.0;
		vec2 hs = mix(vec2(0.86, 0.86), vec2(0.34, 0.42), fi);
		vec2 e3 = abs(q3) - hs;
		float cw = px.y * 2.0 * 1.1;
		float arm = 0.1 + 0.05 * fi;
		float hb = step(abs(e3.y), cw) * step(e3.x, 0.0) * step(-arm, e3.x);
		float vb = step(abs(e3.x), cw) * step(e3.y, 0.0) * step(-arm * aspect, e3.y);
		float mid = step(length(q3 * vec2(aspect, 1.0)), 0.014);
		c = mix(c, vec3(1.0, 0.28, 0.16), max(max(hb, vb), mid) * (0.35 + 0.55 * fi));
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
	// His strings: rays from where he is, a game pixel thick, trembling in standing waves.
	float st_lv = clamp(strings, 0.0, 1.0);
	if (st_lv > 0.004) {
		vec2 g2 = floor(SCREEN_UV / px) * px;
		vec2 p2 = (g2 - 0.5) * 2.0 * vec2(aspect, 1.0);
		vec2 a2 = strings_at * vec2(aspect, 1.0);
		// Stretched from him to you: toward the bottom of the picture, where you are (from
		// the frame's bottom edge, him behind you: up over the picture).
		vec2 to_you = vec2(0.0, 1.35) - a2;
		vec2 to_c = length(to_you) > 0.5 ? normalize(to_you) : vec2(0.0, -1.0);
		vec2 v2 = p2 - a2;
		float r2 = length(v2);
		float th = atan(v2.y, v2.x);
		float th0 = atan(to_c.y, to_c.x);
		float tick2 = floor(time_s * 14.0);
		float best = 1000.0;
		float idx = 0.0;
		for (int i = 0; i < 6; i++) {
			float ang = th0 + (float(i) - 2.5) * 0.16;
			float wob = sin(r2 * 11.0 - tick2 * (1.1 + float(i) * 0.37)) * sin(clamp(r2 / 2.6, 0.0, 1.0) * PI);
			ang += wob * strings_vib * (0.006 + 0.018 * strings_vib);
			float dth = abs(mod(th - ang + PI, TAU) - PI);
			float dd2 = r2 * sin(min(dth, 1.57));
			if (dth < 1.57 && dd2 < best) {
				best = dd2;
				idx = float(i);
			}
		}
		float line = step(best, px.y * 2.0 * 0.62);
		float vis = line * smoothstep(0.0, 0.25, r2) * (1.0 - smoothstep(1.4, 3.2, r2));
		vec3 steel = mix(vec3(0.62, 0.62, 0.7), vec3(0.85, 0.78, 0.5), mod(idx, 2.0));
		c = mix(c, steel, vis * (0.16 + 0.36 * st_lv));
	}
	c *= 1.0 - bar;
	COLOR = vec4(c, 1.0);
}
