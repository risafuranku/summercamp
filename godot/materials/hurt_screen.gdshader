shader_type canvas_item;

// What being hurt does to the view (scripts/ui/hurt_fx.gd), drawn in Build's way: in the
// game's pixels, in steps, dithered, never a smooth gradient.
//   flash   a hit: the palette pushed into red for a few steps (Duke's red flash);
//   hurt    low on health: the colour drains to rust, the edges close in dark red, and
//           they pulse with the heart;
//   dark    a moment of blacking out.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float hurt : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float dark : hint_range(0.0, 1.0) = 0.0;
// Screen pixels to one game pixel (RetroRender.internal_scale).
uniform float px_size = 4.0;

const float BAYER4[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	ivec2 p = ivec2(floor(FRAGCOORD.xy / px_size));
	float b = (BAYER4[(p.x & 3) + (p.y & 3) * 4] + 0.5) / 16.0;
	// Drained towards rust.
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 rust = vec3(lum * 1.12, lum * 0.52, lum * 0.42);
	c = mix(c, rust, hurt * 0.6);
	// The edges closing in, with the heart.
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float r = length((SCREEN_UV - 0.5) * aspect) / length(0.5 * aspect);
	float inner = 0.92 - hurt * 0.42 - pulse * hurt * 0.1;
	float v = smoothstep(inner, inner + 0.35, r) * (0.35 + 0.65 * hurt);
	v = floor(v * 4.0 + b) / 4.0;
	c = mix(c, vec3(0.16, 0.0, 0.0), clamp(v, 0.0, 0.92));
	// The hit's flash: the palette into red, in three steps.
	float f = floor(flash * 3.0 + b * 0.9) / 3.0;
	c = mix(c, c * vec3(1.35, 0.22, 0.18) + vec3(0.22, 0.0, 0.0), f * 0.85);
	// Blacking out.
	float d = floor(dark * 4.0 + b) / 4.0;
	c *= 1.0 - clamp(d, 0.0, 1.0);
	COLOR = vec4(c, 1.0);
}
