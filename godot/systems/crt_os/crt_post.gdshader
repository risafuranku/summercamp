shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float scanline_strength : hint_range(0.0, 0.4) = 0.12;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.42;
uniform float noise_amount : hint_range(0.0, 0.08) = 0.02;
uniform float warp_amount : hint_range(0.0, 0.05) = 0.012;
uniform float flicker_strength : hint_range(0.0, 0.08) = 0.03;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv * 2.0 - 1.0;
	float radial = dot(centered, centered);
	centered *= 1.0 + radial * warp_amount;
	uv = centered * 0.5 + 0.5;

	vec4 color = texture(screen_texture, uv);
	float scanlines = sin((UV.y + TIME * 0.3) * 980.0) * scanline_strength;
	float grain = (hash(UV * vec2(960.0, 540.0) + TIME) - 0.5) * noise_amount;
	float vignette = 1.0 - smoothstep(0.25, 1.25, radial) * vignette_strength;
	float flicker = 1.0 - (hash(vec2(TIME * 20.0, 0.0)) * flicker_strength);

	color.rgb -= scanlines;
	color.rgb += grain;
	color.rgb *= vignette * flicker;
	color.rgb = clamp(color.rgb, vec3(0.0), vec3(1.0));
	COLOR = color;
}
