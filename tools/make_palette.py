#!/usr/bin/env python3
"""Paleta 256 kolorów całej gry.

Skład palety:
  * rampy zaprojektowane ręcznie (ink, grey, steel, wood, mud, straw, moss, ... z poprzedniej wersji gry),
  * nowe rampy: sky (niebieski - magia Modraszki, mana, woda), warp (trujące spaczenie skavenów), grass (łąki wioski),
  * reszta (do 256) wyłuskana metodą median-cut z oryginalnych obrazów postaci (Ivo, Ursa, Borubar, portret, herb).

Wynik: assets/palette/hufduhof_256.png (256x1), palette.json (kolory + rampy) i palette_lut.png (LUT 32^3 dla shadera).
Oryginały nie są modyfikowane. Uruchom:  python3 tools/make_palette.py
"""
import json
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "palette")

# rampy ręczne z poprzedniej palety (pierwsze 140 kolorów) - przenosimy dosłownie
OLD_RAMPS = ["ink", "grey", "steel", "wood", "mud", "straw", "moss", "fog", "skin", "fur", "blood",
             "ember", "fire", "chaos", "glow", "dusk", "night", "bone", "gold", "white"]

NEW_RAMPS = {
    "sky": ["#0e1a3a", "#16295a", "#1f3c80", "#2b52a8", "#3d6cc8", "#5a8ae0", "#85aef0", "#b8d4fa"],
    "warp": ["#0f2a0c", "#18451a", "#226b22", "#2f9426", "#45bd2c", "#6fe03a", "#a6f56a", "#d8ffa8"],
    "grass": ["#1d2a12", "#283a17", "#334b1c", "#3f5c22", "#4b6d29", "#5a7e31", "#6c8f3c", "#82a24c"],
}

SOURCES = [
    "assets/characters/ivo/source",
    "assets/characters/ursa/source/ursa_source.webp",
    "assets/characters/borubar/source/borubar_pixelart.webp",
    "assets/ui/ivo_portrait.png",
    "assets/ui/crest/crest_menu.png",
]


def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgb2hex(c):
    return "#%02x%02x%02x" % tuple(c[:3])


def gather_pixels():
    pix = []
    for rel in SOURCES:
        p = os.path.join(ROOT, rel)
        files = [os.path.join(p, f) for f in sorted(os.listdir(p))] if os.path.isdir(p) else [p]
        for f in files:
            if not f.lower().endswith((".png", ".webp", ".jpg")):
                continue
            im = Image.open(f).convert("RGBA")
            if im.width > 400:
                im = im.resize((im.width // 3, im.height // 3), Image.NEAREST)
            for r, g, b, a in im.getdata():
                if a > 200:
                    pix.append((r, g, b))
    return pix


def main():
    old = json.load(open(os.path.join(OUT, "palette.json")))
    colors = []
    ramps = {}
    for name in OLD_RAMPS:
        idx = []
        for i in old["ramps"][name]:
            idx.append(len(colors))
            colors.append(hex2rgb(old["colors"][i]))
        ramps[name] = idx
    for name, lst in NEW_RAMPS.items():
        ramps[name] = []
        for h in lst:
            ramps[name].append(len(colors))
            colors.append(hex2rgb(h))
    free = 256 - len(colors)
    pix = gather_pixels()
    sample = Image.new("RGB", (len(pix), 1))
    sample.putdata(pix)
    q = sample.quantize(colors=free, method=Image.Quantize.MEDIANCUT)
    pal = q.getpalette()[: free * 3]
    ramps["art"] = []
    for i in range(free):
        ramps["art"].append(len(colors))
        colors.append(tuple(pal[i * 3: i * 3 + 3]))
    assert len(colors) == 256
    img = Image.new("RGB", (256, 1))
    img.putdata(colors)
    img.save(os.path.join(OUT, "hufduhof_256.png"))
    json.dump({"colors": [rgb2hex(c) for c in colors], "ramps": ramps},
              open(os.path.join(OUT, "palette.json"), "w"), indent=1)
    # LUT 32x32x32 -> 1024x32 (x = b*32 + r, y = g)
    import numpy as np
    pal_arr = np.array(colors, dtype=np.int32)
    lut = np.zeros((32, 1024, 3), dtype=np.uint8)
    vals = (np.arange(32) * 255 / 31).astype(np.int32)
    for g in range(32):
        for b in range(32):
            rgb = np.stack([vals, np.full(32, vals[g]), np.full(32, vals[b])], axis=1)
            d = ((rgb[:, None, :] - pal_arr[None, :, :]) ** 2 * np.array([3, 4, 2])).sum(axis=2)
            lut[g, b * 32: b * 32 + 32] = pal_arr[d.argmin(axis=1)]
    Image.fromarray(lut, "RGB").save(os.path.join(OUT, "palette_lut.png"))
    print("paleta: %d kolorów (%d z obrazów autora)" % (len(colors), free))


if __name__ == "__main__":
    main()
