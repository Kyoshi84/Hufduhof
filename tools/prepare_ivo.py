#!/usr/bin/env python3
"""Przygotowuje sprite'y Ivo (8 kierunków) do gry. Oryginały w assets/characters/ivo/source/ NIE są modyfikowane.

Dla każdego kierunku:
 1. wyznacza pivot: środek stóp (dolne 14 wierszy sylwetki) i linię podłoża (najniższy widoczny piksel),
 2. umieszcza kadr na wspólnym płótnie tak, aby pivot był w tym samym punkcie (brak "skakania" przy zmianie kierunku),
 3. skaluje jednolicie (bez deformacji) współczynnikiem SCALE, ważąc kolor przez alfę (brak jasnych/ciemnych obwódek),
 4. kwantyzuje do wspólnej palety 256 kolorów (najbliższy kolor w Lab, bez ditheringu), alfa binarna,
 5. czyści pojedyncze piksele-śmieci i dodaje 1 px obrys w kolorze "ink".
Wyjście: assets/characters/ivo/poses/ivo_<kierunek>.png + manifest.json (pivot, skala, lista kierunków, przycięte krawędzie).
"""
import json, os
import numpy as np
from PIL import Image
import importlib.util

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("mp", os.path.join(ROOT, "tools/make_palette.py"))
mp = importlib.util.module_from_spec(spec); spec.loader.exec_module(mp)

DIRS = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
SCALE = 0.5                 # 160x256 -> 80x128 (dokładnie 2:1)
CANVAS = (192, 256)         # płótno przed skalowaniem (szerokość, wysokość)
PIVOT = (96, 252)           # pivot na płótnie przed skalowaniem
WORLD_PER_TEXEL = 4.0 / 3.0 # 1 piksel wewnętrznego obrazu (960x540) = 4/3 jednostki świata (1280x720)

P = np.array(Image.open(os.path.join(ROOT, "assets/palette/hufduhof_256.png")).convert("RGB")).reshape(-1, 3)
plab = mp.srgb2lab(P)
INK = tuple(int(v) for v in mp.hex2rgb("#0a0708"))

def feet_pivot(im):
    a = np.array(im.getchannel("A")) > 0
    ys, xs = np.nonzero(a)
    base = ys.max()
    foot = a[base - 13:base + 1]
    fx = np.nonzero(foot.any(0))[0]
    return (fx.min() + fx.max()) / 2.0, base

def edges_touched(im):
    a = np.array(im.getchannel("A")) > 0
    return [n for n, v in (("left", a[:, 0].any()), ("right", a[:, -1].any()), ("top", a[0].any()), ("bottom", a[-1].any())) if v]

REMOVED = []

def drop_small_components(mask, min_px):
    """Usuwa odłączone fragmenty mniejsze niż min_px (8-sąsiedztwo). Zwraca (maska, liczba usuniętych pikseli)."""
    h, w = mask.shape
    seen = np.zeros_like(mask, bool); out = mask.copy(); removed = 0
    for y in range(h):
        for x in range(w):
            if mask[y, x] and not seen[y, x]:
                stack = [(y, x)]; seen[y, x] = True; comp = []
                while stack:
                    cy, cx = stack.pop(); comp.append((cy, cx))
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                                seen[ny, nx] = True; stack.append((ny, nx))
                if len(comp) < min_px:
                    for cy, cx in comp: out[cy, cx] = False
                    removed += len(comp)
    return out, removed

def process(path):
    im = Image.open(path).convert("RGBA")
    cx, base = feet_pivot(im)
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    ox = int(round(PIVOT[0] - cx)); oy = int(PIVOT[1] - base)
    canvas.alpha_composite(im, (ox, oy))
    a = np.array(canvas).astype(float)
    al = a[..., 3:4] / 255.0
    pm = Image.fromarray((a[..., :3] * al).astype(np.uint8)); pa = Image.fromarray(a[..., 3].astype(np.uint8))
    nw, nh = int(CANVAS[0] * SCALE), int(CANVAS[1] * SCALE)
    pm = pm.resize((nw, nh), Image.LANCZOS); pa = pa.resize((nw, nh), Image.LANCZOS)
    alpha = np.array(pa).astype(float) / 255.0
    col = np.array(pm).astype(float) / np.maximum(alpha[..., None], 1e-3)
    mask = alpha > 0.5
    # usuń samotne piksele (bez sąsiada w 8-otoczeniu)
    pad = np.pad(mask, 1)
    nb = sum(pad[1 + dy:1 + dy + nh, 1 + dx:1 + dx + nw].astype(int) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dy, dx) != (0, 0))
    mask &= nb >= 1
    mask, removed = drop_small_components(mask, 8)
    REMOVED.append(removed)
    idx = ((mp.srgb2lab(np.clip(col, 0, 255))[..., None, :] - plab[None, None]) ** 2).sum(-1).argmin(-1)
    out = np.zeros((nh, nw, 4), np.uint8)
    out[..., :3] = P[idx]; out[..., 3] = np.where(mask, 255, 0)
    # obrys 1 px (4-sąsiedztwo) w kolorze ink - kwantyzowany do palety
    pad = np.pad(mask, 1)
    border = ~mask & (pad[0:nh, 1:nw + 1] | pad[2:nh + 2, 1:nw + 1] | pad[1:nh + 1, 0:nw] | pad[1:nh + 1, 2:nw + 2])
    ink_i = ((mp.srgb2lab(np.array(INK, float)) - plab) ** 2).sum(-1).argmin()
    out[border, :3] = P[ink_i]; out[border, 3] = 255
    return Image.fromarray(out), edges_touched(im), (cx, base), (ox, oy)

def main():
    os.makedirs(os.path.join(ROOT, "assets/characters/ivo/poses"), exist_ok=True)
    manifest = {"scale": SCALE, "canvas": [int(CANVAS[0] * SCALE), int(CANVAS[1] * SCALE)],
                "pivot": [PIVOT[0] * SCALE, (PIVOT[1] + 1) * SCALE], "world_per_texel": WORLD_PER_TEXEL,
                "dirs": DIRS, "clipped_edges": {}, "notes": "Oryginały: assets/characters/ivo/source. Sprite'y są statycznymi pozami (turnaround), nie klatkami animacji."}
    for d in DIRS:
        img, clipped, feet, off = process(os.path.join(ROOT, "assets/characters/ivo/source", d + ".png"))
        img.save(os.path.join(ROOT, "assets/characters/ivo/poses", f"ivo_{d}.png"))
        manifest["clipped_edges"][d] = clipped
        print(f"{d:11s} usunięte śmieci: {REMOVED[-1]:3d} px  stopy@{feet[0]:.1f},{feet[1]} offset{off} przycięte krawędzie oryginału: {clipped}")
    json.dump(manifest, open(os.path.join(ROOT, "assets/characters/ivo/poses/manifest.json"), "w"), indent=1)
    cols = set()
    for d in DIRS:
        a = np.array(Image.open(os.path.join(ROOT, "assets/characters/ivo/poses", f"ivo_{d}.png")))
        cols |= {tuple(c) for c in a[a[..., 3] > 0][:, :3]}
    print("kolory w gotowych sprite'ach:", len(cols), "(wszystkie z palety 256)")

if __name__ == "__main__":
    main()
