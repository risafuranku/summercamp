shader_type canvas_item;

// The night's close-ups (a face in yours, a frame of something, scripts/night/
// nightmare_fx.gd; the boy's face over the board and in the pipes) drawn as the world is
// (materials/build_post.gdshader): in the world's game pixels, snapped to the screen's
// grid of them however the picture is scaled, turned or shaken (the texture's UV moves
// linearly over the screen, so the middle of each game pixel is found from its
// derivatives), then through the same 256-colour palette with the same ordered dither.
// Drawn at the screen's full resolution they read as a clean painting laid over a Build
// game (the user, 21. 10.: "jumpscare hlavy nedrží pixelated build engine styl").

uniform sampler2D palette_lut : filter_nearest, repeat_disable;
uniform float lut_size = 32.0;
uniform float palette_mix : hint_range(0.0, 1.0) = 1.0;
uniform float dither_strength : hint_range(0.0, 2.0) = 0.3;
uniform float contrast : hint_range(0.5, 1.5) = 1.06;
// Screen pixels to one game pixel (RetroRender.internal_scale).
uniform float px_size = 4.0;

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
	vec2 fc = FRAGCOORD.xy;
	vec2 cell = floor(fc / px_size);
	vec2 d = (cell + 0.5) * px_size - fc;
	vec2 uv = UV + dFdx(UV) * d.x + dFdy(UV) * d.y;
	vec4 raw = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	vec3 c = clamp((raw.rgb - 0.5) * contrast + 0.5, 0.0, 1.0) * COLOR.rgb;
	ivec2 p = ivec2(cell);
	float bayer = BAYER4[(p.x & 3) + (p.y & 3) * 4] / 16.0 - 0.47;
	vec3 pal = lut_lookup(sqrt(c) + vec3(bayer * dither_strength / (lut_size - 1.0)));
	COLOR = vec4(mix(c, pal, palette_mix), raw.a * COLOR.a);
}
