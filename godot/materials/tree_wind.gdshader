shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

// Trees in the wind. The whole tree leans with the wind, more the higher up (height²),
// breathing with slow gusts; crowns add a fast flutter. Strength and direction are
// global (weather_visuals.gd sets them): a still clear day barely moves, a storm bends
// the spruces and whips even the dead trunks. On the anomalous weather the wind stops.

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform float sway = 1.0;
uniform float flutter = 0.0;
uniform float height = 5.0;

global uniform float wind_strength;
global uniform vec2 wind_dir;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = clamp(VERTEX.y / height, 0.0, 1.6);
	float phase = origin.x * 0.37 + origin.z * 0.29;
	float gust = 0.55 + 0.45 * sin(TIME * 0.6 + phase * 0.5);
	float wave = sin(TIME * (1.1 + wind_strength * 0.9) + phase);
	float lean = wind_strength * (0.55 + 0.45 * gust) * 0.45;
	float bend = (lean + wave * wind_strength * gust * 0.22) * h * h * sway;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float f = flutter * wind_strength * sin(TIME * 8.0 + wp.x * 3.1 + wp.y * 2.3 + wp.z * 2.7) * 0.08 * h;
	vec3 off_world = vec3(wind_dir.x * bend + f, -abs(bend) * 0.12, wind_dir.y * bend + f * 0.6);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * off_world;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV * uv_scale);
	ALBEDO = t.rgb * albedo_color.rgb;
	ROUGHNESS = 1.0;
}
