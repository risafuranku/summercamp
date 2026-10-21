shader_type spatial;
render_mode unshaded, cull_disabled;

// The reception monitor's picture tube (building_interior.gd): the OS picture behind
// curved glass. The glass bows out toward you (the mesh is subdivided and pushed out),
// the picture bends with it (the same barrel as crt_sharp.gdshader and the mouse
// mapping in building_interior.gd, CRT_CURVE), the corners are rounded and dark, a
// faint raster of scanlines, the light of the room caught in it as a highlight and a
// sheen that moves as you move, the rim brighter where you see the glass edge on.

uniform sampler2D screen_tex : source_color, filter_linear;
uniform float curve = 0.16;
uniform float corner_radius = 0.05;
uniform float bulge = 0.024;
uniform float scan = 0.14;
uniform float lines = 480.0;
uniform float brightness = 0.95;
uniform float powered = 1.0;
uniform vec3 glass = vec3(0.02, 0.026, 0.03);
// The part of screen_tex this tube shows (x, y, w, h): with the second monitor the
// office PC draws both screens side by side in one picture (building_interior.gd).
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);

varying vec2 v_c;

vec2 barrel(vec2 uv) {
	vec2 c = uv - 0.5;
	float d = dot(c, c);
	return 0.5 + c * (1.0 + curve * d) / (1.0 + curve * 0.25);
}

void vertex() {
	v_c = UV - 0.5;
	vec2 q = v_c * 2.0;
	float w = 1.0 - clamp(dot(q, q) * 0.5, 0.0, 1.0);
	VERTEX.z += bulge * w;
	NORMAL = normalize(vec3(v_c.x * bulge * 9.0, -v_c.y * bulge * 9.0, 1.0));
}

void fragment() {
	vec2 uv = barrel(UV);
	vec2 e = abs(UV - 0.5) - vec2(0.5 - corner_radius);
	float sd = length(max(e, vec2(0.0))) - corner_radius;
	float mask = 1.0 - smoothstep(-0.006, 0.002, sd);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	vec3 pic = texture(screen_tex, uv_rect.xy + clamp(uv, 0.0, 1.0) * uv_rect.zw).rgb * brightness * powered;
	pic *= 1.0 - scan * (0.5 + 0.5 * cos(uv.y * lines * 6.2831853));
	float vig = dot(uv - 0.5, uv - 0.5);
	pic *= 1.0 - 0.38 * smoothstep(0.08, 0.5, vig * 2.0);
	// Past the rounded glass: the black of the tube's mask, as black as the bezel's inside.
	vec3 col = mix(glass, pic + glass, inside) * mask;
	// The room in the glass: a soft highlight from the ceiling light, a broad sheen.
	vec3 r = reflect(-VIEW, NORMAL);
	float spec = pow(max(dot(r, normalize(vec3(-0.35, 0.75, 0.55))), 0.0), 28.0) * 0.22;
	float sheen = smoothstep(0.42, 0.0, abs((UV.x + UV.y) - 0.62 + VIEW.x * 0.3)) * 0.035;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * 0.10;
	col += (spec + sheen + rim) * mask;
	ALBEDO = col;
}
