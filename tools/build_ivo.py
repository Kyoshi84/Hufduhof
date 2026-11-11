#!/usr/bin/env python3
"""Ivo: klatki gry z oryginałów autora (8 póz + 4 klatki chodu z profilu).

Wejście (oryginały, nie są zmieniane):
  assets/characters/ivo/source/<kierunek>.png          8 póz 160x256
  assets/characters/ivo/source/walk_east/east_000N.png 4 klatki chodu z profilu (pół cyklu kroku)

Wyjście (assets/characters/ivo/, płótno 320x192, pivot (160, 190), Ivo ok. 105 px wysokości):
  idle/<8 kierunków>/     pozy pomniejszone do wspólnej skali (east: 2 klatki oddechu)
  walk|attack|heavy|whirl|shout|hurt|death / east /    animacje z profilu; kierunek west gra odbija lustrzanie,
                                                       pozostałe kierunki zostają na pozach ożywianych w kodzie
  sprite.json

Jak powstają klatki z profilu: tułów z pozy stojącej (pochylany pasami o 1 px), nogi z klatek chodu,
ręce i dwuręczny miecz dorysowane wielokątami. Te same kroki rysowania są w projekcie PixelWright
"Hufduhof – Ivo Eggert" (tam także light2, dodge, victory i smugi cięć, których gra izometryczna nie używa).

Uruchom:  python3 tools/build_ivo.py      (nadpisuje klatki w assets/characters/ivo/, oryginałów w source/ nie rusza)
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "assets", "characters", "ivo")
SRC = os.path.join(BASE, "source")
W, H = 320, 192
PIVOT = (160, 190)
SCALE = 0.45

# paleta klatek Ivo (indeks 0 = przezroczysty)
TOK = ["transparent", "outline", "red.0", "red.1", "red.2", "red.3", "red.4", "red.5", "leather.0", "leather.1",
       "leather.2", "leather.3", "leather.4", "leather.5", "flesh.0", "flesh.1", "steel.0", "steel.1", "steel.2",
       "steel.3", "smear.0", "smear.1"]
HEX = ["#000000", "#050100", "#2b0202", "#400405", "#560405", "#740205", "#92080e", "#a33b3e", "#130302", "#1d1714",
       "#302824", "#4a3c34", "#63564b", "#847268", "#712526", "#b48681", "#343844", "#666d7a", "#a2aab4", "#dde3e8",
       "#c9d2dc", "#f6f3e8"]
T = {t: i for i, t in enumerate(TOK)}
RGB = np.array([[int(h[j:j + 2], 16) for j in (1, 3, 5)] for h in HEX], np.int32)
BODY = list(range(1, 16))            # kolory, na które mapowane są oryginały (bez stali i smug)

# punkt stóp na oryginale 160x256: (x, y); y = dolna krawędź postaci
ANCHOR = {"south": 71, "south-east": 80, "east": 80, "north-east": 86, "north": 82, "north-west": 76, "west": 73,
          "south-west": 70}
DIRS = list(ANCHOR.keys())


def shrink(path):
    """Oryginał -> tablica indeksów palety 115x72 (BOX na kolorach z premultiplikowaną alfą, alfa 0/255)."""
    im = np.array(Image.open(path).convert("RGBA")).astype(np.float32)
    a = im[..., 3:4] / 255.0
    pm = np.concatenate([im[..., :3] * a, a * 255.0], axis=2)
    size = (int(round(im.shape[1] * SCALE)), int(im.shape[0] * SCALE))
    r = np.stack([np.array(Image.fromarray(pm[..., c]).resize(size, Image.BOX)) for c in range(4)], axis=2)
    al = r[..., 3] / 255.0
    rgb = np.where(al[..., None] > 0, r[..., :3] / np.maximum(al[..., None], 1e-6), 0)
    d = ((rgb[:, :, None, :] - RGB[BODY][None, None]) ** 2).sum(3).argmin(2)
    idx = np.array(BODY, np.uint8)[d]
    idx[al < 0.5] = 0
    return idx


def on_canvas(idx, anchor_x, src_bottom):
    """Wkleja pomniejszoną pozę tak, by punkt stóp trafił w pivot."""
    c = np.zeros((H, W), np.uint8)
    ox = PIVOT[0] - int(round(anchor_x * SCALE))
    oy = (PIVOT[1] - 1) - int(src_bottom * SCALE)
    h, w = idx.shape
    for y in range(h):
        Y = oy + y
        if 0 <= Y < H:
            x0 = max(0, -ox)
            x1 = min(w, W - ox)
            row = idx[y, x0:x1]
            seg = c[Y, ox + x0:ox + x1]
            seg[row > 0] = row[row > 0]
    return c


def src_bottom(path):
    return Image.open(path).convert("RGBA").getbbox()[3] - 1


# ------------------------------------------------------------------ źródła dla animacji z profilu
def load_profile():
    st_path = os.path.join(SRC, "east.png")
    st = on_canvas(shrink(st_path), 80, 252)
    yy, xx = np.mgrid[0:H, 0:W]
    lm = ((yy >= 143) & (xx >= 151)) | ((yy >= 152) & (xx >= 145))        # maska nóg
    up_run = np.where(lm, 0, st)                                           # tułów z mieczem na ramieniu
    up_fight = up_run.copy()                                               # tułów bez miecza, wolne ręce
    up_fight[((xx <= 152) & (yy <= 97)) | ((xx <= 151) & (yy <= 99))] = 0
    up_fight[(xx >= 170) & (yy >= 112) & (yy <= 119)] = 0
    m = (xx >= 165) & (xx <= 169) & (yy >= 113) & (yy <= 119) & np.isin(up_fight, [13, 12, 11, 15])
    up_fight[m] = 3
    m = (xx >= 156) & (xx <= 164) & (yy >= 137) & (yy <= 144) & np.isin(up_fight, [13, 15, 12])
    up_fight[m] = 5
    legs = {"st": np.where(lm, st, 0)}
    for n, key in ((2, "w2"), (3, "w3"), (4, "w4"), (5, "w5")):
        p = os.path.join(SRC, "walk_east", "east_000%d.png" % n)
        wk = np.where(lm, on_canvas(shrink(p), 80, 252), 0)
        if key != "w2":                                                    # koniec pochwy miecza wchodzący w maskę nóg
            stray = (xx <= 147) & (yy >= 152) & (yy <= 155) & np.isin(wk, [11, 12, 13, 9])
            wk[stray] = 0
        legs[key] = wk
    return up_run, up_fight, legs


PIV = 143


def shift(y, lean):
    return int(round(lean * (PIV - y) / 58.0)) if y < PIV else 0


class Frame:
    def __init__(self):
        self.im = Image.new("P", (W, H), 0)
        self.dr = ImageDraw.Draw(self.im)

    def arr(self):
        return np.array(self.im)

    def paste(self, src, x0, y0, x1, y1, tx, ty):
        a = self.arr()
        blk = src[y0:y1 + 1, x0:x1 + 1]
        h, w = blk.shape
        for j in range(h):
            Y = ty + j
            if 0 <= Y < H:
                for i in range(w):
                    X = tx + i
                    if 0 <= X < W and blk[j, i]:
                        a[Y, X] = blk[j, i]
        self.im = Image.fromarray(a, "P")
        self.dr = ImageDraw.Draw(self.im)

    def poly(self, pts, col):
        tp = [(int(round(x)), int(round(y))) for x, y in pts]
        self.dr.polygon(tp, fill=T[col], outline=T[col])

    def line(self, a, b, col):
        self.dr.line([(int(round(a[0])), int(round(a[1]))), (int(round(b[0])), int(round(b[1])))], fill=T[col])

    def rect(self, a, b, col):
        self.dr.rectangle([(int(round(a[0])), int(round(a[1]))), (int(round(b[0])), int(round(b[1])))], fill=T[col])

    def ell(self, a, b, col):
        self.dr.ellipse([tuple(a), tuple(b)], fill=T[col])

    def pts(self, pts, col):
        for p in pts:
            self.dr.point((int(round(p[0])), int(round(p[1]))), fill=T[col])

    def outline(self):
        a = self.arr()
        m = a > 0
        e = np.zeros_like(m)
        e[1:] |= m[:-1]
        e[:-1] |= m[1:]
        e[:, 1:] |= m[:, :-1]
        e[:, :-1] |= m[:, 1:]
        a[e & ~m] = 1
        self.im = Image.fromarray(a, "P")
        self.dr = ImageDraw.Draw(self.im)


def quad(p0, p1, hw0, hw1=None):
    hw1 = hw0 if hw1 is None else hw1
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    ln = math.hypot(dx, dy) or 1
    nx, ny = -dy / ln, dx / ln
    return [(p0[0] + nx * hw0, p0[1] + ny * hw0), (p1[0] + nx * hw1, p1[1] + ny * hw1),
            (p1[0] - nx * hw1, p1[1] - ny * hw1), (p0[0] - nx * hw0, p0[1] - ny * hw0)]


def ik(S, Hd, l1, l2, bend):
    dx, dy = Hd[0] - S[0], Hd[1] - S[1]
    D = math.hypot(dx, dy)
    D2 = min(D, l1 + l2 - 0.3)
    if D > D2:
        Hd = (S[0] + dx * D2 / D, S[1] + dy * D2 / D)
        dx, dy = Hd[0] - S[0], Hd[1] - S[1]
    a = (l1 * l1 - l2 * l2 + D2 * D2) / (2 * D2)
    h = math.sqrt(max(l1 * l1 - a * a, 0))
    ux, uy = dx / D2, dy / D2
    return (S[0] + ux * a - uy * h * bend, S[1] + uy * a + ux * h * bend), Hd


def arm(f, S, Hd, near=True, bend=1, stretch=1.0):
    ln = 13 * stretch
    E, H2 = ik(S, Hd, ln, ln, bend)
    fill, edge, hi = ("red.4", "red.0", "red.5") if near else ("red.2", "red.0", "red.3")
    f.poly(quad(S, E, 4.2, 3.3), edge)
    f.poly(quad(E, H2, 3.3, 2.6), edge)
    f.poly(quad(S, E, 3.0, 2.2), fill)
    f.poly(quad(E, H2, 2.2, 1.6), fill)
    if near:
        f.line((S[0], S[1] - 1), (E[0], E[1] - 1), hi)
    return H2


def hand(f, Hd, near=True):
    x, y = int(round(Hd[0])), int(round(Hd[1]))
    f.rect((x - 2, y - 2), (x + 2, y + 2), "outline")
    f.rect((x - 1, y - 1), (x + 1, y + 1), "flesh.1" if near else "flesh.0")
    if near:
        f.line((x - 1, y + 1), (x + 1, y + 1), "flesh.0")


def sword(f, G, th):
    """Dwuręczny miecz: G = dłoń przy jelcu, th = kąt ostrza (radiany, 0 = w prawo, -pi/2 = w górę). 99 px długości."""
    u = (math.cos(th), math.sin(th))
    n = (-u[1], u[0])

    def P(t, o=0):
        return (G[0] + u[0] * t + n[0] * o, G[1] + u[1] * t + n[1] * o)

    f.poly(quad(P(-14), P(5), 2.2), "outline")
    f.line(P(-13), P(4), "leather.4")
    f.rect((P(-15)[0] - 1, P(-15)[1] - 1), (P(-15)[0] + 1, P(-15)[1] + 1), "steel.0")
    f.poly([P(6, 2.5), P(78, 2.2), P(84), P(78, -2.2), P(6, -2.5)], "outline")
    f.poly(quad(P(7), P(77), 1.2, 1.0), "steel.2")
    f.line(P(7, -1), P(80, -1), "steel.3")
    f.poly(quad(P(17, -4.5), P(17, 4.5), 1.2), "outline")
    f.poly(quad(P(6, -8.5), P(6, 8.5), 1.6), "outline")
    f.line(P(6, -7.5), P(6, 7.5), "steel.2")
    return P


def build(S, legs="w4", up="fight", L=0, dx=0, dy=0, G=None, th=None, back=False, nearbend=1, farbend=1,
          nearH=None, farH=None, stretch=1.0, pre=None, extra=None):
    """Jedna klatka: nogi + tułów pochylony o L px (na wysokości głowy) + ręce i miecz."""
    f = Frame()

    def tr(p):
        return (p[0] + dx + shift(p[1], L), p[1] + dy)

    Sn, Sf = tr((156, 109)), tr((164, 110))
    D = math.radians(th) if th is not None else None
    P = None
    if pre:
        pre(f)
    if G is not None:
        u = (math.cos(D), math.sin(D))
        Hf = (G[0] - u[0] * 9, G[1] - u[1] * 9)
        if back:
            P = sword(f, G, D)
        arm(f, Sf, Hf, near=False, bend=farbend, stretch=stretch)
    elif farH is not None:
        hand(f, arm(f, Sf, farH, near=False, bend=farbend), False)
    f.paste(S["legs"][legs], 143, 143, 192, 189, 143, 143)
    src = S["up_" + up]
    y = 78
    while y <= 166:
        s0 = shift(y, L)
        y2 = y
        while y2 + 1 <= 166 and shift(y2 + 1, L) == s0:
            y2 += 1
        f.paste(src, 124, y, 176, y2, 124 + dx + s0, y + dy)
        y = y2 + 1
    if G is not None:
        if not back:
            P = sword(f, G, D)
        hand(f, Hf, False)
        arm(f, Sn, G, near=True, bend=nearbend, stretch=stretch)
        hand(f, G, True)
    elif nearH is not None:
        hand(f, arm(f, Sn, nearH, near=True, bend=nearbend), True)
    if extra:
        extra(f, P)
    return f


def lying(lift=0):
    """Ivo na ziemi (ostatnie klatki śmierci), rysowany od zera."""
    f = Frame()
    g = 189 - lift
    f.line((176, g), (262, g), "outline")
    f.line((178, g - 1), (258, g - 1), "steel.2")
    f.line((259, g - 1), (262, g - 1), "steel.1")
    f.line((168, g - 1), (177, g - 1), "leather.4")
    f.line((176, g - 4), (176, g), "steel.1")
    f.rect((165, g - 2), (167, g), "steel.1")
    f.poly([(92, g), (100, g - 6), (128, g - 9), (150, g - 4), (150, g)], "red.1")
    f.line((100, g - 6), (128, g - 9), "red.5")
    f.ell((80, g - 9), (96, g), "red.3")
    f.line((82, g - 8), (94, g - 8), "red.5")
    f.line((78, g), (98, g), "outline")
    f.poly([(148, g - 16), (170, g - 14), (172, g), (148, g)], "red.4")
    f.line((150, g - 14), (168, g - 13), "red.5")
    f.poly([(148, g - 4), (171, g - 4), (172, g), (148, g)], "red.2")
    f.poly([(170, g - 13), (190, g - 12), (190, g), (171, g)], "leather.2")
    f.line((171, g - 12), (189, g - 10), "leather.4")
    f.poly([(188, g - 21), (194, g - 21), (195, g), (188, g)], "leather.1")
    f.line((189, g - 20), (193, g - 20), "leather.5")
    f.poly([(118, g - 18), (148, g - 17), (150, g), (116, g)], "red.3")
    f.poly([(120, g - 18), (146, g - 17), (146, g - 13), (120, g - 14)], "red.4")
    f.line((121, g - 17), (144, g - 16), "red.5")
    f.poly([(116, g - 4), (150, g - 4), (150, g), (116, g)], "red.1")
    f.line((130, g - 17), (133, g - 1), "red.0")
    f.line((141, g - 17), (143, g - 1), "red.0")
    f.poly([(126, g - 12), (150, g - 8), (152, g - 2), (126, g - 4)], "red.4")
    f.line((126, g - 12), (150, g - 8), "red.0")
    f.line((126, g - 3), (152, g - 2), "red.0")
    f.rect((152, g - 6), (155, g - 2), "flesh.1")
    f.line((152, g - 2), (155, g - 2), "flesh.0")
    f.ell((104, g - 16), (118, g - 1), "leather.4")
    f.poly([(108, g - 16), (116, g - 14), (117, g - 8), (110, g - 8)], "flesh.1")
    f.line((110, g - 8), (117, g - 8), "flesh.0")
    f.line((104, g - 3), (116, g - 2), "leather.2")
    f.pts([(114, g - 12)], "outline")
    f.outline()
    return f


def animations(S):
    def b(**kw):
        return build(S, **kw)

    stance = dict(legs="w4", L=2, G=(172, 127), th=-64)

    def raised(dy=0, glint=False):
        def pre(f):
            G = (173, 92 + dy)
            sword(f, G, math.radians(-76))
            arm(f, (164, 110 + dy), G, near=False)
            hand(f, G, False)

        def spark(f, _p):
            if glint:
                f.line((189, 9), (197, 9), "smear.1")
                f.line((193, 5), (193, 13), "smear.1")
                f.pts([(191, 7), (192, 8), (194, 10), (195, 11), (195, 7), (194, 8), (192, 10), (191, 11)], "smear.0")

        return b(legs="st", L=-1, dy=dy, nearH=(166, 131 + dy), pre=pre, extra=spark)

    hurt0 = dict(legs="w4", L=-8, dx=-3, G=(164, 121), th=-92)
    return {
        "idle": [b(legs="st", up="run"), b(legs="st", up="run", dy=1)],
        # chód: 4 klatki oryginału to pół cyklu kroku (kontakt -> przejście -> odbicie), powtórzone dwa razy
        "walk": [b(legs="w5", up="run", L=5, dy=1), b(legs="w2", up="run", L=5, dy=2), b(legs="w4", up="run", L=6),
                 b(legs="w5", up="run", L=5, dy=1), b(legs="w3", up="run", L=5, dy=3), b(legs="w4", up="run", L=6)],
        # zwykły cios: postawa, zamach nad barkiem, cięcie w ruchu, TRAFIENIE (ostrze poziomo, 110 px od pivotu)
        "attack": [b(**stance), b(legs="w4", L=-3, G=(158, 104), th=-118), b(legs="w4", L=3, G=(176, 112), th=-48),
                   b(legs="w5", L=7, dy=1, G=(186, 121), th=3, stretch=1.15)],
        # Potężne cięcie: znad głowy, TRAFIENIE w wypadzie (132 px od pivotu)
        "heavy": [b(legs="w4", L=-1, G=(165, 101), th=-98, nearbend=-1, farbend=-1),
                  b(legs="w4", L=-5, dy=1, G=(158, 88), th=-140, nearbend=-1, farbend=-1, back=True),
                  b(legs="w5", L=4, dx=3, G=(180, 98), th=-48),
                  b(legs="w5", L=10, dx=7, dy=3, G=(210, 129), th=11, stretch=1.3)],
        # Wirujący miecz: miecz za plecy, zamach, łuk dołem, TRAFIENIE z przodu (122 px od pivotu)
        "whirl": [b(legs="w4", L=-2, G=(152, 122), th=190, back=True, nearbend=-1, farbend=-1),
                  b(legs="w4", L=-4, dy=1, G=(148, 124), th=168, back=True, nearbend=-1, farbend=-1),
                  b(legs="w5", L=3, dy=2, G=(176, 126), th=38),
                  b(legs="w5", L=8, dy=2, G=(198, 125), th=0, stretch=1.25)],
        # Okrzyk gwardii: miecz w górę, na końcu błysk ostrza
        "shout": [b(**stance), raised(dy=1), raised(glint=True)],
        "hurt": [b(**hurt0), b(legs="w4", L=-4, dx=-1, G=(169, 125), th=-74)],
        "death": [b(**hurt0),
                  b(legs="w3", L=-12, dx=-5, dy=6, G=(160, 126), th=-110, nearbend=-1, farbend=-1, back=True),
                  b(legs="w3", L=-15, dx=-8, dy=14, G=(152, 140), th=-140, nearbend=-1, farbend=-1, back=True),
                  b(legs="w2", L=-18, dx=-12, dy=24, nearH=(150, 160), farH=(160, 158)),
                  lying(3), lying(1)],
    }


def save(arr, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    rgba = np.zeros((H, W, 4), np.uint8)
    m = arr > 0
    rgba[m, :3] = RGB[arr[m]]
    rgba[m, 3] = 255
    Image.fromarray(rgba, "RGBA").save(path, optimize=True)


def main():
    up_run, up_fight, legs = load_profile()
    S = {"up_run": up_run, "up_fight": up_fight, "legs": legs}
    count = 0
    for d in DIRS:
        if d == "east":
            continue
        p = os.path.join(SRC, d + ".png")
        save(on_canvas(shrink(p), ANCHOR[d], src_bottom(p)), os.path.join(BASE, "idle", d, "0.png"))
        count += 1
    for name, frames in animations(S).items():
        for i, f in enumerate(frames):
            a = f.arr()
            ys, xs = np.nonzero(a)
            assert xs.min() >= 2 and xs.max() <= W - 3 and ys.min() >= 2 and ys.max() <= PIVOT[1] - 1, (name, i)
            save(a, os.path.join(BASE, name, "east", "%d.png" % i))
            count += 1
    meta = {
        "canvas": [W, H],
        "pivot": list(PIVOT),
        "fps": {"idle": 2, "walk": 10, "attack": 0, "heavy": 0, "whirl": 0, "shout": 0, "hurt": 6, "death": 6},
        "_opis": "Pivot = punkt stóp. fps=0: klatki rozkładane na czas zamachu (ostatnia = trafienie). "
                 "Animacje z profilu są tylko w kierunku east (west = odbicie); reszta kierunków to pozy. "
                 "Generator: tools/build_ivo.py",
    }
    json.dump(meta, open(os.path.join(BASE, "sprite.json"), "w"), indent=1, ensure_ascii=False)
    print("Ivo: %d klatek w %s" % (count, os.path.relpath(BASE, ROOT)))


if __name__ == "__main__":
    main()
