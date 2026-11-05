shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// The corn field's ground in one piece (scripts/cornfield.gd): the ploughed soil, and the
// maze's ways trodden pale through it, a map of the maze saying where, their edges ragged.
// They were a flat colour and a tile of another a centimetre over it, the two fighting from
// further off (the user 5. 11.: "the ground has no textures, a clipping path").

uniform sampler2D soil : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D way : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D maze : filter_linear, repeat_disable;
// x, z, width, depth of the maze.
uniform vec4 maze_rect = vec4(0.0, 0.0, 1.0, 1.0);
// Metres a picture covers.
uniform float metres = 2.6;
// Build's visibility (retro_materials): things darken with distance, deeper at night.
global uniform float build_vis_dist;
global uniform float build_vis_dark;

varying vec3 at;
varying float depth;

void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	vec2 uv = at.xz / metres;
	vec3 ground = texture(soil, uv).rgb;
	// Big patches over the tile, so it does not show as one.
	float patches = textureLod(soil, uv * 0.09, 4.0).r + textureLod(soil, uv * 0.031 + 0.4, 4.0).g;
	ground *= 0.72 + patches * 1.15;
	// Crossed with itself: the picture's own ruts go one way, the ways all ways.
	vec3 trod = mix(texture(way, uv).rgb, texture(way, uv.yx + 0.37).rgb, 0.5);
	vec2 m = (at.xz - maze_rect.xy) / maze_rect.zw;
	float open = texture(maze, m).r * step(0.0, m.x) * step(0.0, m.y) * step(m.x, 1.0) * step(m.y, 1.0);
	float rag = texture(way, uv * 1.7).g - 0.5;
	ALBEDO = mix(ground, trod, step(0.5, open + rag * 0.3));
	if (build_vis_dark > 0.0) {
		ALBEDO *= 1.0 - clamp(depth / max(build_vis_dist, 1.0), 0.0, 1.0) * build_vis_dark;
	}
	ROUGHNESS = 1.0;
}
