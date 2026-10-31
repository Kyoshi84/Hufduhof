"""Grafiki prologu (karczma + minigra z kuflami) -> assets/minigame/*.png, kwantyzowane do wspólnej palety.
Uruchom: python3 tools/build_tavern_art.py [--preview katalog]
Skala jak w reszcie gry: 1 px grafiki = 4/3 jednostki świata (świat 1280x720 => tło 960x540 px)."""
import argparse, os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixart import Canvas, RAMPS, OUTLINE, bayer
import importlib.util

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "assets/minigame")
spec = importlib.util.spec_from_file_location("mp", os.path.join(HERE, "tools/make_palette.py"))
mp = importlib.util.module_from_spec(spec); spec.loader.exec_module(mp)

SKIN = [(120, 80, 58), (160, 112, 84), (200, 148, 112), (232, 178, 138)]
RAMPS["skin"] = SKIN
RAMPS["blood"] = RAMPS["red"]
RAMPS["foam"] = [(150, 134, 100), (196, 182, 148), (232, 224, 196), (255, 252, 236)]
RAMPS["ale"] = [(96, 52, 12), (156, 92, 20), (206, 136, 34), (240, 176, 60)]
RAMPS["gold"] = [(98, 66, 12), (170, 120, 24), (226, 178, 50), (255, 226, 120)]
RAMPS["apron"] = [(80, 76, 70), (130, 124, 112), (186, 178, 160), (226, 220, 200)]
RAMPS["blue"] = [(16, 24, 48), (30, 48, 92), (52, 80, 140), (86, 120, 180)]
RAMPS["tunic_red"] = [(50, 10, 14), (100, 18, 24), (150, 28, 34), (196, 52, 48)]
RAMPS["tunic_green"] = [(14, 30, 18), (28, 58, 32), (50, 92, 48), (84, 130, 70)]
RAMPS["tunic_brown"] = [(36, 24, 14), (68, 46, 26), (106, 76, 42), (148, 110, 64)]
RAMPS["tunic_grey"] = [(30, 30, 34), (58, 58, 64), (94, 92, 96), (136, 132, 130)]
RAMPS["hair_grey"] = [(60, 58, 60), (110, 108, 108), (160, 158, 154), (206, 204, 198)]
RAMPS["hair_dark"] = [(14, 10, 8), (32, 22, 16), (58, 40, 26), (88, 62, 38)]
RAMPS["hair_ginger"] = [(60, 20, 8), (110, 40, 14), (164, 70, 24), (206, 104, 40)]

def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

# ------------------------------------------------------------------------------------------ pomocnicze
def lit(xx, x0, x1, lo=0.2, hi=0.9):
    return hi - (xx - x0) / max(1.0, (x1 - x0)) * (hi - lo)

