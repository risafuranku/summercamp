shader_type canvas_item;
render_mode unshaded;

// The studio splash's picture at 320x180 (scripts/ui/studio_splash.gd). sign_tex is the
// sign layer: rgb = the light the gas gives off, a = where there is glass. The light is
// worked out from the tubes' rectangles (rects/lights, one per tile, letter or part):
// a tight edge round each tube and the wall lit around the signs. No bloom in the air:
// it is a Build-engine picture, so it ends like materials/build_post.gdshader ends the
// world, through a 256-colour palette of 16-shade ramps (assets/boot/splash_palette_lut,
// tools/gen_splash_palette.py) with the same light ordered dither. The light comes out
// in shade steps, the colours in the palette's.

const int ELEMENTS = 21;

uniform sampler2D sign_tex : repeat_disable, filter_nearest;
uniform sampler2D wall_tex : source_color, filter_nearest;
uniform sampler2D palette_lut : filter_nearest, repeat_disable;
uniform float lut_size = 32.0;
uniform float dither_strength = 0.85;
uniform vec2 res = vec2(320.0, 180.0);
// The view slides down the wall: the wall and the tubes' rectangles are in wall
// coordinates, `pan` pixels above the view.
uniform vec2 wall_size = vec2(320.0, 180.0);
uniform float pan = 0.0;
// Per tube: xy = top-left, zw = size (wall pixels); rgb = colour x level, a = how much
// it lights the wall (a full tile 1, a word's strokes less).
uniform vec4 rects[21];
uniform vec4 lights[21];
// Grain frame: the script steps it 24 times a second, like film.
uniform float frame = 0.0;
uniform float grain = 0.012;
// Moonlight on the wall and on the coated glass of the unlit tubes.
uniform float ambient = 0.15;
uniform vec3 moon = vec3(0.46, 0.55, 0.86);
uniform vec3 milk = vec3(0.70, 0.70, 0.78);
// The edge glow round the tubes and the neon lighting the wall.
uniform float bloom = 1.0;
uniform float spill = 1.0;

const float BAYER4[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

vec3 lut_lookup(vec3 c) {
	float n = lut_size - 1.0;
	vec3 q = floor(clamp(c, 0.0, 1.0) * n + 0.5);
	vec2 uv = vec2((q.b * lut_size + q.r + 0.5) / (lut_size * lut_size), (q.g + 0.5) / lut_size);
	return texture(palette_lut, uv).rgb;
}

void fragment() {
	vec2 p = floor(UV * res) + 0.5;
	vec2 pw = p + vec2(0.0, pan);
	vec4 tube = textureLod(sign_tex, UV, 0.0);

	vec3 edge = vec3(0.0);
	vec3 near = vec3(0.0);
	vec3 wide = vec3(0.0);
	for (int i = 0; i < ELEMENTS; i++) {
		vec3 c = lights[i].rgb;
		if (c.r + c.g + c.b < 0.001) {
			continue;
		}
		vec2 half_size = rects[i].zw * 0.5;
		vec2 d2 = max(abs(pw - rects[i].xy - half_size) - half_size, 0.0);
		float d = length(d2);
		edge += c * lights[i].a * exp(-d / 1.3);
		near += c * lights[i].a * exp(-d / 5.0);
		wide += c * lights[i].a * exp(-d / 22.0);
	}

	// Moonlight from the upper left, so the wall reads even with the signs off.
	float moonlit = ambient * (0.55 + 0.9 * clamp(1.0 - (UV.x * 0.6 + UV.y * 0.8), 0.0, 1.0));
	// Glass: a >= 0.5. Coated tube (white when off): a >= 0.95; the clear panels less.
	float glass_here = step(0.5, tube.a);
	float coated = step(0.95, tube.a);
	// The signs' shadow from the moon falls down-right on the planks.
	float caster = step(0.5, textureLod(sign_tex, UV - vec2(2.0, 2.0) / res, 0.0).a);
	vec3 wall = texture(wall_tex, pw / wall_size).rgb;
	vec3 col = wall * (moon * moonlit * (1.0 - 0.75 * caster) + (wide * 0.5 + near * 0.28) * spill);
	col += edge * bloom * 0.3;
	// The glass: the neighbours' light and the moon, a highlight along the top of each
	// tube; the gas's own light on top (the layer comes premultiplied: undone here).
	float above = step(0.95, textureLod(sign_tex, UV - vec2(0.0, 1.0) / res, 0.0).a);
	vec3 glass = milk * ambient * (0.7 + 0.8 * coated) + near * 0.3;
	glass += moon * moonlit * 1.3 * coated * (1.0 - above);
	vec3 gas = tube.a > 0.001 ? tube.rgb / tube.a : vec3(0.0);
	col = mix(col, glass, glass_here) + gas * glass_here;

	vec2 q = (UV - 0.5) * vec2(1.2, 1.55);
	col *= clamp(1.0 - dot(q, q) * 1.1, 0.0, 1.0);

	col += (hash(p + vec2(frame * 17.0, frame * 29.0)) - 0.5) * grain;

	int bi = (int(p.x) & 3) + (int(p.y) & 3) * 4;
	float bayer = BAYER4[bi] / 16.0 - 0.47;
	COLOR = vec4(lut_lookup(col + vec3(bayer * dither_strength / (lut_size - 1.0))), 1.0);
}
