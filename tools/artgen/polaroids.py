"""Vera's polaroids (TODO.md D1, the Q&A of 15. 11.): photos of the real game made into
faded late-1990s instant photos, attached to her task mails (CampMail) and pinned on the
office noticeboard.

    python tools/artgen/polaroids.py

In:  tools/artgen/polaroid_src/<id>.png  512 px squares cut from screenshot-driver
     renders of the camp (the steps that made them are in the file's own notes below).
Out: godot/assets/textury/mail/polaroid_<id>.png  (FRAME_W x FRAME_H), and
     polaroid_<id>_small.png at SMALL of it for the noticeboard's row.

The photo paper and the red felt-tip marks are Grok's (tools/artgen/prompts_demo.tsv:
polaroid_frame, felt_marks): when assets/textury/mail/polaroid_frame.png and
felt_marks.png exist they are used; until then a plain off-white frame and no marks.

Where the photos came from (shot driver, 1280x720, a new story camp):
  cabin_out    view_ruined 11 m at -25 deg, crop (360,100)-(800,540)
  cabin_in     the old cabin's room (handle_structure_interact), crop (300,160)-(860,720)
  pc_download  the desk, both setups downloaded, open_app('downloads'), crop (360,80)-(920,640)
  desk_book    the shot driver's "checkin" k4_desk, crop (580,200)-(1100,720)
  desk_drawer  the same picture, crop (720,420)-(1020,720)
  night_door   21:37, door_front main_building 3.5 m, crop (420,60)-(960,600)
"""
import os
import random

from PIL import Image, ImageEnhance, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(HERE, "polaroid_src")
OUT = os.path.join(REPO, "godot", "assets", "textury", "mail")
FRAME_PNG = os.path.join(OUT, "polaroid_frame.png")
MARKS_PNG = os.path.join(OUT, "felt_marks.png")

PHOTO = 84
SIDE = 6
TOP = 6
BOTTOM = 20
FRAME_W = PHOTO + 2 * SIDE
FRAME_H = PHOTO + TOP + BOTTOM
# The noticeboard's prints (board_closeup.gd PHOTO_K).
SMALL = 0.34
PAPER = (226, 221, 206)


def film(img):
    """The picture as a cheap instant camera kept it: soft, lifted blacks, warm light,
    cool shade, a little faded, darker at the corners, grain."""
    img = img.convert("RGB").resize((PHOTO, PHOTO), Image.LANCZOS)
    img = img.filter(ImageFilter.GaussianBlur(0.35))
    img = ImageEnhance.Color(img).enhance(0.82)
    img = ImageEnhance.Contrast(img).enhance(0.86)
    rng = random.Random(PHOTO)
    px = img.load()
    c = (PHOTO - 1) / 2.0
    for y in range(PHOTO):
        for x in range(PHOTO):
            r, g, b = px[x, y]
            lum = (r + g + b) / 765.0
            # Lifted blacks, warm highlights, cool shadows.
            r = 18 + r * 0.92 + 14 * lum
            g = 16 + g * 0.92 + 6 * lum
            b = 22 + b * 0.86 - 4 * lum + 10 * (1.0 - lum)
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5 / (c * 1.414)
            v = 1.0 - 0.28 * d * d
            n = rng.uniform(-7, 7)
            px[x, y] = tuple(max(0, min(255, int(ch * v + n))) for ch in (r, g, b))
    return img


def plain_frame():
    """Off-white photo paper with a faint grain (until Grok's paper is in)."""
    rng = random.Random(7)
    fr = Image.new("RGB", (FRAME_W, FRAME_H), PAPER)
    px = fr.load()
    for y in range(FRAME_H):
        for x in range(FRAME_W):
            n = rng.randint(-5, 4)
            px[x, y] = tuple(max(0, min(255, ch + n)) for ch in PAPER)
    for x in range(FRAME_W):
        px[x, FRAME_H - 1] = tuple(int(ch * 0.8) for ch in px[x, FRAME_H - 1])
    for y in range(FRAME_H):
        px[FRAME_W - 1, y] = tuple(int(ch * 0.85) for ch in px[FRAME_W - 1, y])
    return fr


def frame():
    if os.path.exists(FRAME_PNG):
        return Image.open(FRAME_PNG).convert("RGB").resize((FRAME_W, FRAME_H), Image.LANCZOS)
    return plain_frame()


def main():
    os.makedirs(OUT, exist_ok=True)
    base = frame()
    made = []
    for name in sorted(os.listdir(SRC)):
        if not name.endswith(".png"):
            continue
        pid = name[:-4]
        photo = film(Image.open(os.path.join(SRC, name)))
        out = base.copy()
        out.paste(photo, (SIDE, TOP))
        out.save(os.path.join(OUT, "polaroid_%s.png" % pid))
        small = out.resize((round(FRAME_W * SMALL), round(FRAME_H * SMALL)), Image.LANCZOS)
        small.save(os.path.join(OUT, "polaroid_%s_small.png" % pid))
        made.append(pid)
    print("polaroids: %s (%dx%d)%s" % (", ".join(made), FRAME_W, FRAME_H, "" if os.path.exists(FRAME_PNG) else ", plain frame"))


if __name__ == "__main__":
    main()
