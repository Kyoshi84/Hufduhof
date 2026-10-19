#!/usr/bin/env python3
"""Buduje wspólną paletę 256 kolorów gry + tablicę LUT 32x32x32 dla shadera palety.

Wyjścia:
  assets/palette/hufduhof_256.png   256x1, paleta
  assets/palette/palette_lut.png    1024x32, LUT: (b*32 + r, g) -> najbliższy kolor palety
  assets/palette/palette.json       rampy nazwane + lista
  scripts/art/pal.gd                stałe rampy dla kodu rysującego (generowane, nie edytować ręcznie)
Paleta = rampy zaprojektowane ręcznie (otoczenie/potwory/UI) + kolory wyłuskane k-means ze sprite'ów Ivo.
"""
import json, glob, os, sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def hex2rgb(h): h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def ramp(keys, n):
    ks = [np.array(hex2rgb(k), float) for k in keys]
    out = []
    for i in range(n):
        t = i / (n - 1) * (len(ks) - 1)
        a = min(int(t), len(ks) - 2); f = t - a
        out.append(tuple(int(round(v)) for v in ks[a] * (1 - f) + ks[a + 1] * f))
    return out

RAMPS = {
    "ink":    (["#0a0708", "#2a2224"], 4),
    "grey":   (["#3a3a3f", "#d8d4cc"], 9),
    "steel":  (["#2b3038", "#a9b4c0"], 7),
    "wood":   (["#1a1008", "#a8825a"], 12),
    "mud":    (["#2a2016", "#6b5a3e"], 6),
    "straw":  (["#4a3a18", "#d8c070"], 7),
    "moss":   (["#10180c", "#8aa05a"], 10),
    "fog":    (["#18241f", "#6f8a80"], 6),
    "skin":   (["#4a2a1c", "#e0b088"], 8),
    "fur":    (["#2a1c14", "#9a7650"], 7),
    "blood":  (["#2a0508", "#e03030"], 10),
    "ember":  (["#8a0f14", "#ff6a50"], 4),
    "fire":   (["#6a1a08", "#ffd060"], 7),
    "chaos":  (["#1a0a2a", "#c050e0"], 9),
    "glow":   (["#601040", "#ff80c0"], 4),
    "dusk":   (["#2a1a30", "#d08a6a"], 10),
    "night":  (["#141c2c", "#7a8cb0"], 7),
    "bone":   (["#7a7260", "#f0e8d0"], 5),
    "gold":   (["#5a4010", "#ffd848"], 5),
    "white":  (["#c8c0b0", "#ffffff"], 3),
}

def srgb2lab(rgb):
    c = np.asarray(rgb, float) / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    M = np.array([[0.4124564, 0.3575761, 0.1804375], [0.2126729, 0.7151522, 0.0721750], [0.0193339, 0.1191920, 0.9503041]])
    xyz = c @ M.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)

def kmeans(pts, k, iters=40, seed=3):
    rng = np.random.default_rng(seed)
    cent = pts[rng.choice(len(pts), k, replace=False)].astype(float)
    for _ in range(iters):
        d = ((pts[:, None, :] - cent[None]) ** 2).sum(-1)
        lab = d.argmin(1)
        for i in range(k):
            m = lab == i
            if m.any(): cent[i] = pts[m].mean(0)
    return cent

