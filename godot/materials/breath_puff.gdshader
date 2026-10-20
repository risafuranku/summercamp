shader_type spatial;
// Your breath in the cold (scripts/ambient/player_breath.gd): a puff of vapour (Grok,
// camp/breath_puff.png, its shape) drawn as a scatter of dots, Build's dithered steam
// (the user 20. 10.: the dotted breath was better, only its dots sat in too even a grid).
// The dots are the puff's own (cells of its picture, 32 across, each lit or not by a
// hash of the cell and the puff's `seed`), so they ride along with it and never crawl
// over the screen the way a screen door did, and they fall at random, thinning to the
// edges and as it fades. As bright as the light it is in (`light`, set by the script: the
// day, or your torch through it); in the dark without a torch it is not seen. Turns to the
// camera, each puff its own way round. `fade` 1 fresh, 0 gone.
render_mode blend_mix, unshaded, cull_disabled, shadows_disabled, specular_disabled, depth_draw_never;

uniform sampler2D puff : source_color, filter_nearest;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float light : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
const float CELLS = 32.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

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
	vec2 cell = floor(UV * CELLS);
	vec2 uv = (cell + 0.5) / CELLS;
	if (mod(floor(seed * 3.0), 2.0) > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	if (mod(floor(seed * 7.0), 2.0) > 0.5) {
		uv.y = 1.0 - uv.y;
	}
	vec4 t = texture(puff, uv);
	float k = fade * smoothstep(0.05, 0.5, light);
	// How many of the cells are dots: the picture's own density (its alpha, thinner at the
	// rim), at most two in five (more and they ran together in blocks), fewer as it goes.
	float dens = t.a * smoothstep(0.0, 0.9, k) * 0.4;
	if (hash(cell + floor(seed * 97.0) * 13.7) >= dens) {
		discard;
	}
	ALBEDO = mix(vec3(0.78), t.rgb, 0.5) * (0.25 + 0.55 * light);
	ALPHA = 0.6;
}
