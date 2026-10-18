shader_type spatial;
// The hover highlight on things you can use in a room (scripts/ui/hover_glint.gd):
// laid over the object as material_overlay. A warm wash that breathes, plus pixel
// glints from a tiled texture in world space that crawl in steps (8 a second, like
// the rest of the game's animation), so the object looks dusted with light rather
// than outlined by a UI.
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

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
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
