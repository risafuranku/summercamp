shader_type spatial;
// A campfire flame as a 1996 sprite would draw it, made on the fly: chunky pixels, a
// stepped 12 frames a second, four tongues swaying on their own over a hot base, eaten
// into by two layers of rising turbulence, the colour snapped to six palette steps (deep
// red, red, orange, amber, yellow, the pale core), hot at the bottom, red at the tips.
// Opaque with a hard edge (discard), so it sorts and dithers like any other sprite.
// The quad turns to the camera round its own Y (like Sprite3D's fixed-Y billboard).
// The hash has no sin() in it and the clock wraps: GPUs lose sin() precision on big
// arguments and the noise collapses into stripes (tuned in Python first, float32).
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float intensity : hint_range(0.0, 1.6) = 1.0;
uniform float seed = 0.0;
uniform vec2 pixels = vec2(28.0, 40.0);
uniform float fps = 12.0;
uniform float wind = 0.0;
uniform float flare = 0.0;
// Drawn this far in front of the fire's middle, so the flames wrap the logs.
uniform float toward_cam = 0.34;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX[3].z += toward_cam;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

vec3 ramp(float h) {
	vec3 c = vec3(0.42, 0.05, 0.02);
	c = mix(c, vec3(0.74, 0.13, 0.03), step(0.17, h));
	c = mix(c, vec3(0.93, 0.32, 0.05), step(0.34, h));
	c = mix(c, vec3(1.0, 0.55, 0.1), step(0.5, h));
	c = mix(c, vec3(1.0, 0.78, 0.26), step(0.68, h));
	c = mix(c, vec3(1.0, 0.94, 0.62), step(0.86, h));
	return c;
}

float tongue(float x, float y, float t, float off, float h, float w, float ph, float power) {
	float hh = h * min(power, 1.4);
	float cx = off + (0.07 * sin(t * 2.3 + ph + seed + y * 5.0) + wind) * y;
	float wy = w * pow(clamp(1.0 - y / max(hh, 0.01), 0.0, 1.0), 0.65);
	return (1.0 - smoothstep(0.0, max(wy, 0.001), abs(x - cx))) * (1.0 - smoothstep(hh * 0.55, hh, y));
}

void fragment() {
	vec2 uv = (floor(UV * pixels) + 0.5) / pixels;
	float t = floor(mod(TIME, 600.0) * fps) / fps + seed * 1.7;
	float y = 1.0 - uv.y;
	float x = uv.x - 0.5;
	float power = max(intensity + flare * 0.5, 0.05);
	float body = tongue(x, y, t, -0.17, 0.62, 0.18, 0.0, power);
	body = max(body, tongue(x, y, t, 0.0, 0.95, 0.3, 1.7, power));
	body = max(body, tongue(x, y, t, 0.16, 0.7, 0.18, 3.1, power));
	body = max(body, tongue(x, y, t, -0.05, 0.8, 0.16, 4.4, power));
	float turb = 0.3 + 0.95 * fbm(vec2(x * 5.0 + seed * 3.0, y * 3.0 - t * 2.7)) + 0.45 * fbm(vec2(x * 11.0 - seed, y * 7.0 - t * 4.6)) - 0.42;
	float base = pow(1.0 - y, 3.0) * 0.3 * min(power, 1.0) * (1.0 - smoothstep(0.22, 0.4, abs(x)));
	float heat = body * turb * 1.15 - y * 0.42 / power + base;
	if (heat < 0.2) {
		discard;
	}
	ALBEDO = ramp(clamp((heat - 0.2) * 1.05 - y * 0.28 + flare * 0.15, 0.0, 1.0));
}
