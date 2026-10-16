shader_type canvas_item;

// The reception monitor drawn crisp over the low-res room (building_interior.gd
// _update_crt_sharp): the OS picture at full window resolution, so text stays readable
// at any render style, behind the same curved glass as the tube in the room
// (crt_glass.gdshader): the same barrel and rounded corners, so the two line up and the
// mouse lands where it points (building_interior.gd CRT_CURVE), scanlines, a vignette,
// a little phosphor bloom and the sheen of the glass.

uniform float curve = 0.16;
uniform float corner_radius = 0.05;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.16;
uniform float scanline_period = 3.0;      // screen pixels per scanline
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.38;
uniform float glow : hint_range(0.0, 0.3) = 0.06;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

vec2 barrel(vec2 uv) {
	vec2 c = uv - 0.5;
	float d = dot(c, c);
	return 0.5 + c * (1.0 + curve * d) / (1.0 + curve * 0.25);
}

void fragment() {
	vec2 uv = barrel(UV);
	vec2 e = abs(UV - 0.5) - vec2(0.5 - corner_radius);
	float sd = length(max(e, vec2(0.0))) - corner_radius;
	float mask = 1.0 - smoothstep(-0.004, 0.001, sd);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	vec4 c = texture(TEXTURE, clamp(uv, 0.0, 1.0));
	c.rgb *= inside;
	float line = 0.5 + 0.5 * cos(FRAGCOORD.y * 6.2831853 / scanline_period);
	c.rgb *= 1.0 - scanline_strength * line;
	vec2 d = uv - 0.5;
	float v = 1.0 - vignette_strength * smoothstep(0.08, 0.5, dot(d, d) * 2.0);
	c.rgb = c.rgb * v + glow * c.rgb * c.rgb;
	// The glass: a broad diagonal sheen and a brighter rim.
	float sheen = smoothstep(0.40, 0.0, abs((UV.x + UV.y) - 0.62)) * 0.04;
	float rim = smoothstep(-0.05, 0.0, sd) * 0.06;
	c.rgb += vec3(sheen + rim);
	c.rgb += vec3(0.02, 0.026, 0.03);
	c.a = mask * fade;
	COLOR = c;
}
