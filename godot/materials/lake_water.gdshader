shader_type spatial;
render_mode cull_disabled, specular_disabled, unshaded;

// The forest lake (scripts/camp_lake.gd): the camp's water texture panned two ways in
// world space, Build-engine style (sharp texels, colours in steps, no bloom), darker out
// in the deep, and lit by hand rather than by the engine:
//   - looked at along it, the water gives back the sky (the horizon's colour: red at
//     sunset, grey in rain, near black at night) and, low down, the far shore's trees
//     dark against it; straight down its own dark green-brown;
//   - where a ripple faces the sun (or the moon) a few texels flash, in steps;
//   - the wind pushes the ripples faster and rougher, a storm chops it up;
//   - in rain, rings open on it here and there, in steps of eight a second;
//   - by the camp shore a pale lip of lapping water;
//   - what stands over it (the far shore's forest, the boat, the jetty, a lit window, the
//     moon, the sunset) given back for real: camp_lake.gd renders the world from under the
//     water into `refl_tex` (half the game's pixels), read here upside down and broken by
//     the ripples (the user, 21. 10.: the lake "jen polish").
// camp_lake.gd sets the light, the sky and the weather every quarter second.

uniform sampler2D water_tex : filter_nearest, repeat_enable;  // raw sRGB values: the mean below is measured in them
uniform float tex_scale = 0.09;
uniform vec2 pan = vec2(0.010, 0.004);
uniform vec3 tint : source_color = vec3(0.40, 0.52, 0.60);
uniform vec3 deep : source_color = vec3(0.16, 0.24, 0.26);
uniform vec2 shore_z = vec2(0.0, 40.0);   // world z of the camp shore and of the far side
// Set by camp_lake.gd from the world.
uniform vec3 sky_col : source_color = vec3(0.55, 0.62, 0.70);
uniform vec3 sun_dir = vec3(0.3, 0.8, 0.4);     // towards the light
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.85);
uniform float light_level = 1.0;                 // the scene's light, 0 night .. 1 noon
uniform float wind = 0.2;                        // 0 still .. 1 a gale
uniform float rain = 0.0;                        // 0 dry .. 1 a downpour
// How many shades each channel comes out in (the palette's steps).
uniform float steps = 22.0;
// The world seen from under the water (camp_lake.gd), and whether it is being drawn.
uniform sampler2D refl_tex : filter_nearest, repeat_disable;
uniform float refl_on = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Rain rings: one per cell of a 1.4 m grid now and then, opening out over half a second.
float rings(vec2 xz, float t) {
	vec2 cell = floor(xz / 1.4);
	float ring = 0.0;
	for (int dx = -1; dx <= 1; dx++) {
		for (int dz = -1; dz <= 1; dz++) {
			vec2 c = cell + vec2(float(dx), float(dz));
			float seed = hash12(c);
			float period = 0.9 + seed * 1.6;
			float phase = fract(t / period + seed * 7.0);
			// Not every cell rains every time.
			if (hash12(c + floor(t / period + seed * 7.0)) > rain * 0.9)
				continue;
			vec2 at = (c + vec2(hash12(c + 3.1), hash12(c + 7.7))) * 1.4;
			float r = phase * 0.55;
			float d = abs(length(xz - at) - r);
			ring = max(ring, (1.0 - smoothstep(0.0, 0.05, d)) * (1.0 - phase));
		}
	}
	return ring;
}

void fragment() {
	float gust = 1.0 + wind * 2.4;
	vec2 uv = wpos.xz * tex_scale;
	vec3 a = texture(water_tex, uv + TIME * pan * gust).rgb;
	vec3 b = texture(water_tex, uv * 0.73 + vec2(0.37, 0.11) - TIME * pan * 1.4 * gust).rgb;
	// The texture is dark and soft: measure each texel against its average (mean and
	// spread measured from lake_water.png) and turn that into ripples and a few glints.
	vec3 m = vec3(0.108, 0.145, 0.073);
	float la = dot(a - m, vec3(0.333)) / 0.028;
	float lb = dot(b - m, vec3(0.333)) / 0.028;
	float rough = 0.09 + wind * 0.08;
	float ripple = clamp((la + lb) * rough, -0.35, 0.45);
	float depth = clamp((wpos.z - shore_z.x) / max(1.0, shore_z.y - shore_z.x), 0.0, 1.0);
	// Its own colour: the brown-green water, darker out in the deep, as lit as the scene.
	vec3 own = tint * (0.85 + ripple);
	own = mix(own, own * deep * 2.2, smoothstep(0.05, 0.8, depth));
	own *= mix(0.12, 1.0, light_level);
	// The ripples tilt the surface a little: the sky they give back comes and goes.
	vec3 n = normalize(vec3(la * 0.06, 1.0, lb * 0.06));
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	float facing = clamp(dot(n, v), 0.0, 1.0);
	float fres = pow(1.0 - facing, 3.0) * 0.85 + 0.08;
	// What it gives back: the sky, and low down the far shore's trees, dark against it.
	vec3 r = reflect(-v, n);
	vec3 refl = sky_col * (0.75 + ripple * 0.5);
	float trees = 1.0 - smoothstep(0.015, 0.075, r.y + ripple * 0.02);
	refl = mix(refl, refl * 0.22 + own * 0.3, trees);
	if (refl_on > 0.5) {
		// The real thing, upside down, broken up by the ripples (more in a wind), a little
		// darker than what it gives back and tinted by the water.
		vec2 wob = vec2(la, lb) * (0.0035 + wind * 0.006);
		vec3 world = texture(refl_tex, vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y) + wob).rgb;
		refl = mix(world * 0.82, world * tint * 1.6, 0.25) * (0.9 + ripple * 0.35);
		fres = fres * 0.85 + 0.12;
	}
	vec3 c = mix(own, refl, clamp(fres, 0.0, 0.92));
	// The sun (or the moon) in the ripples: a few texels that line up flash.
	float g = pow(max(dot(r, normalize(sun_dir)), 0.0), 60.0);
	float flash = step(0.55, g) * step(0.9, la + lb);
	c += sun_col * flash * (0.35 + 0.5 * light_level) * step(0.02, sun_dir.y);
	// Rain rings.
	if (rain > 0.01) {
		float t = floor(TIME * 8.0) / 8.0;
		c += vec3(0.16, 0.17, 0.18) * rings(wpos.xz, t) * clamp(rain * 1.4, 0.0, 1.0) * mix(0.35, 1.0, light_level);
	}
	// The lip of lapping water along the camp shore.
	float lip = 1.0 - smoothstep(0.0, 0.9, wpos.z - shore_z.x);
	float lap = step(0.5, fract(wpos.x * 0.7 + floor(TIME * 4.0) * 0.13 + la * 0.1));
	c = mix(c, c * 1.25 + vec3(0.05) * light_level, lip * lap * 0.8 * light_level);
	// In steps, like the rest of the game's colours.
	c = floor(clamp(c, 0.0, 1.0) * steps + 0.5) / steps;
	ALBEDO = c;
}
