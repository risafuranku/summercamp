shader_type spatial;
// The hover glint (materials/hover_glint.gdshader) for a Duke 3D sprite on a station
// (scripts/business/station3d.gd): laid over the sprite as its material_overlay, only
// where the sprite's own picture is (the mask), so a slice in the pan sparkles in its
// own shape and not as a square round it.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D mask : source_color, filter_nearest;
uniform sampler2D glint : source_color, filter_nearest, repeat_enable;
uniform bool has_glint = false;
uniform vec4 tint : source_color = vec4(1.0, 0.80, 0.42, 1.0);
uniform float wash = 0.2;
uniform float sparkle = 0.9;
uniform float metres = 1.4;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (texture(mask, UV).a < 0.5) {
		discard;
	}
	float step_t = floor(TIME * 8.0) / 8.0;
	float breath = 0.65 + 0.35 * sin(step_t * 4.2);
	vec2 uv = (wpos.xz + wpos.xy * 0.5) / metres;
	float g = 0.0;
	if (has_glint) {
		vec2 drift = vec2(floor(step_t * 3.0) * 0.0625, -floor(step_t * 2.0) * 0.0625);
		vec3 a = texture(glint, uv + drift).rgb;
		vec3 b = texture(glint, uv * 0.73 - drift * 1.7 + 0.31).rgb;
		g = max(a.r, max(a.g, a.b)) * max(b.r, max(b.g, b.b));
		g = step(0.18, g) * g;
	}
	ALBEDO = tint.rgb * (wash * breath + sparkle * g);
}
