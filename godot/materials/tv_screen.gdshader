shader_type spatial;
// The back room's little black-and-white set (scripts/reception/back_room.gd). What is
// on: `picture` (the late programme or, after close-down, the test card) through a
// cheap aerial: snow, a rolling bar, the picture breathing with the signal. Drawn in
// steps at 12 fps like the rest of the game's animation; unshaded, it lights itself.
render_mode unshaded, cull_back, fog_disabled;

uniform sampler2D picture : source_color, filter_nearest;
uniform bool has_picture = false;
uniform float signal = 0.75;     // 0 = snow only, 1 = clean
uniform float power = 1.0;       // 0 off .. 1 on (the tube warms up / dies)
uniform float res = 64.0;        // scan lines

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float t = floor(TIME * 12.0) / 12.0;
	vec2 uv = UV;
	// Curved tube: a slight barrel and dark corners.
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	uv = 0.5 + c * (1.0 + 0.18 * r2);
	vec2 px = floor(uv * vec2(res * 1.33, res)) / vec2(res * 1.33, res);
	float snow = hash(px + vec2(t * 7.13, t * 3.71));
	float roll = smoothstep(0.0, 0.08, abs(fract(uv.y + t * 0.21) - 0.5) - 0.38);
	float jitter = (hash(vec2(floor(uv.y * res), t)) - 0.5) * 0.012 * (1.0 - signal);
	float img = 0.35;
	if (has_picture) {
		vec3 p = texture(picture, vec2(px.x + jitter, px.y)).rgb;
		img = dot(p, vec3(0.3, 0.59, 0.11));
	}
	float breathe = 0.85 + 0.15 * hash(vec2(t, 1.7));
	float v = mix(snow, img * breathe, signal);
	v *= mix(0.78, 1.0, roll);
	v *= 0.92 + 0.08 * step(0.5, fract(uv.y * res * 0.5));
	float vignette = smoothstep(0.62, 0.18, r2 * 2.2);
	vec3 col = vec3(v) * vec3(0.86, 0.92, 1.0) * vignette;
	// Off: the dark grey-green of a dead tube, with a fading dot when it dies.
	vec3 dead = vec3(0.07, 0.08, 0.075) + vec3(0.6) * smoothstep(0.02, 0.0, r2) * power;
	ALBEDO = mix(dead, col * 1.15, clamp(power, 0.0, 1.0));
}
