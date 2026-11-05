shader_type canvas_item;
render_mode unshaded;

// Her for an instant in the dark when you find her (nightmare_fx.lock): what is lit of her
// in hard bone white, what is dark in her left black (the dress, the eyes, the mouth).
// `negative`, him in the white the world has burnt out to: all of him black but what burns,
// the glasses.

uniform bool negative = false;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float l = dot(t.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(vec3(0.95, 0.9, 0.76) * step(negative ? 0.75 : 0.2, l), step(0.5, t.a));
}
