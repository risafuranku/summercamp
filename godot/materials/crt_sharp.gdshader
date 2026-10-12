shader_type canvas_item;

// The reception monitor drawn crisp over the low-res room (building_interior.gd
// _update_crt_sharp): the OS picture at full window resolution, so text stays readable
// at any render style, with a light CRT finish so it still looks like a tube.

uniform float scanline_strength : hint_range(0.0, 0.5) = 0.16;
uniform float scanline_period = 3.0;      // screen pixels per scanline
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float glow : hint_range(0.0, 0.3) = 0.06;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// Horizontal scanlines in screen space.
	float line = 0.5 + 0.5 * cos(FRAGCOORD.y * 6.2831853 / scanline_period);
	c.rgb *= 1.0 - scanline_strength * line;
	// A soft darkening towards the tube's edges and a touch of phosphor bloom.
	vec2 d = UV - 0.5;
	float v = 1.0 - vignette_strength * smoothstep(0.18, 0.75, dot(d, d) * 2.2);
	c.rgb = c.rgb * v + glow * c.rgb * c.rgb;
	c.a *= fade;
	COLOR = c;
}
