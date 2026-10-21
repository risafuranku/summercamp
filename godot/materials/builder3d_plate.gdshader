shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Builder 98's 3D view (scripts/builder/map3d.gd): one tile's plate on the camp's ground,
// a MultiMesh instance each: the ghost's footprint, a path or a row being dragged, the
// bulldozer's box, the building whose card is open, an overlay's colour, a lamp's reach.
// The instance colour is the plate's; INSTANCE_CUSTOM: r the pattern (0 a plate with its
// rim, 1 the rim and hatched: it does not fit, 2 a wash with no rim), g the fill's alpha.

varying vec4 plate_col;
varying vec4 plate;

void vertex() {
	plate_col = COLOR;
	plate = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 uv = UV;
	float e = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float rim = plate.r < 1.5 ? step(e, 0.07) : 0.0;
	float hatch = (plate.r > 0.5 && plate.r < 1.5) ? step(0.55, fract((uv.x + uv.y) * 3.0)) : 0.0;
	float a = max(rim * 0.95, max(plate.g, hatch * 0.62));
	ALBEDO = plate_col.rgb * (1.0 + rim * 0.3);
	ALPHA = a * plate_col.a;
}
