shader_type spatial;
// A puff of the bonfire's smoke (scripts/attractions/campfire.gd): Grok camp/fire_smoke.png
// drawn the way Build drew its smoke, the whole sprite see-through at one of two levels and
// then gone (it was a screen door of dots, an ordered dither over noise, the fault the
// breath had too: inventory 20. 10.). Turns to the camera (fixed Y). `fade` 1 fresh, 0
// gone; `color` the smoke's shade for the hour (grey by day, near black at night), the
// picture's own shading in it; `seed` turns some of the puffs the other way round.
render_mode blend_mix, unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform sampler2D puff : source_color, filter_nearest;
uniform vec4 color : source_color = vec4(0.62, 0.6, 0.58, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;

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
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = UV;
	if (mod(floor(seed), 2.0) > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	vec4 t = texture(puff, uv);
	// Build's translucencies: two thirds, a third, gone (at a half and a quarter, and as
	// dark as the colour alone, it hardly showed over the trees).
	float level = fade > 0.35 ? 0.66 : (fade > 0.1 ? 0.33 : 0.0);
	if (t.a < 0.5 || level <= 0.0) {
		discard;
	}
	ALBEDO = t.rgb * color.rgb * 2.2;
	ALPHA = level;
}
