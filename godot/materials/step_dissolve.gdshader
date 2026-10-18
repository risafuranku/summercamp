shader_type canvas_item;
render_mode unshaded;

// The frozen frame of a door transition (scripts/ui/door_transition.gd): it breaks up
// in an ordered dither of whole game pixels (`cell` screen pixels each, the 240-line
// grid), darkening as it goes, so the new view shows through it. `progress` runs
// smoothly (the script, at the full frame rate).

uniform float progress = 0.0;
uniform float cell = 4.0;

const float BAYER4[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec2 c = floor(FRAGCOORD.xy / cell);
	int i = (int(c.x) & 3) + (int(c.y) & 3) * 4;
	float threshold = (BAYER4[i] + 0.5) / 16.0;
	vec4 frozen = texture(TEXTURE, UV);
	frozen.rgb *= 1.0 - progress * 0.55;
	COLOR = vec4(frozen.rgb, progress < threshold ? 1.0 : 0.0);
}
