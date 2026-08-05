shader_type canvas_item;

uniform float color_depth : hint_range(1.0, 32.0) = 15.0; // PS1 was 15-bit typically
uniform bool dithering = true;
uniform float fisheye_strength : hint_range(-0.1, 0.1) = -0.02; // Negative for slight barrel
uniform float resolution_scale = 1.0; 

// Dither matrix 4x4
const float dither[16] = float[](
	0.0, 0.5, 0.125, 0.625,
	0.75, 0.25, 0.875, 0.375,
	0.1875, 0.6875, 0.0625, 0.5625,
	0.9375, 0.4375, 0.8125, 0.3125
);

vec2 distort(vec2 uv) {
	vec2 center = vec2(0.5, 0.5);
	vec2 rel = uv - center;
	float d2 = dot(rel, rel);
	float f = 1.0 + d2 * fisheye_strength;
	return center + rel * f;
}

void fragment() {
	vec2 uv = UV;
	
	// Apply barrel distortion
	uv = distort(uv);
	
	// Black out out-of-bounds UVs
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec4 raw = texture(TEXTURE, uv);
		vec3 color = raw.rgb;
		
		if (dithering) {
			int x = int(FRAGCOORD.x) % 4;
			int y = int(FRAGCOORD.y) % 4;
			int index = x + y * 4;
			float d = (dither[index] - 0.5) / color_depth;
			color += d;
		}
		
		// Color quantization
		float steps = pow(2.0, 5.0) - 1.0; // 5 bits per channel (15-bit color)
		color = floor(color * steps) / steps;
		
		COLOR = vec4(color, raw.a);
	}
}
