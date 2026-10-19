shader_type canvas_item;

// The hands (scripts/ui/hands.gd): a Build-engine shade table meeting a PS1 frame
// buffer. The sprite's colour lit by the place it is in, stepped to `shades` levels
// like a sector's shade; the levels in between are not blended but dithered with a
// 4x4 Bayer matrix laid on the sprite's own pixels (the PS1's ordered dither), then
// cut to 15-bit colour, five bits a channel.

uniform vec4 light : source_color = vec4(1.0);
uniform float shades = 16.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// The sprite's pixel this fragment is in (the dither moves with the sprite).
	vec2 p = floor(UV / TEXTURE_PIXEL_SIZE);
	int i = int(mod(p.x, 4.0)) + int(mod(p.y, 4.0)) * 4;
	float d = (BAYER[i] + 0.5) / 16.0 - 0.5;
	vec3 lit = c.rgb * light.rgb;
	lit = clamp(floor(lit * shades + 0.5 + d) / shades, 0.0, 1.0);
	lit = floor(lit * 31.0 + 0.5) / 31.0;
	COLOR = vec4(lit, c.a * light.a);
}
