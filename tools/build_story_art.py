#!/usr/bin/env python3
"""Ilustracje ekranów fabularnych (1280x720) z panoramy assets/stages/source/hufduhof_panorama.png.
  python3 tools/build_story_art.py
Zapisuje assets/ui/story/story_village.png, story_forest.png, story_champion.png. Każdy plik można podmienić własnym
(1280x720, PNG); ścieżki są w data/story.json."""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(HERE, "assets/stages/source/hufduhof_panorama.png")
OUT = os.path.join(HERE, "assets/ui/story")

# (plik, x lewej krawędzi wycinka 1287x724, korekta barw RGB, saturacja, mgła u dołu, winieta)
ART = [
    ("story_village.png", 0,   (1.06, 0.98, 0.90), 1.05, (0.00, None), 0.45),
    ("story_forest.png",  620, (0.92, 1.02, 0.96), 0.95, (0.10, (40, 52, 60)), 0.50),
    ("story_champion.png", 885, (1.00, 0.80, 0.84), 0.80, (0.38, (70, 28, 52)), 0.60),
]

def make(name, x0, mult, sat, fog, vig):
    pan = np.array(Image.open(SRC).convert("RGB")).astype(float)
    crop = pan[:, x0:x0 + 1287]
    im = np.array(Image.fromarray(crop.astype(np.uint8)).resize((1280, 720), Image.LANCZOS)).astype(float)
    g = im.mean(-1, keepdims=True)
    im = np.clip((g + (im - g) * sat) * np.array(mult), 0, 255)
    h, w = im.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    amount, col = fog
    if col is not None:                                   # mgła pełznąca od dołu
        t = np.clip((yy - h * 0.35) / (h * 0.65), 0, 1) ** 1.5
        wave = 0.5 + 0.5 * np.sin(xx / 70.0 + yy / 23.0)
        a = (t * amount * (0.7 + 0.3 * wave))[..., None]
        im = im * (1 - a) + np.array(col) * a
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    im *= (1 - vig * np.clip(d - 0.55, 0, 1) ** 1.4)[..., None]
    Image.fromarray(np.clip(im, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name))
    print("zapisano", name)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for a in ART:
        make(*a)
