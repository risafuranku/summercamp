shader_type spatial;
// Your breath in the cold (scripts/ambient/player_breath.gd): a puff of vapour (Grok,
// camp/breath_puff.png) drawn the way Build drew its steam and smoke: the whole sprite
// see-through at one of two levels (its translucency tables), then gone; no screen door
// (a 2 x 2 screen door read as a sheet of black dots over the torch's pool and the snow,
// a cloud of one even step in cells as a grey square, one thinned texel by texel as dead
// pixels: inventory 20. 10.). As bright as the light it is in (`light`, set by the
// script: the day, or your torch through it); in the dark without a torch it is not
// seen. Turns to the camera, each puff its own way round (`seed`). `fade` 1 fresh, 0 gone.
render_mode blend_mix, unshaded, cull_disabled, shadows_disabled, specular_disabled, depth_draw_never;

uniform sampler2D puff : source_color, filter_nearest;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float light : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;

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
	vec2 uv = UV;
	if (mod(floor(seed * 3.0), 2.0) > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	if (mod(floor(seed * 7.0), 2.0) > 0.5) {
		uv.y = 1.0 - uv.y;
	}
	vec4 t = texture(puff, uv);
	float k = fade * smoothstep(0.05, 0.5, light);
	float level = k > 0.45 ? 0.33 : (k > 0.15 ? 0.16 : 0.0);
	if (t.a < 0.5 || level <= 0.0) {
		discard;
	}
	ALBEDO = t.rgb * (0.35 + 0.65 * light);
	ALPHA = level;
}
