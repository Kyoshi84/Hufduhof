#!/usr/bin/env python3
"""Ursa (czarodziejka ognia) z obrazu autora -> pixel-art do gry (wspólna paleta 256 kolorów).

Źródło: assets/characters/ursa/source/ursa_source.webp (cała postać, prawdziwa przezroczystość, zwrócona w lewo, 3/4 przodem).
Wynik:
  assets/characters/ursa/poses/ursa_<kierunek>.png + manifest.json   8 póz jak u Ivo (płótno 96x128, pivot 48,126.5)
  assets/ui/heroes/ursa.png                                           duży portret na ekran wyboru bohatera
Uruchom: python3 tools/build_ursa.py [--preview katalog]

Jest tylko jeden rysunek, więc kierunki są z niego złożone: zwrócone w lewo (W, SW, NW, S, N) = oryginał,
w prawo (E, SE, NE) = odbicie lustrzane. Gdy pojawią się osobne rysunki (np. plecy dla N), wystarczy podmienić PNG
w poses/ - gra ładuje to, co znajdzie.
"""
import argparse, json, os
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
from scipy import ndimage
import importlib.util

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(HERE, "assets/characters/ursa/source/ursa_source.webp")
spec = importlib.util.spec_from_file_location("mp", os.path.join(HERE, "tools/make_palette.py"))
mp = importlib.util.module_from_spec(spec); spec.loader.exec_module(mp)

DIRS = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
MIRRORED = {"south-east", "east", "north-east"}   # w prawo = odbicie oryginału
CANVAS = (96, 128)                  # jak pozy Ivo
PIVOT = (48, 126.5)
WORLD_PER_TEXEL = 4.0 / 3.0
FIG_H = 116                         # wysokość postaci w pikselach gry (Ivo ~120 z mieczem)
PIVOT_X_SRC = 470                   # środek między butami na obrazie źródłowym (px)
PORTRAIT_H = 300                    # portret na ekran wyboru (wyświetlany ~2x)
OUTLINE = (10, 7, 8)


class Pal:
    def __init__(self):
        self.P = np.array(Image.open(os.path.join(HERE, "assets/palette/hufduhof_256.png")).convert("RGB")).reshape(-1, 3)
        self.lab = mp.srgb2lab(self.P)

    def nearest(self, rgb):
        a = rgb.astype(float)
        h, w = a.shape[:2]
        idx = np.zeros((h, w), int)
        for y0 in range(0, h, 24):
            blk = mp.srgb2lab(a[y0:y0 + 24])
            idx[y0:y0 + 24] = ((blk[..., None, :] - self.lab[None, None]) ** 2).sum(-1).argmin(-1)
        return self.P[idx].astype(np.uint8)


def load():
    im = Image.open(SRC).convert("RGBA")
    rgb = Image.fromarray(np.asarray(im)[..., :3])
    rgb = rgb.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    rgb = ImageEnhance.Contrast(rgb).enhance(1.06)
    a = np.asarray(im)
    mask = a[..., 3] > 128
    lab, n = ndimage.label(mask)
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    mask = np.isin(lab, [i + 1 for i in range(n) if sizes[i] > 400])   # bez okruchów wokół włosów
    return np.asarray(rgb), mask


def downscale(rgb, mask, box, size):
    """Średnia po powierzchni z premultiplikowaną alfą (brzegi nie łapią koloru tła)."""
    x0, y0, x1, y1 = box
    h, w = mask.shape
    pad = ((max(0, -y0), max(0, y1 - h)), (max(0, -x0), max(0, x1 - w)))
    r = np.pad(rgb.astype(float), pad + ((0, 0),))[y0 + pad[0][0]:y1 + pad[0][0], x0 + pad[1][0]:x1 + pad[1][0]]
    m = np.pad(mask.astype(float), pad)[y0 + pad[0][0]:y1 + pad[0][0], x0 + pad[1][0]:x1 + pad[1][0]]
    pre = np.dstack([r * m[..., None], m * 255.0]).astype(np.float32)
    chans = [Image.fromarray(pre[..., i], "F").resize(size, Image.BOX) for i in range(4)]
    arr = np.dstack([np.asarray(c) for c in chans])
    al = arr[..., 3] / 255.0
    col = arr[..., :3] / np.maximum(al[..., None], 1e-4)
    return np.clip(col, 0, 255), al


