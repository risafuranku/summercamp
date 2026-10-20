shader_type spatial;
// The hover highlight on things you can use in a room (scripts/ui/hover_glint.gd):
// laid over the object as material_overlay. A warm wash that breathes, plus pixel
// glints from a tiled texture in world space that crawl in steps (8 a second, like
// the rest of the game's animation), so the object looks dusted with light rather
// than outlined by a UI. On a sprite (a cut-out picture on a quad, turned to you: the
// desk bell) it takes the sprite's own shape and turn (`sprite_tex`, `sprite_billboard`),
// or it lit the whole quad, flat and the wrong way round: a box round the bell.
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

uniform sampler2D glint : source_color, filter_nearest, repeat_enable;
uniform bool has_glint = false;
uniform vec4 tint : source_color = vec4(1.0, 0.80, 0.42, 1.0);
uniform float wash = 0.16;
uniform float sparkle = 0.85;
// One tile of glints to 1.4 m: the rooms' own pixel (128 px to a 1.4 m tile), finer
// would melt into a flat wash at the game's resolution.
uniform float metres = 1.4;
uniform float fade = 1.0;
uniform sampler2D sprite_tex : source_color, filter_nearest;
uniform bool use_sprite = false;
// 0 none, 1 turned to the camera, 2 turned round the upright only.
uniform int sprite_billboard = 0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	if (sprite_billboard == 1) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	} else if (sprite_billboard == 2) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	}
	if (sprite_billboard != 0) {
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
		wpos = (INV_VIEW_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		wnorm = normalize((INV_VIEW_MATRIX * vec4(mat3(MODELVIEW_MATRIX) * NORMAL, 0.0)).xyz);
	} else {
		wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
}

void fragment() {
	if (use_sprite && texture(sprite_tex, UV).a < 0.5) {
		discard;
	}
	float step_t = floor(TIME * 8.0) / 8.0;
	float breath = 0.65 + 0.35 * sin(step_t * 4.2);
	vec3 n = abs(wnorm);
	vec2 uv = n.x > n.y && n.x > n.z ? wpos.zy : (n.y > n.z ? wpos.xz : wpos.xy);
	uv /= metres;
	float g = 0.0;
	if (has_glint) {
		vec2 drift = vec2(floor(step_t * 3.0) * 0.0625, -floor(step_t * 2.0) * 0.0625);
		vec3 a = texture(glint, uv + drift).rgb;
		vec3 b = texture(glint, uv * 0.73 - drift * 1.7 + 0.31).rgb;
		g = max(a.r, max(a.g, a.b)) * max(b.r, max(b.g, b.b));
		g = step(0.18, g) * g;
	}
	vec3 c = tint.rgb * (wash * breath + sparkle * g);
	ALBEDO = c * fade;
}
