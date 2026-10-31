#!/usr/bin/env python3
"""Przerabia lewą stronę far1/far2 etapu 1 (droga): usuwa chatę z kominem, wóz i zostawia same drzewa.
Uruchamiać PO tools/build_stage_backgrounds.py (nadpisuje assets/stages/stage1_road/far1.png i far2.png).
Tło lewej strony: las i pole z innego fragmentu panoramy (bez budynków), na to ręcznie ustawione sosny i dęby
z generatora rekwizytów. Szew powtarzania (x=639 -> x=0) jest zamazany od nowa."""
import os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_stage_backgrounds as B
import build_props as BP

HERE = B.HERE
D = os.path.join(HERE, "assets/stages/stage1_road")
ZONE_TOP = 262          # tło (nad wiersz 196) czyścimy do x=262 (dalej zaczynają się odległe domy)
ZONE_BOT = 296          # w dolnych wierszach (pole, wóz) do x=296
LOW_ROW = 196
SRC_X0, SRC_X1 = 1090, 1400      # panorama: las i pole za wsią, bez budynków

def main():
    P = np.array(Image.open(os.path.join(HERE, "assets/palette/hufduhof_256.png")).convert("RGB")).reshape(-1, 3)
    plab = B.mp.srgb2lab(P)
    far1 = np.array(Image.open(os.path.join(D, "far1.png")).convert("RGB")).astype(float)
    far2 = np.array(Image.open(os.path.join(D, "far2.png")).convert("RGB")).astype(float)
    band = np.concatenate([far1, far2], 0)                      # 250 x 640
    H, W = band.shape[:2]
    pan = np.array(Image.open(B.SRC).convert("RGB"))
    s = B.BAND_H / float(B.BAND_BOT - B.BAND_TOP)
    strip = B.cut(pan, SRC_X0, SRC_X1, B.BAND_TOP, B.BAND_BOT).astype(float)
    strip = B.resize(strip, int(round(strip.shape[1] * s)), H)
    n = np.concatenate([strip, strip[:, ::-1], strip], 1)[:, :300]   # lustrzane przedłużenie
    new = B.grade(n, (1.0, 1.0, 1.0), 1.0)
    # maska strefy z miękkim brzegiem
    mask = np.zeros((H, W))
    for y in range(H):
        lim = ZONE_BOT if y >= LOW_ROW else ZONE_TOP
        mask[y, :lim] = 1.0
        f = 14
        mask[y, lim - f:lim] = np.linspace(1.0, 0.0, f)
    out = band.copy()
    # szew: prawa krawędź płynnie przechodzi w nową lewą (lustro)
    bl = 48
    for k in range(bl):
        t = (k + 1) / bl
        x = W - bl + k
        out[:, x] = band[:, x] * (1 - t) + new[:, min(bl - 1 - k, 299)] * t
    for y in range(H):
        out[y, :300] = out[y, :300] * (1 - mask[y, :300, None]) + new[y] * mask[y, :300, None]
    # drzewa: najpierw dalekie (mniejsze, przygaszone mgłą), potem bliskie
    fog = np.array([76, 97, 89], float)
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).convert("RGBA")
    def tree(kind, w, h, seed, x, base_y, fogk):
        t = (BP.tree_pine if kind == "pine" else BP.tree_oak)(w, h, seed=seed)
        a = np.array(t).astype(float)
        a[..., :3] = (a[..., :3] * 0.72) * (1 - fogk) + fog * fogk
        t2 = Image.fromarray(a.astype(np.uint8), "RGBA")
        img.alpha_composite(t2, (int(x - w / 2), int(base_y - h)))
    far = [("pine", 24, 58, i + 1, x, 208 + (i % 3)) for i, x in enumerate(range(8, 290, 22))]
    for kind, w, h, sd, x, by in far:
        tree(kind, w, h, sd, x, by, 0.45)
    mid = [("pine", 34, 84, 7, 14, 226), ("pine", 36, 92, 8, 60, 228), ("oak", 46, 66, 1, 96, 227),
           ("pine", 34, 86, 9, 138, 227), ("pine", 38, 96, 3, 182, 228), ("oak", 44, 64, 2, 222, 227),
           ("pine", 34, 88, 5, 262, 227)]
    for kind, w, h, sd, x, by in mid:
        tree(kind, w, h, sd, x, by, 0.22)
    near = [("pine", 46, 118, 1, 36, 246), ("pine", 44, 108, 2, 122, 247), ("oak", 56, 80, 3, 80, 247),
            ("pine", 46, 114, 4, 206, 247), ("oak", 54, 78, 5, 258, 247)]
    for kind, w, h, sd, x, by in near:
        tree(kind, w, h, sd, x, by, 0.05)
    rgb = np.array(img.convert("RGB")).astype(float)
    # kwantyzacja do palety tylko w strefie zmian + szew
    res = np.array(Image.fromarray(band.astype(np.uint8)))
    q = np.array(B.quantize(rgb, np.full(rgb.shape[:2], 255), P, plab, strength=6.0))[..., :3]
    keep = np.zeros((H, W), bool)
    keep[:, :310] = True
    keep[:, W - bl:] = True
    res[keep] = q[keep]
    for name, rows in (("far1", slice(0, B.FAR1_H)), ("far2", slice(B.FAR1_H, H))):
        part = res[rows]
        im = Image.fromarray(np.dstack([part, np.full(part.shape[:2], 255, np.uint8)]), "RGBA")
        im.save(os.path.join(D, name + ".png"))
        print("zapisano", name, im.size)

if __name__ == "__main__":
    main()