def person(w, h, tunic, pants="tunic_brown", hair="hair_dark", hat=None, beard=False, skin=2,
           belly=1.0, seed=1, arms_up=False, dwarf=False, scarf=False, mug=False):
    c = Canvas(w, h)
    c.rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    cx = w / 2
    leg_y = h * (0.66 if not dwarf else 0.72)
    # nogi
    for dx in (-0.11, 0.11):
        m = c.rect(cx + dx * w - w * 0.075, leg_y, cx + dx * w + w * 0.075, h - 3)
        c.paint(m, pants, lit(xx, cx - w * 0.3, cx + w * 0.3, 0.25, 0.75), 0.15)
        boots = c.rect(cx + dx * w - w * 0.09, h - 8, cx + dx * w + w * 0.09, h - 2)
        c.paint(boots, "char", 0.55, 0.1)
    # tułów
    top = h * (0.30 if not dwarf else 0.36)
    bw = w * 0.30 * belly
    torso = c.poly([(cx - bw * 0.85, top), (cx + bw * 0.85, top), (cx + bw, leg_y + 3), (cx - bw, leg_y + 3)])
    torso |= c.ellipse(cx, (top + leg_y) / 2 + 3, bw * 1.02, (leg_y - top) * 0.55)
    c.volume(torso, tunic, bulge=6, noise=0.12, base=0.6)
    belt = c.rect(cx - bw * 0.98, leg_y - 5, cx + bw * 0.98, leg_y - 2)
    c.paint(belt, "char", 0.6, 0.0)
    # ręce
    for sgn in (-1, 1):
        sx = cx + sgn * bw * 0.9
        if arms_up:
            hand = (cx + sgn * w * 0.20, top - h * 0.16)
            arm = c.line((sx, top + 4), hand, max(4, int(w * 0.11)))
            c.volume(arm, tunic, bulge=3, noise=0.1, base=0.55)
            c.paint(c.ellipse(hand[0], hand[1] - 1, w * 0.07, w * 0.07), "skin", 0.7, 0.0)
        else:
            hand = (sx + sgn * 2, leg_y - 2)
            arm = c.line((sx, top + 3), hand, max(4, int(w * 0.11)))
            c.volume(arm, tunic, bulge=3, noise=0.1, base=0.5)
            c.paint(c.ellipse(hand[0], hand[1] + 1, w * 0.065, w * 0.065), "skin", 0.7, 0.0)
    # głowa
    hr = w * (0.17 if not dwarf else 0.2)
    hy = top - hr * 0.55
    head = c.ellipse(cx, hy, hr, hr * 1.1)
    c.volume(head, "skin", bulge=5, noise=0.08, base=0.55 + 0.1 * (skin - 2))
    c.paint(c.rect(cx - hr * 0.35, hy + hr * 0.9, cx + hr * 0.35, hy + hr * 1.3), "skin", 0.35, 0.05)  # szyja
    # oczy, nos
    ey = hy - hr * 0.1
    c.flat(c.rect(cx - hr * 0.55, ey, cx - hr * 0.25, ey + 2), (20, 14, 12))
    c.flat(c.rect(cx + hr * 0.25, ey, cx + hr * 0.55, ey + 2), (20, 14, 12))
    c.paint(c.ellipse(cx, hy + hr * 0.3, hr * 0.17, hr * 0.2), "skin", 0.85, 0.0)
    c.flat(c.rect(cx - hr * 0.3, hy + hr * 0.62, cx + hr * 0.3, hy + hr * 0.7), (96, 40, 36))
    # włosy / broda / nakrycie głowy
    if beard:
        b = c.poly([(cx - hr * 0.95, hy + hr * 0.1), (cx + hr * 0.95, hy + hr * 0.1), (cx + hr * 0.6, hy + hr * 1.9), (cx, hy + hr * 2.3), (cx - hr * 0.6, hy + hr * 1.9)])
        c.paint(b & ~c.ellipse(cx, hy + hr * 0.35, hr * 0.45, hr * 0.28), hair, lit(xx, cx - hr, cx + hr, 0.3, 0.8), 0.25)
    if hat == "cap":
        m = c.ellipse(cx, hy - hr * 0.35, hr * 1.12, hr * 0.8) & c.rect(0, 0, w, hy - hr * 0.1)
        c.volume(m, "tunic_brown", bulge=4, base=0.6)
    elif hat == "hood":
        m = c.ellipse(cx, hy - hr * 0.1, hr * 1.25, hr * 1.35) & ~c.ellipse(cx, hy + hr * 0.3, hr * 0.8, hr * 0.85)
        c.volume(m, tunic, bulge=4, base=0.5)
    elif hat == "helmet":
        m = c.ellipse(cx, hy - hr * 0.3, hr * 1.15, hr * 0.95) & c.rect(0, 0, w, hy + hr * 0.1)
        c.volume(m, "steel" if False else "iron", bulge=4, base=0.6)
    elif hat == "bandana":
        m = c.rect(cx - hr * 1.05, hy - hr * 0.7, cx + hr * 1.05, hy - hr * 0.25) & c.ellipse(cx, hy, hr * 1.08, hr * 1.12)
        c.volume(m, "tunic_red", bulge=3, base=0.6)
    elif hat == "scarf":
        m = c.ellipse(cx, hy - hr * 0.1, hr * 1.2, hr * 1.25) & ~c.ellipse(cx, hy + hr * 0.4, hr * 0.78, hr * 0.8)
        c.volume(m, "tunic_red", bulge=4, base=0.6)
    elif hat == "bald":
        pass
    else:
        m = c.ellipse(cx, hy - hr * 0.4, hr * 1.02, hr * 0.8) & c.rect(0, 0, w, hy - hr * 0.15)
        c.paint(m, hair, 0.5, 0.25)
    if mug:
        mx, my = cx + bw * 1.15, leg_y - 10
        c.paint(c.rect(mx - 5, my - 7, mx + 5, my + 6), "wood", 0.7, 0.1)
        c.paint(c.rect(mx - 5, my - 9, mx + 5, my - 6), "foam", 0.8, 0.0)
    c.outline()
    return c.image()

