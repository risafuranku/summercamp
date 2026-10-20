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

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE * cell;
	float a = clamp(amount, 0.0, 1.0);
	float d = clamp(dread, 0.0, 1.0);
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
	c += (n - 0.5) * (0.03 + 0.12 * d + 0.35 * a);
	// The colour drains towards rust and black.
	float drain = d * 0.35 + a * 0.6;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(lum * 1.25, lum * 0.42, lum * 0.36), drain);
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
	COLOR = vec4(c, 1.0);
}