def main():
    pal = []; named = {}
    for name, (keys, n) in RAMPS.items():
        cols = ramp(keys, n); named[name] = [len(pal) + i for i in range(n)]
        pal.extend(cols)
    # kolory Ivo (k-means po wszystkich 8 sprite'ach, tylko widoczne piksele)
    px = []
    for f in sorted(glob.glob(os.path.join(ROOT, "assets/characters/ivo/source/*.png"))):
        a = np.array(Image.open(f).convert("RGBA")).reshape(-1, 4)
        px.append(a[a[:, 3] > 128][:, :3])
    px = np.concatenate(px)
    uniq, cnt = np.unique(px, axis=0, return_counts=True)
    k = 256 - len(pal)
    labs = srgb2lab(uniq)
    # ważone próbki (powtarzamy częste kolory), żeby k-means nie zgubił dużych płaszczyzn
    idx = np.repeat(np.arange(len(uniq)), np.minimum(cnt, 40))
    cent_lab = kmeans(labs[idx], k)
    # z centroidów Lab wybierz najbliższe rzeczywiste kolory
    ivo_cols = []
    for c in cent_lab:
        j = ((labs - c) ** 2).sum(1).argmin()
        ivo_cols.append(tuple(int(v) for v in uniq[j]))
    seen = set(pal)
    ivo_idx = []
    for c in ivo_cols:
        if c not in seen:
            seen.add(c); ivo_idx.append(len(pal)); pal.append(c)
    # uzupełnienie do 256 (gdy duplikaty) - kolejne kolory Ivo wg częstości
    order = np.argsort(-cnt)
    for j in order:
        if len(pal) >= 256: break
        c = tuple(int(v) for v in uniq[j])
        if c not in seen:
            seen.add(c); ivo_idx.append(len(pal)); pal.append(c)
    named["ivo"] = ivo_idx
    assert len(pal) == 256, len(pal)
    P = np.array(pal, np.uint8)
    Image.fromarray(P.reshape(1, 256, 3), "RGB").save(os.path.join(ROOT, "assets/palette/hufduhof_256.png"))
    # LUT 32^3 -> najbliższy kolor (Lab); komórki palety odwzorowują się same na siebie
    plab = srgb2lab(P)
    g = np.arange(32); R, G, B = np.meshgrid(g, g, g, indexing="ij")
    cell = np.stack([R, G, B], -1).reshape(-1, 3)
    rgb = np.clip(np.round(cell * 255.0 / 31.0), 0, 255)
    clab = srgb2lab(rgb)
    out = np.zeros((len(cell), 3), np.uint8)
    for s in range(0, len(cell), 4096):
        d = ((clab[s:s + 4096, None, :] - plab[None]) ** 2).sum(-1)
        out[s:s + 4096] = P[d.argmin(1)]
    out = out.reshape(32, 32, 32, 3)           # [r][g][b]
    for i, c in enumerate(P):                   # idempotentność: kolor palety -> ten sam kolor
        r, gg, b = [int(round(int(v) * 31 / 255)) for v in c]
        dd = ((srgb2lab(np.round(np.array([r, gg, b]) * 255 / 31)) - plab) ** 2).sum(-1)
        out[r, gg, b] = P[dd.argmin()]
    lut = np.zeros((32, 1024, 3), np.uint8)     # x = b*32 + r, y = g
    for b in range(32):
        for gg in range(32):
            lut[gg, b * 32:(b + 1) * 32] = out[:, gg, b]
    Image.fromarray(lut, "RGB").save(os.path.join(ROOT, "assets/palette/palette_lut.png"))
    json.dump({"colors": ["#%02x%02x%02x" % tuple(c) for c in pal], "ramps": named}, open(os.path.join(ROOT, "assets/palette/palette.json"), "w"), indent=1)
    # pal.gd
    L = ["# GENEROWANE przez tools/make_palette.py - nie edytować ręcznie.", "class_name Pal", "extends RefCounted", "## Wspólna paleta 256 kolorów. Rampy: Pal.r(\"wood\", 3) = 4. odcień od najciemniejszego.", "", "const RAMPS := {"]
    for name, idxs in named.items():
        L.append('\t"%s": [%s],' % (name, ", ".join('Color8(%d, %d, %d)' % pal[i] for i in idxs)))
    L += ["}", "", "static func r(ramp: String, i: int) -> Color:", "\tvar a: Array = RAMPS[ramp]", "\treturn a[clampi(i, 0, a.size() - 1)]", "",
          "## t = 0..1 wzdłuż rampy", "static func rt(ramp: String, t: float) -> Color:", "\tvar a: Array = RAMPS[ramp]", "\treturn a[clampi(int(round(t * (a.size() - 1))), 0, a.size() - 1)]", ""]
    open(os.path.join(ROOT, "scripts/art/pal.gd"), "w").write("\n".join(L))
    print("paleta:", len(pal), "kolorów; rampy:", {k: len(v) for k, v in named.items()})

if __name__ == "__main__":
    main()