def tankard(w, h, big=True, gold=False):
    """Kufel: klepki, obręcze, piana. Widok z lekkiej góry; uchwyt po prawej."""
    c = Canvas(w, h)
    yy, xx = np.mgrid[0:h, 0:w]
    bx0, bx1 = 3, w - (w * 0.28 if big else 7)
    cx = (bx0 + bx1) / 2
    rx = (bx1 - bx0) / 2
    body = c.poly([(bx0 + 1, h * 0.28), (bx1 - 1, h * 0.28), (bx1 + 1, h - 4), (bx0 - 1, h - 4)]) | c.ellipse(cx, h - 5, rx + 1, h * 0.09)
    ramp = "gold" if gold else "wood"
    c.paint(body, ramp, lit(xx, bx0, bx1, 0.15, 0.95) - ((xx - bx0) % max(4, int(w // 8)) == 0) * 0.28, 0.12)
    for fy in (0.42, 0.82):
        hoop = c.rect(bx0 - 1, h * fy, bx1 + 1, h * fy + max(2, h * 0.07))
        c.paint(hoop & body, "iron" if not gold else "gold", lit(xx, bx0, bx1, 0.3, 1.0), 0.1)
    # uchwyt
    hx = bx1 + 2
    ring = c.ellipse(hx + w * 0.07, h * 0.58, w * 0.13, h * 0.26) & ~c.ellipse(hx + w * 0.07, h * 0.58, w * 0.06, h * 0.15)
    c.paint(ring, ramp, 0.55, 0.12)
    # piana nad krawędzią + oczko piwa
    rim = c.ellipse(cx, h * 0.28, rx + 1, h * 0.10)
    c.paint(rim, "ale", 0.7, 0.1)
    foam = c.ellipse(cx, h * 0.2, rx, h * 0.14)
    for bx in np.linspace(bx0 + 3, bx1 - 3, 4 if big else 3):
        foam |= c.ellipse(bx, h * 0.12, rx * 0.34, h * 0.13)
    c.paint(foam, "foam", 0.55 + 0.3 * (yy < h * 0.2), 0.2)
    c.outline()
    return c.image()

def splash(w, h):
    c = Canvas(w, h)
    cx, cy = w / 2, h * 0.62
    pool = c.ellipse(cx, cy, w * 0.42, h * 0.3)
    c.paint(pool, "ale", 0.6, 0.2)
    c.paint(c.ellipse(cx - w * 0.1, cy - h * 0.08, w * 0.18, h * 0.1), "foam", 0.85, 0.15)
    for dx, dy, s in ((-0.4, -0.3, 2), (0.38, -0.34, 2), (0.12, -0.42, 1), (-0.18, -0.4, 1)):
        c.paint(c.rect(cx + dx * w, cy + dy * h * 1.6, cx + dx * w + s, cy + dy * h * 1.6 + s), "wood", 0.5, 0.1)
    c.outline()
    return c.image()

def innkeeper(w, h):
    c = Canvas(w, h)
    c.rng = np.random.default_rng(7)
    yy, xx = np.mgrid[0:h, 0:w]
    cx = w / 2
    # nogi i buty
    for dx in (-0.14, 0.14):
        c.paint(c.rect(cx + dx * w - 6, h * 0.7, cx + dx * w + 6, h - 3), "tunic_grey", lit(xx, cx - 20, cx + 20, 0.2, 0.7), 0.12)
        c.paint(c.rect(cx + dx * w - 8, h - 8, cx + dx * w + 8, h - 2), "char", 0.55, 0.1)
    body = c.ellipse(cx, h * 0.52, w * 0.34, h * 0.27) | c.rect(cx - w * 0.25, h * 0.4, cx + w * 0.25, h * 0.72)
    c.volume(body, "tunic_brown", bulge=8, base=0.55)
    apron = c.poly([(cx - w * 0.22, h * 0.46), (cx + w * 0.22, h * 0.46), (cx + w * 0.28, h * 0.84), (cx - w * 0.28, h * 0.84)])
    c.paint(apron, "apron", lit(xx, cx - w * 0.28, cx + w * 0.28, 0.45, 0.95), 0.1)
    c.flat(c.rect(cx - w * 0.22, h * 0.46, cx + w * 0.22, h * 0.48), RAMPS["char"][2])
    for sgn in (-1, 1):                                       # ręce rozłożone na boki
        sh = (cx + sgn * w * 0.28, h * 0.42)
        hand = (cx + sgn * w * 0.47, h * 0.3)
        c.volume(c.line(sh, hand, 8), "tunic_brown", bulge=3, base=0.55)
        c.paint(c.ellipse(hand[0], hand[1], 5, 5), "skin", 0.7, 0.0)
    head = c.ellipse(cx, h * 0.24, w * 0.19, h * 0.15)
    c.volume(head, "skin", bulge=6, base=0.62)
    c.paint(c.ellipse(cx - w * 0.17, h * 0.26, 3, 4), "skin", 0.5, 0.0)
    c.paint(c.ellipse(cx + w * 0.17, h * 0.26, 3, 4), "skin", 0.5, 0.0)
    c.paint(c.ellipse(cx, h * 0.27, w * 0.06, h * 0.045), "skin", 0.9, 0.0)                    # nos
    c.flat(c.rect(cx - w * 0.12, h * 0.215, cx - w * 0.05, h * 0.235), (20, 14, 12))
    c.flat(c.rect(cx + w * 0.05, h * 0.215, cx + w * 0.12, h * 0.235), (20, 14, 12))
    must = c.poly([(cx - w * 0.2, h * 0.3), (cx, h * 0.285), (cx + w * 0.2, h * 0.3), (cx + w * 0.26, h * 0.36), (cx + w * 0.1, h * 0.325), (cx - w * 0.1, h * 0.325), (cx - w * 0.26, h * 0.36)])
    c.paint(must, "hair_ginger", 0.55, 0.3)
    c.paint(c.ellipse(cx, h * 0.12, w * 0.15, h * 0.04) & c.rect(0, 0, w, h * 0.13), "hair_ginger", 0.5, 0.3)
    c.outline()
    return c.image()

def borubar(w, h, dizzy=False):
    """Pijak Borubar: łysy z kępką włosów, czerwony nos, łachmany, ręce wyciągnięte w górę (trzyma kufel)."""
    c = Canvas(w, h)
    c.rng = np.random.default_rng(11)
    yy, xx = np.mgrid[0:h, 0:w]
    cx = w / 2
    leg_y = h * 0.7
    for dx, sh in ((-0.12, 0), (0.12, 2)):
        c.paint(c.rect(cx + dx * w - 7, leg_y, cx + dx * w + 7, h - 3), "tunic_green", lit(xx, cx - 24, cx + 24, 0.15, 0.6), 0.2)
        c.paint(c.rect(cx + dx * w - 9, h - 9 + sh * 0, cx + dx * w + 9, h - 2), "char", 0.5, 0.1)
    top = h * 0.5
    belly = c.ellipse(cx, top + h * 0.12, w * 0.3, h * 0.2) | c.poly([(cx - w * 0.2, top - 2), (cx + w * 0.2, top - 2), (cx + w * 0.3, top + h * 0.1), (cx - w * 0.3, top + h * 0.1)])
    c.volume(belly, "tunic_brown", bulge=9, noise=0.2, base=0.5)
    for (px, py) in ((cx - 12, top + h * 0.1), (cx + 9, top + h * 0.17), (cx - 3, top + h * 0.05)):   # łaty
        c.paint(c.rect(px, py, px + 8, py + 6), "tunic_green", 0.5, 0.2)
    c.flat(c.rect(cx - w * 0.3, top + h * 0.2, cx + w * 0.3, top + h * 0.2 + 3), RAMPS["char"][2])
    # ręce w górę
    for sgn in (-1, 1):
        sh = (cx + sgn * w * 0.22, top + 3)
        hand = (cx + sgn * w * 0.2, h * 0.07)
        arm = c.line(sh, (cx + sgn * w * 0.3, top - h * 0.22), 9) | c.line((cx + sgn * w * 0.3, top - h * 0.22), hand, 8)
        c.volume(arm, "tunic_brown", bulge=3, base=0.5)
        c.paint(c.ellipse(hand[0], hand[1], 5, 5), "skin", 0.65, 0.0)
    # głowa
    hy = top - h * 0.1
    head = c.ellipse(cx, hy, w * 0.19, h * 0.115)
    c.volume(head, "skin", bulge=6, base=0.7)
    c.paint(c.ellipse(cx, hy + h * 0.02, w * 0.075, h * 0.05), "tunic_red", 0.7 + 0.1 * dizzy, 0.15)   # czerwony nos
    ey = hy - h * 0.02
    if dizzy:
        for ex in (cx - w * 0.09, cx + w * 0.09):
            c.flat(c.line((ex - 3, ey - 3), (ex + 3, ey + 3), 2), (20, 14, 12))
            c.flat(c.line((ex - 3, ey + 3), (ex + 3, ey - 3), 2), (20, 14, 12))
        c.flat(c.ellipse(cx, hy + h * 0.075, 4, 3), (60, 14, 14))
    else:
        for ex in (cx - w * 0.09, cx + w * 0.09):
            c.flat(c.rect(ex - 3, ey - 2, ex + 3, ey + 2), (232, 224, 196))
            c.flat(c.rect(ex - 1, ey - 1, ex + 1, ey + 2), (20, 14, 12))
        c.flat(c.rect(cx - 7, hy + h * 0.07, cx + 7, hy + h * 0.07 + 2), (60, 14, 14))
    c.paint(c.rect(cx - w * 0.2, ey - 5, cx - w * 0.04, ey - 3), "hair_ginger", 0.4, 0.2)               # brwi
    c.paint(c.rect(cx + w * 0.04, ey - 5, cx + w * 0.2, ey - 3), "hair_ginger", 0.4, 0.2)
    c.paint(c.poly([(cx - 5, hy - h * 0.11), (cx, hy - h * 0.2), (cx + 5, hy - h * 0.11)]), "hair_ginger", 0.55, 0.25)    # kępka
    brd = c.poly([(cx - w * 0.18, hy + h * 0.04), (cx + w * 0.18, hy + h * 0.04), (cx + w * 0.1, hy + h * 0.13), (cx - w * 0.1, hy + h * 0.13)])
    c.paint(brd & ~c.ellipse(cx, hy + h * 0.06, w * 0.08, h * 0.03), "hair_ginger", 0.45, 0.3)           # zarost
    c.outline()
    return c.image()

def stars(w=48, h=14):
    c = Canvas(w, h)
    for i, x in enumerate((8, 24, 40)):
        y = 7 + (3 if i == 1 else -2)
        c.flat(c.rect(x - 1, y - 4, x + 2, y + 5), (255, 226, 120))
        c.flat(c.rect(x - 4, y - 1, x + 5, y + 2), (255, 226, 120))
    return c.image()

def door_closed(c, x0, y0, x1, y1):
    yy, xx = np.mgrid[0:c.h, 0:c.w]
    arch = c.rect(x0 - 8, y0 - 8, x1 + 8, y1) & ~c.rect(0, 0, 0, 0)
    c.paint(arch, "stone", 0.35 + 0.35 * ((xx // 9 + yy // 6) % 2), 0.2)
    d = c.rect(x0, y0, x1, y1) | c.ellipse((x0 + x1) / 2, y0, (x1 - x0) / 2, 14)
    c.paint(d, "wood", lit(xx, x0, x1, 0.3, 0.8) - ((xx - x0) % 12 == 0) * 0.25, 0.14)
    for hy in (y0 + 12, y1 - 22):
        c.paint(c.rect(x0, hy, x1, hy + 4), "iron", 0.55, 0.1)
    c.paint(c.ellipse(x1 - 10, (y0 + y1) / 2 + 6, 3, 3), "iron", 0.9, 0.0)

def door_open(w, h):
    """Nakładka na drzwi: ciemne wnętrze z czerwonym blaskiem pożaru i wyrwane skrzydła."""
    c = Canvas(w, h)
    yy, xx = np.mgrid[0:h, 0:w]
    cx = w / 2
    gap = c.rect(10, 12, w - 10, h) | c.ellipse(cx, 24, w / 2 - 10, 16)
    glow = 1.0 - np.hypot((xx - cx) / (w / 2), (yy - h * 0.7) / (h * 0.7))
    c.paint(gap, "fire", np.clip(glow * 0.9, 0, 0.9), 0.25)
    c.paint(gap & (yy < h * 0.35), "blood", 0.2 + 0.3 * glow.clip(0, 1), 0.2)
    for sgn in (-1, 1):                                       # skrzydła drzwi odchylone
        x_in = cx + sgn * (w / 2 - 10)
        leaf = c.poly([(x_in, 14), (x_in + sgn * 14, 22), (x_in + sgn * 14, h), (x_in, h)])
        c.paint(leaf, "wood", 0.45 + 0.1 * sgn, 0.15)
    c.outline()
    return c.image()

# ------------------------------------------------------------------------------------------ tło
def background(W=960, H=540):
    c = Canvas(W, H)
    c.rng = np.random.default_rng(3)
    yy, xx = np.mgrid[0:H, 0:W]
    rng = c.rng
    FLOOR = 392
    BAL = 128                                       # dolna krawędź balkonu
    # --- ściana: dolna część kamienna, górna drewniana
    wall = c.rect(0, 0, W, FLOOR)
    stone = (yy > 250)
    brick = ((xx + (yy // 22 % 2) * 21) // 42 + (yy // 22) * 7) % 5
    shade = np.where(stone, 0.28 + 0.1 * brick / 4 - (((yy % 22) == 0) | (((xx + (yy // 22 % 2) * 21) % 42) == 0)) * 0.12,
                     0.30 + 0.08 * (((xx // 24) % 2)) - ((xx % 24) == 0) * 0.14)
    # światło ognia z lewej + latarni; ściana ciemniejsza ku prawej
    fire_c = (150, 330)
    glow = np.clip(1.0 - np.hypot(xx - fire_c[0], (yy - fire_c[1]) * 1.2) / 330.0, 0, 1)
    shade = shade + glow * 0.38
    for lx in (330, 640):
        shade += np.clip(1.0 - np.hypot(xx - lx, yy - 175) / 120.0, 0, 1) * 0.28
    c.paint(wall & stone, "stone", shade, 0.2)
    c.paint(wall & ~stone, "wood", shade * 1.15, 0.2)
    # belka oddzielająca
    c.paint(c.rect(0, 246, W, 258), "wood", 0.25 + glow[246:258].mean() * 0, 0.1)
    # --- belki konstrukcyjne
    for bx in range(60, W, 210):
        c.paint(c.rect(bx, BAL, bx + 18, 250), "wood", lit(xx, bx, bx + 18, 0.1, 0.5) + glow * 0.25, 0.12)
    # --- balkon (galeria) u góry
    c.paint(c.rect(0, 0, W, 38), "wood", 0.14 + (xx % 36 == 0) * -0.06 + (yy < 8) * -0.05, 0.1)           # strop
    gal = c.rect(0, BAL - 14, W, BAL + 6)
    c.paint(gal, "woodpale" if False else "wood", np.where(yy < BAL - 6, 0.55, 0.3), 0.12)
    c.paint(c.rect(0, BAL + 6, W, BAL + 12), "wood", 0.1, 0.05)                                          # cień pod galerią
    for bx in range(30, W, 120):                                                                           # wsporniki
        c.paint(c.poly([(bx, BAL + 6), (bx + 26, BAL + 6), (bx, BAL + 34)]), "wood", 0.3, 0.1)
    # okna z zmierzchem
    for wx in (270, 690):
        win = c.rect(wx - 28, 176, wx + 28, 240)
        sky = 0.35 + 0.35 * (1 - (yy - 176) / 64.0)
        c.paint(win, "dusk" if "dusk" in RAMPS else "blue", np.clip(sky, 0, 1), 0.15)
        c.paint(c.rect(wx - 2, 176, wx + 2, 240) | c.rect(wx - 28, 206, wx + 28, 210), "wood", 0.25, 0.05)
        c.paint(c.rect(wx - 32, 172, wx + 32, 178) | c.rect(wx - 32, 240, wx + 32, 246), "wood", 0.5, 0.1)
    # --- kominek (lewa strona)
    fx0, fx1, fy0 = 60, 250, 250
    c.paint(c.rect(fx0 - 14, fy0 - 70, fx1 + 14, FLOOR), "stone", 0.4 + (((xx // 20 + yy // 14) % 3) * 0.06), 0.2)
    opening = c.rect(fx0 + 26, fy0 - 10, fx1 - 26, FLOOR - 14) | c.ellipse((fx0 + fx1) / 2, fy0 - 10, (fx1 - fx0) / 2 - 26, 22)
    c.paint(opening, "char", 0.15, 0.1)
    fg = np.clip(1.0 - np.hypot((xx - 155) / 75.0, (yy - 350) / 62.0), 0, 1)
    c.paint(opening, "fire", np.clip(fg * 1.05, 0.0, 0.98), 0.3)
    for lg in range(3):                                                                                   # polana
        c.paint(c.line((100 + lg * 22, 372), (130 + lg * 24, 360), 6), "wood", 0.3, 0.15)
    c.paint(c.rect(fx0 - 20, fy0 - 76, fx1 + 20, fy0 - 66), "wood", 0.55, 0.12)                           # półka nad kominkiem
    # --- drzwi (środek)
    door_closed(c, 440, 262, 520, FLOOR)
    # --- regały z kuflami (prawa strona)
    for sy in (292, 336):
        c.paint(c.rect(720, sy, 910, sy + 7), "wood", 0.55 - (0.0 if sy == 292 else 0.1), 0.1)
        for mx in range(730, 900, 22):
            c.paint(c.rect(mx, sy - 15, mx + 11, sy), "wood", 0.5 + 0.1 * ((mx // 22) % 3), 0.15)
            c.paint(c.rect(mx, sy - 15, mx + 11, sy - 12), "iron", 0.6, 0.1)
    # --- baryłki pod ścianą
    for bx, by in ((300, FLOOR - 2), (352, FLOOR - 2), (326, FLOOR - 40)):
        body = c.ellipse(bx, by - 22, 26, 25)
        c.paint(body, "wood", lit(xx, bx - 26, bx + 26, 0.15, 0.8) + glow * 0.15, 0.12)
        c.paint(c.rect(bx - 27, by - 36, bx + 27, by - 32) | c.rect(bx - 27, by - 14, bx + 27, by - 10), "iron", 0.5, 0.1)
    # --- sztandary
    for bx, col in ((560, "tunic_red"), (610, "tunic_red")):
        flag = c.poly([(bx, 150), (bx + 34, 150), (bx + 34, 232), (bx + 17, 218), (bx, 232)])
        c.volume(flag, col, bulge=5, base=0.5)
        c.paint(c.rect(bx + 11, 164, bx + 23, 190), "gold", 0.6, 0.05)
    # --- lampy (latarnie)
    for lx in (330, 640):
        c.paint(c.rect(lx - 1, 140, lx + 1, 160), "iron", 0.4, 0.0)
        lan = c.rect(lx - 8, 160, lx + 8, 184)
        c.paint(lan, "fire", 0.85, 0.1)
        c.paint(c.rect(lx - 9, 158, lx + 9, 162) | c.rect(lx - 9, 183, lx + 9, 187), "iron", 0.4, 0.0)
    # --- podłoga: deski z perspektywą
    flo = c.rect(0, FLOOR, W, H)
    t = (yy - FLOOR) / float(H - FLOOR)
    seam_x = (xx - W / 2) / (60.0 * (0.55 + t * 0.9))
    seam = np.abs(seam_x - np.round(seam_x)) < 0.025
    row = ((yy - FLOOR) // 32) % 2
    board = 0.30 + 0.16 * (np.floor(seam_x + row * 0.5) % 3) / 2 + t * 0.12 + glow * 0.0
    fl_glow = np.clip(1.0 - np.hypot((xx - 160) / 400.0, (yy - FLOOR) / 230.0), 0, 1) * 0.3
    c.paint(flo, "wood", board + fl_glow - seam * 0.2 - ((yy - FLOOR) % 32 == 0) * 0.08, 0.2)
    # dywan pośrodku
    rug = c.poly([(300, 452), (660, 452), (700, 530), (260, 530)])
    c.paint(rug, "tunic_red", 0.35 + 0.15 * (((xx // 10 + yy // 6) % 2)), 0.1)
    c.paint(rug & ~c.poly([(316, 460), (644, 460), (680, 522), (280, 522)]), "gold", 0.35, 0.08)
    # winieta
    vig = np.clip(np.hypot((xx - W / 2) / (W * 0.62), (yy - H * 0.55) / (H * 0.78)), 0, 1.2)
    out = c.rgb.astype(float)
    out *= (1.0 - 0.45 * np.clip(vig - 0.45, 0, 1) ** 1.2)[..., None]
    c.rgb = out.clip(0, 255).astype(np.uint8)
    c.a[:] = True
    return c.image()

def balcony_rail(W=960, H=44):
    """Balustrada przysłaniająca nogi karczmarza (rysowana przed nim)."""
    c = Canvas(W, H)
    yy, xx = np.mgrid[0:H, 0:W]
    c.paint(c.rect(0, 0, W, 8), "wood", 0.62 - (yy % 8) * 0.03, 0.1)
    for bx in range(10, W, 36):
        c.paint(c.rect(bx, 8, bx + 10, H), "wood", lit(xx, bx, bx + 10, 0.2, 0.7), 0.12)
    c.paint(c.rect(0, H - 6, W, H), "wood", 0.2, 0.05)
    return c.image()


REF = os.path.join(HERE, "assets/minigame/source/tavern_reference.png")
CREST = os.path.join(HERE, "assets/ui/crest/carroburg_source.png")

def mirror_tile(src, w):
    """Powtarza pas src (h x sw x 3) w poziomie z odbiciami lustrzanymi do szerokości w."""
    parts, n, flip = [], 0, False
    while n < w:
        parts.append(src[:, ::-1] if flip else src); n += src.shape[1]; flip = not flip
    return np.concatenate(parts, 1)[:, :w]

def patch_floor(a, x0, x1, y0, y1, sx0, sx1, feather=22):
    """Zamazuje prostokąt (x0..x1, y0..y1) pasem podłogi z (sx0..sx1) w tych samych wierszach, z dopasowaniem jasności."""
    H = y1 - y0
    src = a[y0:y1, sx0:sx1].astype(float)
    tile = mirror_tile(src, x1 - x0)
    # dopasuj jasność wierszami do brzegu sąsiadującego z łatą (smooth gain)
    edge_x = x1 if x0 == 0 else x0 - 1
    edge_col = a[y0:y1, min(edge_x, a.shape[1] - 1)].astype(float).mean(-1)
    near = tile[:, (-1 if x0 == 0 else 0)].mean(-1)
    gain = np.clip(edge_col / np.maximum(near, 1.0), 0.6, 1.5)
    from scipy.ndimage import gaussian_filter1d
    gain = gaussian_filter1d(gain, 6)
    tile = tile * gain[:, None, None]
    from scipy.ndimage import gaussian_filter
    tile = gaussian_filter(tile, (1.0, 7.0, 0))                # rozmyj szwy lustrzanych pasów
    xs = np.linspace(0, 1, tile.shape[1]) if x0 != 0 else np.linspace(1, 0, tile.shape[1])
    tile = tile * (1.0 - 0.38 * xs ** 1.5)[None, :, None]      # ciemniejsze rogi: stoły zastąpiła ciemna podłoga
    m = np.ones((H, x1 - x0))
    f = feather
    if x0 == 0:
        m[:, -f:] = np.linspace(1, 0, f)
    else:
        m[:, :f] = np.linspace(0, 1, f)
    m[:f, :] *= np.linspace(0, 1, f)[:, None]
    a[y0:y1, x0:x1] = (a[y0:y1, x0:x1] * (1 - m[..., None]) + tile * m[..., None]).clip(0, 255)


def synth_floor(a, x0, x1, y0, y1, ref_box, vp=(836.0, 250.0), feather=26, seed=5, dark=0.85, pw=0.10):
    """Podłoga z deskami w poprawnej perspektywie (punkt zbiegu vp): zastępuje zasłonięte stołami rogi."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(float)
    dy = yy - vp[1]
    u = (xx - vp[0]) / dy                      # stałe wzdłuż promienia od punktu zbiegu = jedna deska
    pid = np.floor(u / pw)
    fr = (u / pw) - pid
    ry0, ry1, rx0, rx1 = ref_box
    ref = a[ry0:ry1, rx0:rx1].reshape(-1, 3).mean(0)
    base = np.zeros(xx.shape + (3,))
    shade = (rng.random(int(pid.max() - pid.min()) + 2) - 0.5) * 0.34
    sh = shade[(pid - pid.min()).astype(int)]
    grain = (rng.random(xx.shape) - 0.5) * 0.10
    # poprzeczne łączenia desek (odstępy rosną ku dołowi)
    row = np.floor(np.log(np.maximum(dy, 1.0)) * 7.0 + pid * 1.7)
    joint = (np.abs((np.log(np.maximum(dy, 1.0)) * 7.0 + pid * 1.7) - np.round(np.log(np.maximum(dy, 1.0)) * 7.0 + pid * 1.7)) < 0.035)
    k = dark * (1 + sh + grain)
    k = np.where(fr < 0.045, k * 0.45, k)
    k = np.where(joint, k * 0.6, k)
    glow = np.clip(1.0 - (np.hypot(xx - 150.0, (yy - 700.0) * 1.3) / 700.0), 0, 1) * 0.35
    out = ref[None, None, :] * (k + glow)[..., None]
    m = np.ones(xx.shape)
    f = feather
    if x0 == 0:
        m[:, -f:] = np.linspace(1, 0, f)
    else:
        m[:, :f] = np.linspace(0, 1, f)
    m[:f] *= np.linspace(0, 1, f)[:, None]
    a[y0:y1, x0:x1] = a[y0:y1, x0:x1] * (1 - m[..., None]) + out * m[..., None]

def crest_image(size, margin=0.0):
    im = Image.open(CREST).convert("RGBA")
    bb = im.getbbox()
    im = im.crop(bb)
    k = size / max(im.size)
    return im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)

def background_from_reference(W=960, H=540):
    ref = Image.open(REF).convert("RGB")
    sx = ref.width / W
    a = np.array(ref).astype(float)          # pracujemy w pełnej rozdzielczości, potem skalujemy
    # 1. stoły, kufel i świeca: dolne rogi zastępujemy podłogą (pasy z sąsiedztwa)
    synth_floor(a, 0, 345, 690, 941, (700, 760, 350, 440), seed=5, dark=0.88)
    a[606:642, 1486:1536] = a[606:642, 1430:1480]            # resztka świecy ze stołu
    synth_floor(a, 1250, 1672, 630, 941, (655, 700, 1000, 1240), seed=9, dark=0.80)
    # 2. tarcza z gryfem nad kominkiem -> kamień (pas z lewej strony komina)
    patch_stone = a[110:305, 150:232].copy()
    tile = mirror_tile(patch_stone, 150)
    m = np.zeros((195, 150)); m[:] = 1
    for k in range(14):
        m[:, k] = k / 14.0; m[:, 149 - k] = k / 14.0
        m[k, :] *= k / 14.0; m[194 - k, :] *= k / 14.0
    a[110:305, 226:376] = a[110:305, 226:376] * (1 - m[..., None]) + tile * m[..., None]
    img = Image.fromarray(a.clip(0, 255).astype(np.uint8)).convert("RGBA")
    # 3. herb Carroburga nad kominkiem
    c = crest_image(200)
    img.alpha_composite(c, (int(295 - c.width / 2), int(205 - c.height / 2)))
    # 4. sztandary: złota wieża -> herb Carroburga
    for bx in (1022, 1117):
        # zamaluj wieżę kolorem sztandaru i wstaw herb
        arr = np.array(img)
        box = arr[238:312, bx - 22:bx + 22]
        gold = (box[..., 0] > 140) & (box[..., 1] > 110) & (box[..., 2] < 110)
        base = arr[318:332, bx - 18:bx + 18, :3].reshape(-1, 3).mean(0)
        box[gold, :3] = base
        img = Image.fromarray(arr)
        c = crest_image(66)
        img.alpha_composite(c, (int(bx - c.width / 2), int(276 - c.height / 2)))
    return img.convert("RGB").resize((W, H), Image.LANCZOS)

def door_open_new(w=88, h=152):
    return door_open(w, h)

def crest_variants():
    """Herb Carroburga: wersje do menu (duża), HUD/rekwizytów (mała) w palecie gry."""
    return {
        "crest_menu": crest_image(300),
        "crest_small": crest_image(96),
    }

# ------------------------------------------------------------------------------------------ wyjście
def quantize(im, P, plab):
    a = np.array(im.convert("RGBA"))
    idx = np.zeros(a.shape[:2], int)
    for y0 in range(0, a.shape[0], 24):                      # kawałkami: pełny obraz naraz zjada pamięć
        blk = mp.srgb2lab(a[y0:y0 + 24, :, :3].astype(float))
        idx[y0:y0 + 24] = ((blk[..., None, :] - plab[None, None]) ** 2).sum(-1).argmin(-1)
    out = np.zeros_like(a)
    out[..., :3] = P[idx]
    out[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
    out[out[..., 3] == 0, :3] = 0
    return Image.fromarray(out, "RGBA")

def quantize_dither(im, P, plab, strength=9.0):
    """Jak quantize, ale z ditheringiem Bayera 4x4 (obraz fotograficzny bez pasów)."""
    a = np.array(im.convert("RGB")).astype(float)
    h, w = a.shape[:2]
    bay = (np.tile(bayer(4, 4), (h // 4 + 1, w // 4 + 1))[:h, :w, None] - 0.5) * strength * 2
    a = np.clip(a + bay, 0, 255)
    idx = np.zeros((h, w), int)
    for y0 in range(0, h, 24):
        blk = mp.srgb2lab(a[y0:y0 + 24])
        idx[y0:y0 + 24] = ((blk[..., None, :] - plab[None, None]) ** 2).sum(-1).argmin(-1)
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = P[idx]
    out[..., 3] = 255
    return Image.fromarray(out, "RGBA")

def build():
    sheets = {
        "tavern_bg": background_from_reference() if os.path.exists(REF) else background(),
        "balcony_rail": balcony_rail(),
        "door_open": door_open_new(),
        "borubar": borubar(84, 104),
        "borubar_dizzy": borubar(84, 104, dizzy=True),
        "tankard_big": tankard(76, 56, big=True),
        "innkeeper": innkeeper(84, 100),
        "mug": tankard(24, 28, big=False),
        "mug_gold": tankard(24, 28, big=False, gold=True),
        "splash": splash(40, 16),
        "stars": stars(),
        "guest_1": person(54, 92, "tunic_green", hat="cap", seed=1),
        "guest_2": person(54, 92, "tunic_red", hat="scarf", skin=3, belly=0.9, seed=2),
        "guest_3": person(58, 80, "tunic_brown", pants="tunic_grey", hair="hair_ginger", hat=None, beard=True, dwarf=True, seed=3, mug=True),
        "guest_4": person(54, 94, "tunic_grey", pants="tunic_brown", hat="helmet", seed=4, belly=1.05),
        "guest_5": person(56, 92, "blue", hair="hair_grey", hat="hood", beard=True, seed=5),
        "guest_6": person(54, 90, "tunic_brown", hair="hair_dark", hat="bandana", skin=1, seed=6, mug=True),
    }
    return sheets

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default=None)
    a = ap.parse_args()
    P = np.array(Image.open(os.path.join(HERE, "assets/palette/hufduhof_256.png")).convert("RGB")).reshape(-1, 3)
    plab = mp.srgb2lab(P)
    os.makedirs(OUT, exist_ok=True)
    res = {}
    for name, im in build().items():
        q = quantize(im, P, plab) if name != "tavern_bg" else quantize_dither(im, P, plab)
        q.save(os.path.join(OUT, name + ".png"))
        res[name] = q
        print(f"assets/minigame/{name}.png {q.width}x{q.height}")
    cdir = os.path.join(HERE, "assets/ui/crest")
    os.makedirs(cdir, exist_ok=True)
    for name, im in crest_variants().items():
        q = quantize(im, P, plab)
        q.save(os.path.join(cdir, name + ".png"))
        print(f"assets/ui/crest/{name}.png {q.width}x{q.height}")
    if a.preview:
        os.makedirs(a.preview, exist_ok=True)
        res["tavern_bg"].convert("RGB").save(os.path.join(a.preview, "tavern_bg.png"))
        names = [n for n in res if n != "tavern_bg"]
        W = 1400
        sheet = Image.new("RGBA", (W, 900), (60, 40, 30, 255))
        x, y, rowh = 8, 8, 0
        for n in names:
            q = res[n]; sc = 2 if q.width < 120 else 1
            im = q.resize((q.width * sc, q.height * sc), Image.NEAREST)
            if x + im.width > W:
                x = 8; y += rowh + 10; rowh = 0
            sheet.alpha_composite(im, (x, y)); x += im.width + 12; rowh = max(rowh, im.height)
        sheet.convert("RGB").save(os.path.join(a.preview, "tavern_sprites.png"))

if __name__ == "__main__":
    main()
