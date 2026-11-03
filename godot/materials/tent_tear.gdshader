shader_type spatial;
render_mode cull_disabled, specular_disabled;

// The tent's canvas the mushroom granny tore open (interior_prep's "slit", tent_interior
// _tick_tear; Richard 3. 11.: "lepe udelat protrzeny stan. fakt dirou videt ven"). One
// picture (assets/textury/mess/carnage_tear.png, tools/artgen/tear.py): the torn edge of
// the canvas where it is opaque, the hole where it is magenta, nothing elsewhere (the
// tent's own back wall behind it). In the hole the camp as it is from there, read from the
// room's shared view of the camp at the hole's own screen pixels (window_shared_view.gd),
// as a doorway reads it; the edge lit by the room's lights and stirring in the wind, a step
// at a time like the rest of the Build world.

uniform sampler2D tear_tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D room_tex : source_color, filter_nearest;
uniform float live = 0.0;
// The night out there while the camp is not drawn (a tool's room, or out of sight).
uniform vec3 dark = vec3(0.012, 0.014, 0.02);
// The wind on the flaps (room_weather's): how far the torn edge stirs.
uniform float wind = 0.3;
// The picture's width in texels (a texel of stir).
uniform float texels = 88.0;
// The task's hover look (interior_tasks swaps the material in): the edge glows a little.
uniform float hl = 0.0;

void fragment() {
	float t = floor(TIME * 12.0) / 12.0;
	// A slow swell of the gusts, and the cloth's wave running up the tear.
	float gust = 0.55 + 0.45 * sin(t * 1.3) * sin(t * 0.47 + 1.1);
	float dx = sin(UV.y * 13.0 + t * 5.0) * wind * gust * 1.6 / texels;
	vec4 c = texture(tear_tex, UV + vec2(dx, 0.0));
	if (c.a < 0.5) {
		discard;
	}
	ROUGHNESS = 1.0;
	if (c.r > 0.7 && c.g < 0.3 && c.b > 0.7) {
		// The hole: the camp out there, as it is lit, not lit by the room.
		ALBEDO = vec3(0.0);
		EMISSION = mix(dark, texture(room_tex, SCREEN_UV).rgb, live);
	} else {
		ALBEDO = c.rgb;
		EMISSION = c.rgb * hl * 0.35 * vec3(1.0, 0.85, 0.5);
	}
}
