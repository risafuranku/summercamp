shader_type canvas_item;
render_mode unshaded;

// Builder 98's hidden 3D view (scripts/builder/map3d.gd): the camp's world from the
// strategy camera, rendered at half the PC's pixels, through the same 256-colour Build
// palette as the world view (materials/build_post.gdshader), coming in and going out in
// an ordered dither of its own pixels (`reveal`, stepped by the script).

uniform sampler2D palette_lut : filter_nearest, repeat_disable;
uniform float lut_size = 32.0;
uniform float palette_mix : hint_range(0.0, 1.0) = 1.0;
uniform float dither_strength : hint_range(0.0, 2.0) = 0.3;
uniform float contrast : hint_range(0.5, 1.5) = 1.06;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
// PC pixels per view pixel (the dither's cell).
uniform float cell = 2.0;
// After dusk the darks are lifted (a gamma, so the lamps stay where they are).
uniform float lift : hint_range(0.0, 1.0) = 0.0;

const float BAYER4[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

vec3 lut_lookup(vec3 c) {
	float n = lut_size - 1.0;
	vec3 q = floor(clamp(c, 0.0, 1.0) * n + 0.5);
	vec2 uv = vec2((q.b * lut_size + q.r + 0.5) / (lut_size * lut_size), (q.g + 0.5) / lut_size);
	return texture(palette_lut, uv).rgb;
}

void fragment() {
	vec2 rc = floor(FRAGCOORD.xy / cell);
	int ri = (int(rc.x) & 3) + (int(rc.y) & 3) * 4;
	if ((BAYER4[ri] + 0.5) / 16.0 > reveal) {
		discard;
	}
	vec4 raw = texture(TEXTURE, UV);
	vec3 c = pow(max(raw.rgb, vec3(0.0)), vec3(1.0 / (1.0 + lift * 1.5)));
	c = (c - 0.5) * contrast + 0.5;
	ivec2 px = ivec2(floor(UV / TEXTURE_PIXEL_SIZE));
	float bayer = BAYER4[(px.x & 3) + (px.y & 3) * 4] / 16.0 - 0.47;
	vec3 dithered = sqrt(clamp(c, 0.0, 1.0)) + vec3(bayer * dither_strength / (lut_size - 1.0));
	vec3 pal = lut_lookup(dithered);
	COLOR = vec4(mix(clamp(c, 0.0, 1.0), pal, palette_mix), 1.0);
}
