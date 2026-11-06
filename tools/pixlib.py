"""Wspólne narzędzia do generowania grafiki tymczasowej (placeholderów) w stylu DOS pixel-art.

- paleta 256 kolorów z assets/palette (każdy zapisany PNG jest do niej sprowadzany),
- kontury 1 px, alfa tylko 0/255 (bez półprzezroczystości), bez gradientów (rampy kolorów + dithering),
- rzut izometryczny: komórka siatki = romb 128x64 px.
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TW, TH = 128, 64          # rozmiar kafla izometrycznego
HW, HH = TW // 2, TH // 2

_pal = json.load(open(os.path.join(ROOT, "assets", "palette", "palette.json")))
PALETTE = [tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) for h in _pal["colors"]]
RAMPS = _pal["ramps"]
_cache = {}


def R(ramp, i):
    """Kolor z rampy palety (i obcinane do zakresu, ujemne liczone od końca)."""
    lst = RAMPS[ramp]
    if i < 0:
        i = len(lst) + i
    i = max(0, min(len(lst) - 1, i))
    return PALETTE[lst[i]] + (255,)


def nearest(c):
    c = tuple(c[:3])
    if c in _cache:
        return _cache[c]
    best, bd = None, 1e18
    for p in PALETTE:
        d = (p[0] - c[0]) ** 2 * 3 + (p[1] - c[1]) ** 2 * 4 + (p[2] - c[2]) ** 2 * 2
        if d < bd:
            bd, best = d, p
    _cache[c] = best
    return best


def to_palette(im):
    """Sprowadza obraz do palety: alfa 0/255, kolory najbliższe z palety."""
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a < 128:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = nearest((r, g, b)) + (255,)
    return im


def outline(im, col=None, inner=False):
    """Kontur 1 px wokół nieprzezroczystych pikseli (klasyczny wygląd sprite'a)."""
    col = col or R("ink", 0)
    src = im.copy()
    sp = src.load()
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if sp[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and sp[nx, ny][3] != 0:
                    px[x, y] = col
                    break
    return im


def save(im, rel, quantize=True):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if quantize:
        im = to_palette(im)
    im.save(path)
    return path


def iso(gx, gy, z=0.0):
    """Punkt siatki (gx, gy) na wysokości z (px) -> współrzędne ekranu względem narożnika (0,0)."""
    return ((gx - gy) * HW, (gx + gy) * HH - z)


def dither(draw, poly_mask_img, col_a, col_b, pattern=2):
    pass


class Canvas:
    """Duże płótno z punktem odniesienia (ox, oy) = narożnik (0,0) siatki; po narysowaniu przycina się do kotwicy."""

    def __init__(self, w=1400, h=1400, ox=700, oy=900):
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)
        self.ox, self.oy = ox, oy

    def P(self, gx, gy, z=0.0):
        x, y = iso(gx, gy, z)
        return (self.ox + x, self.oy + y)

    def poly(self, pts, fill, outline_col=None):
        self.d.polygon([(round(x), round(y)) for x, y in pts], fill=fill, outline=outline_col)

    def gpoly(self, gpts, fill, outline_col=None):
        self.poly([self.P(*p) for p in gpts], fill, outline_col)

    def line(self, a, b, col, w=1):
        self.d.line([(round(a[0]), round(a[1])), (round(b[0]), round(b[1]))], fill=col, width=w)

    def crop_anchor(self, ax, ay, pad_top=2):
        """Przycina tak, by punkt (ax, ay) płótna był środkiem dolnej krawędzi obrazu."""
        bb = self.im.getbbox()
        if bb is None:
            return Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        half = int(math.ceil(max(ax - bb[0], bb[2] - ax))) + 1
        top = bb[1] - pad_top
        box = (int(round(ax)) - half, top, int(round(ax)) + half, int(round(ay)))
        return self.im.crop(box)


def noise_fill(im, mask_fn, cols, rnd, density=0.5):
    """Wypełnia piksele spełniające mask_fn losowo kolorami z listy (dithering szumowy)."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if mask_fn(x, y) and rnd.random() < density:
                px[x, y] = rnd.choice(cols)


def face_shade(col, k):
    return tuple(max(0, min(255, int(c * k))) for c in col[:3]) + (255,)
