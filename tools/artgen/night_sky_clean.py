"""The clear night's panorama without its stars: the deep blue and the milky way only.

    python tools/artgen/night_sky_clean.py

The stars are the sky shader's now (materials/sky_transition.gdshader): in the panorama each
was a blocky cross a few texels wide, and the panorama is stretched, sideways more and more
toward the top, so on the screen they came out as squares and bars like confetti. Taken out
by a grey opening (each channel's minimum over a window, then its maximum), which leaves what
is wider than the window, the band among them; a soft blur for the steps it leaves.
"""
import os

from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SKY = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "skybox")
WINDOW = 9
BLUR = 5


def main() -> None:
    im = Image.open(os.path.join(SKY, "skystars.png")).convert("RGB")
    out = im.filter(ImageFilter.MinFilter(WINDOW)).filter(ImageFilter.MaxFilter(WINDOW))
    out = out.filter(ImageFilter.GaussianBlur(BLUR))
    out.save(os.path.join(SKY, "skyf_night.png"))
    print("skyf_night.png", out.size)


if __name__ == "__main__":
    main()
