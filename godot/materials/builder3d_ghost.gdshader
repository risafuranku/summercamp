shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

// Builder 98's 3D view (scripts/builder/map3d.gd): the building in hand as a blueprint of
// its real model, in bands at the Build engine's two translucencies (a third and two
// thirds), a light running up it; `rise` builds it from the ground up (a new ghost, a
// thing just built), `fade` lets it go. `t` steps twelve a second (the script).

uniform vec4 tint : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform float base_y = 0.0;
uniform float height = 3.0;
uniform float rise = 1.0;
uniform float fade = 1.0;
uniform float t = 0.0;

varying float h;

void vertex() {
	h = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - base_y;
}

void fragment() {
	float top = (height + 0.1) * rise;
	if (h > top) {
		discard;
	}
	float band = step(0.5, fract(h * 2.5 - t * 0.6));
	float sweep_y = fract(t * 0.3) * (height + 1.2) - 0.6;
	float sweep = step(abs(h - sweep_y), 0.12);
	float edge = rise < 0.999 ? step(top - 0.22, h) : 0.0;
	float rim = step(0.8, 1.0 - abs(NORMAL.z));
	float lit = max(sweep, edge);
	ALBEDO = tint.rgb * (0.72 + 0.28 * band + 0.55 * lit + 0.22 * rim);
	ALPHA = fade * clamp(mix(0.26, 0.62, band) + 0.34 * lit, 0.0, 1.0);
}
