shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

// One slice of the cloud deck (scripts/ambient/cloud_layers.gd): a wide plane at the
// cloud's height, round the camera, reading Grok's cloud cover from below
// (skybox/cloud_cover_a/b.png: brightness = how thick the cloud is, its values spread
// evenly so `coverage` is the share of the sky under cloud). The deck is several slices
// one over another: a slice higher up needs thicker cloud, so the thin edges are only in
// the lowest and the thick middles in all of them; seen from under it and toward the
// horizon a cloud has a belly, sides and a top, and moves against the others as you go.
// The sun's side lit: where the cloud thins toward the sun its edge takes the light
// (`rim_color`, its alpha how strong), the far side stays in shade; a finer look at the
// same cover frays the edges and gives the inside its texture.
// A storm churns it (`churn`): the cover pulled about by a slow-moving field and a second
// layer of it running across the first, so the clouds boil, tear and wheel overhead;
// lightning lights it from inside round `flash_pos` (a bolt, or a flash deep in the cloud).
// The shade in a few steps, as Build shaded (no glow).

uniform sampler2D cover_a : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D cover_b : hint_default_black, filter_linear_mipmap, repeat_enable;
// 0 the scattered clouds of fair weather .. 1 the torn overcast of the rain.
uniform float cover_mix : hint_range(0.0, 1.0) = 0.0;
uniform float coverage : hint_range(0.0, 1.0) = 0.3;
// 0 the deck's underside .. 1 its top.
uniform float slice : hint_range(0.0, 1.0) = 0.0;
// How much thicker the cloud must be for the top slice than for the underside.
uniform float thickness = 0.32;
// The wind's drift, metres.
uniform vec2 scroll = vec2(0.0);
// Metres of sky one picture of the cover spans.
uniform float tile_m = 1100.0;
uniform vec4 belly_color : source_color = vec4(0.45, 0.47, 0.5, 1.0);
uniform vec4 top_color : source_color = vec4(0.92, 0.93, 0.94, 1.0);
uniform float alpha_max : hint_range(0.0, 1.0) = 0.92;
// Faded out between these shares of `radius` from the camera (before the far plane).
uniform float radius = 950.0;
uniform float fade_from = 0.42;
uniform float fade_to = 0.96;
uniform float steps = 5.0;
// The direction to the sun.
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float detail_scale = 3.7;
uniform float churn : hint_range(0.0, 1.0) = 0.0;
uniform float churn_time = 0.0;
// The flash: where (world), how strong (0..1), how far round it (m), its colour.
uniform vec3 flash_pos = vec3(0.0);
uniform float flash_strength = 0.0;
uniform float flash_radius = 260.0;
uniform vec4 flash_color : source_color = vec4(0.86, 0.88, 1.0, 1.0);

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float density(vec2 p) {
	if (churn > 0.001) {
		// Pulled about by a slow field of its own (the storm's cover, far larger, moving).
		// Pulled only a little (pulled far, it ran into marble).
		vec2 wuv = p / 2600.0 + vec2(churn_time * 0.009, -churn_time * 0.006);
		vec2 warp = vec2(texture(cover_b, wuv).r, texture(cover_b, wuv + vec2(0.31, 0.57)).r) - 0.5;
		p += warp * churn * 95.0;
	}
	vec2 uv = (p + scroll) / tile_m;
	// The fair-weather puffs at half the storm's scale (their picture is of smaller clouds).
	float a = texture(cover_a, uv * 0.5).r;
	float b = texture(cover_b, uv + vec2(0.37, 0.11)).r;
	float d = mix(a, b, cover_mix);
	if (churn > 0.001) {
		// A second layer of it running across the first, the other way.
		float c = texture(cover_b, (p - scroll * 1.7) / (tile_m * 0.7) + vec2(churn_time * 0.004, 0.23)).r;
		d = mix(d, max(d, c), churn * 0.55);
	}
	// Over a larger stretch the clouds gather in some parts of the sky and thin in others.
	float gather = texture(cover_b, uv * 0.19 + vec2(0.53, 0.19)).r;
	return clamp(d + (gather - 0.5) * 0.22, 0.0, 1.0);
}

void fragment() {
	float d = density(world.xz);
	float det = texture(cover_b, (world.xz + scroll) / tile_m * detail_scale + vec2(0.13, 0.71)).r;
	float thr = 1.0 - coverage + slice * thickness;
	float a = smoothstep(thr, thr + 0.14, d + (det - 0.5) * 0.14);
	a = floor(a * steps + 0.5) / steps;
	float r = length(world.xz - CAMERA_POSITION_WORLD.xz) / radius;
	a *= 1.0 - smoothstep(fade_from, fade_to, r);
	// The thick of it darker underneath (no light through it), the top light.
	float thick = clamp((d - thr) / 0.35, 0.0, 1.0);
	float under = (1.0 - slice) * (0.35 + 0.65 * thick);
	under = floor(under * steps + 0.5) / steps;
	vec3 col = mix(top_color.rgb, belly_color.rgb, under);
	// Lit where it thins toward the sun.
	float side = length(sun_dir.xz);
	if (rim_color.a > 0.001 && side > 0.05) {
		float toward = density(world.xz + sun_dir.xz / side * 45.0);
		float rim = clamp((d - toward) * 3.0, 0.0, 1.0) * clamp(side * 1.6, 0.0, 1.0);
		rim = floor(rim * steps + 0.5) / steps;
		col = mix(col, rim_color.rgb, rim * rim_color.a);
	}
	col *= 0.92 + 0.16 * floor(det * steps + 0.5) / steps;
	// Lightning in it: the cloud round the flash lit from inside, the thin of it most.
	if (flash_strength > 0.001) {
		float fd = length(world.xz - flash_pos.xz) / flash_radius;
		float lit = (1.0 - smoothstep(0.0, 1.0, fd)) * flash_strength * (1.0 - 0.45 * thick);
		lit = floor(lit * steps + 0.5) / steps;
		col = mix(col, flash_color.rgb, clamp(lit, 0.0, 1.0));
	}
	ALBEDO = col;
	ALPHA = a * alpha_max;
}
