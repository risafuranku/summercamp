#!/usr/bin/env python3
"""Rows for the people seen from eight sides (DESIGN.md "People as in Doom"): writes
tools/artgen/prompts_figures.tsv, read by gen.sh.

    python tools/artgen/figure_prompts.py

For each person (FIGURES) and sheet (SHEETS): a turnaround of five standing views, then
the walk, the run, the idle and the work, each as one picture of several frames so Grok
keeps the person the same across them. The reference is the person's sprite from the
front (the law: it is never redrawn) blown up four times on magenta, and once the
turnaround is picked, that sprite beside the turnaround (figures.py ref). Variants are
the same row under _1, _2, ... (one Grok run each, the best is picked by figures.py).
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "prompts_figures.tsv")

STYLE = ("Pixel-art game character sprites in exactly the same style as the reference image, "
	"a mid-1990s Build-engine game like Duke Nukem 3D, Blood or Redneck Rampage: the same coarse "
	"pixel size, the same limited palette, the same shading and the same dark outline. ")
SAME = ("Every figure is exactly the person in the reference image, with the same face, hair, "
	"body, proportions, clothes, colours and things they carry, nothing added and nothing left "
	"out: %s. ")
BG = ("Background must be flat solid pure magenta #FF00FF everywhere around and between the "
	"figures, no ground, no floor line, no shadows, no text, no labels, no numbers, no grid lines, "
	"no frames, no borders, no watermark.")

## The five views of a turnaround, in the order they stand in the sheet.
VIEWS = ("(1) seen straight from the front, (2) a three-quarter view from the front with the body "
	"turned toward the right edge of the image, (3) an exact side profile facing the right edge "
	"of the image, (4) a three-quarter view from behind, turned away toward the right edge of the "
	"image so the back and the right shoulder show, (5) seen straight from behind, the back of "
	"the head and the back of the clothes")
## The same five, one at a time (walk and run rows: one picture per view).
VIEW = {
	1: "seen straight from the front, walking toward the viewer",
	2: "seen in three-quarter view from the front, the body turned toward the right edge of the image, walking toward the lower right",
	3: "seen in exact side profile, facing and walking toward the right edge of the image",
	4: "seen in three-quarter view from behind, turned away toward the right edge of the image so the back and the right shoulder show, walking away toward the upper right",
	5: "seen straight from behind, walking away from the viewer, the back of the head and the back of the clothes showing",
}
RUN_VIEW = {k: v.replace("walking", "running") for k, v in VIEW.items()}

## Grok copies one stride four times when asked for "a walk cycle" (fig_warden_a_walk3_1):
## the frames are named by their shape, the passing ones as standing on one leg.
WALK = ("Four frames of a classic sprite walking animation in one row, left to right, evenly "
	"spaced with clear magenta gaps, all the same scale with the feet on one common baseline "
	"near the bottom edge, the person %s. Each frame is a clearly DIFFERENT pose, never a copy "
	"of another frame. Frame 1, STRIDE: the legs spread wide apart like an upside-down V, the "
	"left leg reaching forward with its heel on the ground, the right leg stretched behind on its "
	"toes, the right arm swung forward and the left arm back. Frame 2, PASSING: the legs close "
	"together under the body, standing on the straight left leg, the right knee bent and lifted "
	"so the right foot is off the ground beside the left shin, the arms hanging down by the "
	"sides; this frame is narrower than frame 1. Frame 3, STRIDE the other way: the legs spread "
	"wide apart again, now the right leg reaching forward with its heel on the ground and the "
	"left leg stretched behind on its toes, the left arm swung forward and the right arm back. "
	"Frame 4, PASSING the other way: the legs close together, standing on the straight right "
	"leg, the left knee bent and lifted so the left foot is off the ground, the arms hanging "
	"down. A calm walking pace, the body upright. ")
## Straight from the front or behind Grok turns the strides sideways (fig_warden_a_walk1_2:
## the body three-quarter in frames 1 and 3): square shoulders, the legs apart toward and
## away from you, the forward foot lower in the picture.
WALK_SQUARE = ("Four frames of a classic sprite walking animation in one row, left to right, "
	"evenly spaced with clear magenta gaps, all the same scale with the feet near one common "
	"baseline at the bottom edge, the person %s. The chest, the hips and both shoulders face "
	"the viewer squarely in EVERY frame, the body never turns sideways, the legs move toward "
	"and away from the viewer, not to the side. Each frame is a clearly DIFFERENT pose, never a "
	"copy of another frame. Frame 1: the left leg steps %s, its foot lower in the picture, the "
	"right leg behind it with the heel lifted, the right arm swung forward and the left arm back. "
	"Frame 2: passing, both feet under the body, standing on the straight left leg, the right "
	"knee bent and the right foot lifted off the ground, the arms hanging down. Frame 3: the "
	"right leg steps %s, its foot lower in the picture, the left leg behind it with the heel "
	"lifted, the left arm swung forward and the right arm back. Frame 4: passing, standing on "
	"the straight right leg, the left knee bent and the left foot lifted, the arms hanging down. "
	"A calm walking pace. ")
RUN_SQUARE = ("Four frames of a classic sprite running animation in one row, left to right, "
	"evenly spaced with clear magenta gaps, all the same scale, the person %s, leaning a little "
	"forward, the arms bent at the elbows. The chest, the hips and both shoulders face the "
	"viewer squarely in EVERY frame, the body never turns sideways, the legs move toward and "
	"away from the viewer. Each frame is a clearly DIFFERENT pose. Frame 1: the left knee "
	"driven high %s, the right leg pushing off behind, the right fist pumped up in front. "
	"Frame 2: both feet off the ground, the legs passing. Frame 3: the right knee driven high "
	"%s, the left leg pushing off behind, the left fist pumped up in front. Frame 4: both "
	"feet off the ground again. Whatever they carry stays in the same hand as in the reference. ")
SQUARE_WAY = {1: "forward toward the viewer", 5: "forward away from the viewer"}

RUN = ("Four frames of a classic sprite running animation in one row, left to right, evenly "
	"spaced with clear magenta gaps, all the same scale, the person %s, leaning a little "
	"forward, the arms bent at the elbows. Each frame is a clearly DIFFERENT pose, never a copy "
	"of another frame. Frame 1, PUSH: a long stride, the left leg reaching far forward with the "
	"knee bent and the foot landing, the right leg stretched far behind pushing off from its "
	"toes, the right arm pumped forward and the left arm back. Frame 2, FLIGHT: both feet off "
	"the ground, the right knee driven high up in front, the left foot kicked up behind toward "
	"the seat, the arms swapping; this frame is narrower than frame 1. Frame 3, PUSH the other "
	"way: the right leg reaching far forward and landing, the left leg stretched far behind, the "
	"left arm pumped forward and the right arm back. Frame 4, FLIGHT the other way: both feet off "
	"the ground, the left knee high in front, the right foot kicked up behind. Whatever they "
	"carry stays in the same hand as in the reference. ")

# Who they are: the sprite from the front (relative to godot/) and every piece of them.
FIGURES = {
	"warden_a": ("assets/textury/npc/warden_a.png",
		"a young man in his twenties, a tired face, short messy dark brown hair and no hat or cap, "
		"a faded dark green zip-up windbreaker worn open with a small round orange camp patch on "
		"the left chest, a grey hoodie under it with the hood down, worn blue jeans with mud "
		"stains, muddy green rubber boots, a ring of keys on the belt, a black rubber flashlight "
		"held low in his right hand pointing at the ground"),
	"warden_b": ("assets/textury/npc/warden_b.png",
		"a young man in his twenties, a tired face, a knitted dark grey beanie, a faded red rain "
		"anorak with the hood down over a dark grey collared shirt, a khaki canvas shoulder bag "
		"on a strap across the body hanging at his left hip, dark charcoal grey cargo trousers, "
		"brown hiking boots, a black rubber flashlight held low in his right hand pointing at "
		"the ground"),
	"warden_c": ("assets/textury/npc/warden_c.png",
		"a young woman in her twenties, a tired face, dark brown hair tied back in a ponytail and "
		"no hat, a faded dark green zip-up windbreaker worn open with a small round orange camp "
		"patch on the left chest, a grey hoodie under it with the hood down, worn blue jeans "
		"with mud stains, dark olive lace-up boots, a ring of keys on the belt, a black rubber "
		"flashlight held low in her right hand pointing at the ground; nothing else on her is green"),
	"warden_d": ("assets/textury/npc/warden_d.png",
		"a young woman in her twenties, a tired face, short curly auburn hair and no hat, small "
		"round glasses, a faded dark green hooded parka worn open over a cream knitted jumper, a "
		"brown canvas shoulder bag on a strap across the body, dark charcoal grey trousers, brown "
		"lace-up hiking boots, a black rubber flashlight held low in her right hand pointing at "
		"the ground; nothing else on her is green"),
	"host1": ("assets/textury/npc/host1.png",
		"a thin, pale, quiet man in his forties, a beige bucket hat, small round dark sunglasses, "
		"a grey patterned short-sleeved shirt worn open over an olive green t-shirt, a green "
		"rucksack on his back, baggy faded blue jeans, grey trainers, his arms hanging by his sides"),
	"host2": ("assets/textury/npc/host2.png",
		"a stout, sunburnt, red-faced man of about forty-five with a wide grin, a green and white "
		"trucker cap, dark sunglasses, a yellow t-shirt with a green lizard and an orange sun "
		"printed on it, a black camera on a strap round his neck, a red checked flannel shirt "
		"tied round his waist, frayed denim cut-off shorts, white socks, brown hiking boots, a "
		"brown beer bottle in his right hand and a rolled-up green sleeping mat under his left arm"),
	"host3": ("assets/textury/npc/host3.png",
		"a skinny young woman of about twenty-five, long curly brown hair under a red bandana "
		"headband, heavy make-up, a short tight black dress with a low neckline, a thin gold "
		"necklace and gold bracelets, dark spotted fishnet tights, red high-heeled sandals with "
		"ankle straps, a small green handbag hanging from her left arm, a lit cigarette held up "
		"in her left hand"),
	"host_tramp": ("assets/textury/npc/host_tramp.png",
		"a Czech tramp camper, a bearded man of about thirty, a battered brown cowboy hat, a red "
		"checked flannel shirt with the sleeves rolled up, a big olive army canvas rucksack on "
		"his back with a tin mug hanging from it, an acoustic guitar slung on his back with its "
		"neck up behind his left shoulder, faded blue jeans, heavy brown boots"),
	"host_father": ("assets/textury/npc/host_father.png",
		"a tired Czech father of about thirty-five on a family holiday, short brown hair, a "
		"moustache, a red zip-up track jacket with two white stripes across the chest over a "
		"white t-shirt, khaki shorts, white socks pulled up, brown sandals"),
	"host_mother": ("assets/textury/npc/host_mother.png",
		"a Czech mother of about thirty-five on a family holiday, short permed light brown hair, "
		"a turquoise and purple windbreaker jacket worn open over a white t-shirt, a black bum bag "
		"on her belt, light blue jeans, white trainers"),
	"host_kid": ("assets/textury/npc/host_kid.png",
		"a small boy of about seven, a red baseball cap, a blue and white striped t-shirt, green "
		"shorts, blue and white trainers, a thin red toy fishing rod held upright in his right hand"),
	"host_pensioner": ("assets/textury/npc/host_pensioner.png",
		"an elderly stooped Czech woman of about seventy, a mushroom picker, grey hair under a "
		"beige headscarf, a brown knitted cardigan over a long blue-grey flowered dress, green "
		"rubber boots, a big wicker basket with a few red-capped mushrooms in it on her right "
		"arm, a small knife in her left hand"),
}

# The day's callers.
FIGURES["npc_electrician"] = ("assets/textury/npc/npc_electrician.png",
	"a stocky Czech electrician in his fifties, a grey moustache, a dark flat cap, faded navy "
	"blue work bib overalls over a beige t-shirt, a rucksack strap over his left shoulder, a "
	"grey metal toolbox in his right hand, a black flashlight in his left hand, brown work boots")
# The hands in the businesses (tools/artgen/biz_prompts.py HANDS: who, and what they hold at work).
import biz_prompts  # noqa: E402
STAFF = {slug: (desc.rstrip("."), tool) for slug, _ref, desc, tool in biz_prompts.HANDS}
for _slug, (_desc, _tool) in STAFF.items():
	FIGURES[_slug] = ("assets/textury/npc/staff/%s.png" % _slug, _desc)

## What each one does standing about (the idle, four frames from the front): the wardens
## glance at a watch; a guest after their nature.
WARDEN_IDLE = ("they lift the left wrist and glance at a wristwatch (frames 1 and 2), then "
	"scratch the back of the head with the left hand (frame 3), then the left hand drops back "
	"down (frame 4); the flashlight stays low in the right hand all the time")
IDLE = {
	"warden_a": WARDEN_IDLE, "warden_b": WARDEN_IDLE, "warden_c": WARDEN_IDLE, "warden_d": WARDEN_IDLE,
	"host1": "he pushes his sunglasses up his nose with one finger (frame 1), looks over his left "
		"shoulder (frame 2), looks over his right shoulder (frame 3), then stands still again, hands "
		"hanging (frame 4)",
	"host2": "drunk, he sways to one side (frame 1), raises the beer bottle to his mouth and takes a "
		"swig (frame 2), lowers it and burps with his cheeks puffed (frame 3), sways to the other side "
		"(frame 4)",
	"host3": "she brings the cigarette to her lips and takes a drag (frame 1), blows out a puff of grey "
		"smoke (frame 2), flicks the ash off the cigarette (frame 3), rests the other hand on her hip "
		"(frame 4)",
	"host_tramp": "he puts a roll-up cigarette in his mouth (frame 1), strikes a match (frame 2), lights "
		"the cigarette with the match cupped in both hands (frame 3), shakes the match out with smoke "
		"rising (frame 4)",
	"host_father": "he wipes his forehead with the back of his hand (frame 1), puts both hands on his "
		"hips (frame 2), shades his eyes with one hand and looks into the distance (frame 3), lets the "
		"hand drop (frame 4)",
	"host_mother": "she looks to the left for her children (frame 1), cups a hand to her mouth and calls "
		"them (frame 2), looks to the right (frame 3), folds her arms (frame 4)",
	"host_kid": "he hops on the spot with both feet off the ground (frame 1), lands (frame 2), scratches "
		"his nose (frame 3), swings his arms (frame 4)",
	"host_pensioner": "she bends forward peering at the ground for mushrooms (frame 1), straightens up "
		"slowly with a hand on her lower back (frame 2), wipes her brow with her sleeve (frame 3), shifts "
		"the basket on her arm (frame 4)",
}

## Poses drawn from five sides (one frame each; view 1 is the pose's own sprite from the
## front, warden_a_sweep.png): the wardens' work seen most by day, the guests' seats.
POSE_TEXT = {
	"sweep": "standing and bent forward sweeping the ground with a long-handled broom held in both "
		"hands, the broom head on the ground in front of the feet",
	"fix": "standing and working with a big spanner held up in both hands at chest height, as if "
		"tightening a bolt on something in front of them",
	"bag": "bent over holding open a big black rubbish bag with both hands, putting rubbish into it",
	"sit": "SITTING on an invisible seat at knee height: thighs level, knees bent, lower legs "
		"straight down, feet flat on the ground, hands resting on the knees",
	"eat": "SITTING on an invisible seat at knee height, thighs level, feet flat on the ground, "
		"holding a fork with a piece of bread dumpling up to the mouth",
	"drink": "SITTING on an invisible seat at knee height, thighs level, feet flat on the ground, "
		"raising a big glass beer mug of golden beer with a white foam head to the mouth",
}
for _slug, (_desc, _tool) in STAFF.items():
	POSE_TEXT["work_" + _slug] = ("standing at work behind a counter that is not drawn, holding %s in "
		"front of them in both hands, looking down at it" % _tool)
POSES_OF = {
	"warden_a": ["sweep", "fix", "bag", "sit"], "warden_b": ["sweep", "fix", "bag", "sit"],
	"warden_c": ["sweep", "fix", "bag", "sit"], "warden_d": ["sweep", "fix", "bag", "sit"],
	"host1": ["sit", "eat", "drink"], "host2": ["sit", "eat", "drink"], "host3": ["sit", "eat", "drink"],
	"host_tramp": ["sit", "eat", "drink"], "host_pensioner": ["sit", "eat", "drink"],
}
for _slug in STAFF:
	POSES_OF[_slug] = ["work"]

## Where a person's jacket is, for its colour (scripts/coop/warden_looks.gd): its hue band
## (degrees, may wrap past 360), the least saturation (and brightness) that count, and the
## rows of a frame it can be in by animation (shares of the frame's height from the top;
## the boots below are the same green on Pepa, nearly the same red on Ondra).
JACKETS = {
	"warden_a": {"hue": [62.0, 165.0], "sat": 0.16, "band": {"stand": [0.14, 0.6], "walk": [0.12, 0.62], "run": [0.1, 0.62], "idle": [0.12, 0.62]}},
	"warden_b": {"hue": [338.0, 10.0], "sat": 0.42, "vmin": 0.16, "band": {"stand": [0.12, 0.6], "walk": [0.12, 0.62], "run": [0.1, 0.62], "idle": [0.12, 0.62]}},
	"warden_c": {"hue": [62.0, 165.0], "sat": 0.16, "band": {"stand": [0.14, 0.6], "walk": [0.12, 0.62], "run": [0.1, 0.62], "idle": [0.12, 0.62]}},
	"warden_d": {"hue": [62.0, 165.0], "sat": 0.16, "band": {"stand": [0.1, 0.62], "walk": [0.1, 0.64], "run": [0.08, 0.64], "idle": [0.1, 0.64]}},
}

# id suffix -> (aspect, which reference, text). "front": the sprite alone; "turn": the
# sprite beside its picked turnaround.
def sheets(fig, desc):
	same = SAME % desc
	out = {
		"turn": ("16:9", "front", STYLE + "A character turnaround model sheet: five full-body views "
			"of one and the same person standing upright and relaxed, arms hanging down, side by "
			"side in a single row, evenly spaced with clear magenta gaps between them, all exactly "
			"the same height and scale with the feet on one common baseline near the bottom edge: "
			+ VIEWS + ". " + same + BG),
	}
	for v in range(1, 6):
		if v in SQUARE_WAY:
			out["walk%d" % v] = ("16:9", "turn", STYLE + (WALK_SQUARE % (VIEW[v], SQUARE_WAY[v], SQUARE_WAY[v])) + same + BG)
			out["run%d" % v] = ("16:9", "turn", STYLE + (RUN_SQUARE % (RUN_VIEW[v], SQUARE_WAY[v], SQUARE_WAY[v])) + same + BG)
			continue
		out["walk%d" % v] = ("16:9", "turn", STYLE + (WALK % VIEW[v]) + same + BG)
		out["run%d" % v] = ("16:9", "turn", STYLE + (RUN % RUN_VIEW[v]) + same + BG)
	if fig in IDLE:
		out["idle1"] = ("16:9", "turn", STYLE + "Four frames of a classic sprite idle animation in one "
			"row, left to right, evenly spaced with clear magenta gaps, all the same scale with the feet "
			"on one common baseline near the bottom edge, the person seen straight from the front, "
			"standing in place, the feet not moving: " + IDLE[fig] + ". Each frame is a clearly DIFFERENT "
			"pose. " + same + BG)
	for pose in POSES_OF.get(fig, []):
		text = POSE_TEXT.get(pose + "_" + fig, POSE_TEXT.get(pose))
		out["pose_" + pose] = ("16:9", "pose_" + pose, STYLE + "Five full-body views of one and the "
			"same person in one and the same pose, " + text + ", side by side in a single "
			"row, evenly spaced with clear magenta gaps, all exactly the same scale with the feet on "
			"one common baseline near the bottom edge, the person turned a different way in each: "
			+ VIEWS + ". The first view is exactly the pose in the reference image. " + same + BG)
	return out


## New people's sprites from the front (the family split into its people): the sprite the
## rest is drawn from, made from an old one (its reference, x4 on magenta: fig_refs/<ref>_front.png).
BASES = {
	"host_father": ("host_family", "front view, full body standing, feet touching the bottom edge, "
		"the figure centred and filling about 90% of the height. It is exactly the father on the left "
		"of the reference image, with the same face, moustache, hair, red zip-up track jacket with two "
		"white stripes across the chest, white t-shirt, khaki shorts, white socks pulled up and brown "
		"sandals, the same body, proportions, colours and pixel size, but ALONE: no child, his left "
		"arm hanging relaxed by his side like the right one."),
	"host_mother": ("host_family", "front view, full body standing, feet touching the bottom edge, "
		"the figure centred and filling about 90% of the height, arms hanging relaxed by her sides. It "
		"is the wife of the father in the reference image, drawn by the same artist in the same style, "
		"pixel size, shading and outline, the same kind of tired 1990s Czech holiday look: a woman of "
		"about thirty-five, short permed light brown hair, a turquoise and purple windbreaker jacket "
		"worn open over a white t-shirt, a black bum bag on her belt, light blue jeans, white trainers; "
		"no child."),
}


## The family's people at the attractions (their own pictures from the front, as the other
## guests have them: assets/textury/npc/<fig>_<pose>.png), and how tall each is processed.
SEAT = ("The seat itself is NOT drawn: only the person, as if sitting on an invisible seat at "
	"knee height, so the game can put them on any bench or chair. Front view facing the viewer, "
	"the whole figure centred and filling about 90% of the height, feet touching the bottom edge.")
BASE_POSES = {
	"sit": (96, "Now SITTING: thighs level, knees bent toward the viewer, lower legs straight down, "
		"feet flat on the ground, hands resting on the knees, relaxed, looking a little to one side. " + SEAT),
	"eat": (96, "Now SITTING at an imagined table: thighs level, knees bent toward the viewer, feet flat "
		"on the ground, holding a fork with a piece of bread dumpling up to the mouth, the other hand "
		"resting at waist height, chewing. " + SEAT),
	"drink": (96, "Now SITTING: thighs level, knees bent toward the viewer, feet flat on the ground, "
		"raising %s to the mouth with one hand, the other hand on the knee. " + SEAT),
	"kick": (124, "Now playing foot volleyball: seen from the side, facing to the right, standing on one "
		"leg, the other leg swung up high in front kicking with the instep at hip height, both arms out "
		"to the sides for balance, leaning back a little. The whole figure filling about 90% of the "
		"height, the feet touching the bottom edge."),
	"bat": (117, "Now playing table tennis: seen from the front and a little from the side, standing with "
		"the knees slightly bent and leaning forward, a red table-tennis bat held out in the right hand "
		"at waist height, the left hand forward for balance, watching for the ball. The whole figure "
		"filling about 90% of the height, the feet touching the bottom edge."),
}
DRINK = {"host_kid": "a glass of red raspberry lemonade"}
FAMILY = ["host_father", "host_mother", "host_kid"]


def ref_path(fig, kind):
	# Relative to godot/ (gen.sh copies ../../../../godot/<ref>).
	return "../tools/artgen/out/fig_refs/%s_%s.png" % (fig, kind)


def main():
	rows = []
	for fig, (_sprite, desc) in FIGURES.items():
		for key, (aspect, ref, text) in sheets(fig, desc).items():
			for n in (1, 2, 3, 4):
				rows.append("\t".join(["fig_%s_%s_%d" % (fig, key, n), aspect, ref_path(fig, ref), text]))
	for fig, (ref, text) in BASES.items():
		for n in (1, 2, 3):
			rows.append("\t".join(["fig_base_%s_%d" % (fig, n), "9:16", ref_path(ref, "front"),
				"Pixel-art game character sprite in exactly the same style as the reference image: "
				"the same pixel size, palette, shading and dark outline, " + text + " " + BG]))
	for fig in FAMILY:
		for pose, (_h, text) in BASE_POSES.items():
			if "%s" in text:
				text = text.replace("%s", DRINK.get(fig, "a big Czech glass beer mug full of golden beer with a white foam head"))
			for n in (1, 2, 3):
				rows.append("\t".join(["fig_base_%s_%s_%d" % (fig, pose, n), "1:1", ref_path(fig, "front"),
					"Pixel-art game character sprite in exactly the same style as the reference image: the same "
					"pixel size, palette, shading and dark outline, the same person with the same face, hair, "
					"body, clothes and colours (" + FIGURES[fig][1] + "), nothing in the hands but what is said "
					"here. " + text + " " + BG.replace("figures", "figure")]))
	with open(OUT, "w", encoding="utf-8", newline="\n") as f:
		f.write("\n".join(rows) + "\n")
	print("%d rows -> %s" % (len(rows), OUT))


if __name__ == "__main__":
	main()
