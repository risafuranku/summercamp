shader_type sky;

uniform sampler2D panorama_from : filter_linear, source_color;
uniform sampler2D panorama_to : filter_linear, source_color;
uniform float blend : hint_range(0.0, 1.0) = 0.0;

void sky() {
	vec3 col_from = texture(panorama_from, SKY_COORDS).rgb;
	vec3 col_to = texture(panorama_to, SKY_COORDS).rgb;
	COLOR = mix(col_from, col_to, blend);
}
