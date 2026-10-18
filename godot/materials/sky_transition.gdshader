shader_type sky;

// Two pairs of panoramas (weather_visuals.gd _sky_pair): each pair blends with the clock
// (day -> evening -> dusk -> night), and `blend` cross-fades from the old pair to the new
// one when the weather changes.
uniform sampler2D from_a : filter_linear, source_color;
uniform sampler2D from_b : filter_linear, source_color;
uniform float from_t : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D to_a : filter_linear, source_color;
uniform sampler2D to_b : filter_linear, source_color;
uniform float to_t : hint_range(0.0, 1.0) = 0.0;
uniform float blend : hint_range(0.0, 1.0) = 1.0;

void sky() {
	vec3 col_from = mix(texture(from_a, SKY_COORDS).rgb, texture(from_b, SKY_COORDS).rgb, from_t);
	vec3 col_to = mix(texture(to_a, SKY_COORDS).rgb, texture(to_b, SKY_COORDS).rgb, to_t);
	COLOR = mix(col_from, col_to, blend);
}
