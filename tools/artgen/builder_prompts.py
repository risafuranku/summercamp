#!/usr/bin/env python3
"""Rows of tools/artgen/prompts_builder.tsv: Builder 98's art.

    python tools/artgen/builder_prompts.py

iso4_<type>_a / _b: the four views of a building repainted from the sheet of its 3D
renders (tools/artgen/iso_views.py sheet <type>), two tries each to choose from; cut back
into sprites with `iso_views.py cut iso4_<type>_a <type>`.
Other rows (the map's life, the god cursor) are appended below by hand.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "prompts_builder.tsv")

WHAT = {
	"tent_1": "a small yellow A-frame camping tent with guy ropes and pegs",
	"tent_2": "a bigger two-person ridge tent with a porch flap, guy ropes and pegs",
	"tent_3": "a large family frame tent with a sewn-in porch and a little awning, guy ropes",
	"cabin_1": "a small bare cabin of weathered grey planks under a rusty corrugated tin roof, a door between two small windows, a concrete block for a step, firewood stacked at the side",
	"cabin_2": "a small cabin of red-painted planks with white trim under a tin roof, a little porch with two posts and its own tin roof over the door, a flower box, a lower bathroom built on at one side with a small window",
	"cabin_3": "a well kept cabin of dark stained planks with green shutters, a brick chimney, a TV aerial on the ridge, gutters, a deep porch with a bench and a lantern, a lower bathroom built on at one side",
	"caravan_1": "an old Czech touring caravan, cream with a brown stripe, a striped awning, a tow bar",
	"caravan_2": "a longer done-up touring caravan with a fresh stripe and an awning on poles",
	"caravan_3": "a large restored 1970s two-axle caravan, two-tone paint, chrome trim, a wide awning",
	"toilet_block": "a camp toilet block: a small plank and concrete hut with a WC door",
	"shower_block": "a concrete shower block with a strip of glass blocks, a green steel door and a hot-water tank on its flat roof",
	"restaurant": "a camp bistro: a single-storey building with a serving hatch, a terrace and a chimney",
	"pub": "a Czech village pub: a yellow plastered house with a dark tiled roof, a green awning over the door and a lower side wing",
	"corn_stand": "a small wooden boiled-corn stand with a counter and a striped canopy",
	"vecerka": "a Jednota village grocery: a flat-roofed concrete shop with a long shop window, a red sign board without letters and crates by the door",
	"bonfire": "a camp fire ring of stones with logs round it to sit on",
	"sports_field": "a small sports pitch: trodden grass, white lines and a net on two posts",
	"lake_slide": "a water slide: a ladder tower and a curving chute",
	"playground": "a playground: swings and a seesaw on a sandy patch",
	"ping_pong": "an outdoor concrete ping-pong table",
	"hammock": "a hammock slung between two posts",
	"bench": "a park bench with green slats and iron legs",
	"picnic_table": "a wooden picnic table with its two benches",
	"flower_bed": "a raised flower bed edged with planks, bright flowers",
	"gnome": "a garden gnome with a red hat",
	"mega_gnome": "a giant garden gnome with a red hat, as tall as a cabin",
	"flagpole": "a white flagpole with a flag, on a little concrete base",
	"sewer": "a sewage pump hatch: a concrete ring, a steel lid and a pipe",
	"lamp_post": "an old camp lamp post with one lamp head",
	"power_generator": "a diesel generator in a small tin shed",
	"main_building": "the camp office and reception: a long plank building with a porch, windows and a sign post",
}

PROMPT = (
	"The reference image is a 2x2 sheet: four isometric views of ONE camp building ({what}), "
	"rendered from a crude low-poly 3D model, each view alone in its own quarter on flat magenta. "
	"Repaint all four views as polished hand-pixelled isometric building sprites for a late-1990s camp tycoon game "
	"(RollerCoaster Tycoon 2 and Theme Hospital style): crisp pixel art, rich weathered textures (cracked plaster, "
	"worn planks, rusty tin, moss, grime), a dark one-pixel outline, soft light from the upper left on every view, "
	"a thin dark contact shadow hugging the base only. Add the hand-painted detail of the classic tycoon sprites on top of the model's flat surfaces: single roof tiles or shingles, gutters and downpipes, window frames with a glint on the glass, curtains, flower boxes, cracks, stains and moss, all without changing any shape. Keep EXACTLY what the reference shows: the 2x2 layout, the "
	"same building in the same four orientations, the same silhouette, proportions, roof shape and colours, and "
	"every door, window, porch, awning, sign and chimney in the same place on the same wall in every view. Do not "
	"mirror or turn any view, do not add other buildings, people, ground tiles, grass or any text or letters. "
	"Each view stays centred in its quarter at the same size as in the reference. Flat pure magenta (#FF00FF) "
	"background everywhere else."
)


## Small things four to a sheet (iso_views.py sheet4): a row each, its four views across.
SHEETS4 = {
	"decor1": "row 1 a park bench, row 2 a wooden picnic table with benches, row 3 a raised flower bed, row 4 a small garden gnome",
	"decor2": "row 1 a white flagpole with its flag, row 2 an old camp lamp post, row 3 a sewage pump hatch with a pipe, row 4 a diesel generator in a small tin shed",
	"fun1": "row 1 an outdoor concrete ping-pong table, row 2 a hammock between two posts, row 3 a stone fire ring with logs to sit on, row 4 a giant garden gnome",
	"fun2": "row 1 a small sports pitch with a net, row 2 a water slide with a ladder tower, row 3 a playground with swings and a seesaw, row 4 a small wooden boiled-corn stand",
}

PROMPT4 = (
	"The reference image is a 4x4 sheet of small camp things rendered from crude low-poly 3D models on flat magenta: "
	"{what}; each thing is shown four times across its own row, from four isometric directions. Repaint all sixteen "
	"pictures as polished hand-pixelled isometric sprites for a late-1990s camp tycoon game (RollerCoaster Tycoon 2 "
	"style): crisp pixel art, weathered textures, a dark one-pixel outline, soft light from the upper left on every "
	"picture, a thin dark contact shadow at the base only, the detail of classic tycoon sprites. Keep EXACTLY the "
	"reference's 4x4 layout, every picture centred in its own cell at the same size, the same silhouettes, "
	"proportions, colours and orientations; do not mirror or turn anything, no ground tiles, no grass, no people, no "
	"text. Flat pure magenta (#FF00FF) background everywhere else."
)


def main():
	rows = []
	for name, what in SHEETS4.items():
		for v in ("a", "b"):
			rows.append("iso4_%s_%s\t1:1\t../tools/artgen/out/iso3d/%s_ref.png\t%s" % (name, v, name, PROMPT4.format(what=what)))
	for t, what in WHAT.items():
		for v in ("a", "b"):
			rows.append("iso4_%s_%s\t1:1\t../tools/artgen/out/iso3d/%s_ref.png\t%s" % (t, v, t, PROMPT.format(what=what)))
	extra = []
	if os.path.exists(OUT):
		with open(OUT, encoding="utf-8") as f:
			extra = [l.rstrip("\n") for l in f if l.strip() and not l.startswith("iso4_")]
	with open(OUT, "w", encoding="utf-8", newline="\n") as f:
		f.write("\n".join(rows + extra) + "\n")
	print("%d rows" % (len(rows) + len(extra)))


if __name__ == "__main__":
	main()
