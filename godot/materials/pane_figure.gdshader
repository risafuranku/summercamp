shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, specular_schlick_ggx;

// A pane of a lodging with its room standing behind it (cabin_interior._host_panes): the
// clear glass, and somebody moving about in there, their shape on the curtain or against
// the lamp (scripts/ambient/window_lights.gd `figure`: x across the pane, height in panes,
// how dark; `pane_size` its metres).

uniform sampler2D figure_tex : filter_nearest;
instance uniform vec3 figure = vec3(0.0);
instance uniform vec2 pane_size = vec2(0.7, 0.6);

void fragment() {
	ALBEDO = vec3(0.6, 0.68, 0.68);
	ALPHA = 0.14;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	if (figure.z > 0.0) {
		float fw = figure.y * 0.5 * pane_size.y / pane_size.x;
		vec2 fuv = vec2((UV.x - figure.x) / fw + 0.5, (UV.y - 0.1) / figure.y);
		if (fuv.x > 0.0 && fuv.x < 1.0 && fuv.y > 0.0 && fuv.y < 1.0 && texture(figure_tex, fuv).a > 0.5) {
			ALBEDO = vec3(0.02);
			ALPHA = figure.z;
		}
	}
}