def finish(col, al, pal, thr=0.5):
    """Kwantyzacja do palety, alfa binarna, 1 px kontur."""
    inside = al >= thr
    inside = ndimage.binary_opening(inside, structure=np.ones((2, 2))) | (al >= 0.85)
    q = pal.nearest(col)
    h, w = inside.shape
    out = np.zeros((h, w, 4), np.uint8)
    out[inside, :3] = q[inside]
    out[inside, 3] = 255
    edge = ndimage.binary_dilation(inside, structure=ndimage.generate_binary_structure(2, 1)) & ~inside
    out[edge, :3] = OUTLINE
    out[edge, 3] = 255
    return out


def figure(rgb, mask, pal, fig_h, canvas, pivot):
    """Postać przeskalowana do fig_h px, stopy w punkcie pivot płótna."""
    ys, xs = np.nonzero(mask)
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    k = fig_h / (y1 - y0)
    cw, ch = canvas
    # pole źródła odpowiadające płótnu (pivot płótna = (PIVOT_X_SRC, y1))
    sx0 = PIVOT_X_SRC - pivot[0] / k
    sy0 = y1 - (pivot[1] + 0.5) / k
    box = (int(round(sx0)), int(round(sy0)), int(round(sx0 + cw / k)), int(round(sy0 + ch / k)))
    col, al = downscale(rgb, mask, box, (cw, ch))
    return finish(col, al, pal)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default=None)
    args = ap.parse_args()
    pal = Pal()
    rgb, mask = load()
    base = figure(rgb, mask, pal, FIG_H, CANVAS, PIVOT)
    a = base[..., 3] > 0
    clipped = [n for n, v in (("left", a[:, 0].any()), ("right", a[:, -1].any()), ("top", a[0].any())) if v]
    pose_dir = os.path.join(HERE, "assets/characters/ursa/poses")
    os.makedirs(pose_dir, exist_ok=True)
    outs = {}
    for d in DIRS:
        arr = base[:, ::-1].copy() if d in MIRRORED else base
        p = os.path.join(pose_dir, "ursa_%s.png" % d)
        Image.fromarray(arr, "RGBA").save(p)
        outs[p] = arr
    manifest = {
        "figure_height_px": FIG_H,
        "canvas": list(CANVAS),
        "pivot": list(PIVOT),
        "world_per_texel": WORLD_PER_TEXEL,
        "dirs": DIRS,
        "clipped_edges": {d: clipped for d in DIRS},
        "source": "assets/characters/ursa/source/ursa_source.webp (tools/build_ursa.py)",
        "mirrored": sorted(MIRRORED),
    }
    with open(os.path.join(pose_dir, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=1)
    # portret na ekran wyboru: cała postać, większa
    ys, xs = np.nonzero(mask)
    k = PORTRAIT_H / (ys.max() + 1 - ys.min())
    pw = int(round((xs.max() + 1 - xs.min()) * k)) + 4
    col, al = downscale(rgb, mask, (int(xs.min() - 2 / k), int(ys.min() - 2 / k), int(xs.min() - 2 / k + pw / k), int(ys.min() - 2 / k + (PORTRAIT_H + 4) / k)), (pw, PORTRAIT_H + 4))
    por = finish(col, al, pal)
    ui_dir = os.path.join(HERE, "assets/ui/heroes")
    os.makedirs(ui_dir, exist_ok=True)
    pp = os.path.join(ui_dir, "ursa.png")
    Image.fromarray(por, "RGBA").save(pp)
    outs[pp] = por
    for p, arr in outs.items():
        print(os.path.relpath(p, HERE), "%dx%d" % (arr.shape[1], arr.shape[0]))
        if args.preview:
            os.makedirs(args.preview, exist_ok=True)
            im = Image.fromarray(arr, "RGBA")
            im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(os.path.join(args.preview, os.path.basename(p)))
    print("przycięte krawędzie pozy:", clipped or "brak")


if __name__ == "__main__":
    main()
