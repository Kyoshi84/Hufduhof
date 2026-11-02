#!/usr/bin/env python3
"""Droga etapu 1 rysowana od zera w pixel-arcie 1:1 (1 px = 1 px gry, bez skalowania z panoramy).

Kolory wzięte z dębów (oliwkowa zieleń), domów i pni (ciepłe brązy) i pola z far2 (złota trawa),
więc droga pasuje do rekwizytów. Wynik:
  assets/stages/stage1_road/ground.png            podłoże 1024x320 (powtarzane poziomo, szew niewidoczny)
  assets/stages/stage1_road/decals/*.png          nakładki terenu: rozdroża, skarpy, murek, bruk, głazy, kałuże
  assets/stages/stage1_road/decals.json           co, gdzie i jak często gra rysuje na drodze

    python3 tools/build_road.py                 # przebudowa
    python3 tools/build_road.py --preview DIR   # + podgląd 1280x720 z drzewami i płotem

Układ wierszy (od horyzontu w dół, px): 0..BACK_EDGE pobocze tylne (tu stoją drzewa i płoty),
BACK_EDGE..FRONT_EDGE droga (pas walki 30..191 px), FRONT_EDGE..320 pobocze przednie.
"""
import argparse, json, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_props as BP

HERE = BP.HERE
OUT = os.path.join(HERE, "assets/stages/stage1_road")
W, H = 1024, 320
BACK_EDGE, FRONT_EDGE = 26, 202
OUTLINE = (14, 9, 8)

# rampy od najciemniejszej do najjaśniejszej
GRASS = [(16, 24, 12), (30, 39, 21), (43, 54, 29), (57, 69, 38), (70, 84, 47), (84, 100, 55), (97, 115, 64), (111, 130, 73)]
DRY = [(52, 40, 18), (74, 58, 24), (98, 80, 39), (131, 102, 30), (169, 147, 83)]
EARTH = [(26, 18, 11), (39, 28, 17), (52, 38, 24), (65, 48, 30), (80, 60, 38), (98, 74, 48), (116, 89, 60), (134, 106, 72), (155, 126, 88)]
FACE = [(31, 22, 14), (52, 38, 24), (74, 56, 34), (98, 76, 46), (122, 96, 60), (146, 118, 76)]   # ściana skarpy (światło z góry)
SOIL = [(24, 15, 10), (40, 26, 16), (58, 38, 24), (78, 54, 34), (98, 70, 44)]       # odsłonięta ziemia skarpy
STONE = [(24, 21, 19), (44, 40, 36), (66, 61, 55), (90, 84, 75), (115, 108, 96), (142, 134, 119), (168, 160, 142)]
WATER = [(26, 32, 44), (43, 52, 66), (64, 76, 92), (92, 106, 122), (150, 162, 172)]
FLOWER = [(169, 147, 83), (196, 193, 186), (150, 80, 70)]

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], float) / 16.0

# ---------------------------------------------------------------- szum (powtarzalny w poziomie)
def vnoise(h, w, cy, cx, seed, wrap=True):
    """Szum wartości: siatka co (cy, cx) px, interpolacja smoothstep; wrap=True -> szew poziomy niewidoczny."""
    rng = np.random.default_rng(seed)
    gw = max(1, int(round(w / cx))); gh = int(np.ceil(h / cy)) + 2
    g = rng.random((gh, gw + 1))
    if wrap:
        g[:, -1] = g[:, 0]
    ys = np.arange(h) / cy; xs = np.arange(w) / (w / gw)
    y0 = ys.astype(int); x0 = xs.astype(int)
    fy = ys - y0; fx = xs - x0
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]; b = g[y0][:, x0 + 1]; c = g[y0 + 1][:, x0]; d = g[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy[:, None]) + (c * (1 - fx) + d * fx) * fy[:, None]

def fbm(h, w, seed, scales=((24, 48, 0.55), (8, 16, 0.3), (3, 4, 0.15)), wrap=True):
    out = np.zeros((h, w))
    for k, (cy, cx, amp) in enumerate(scales):
        out += vnoise(h, w, cy, cx, seed + k * 17, wrap) * amp
    return out

def ramp_map(v, ramp, dither=0.0, ox=0, oy=0):
    """v 0..1 -> kolory rampy; opcjonalny dithering Bayera tylko na granicach stopni."""
    h, w = v.shape
    n = len(ramp)
    t = np.clip(v, 0, 0.999) * n
    if dither:
        by = np.tile(BAYER, (h // 4 + 2, w // 4 + 2))[oy % 4:oy % 4 + h, ox % 4:ox % 4 + w]
        t = t + (by - 0.5) * dither
    idx = np.clip(t.astype(int), 0, n - 1)
    return np.array(ramp, float)[idx]

# ---------------------------------------------------------------- płótno RGBA
class Layer:
    def __init__(self, h, w, wrap=True):
        self.h, self.w, self.wrap = h, w, wrap
        self.rgb = np.zeros((h, w, 3)); self.a = np.zeros((h, w), bool)

    def put(self, y, x, col):
        if 0 <= y < self.h:
            if self.wrap:
                x %= self.w
            if 0 <= x < self.w:
                self.rgb[y, x] = col; self.a[y, x] = True

    def ellipse_mask(self, cx, cy, rx, ry):
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        dx = xx - cx
        if self.wrap:
            dx = (dx + self.w / 2) % self.w - self.w / 2
        return (dx / max(rx, 0.5)) ** 2 + ((yy - cy) / max(ry, 0.5)) ** 2 <= 1.0

# ---------------------------------------------------------------- elementy rysunku
def blade(L, x, y, hgt, ramp, rng, lean=0):
    """Źdźbło trawy: od ciemnej podstawy do jasnego czubka."""
    for k in range(hgt):
        t = k / max(hgt - 1, 1)
        xi = int(round(x + lean * t * t))
        ci = min(len(ramp) - 1, int(1 + t * (len(ramp) - 2) + rng.random() * 0.9))
        L.put(y - k, xi, ramp[ci])

def tuft(L, x, y, size, rng, ramp=GRASS, dry=0.0):
    n = int(3 + size * 1.6)
    for i in range(n):
        r = DRY if rng.random() < dry else ramp
        bx = x + rng.integers(-size, size + 1)
        hg = int(2 + size * (0.6 + rng.random() * 0.9))
        blade(L, bx, y + rng.integers(-1, 2), hg, r, rng, lean=rng.uniform(-1.6, 1.6))

def pebble(L, cx, cy, rx, ry, rng, ramp=STONE, outline=True):
    """Kamień: kontur, cieniowanie światłem z lewej-góry, połysk."""
    rx = max(rx, 1.0); ry = max(ry, 0.8)
    x0, x1 = int(cx - rx - 2), int(cx + rx + 3)
    y0, y1 = int(cy - ry - 2), int(cy + ry + 3)
    base = rng.uniform(0.35, 0.7)
    for y in range(y0, y1):
        for x in range(x0, x1):
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d <= 1.0:
                lx = (x - cx) / rx; ly = (y - cy) / ry
                v = base + (-lx * 0.25 - ly * 0.45) + (rng.random() - 0.5) * 0.12
                if d > 0.65 and ly > 0:
                    v -= 0.25
                ci = int(np.clip(v, 0, 0.999) * len(ramp))
                L.put(y, x, ramp[ci])
            elif outline and d <= (1 + 1.0 / max(min(rx, ry), 1)) ** 2 and y >= cy - ry * 0.2:
                L.put(y, x, OUTLINE)
    if rx >= 2 and ry >= 1.5:
        L.put(int(cy - ry * 0.45), int(cx - rx * 0.35), ramp[-1])

def contact_shadow(L, cx, cy, rx, col=EARTH[1]):
    for x in range(int(cx - rx), int(cx + rx + 1)):
        L.put(int(cy + 1), x, col)

# ---------------------------------------------------------------- tekstury
def persp(y):
    """0 = daleko (tylna krawędź drogi), 1 = blisko (przednia)."""
    return float(np.clip((y - BACK_EDGE) / (FRONT_EDGE - BACK_EDGE), 0, 1))

def earth_fill(L, mask, seed, light=0.0):
    """Ubita ziemia: duże plamy (wilgotne / zakurzone), grudki z jasną górą i cieniem, ciemne drobiny.
    Rysuje tylko tam, gdzie mask=True. Wielkość grudek rośnie z bliskością (perspektywa)."""
    rng = np.random.default_rng(seed)
    h, w = mask.shape
    yy = np.arange(h)[:, None] * np.ones((1, w))
    pp = np.clip((yy - BACK_EDGE) / (FRONT_EDGE - BACK_EDGE), 0, 1)
    big = fbm(h, w, seed, ((22, 90, 0.55), (9, 34, 0.30), (3, 8, 0.15)), wrap=L.wrap)
    dust = vnoise(h, w, 30, 160, seed + 5, wrap=L.wrap)
    mid = 1 - np.abs(pp - 0.45) * 2
    v = 0.20 + big * 0.50 + mid * 0.12 + (dust - 0.5) * 0.24 - (1 - pp) * 0.06 + light
    col = ramp_map(v, EARTH[1:], dither=0.9)
    L.rgb[mask] = col[mask]; L.a[mask] = True
    # grudki
    n = int(mask.sum() * 0.045)
    ys, xs = np.where(mask)
    idx = rng.integers(0, len(ys), n)
    for k in idx:
        y, x = ys[k], xs[k]
        p = persp(y)
        lw = 1 + int(rng.random() * (1 + p * 3))
        base = int(np.clip(v[y, x], 0, 0.999) * (len(EARTH) - 1)) + 1
        hi = EARTH[min(len(EARTH) - 1, base + 1 + (rng.random() < 0.3))]
        lo = EARTH[max(0, base - 2)]
        for dx in range(lw):
            if mask[y, (x + dx) % w if L.wrap else min(x + dx, w - 1)]:
                L.put(y, x + dx, hi)
                L.put(y + 1, x + dx, lo)
        if lw > 2 and rng.random() < 0.5:
            L.put(y - 1, x + lw // 2, hi)
    # ciemne drobiny i kamyczki
    idx = rng.integers(0, len(ys), int(mask.sum() * 0.012))
    for k in idx:
        y, x = ys[k], xs[k]
        if rng.random() < 0.55:
            L.put(y, x, EARTH[1])
        else:
            L.put(y, x, STONE[4 + rng.integers(0, 3)]); L.put(y + 1, x, EARTH[0])
    return v

def grass_fill(L, y0, y1, x0, x1, seed, back, dry=0.25, density=0.32):
    """Trawa malowana źdźbłami: ciemny spód, gęste źdźbła z jasnymi czubkami, plamy suchej trawy."""
    rng = np.random.default_rng(seed)
    hh, w = y1 - y0, x1 - x0
    n = fbm(hh, w, seed, ((8, 40, 0.6), (3, 9, 0.4)), wrap=L.wrap)
    v = 0.12 + n * 0.30
    col = ramp_map(v, GRASS, dither=1.0, ox=x0, oy=y0)
    dryn = vnoise(hh, w, 7, 44, seed + 1, wrap=L.wrap)
    drym = dryn > (1 - dry)
    col[drym] = ramp_map(v + 0.05, DRY[:3], dither=1.0)[drym]
    L.rgb[y0:y1, x0:x1] = col; L.a[y0:y1, x0:x1] = True
    nb = int(w * hh * density)
    for _ in range(nb):
        x = x0 + rng.integers(0, w)
        y = y0 + rng.integers(0, hh + 2)
        t = (y - y0) / max(hh, 1)
        if back:
            hg = 1 + int(rng.random() * (2 + t * 3))
        else:
            hg = 2 + int(rng.random() * (3 + min(t, 1) * 6))
        isdry = dryn[min(max(y - y0, 0), hh - 1), x - x0] > (1 - dry) or rng.random() < 0.06
        ramp = DRY if isdry else GRASS[1:]
        blade(L, x, min(y, y1 - 1), hg, ramp, rng, lean=rng.uniform(-1.4, 1.4))
    # kwiatki
    for _ in range(int(w * hh / 700)):
        x = x0 + rng.integers(0, w); y = y0 + rng.integers(2, max(hh - 1, 3))
        L.put(y, x, FLOWER[rng.integers(0, len(FLOWER))]); L.put(y + 1, x, GRASS[1])

# ---------------------------------------------------------------- podłoże
def road_base(rng):
    """Zwraca Layer z całym kafelkiem podłoża."""
    L = Layer(H, W, wrap=True)
    road = np.zeros((H, W), bool); road[BACK_EDGE - 2:FRONT_EDGE + 2] = True
    v = earth_fill(L, road, 11)

    # --- koleiny: dwie pary szerokich rowków; łagodnie wygięte, głębokość zmienna, zanikają ditheringiem
    by = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    for (yc, gap, th, ph, amp, sd) in ((70, 10, 2, 0.0, 4.0, 21), (134, 17, 4, 1.3, 6.0, 23)):
        wob = vnoise(1, W, 1, 170, sd)[0]
        depth = vnoise(1, W, 1, 110, sd + 1)[0]
        for x in range(W):
            d = np.clip((depth[x] - 0.12) / 0.5, 0, 1)
            off = np.sin(2 * np.pi * x / W * 2 + ph) * amp + (wob[x] - 0.5) * 6
            for yoff in (0, gap):
                y0 = int(round(yc + yoff + off))
                for t in range(-1, th + 1):
                    y = y0 + t
                    if by[y % H, x] >= d:            # słaba koleina = rzadszy wzór
                        continue
                    if t == -1:
                        c = EARTH[2]                  # górna ścianka w cieniu
                    elif t == th:
                        c = EARTH[7]                  # dolna, oświetlona
                    elif t == 0:
                        c = EARTH[0] if d > 0.7 else EARTH[1]
                    else:
                        c = EARTH[1] if t < th - 1 else EARTH[3]
                    L.put(y, x, c)
            if d > 0.6 and rng.random() < 0.14:      # grzbiet między koleinami: trochę trawy
                yg = int(round(yc + gap * 0.5 + off)) + 2
                blade(L, x, yg, int(1 + gap * 0.18 + rng.random() * 2), GRASS[1:6], rng, lean=rng.uniform(-1, 1))
            if d > 0.92:                              # woda na dnie najgłębszych kolein
                L.put(int(round(yc + gap + off)) + 1, x, WATER[2] if x % 7 else WATER[3])

    # --- ślady kopyt
    for _ in range(90):
        x = rng.integers(0, W); y = rng.integers(BACK_EDGE + 8, FRONT_EDGE - 8)
        s = 1 + int(persp(y) * 2)
        for dx in range(-s, s + 1):
            L.put(y, x + dx, EARTH[1])
        L.put(y - 1, x - s, EARTH[1]); L.put(y - 1, x + s, EARTH[1])
        L.put(y + 1, x, EARTH[7])

    # --- kamyki, większe bliżej
    for _ in range(150):
        x = rng.integers(0, W); y = rng.integers(BACK_EDGE + 4, FRONT_EDGE - 3)
        r = 0.9 + persp(y) * 2.6 * rng.random() ** 1.5
        pebble(L, x, y, r * 1.3, r * 0.8, rng)
    for _ in range(12):
        x = rng.integers(0, W); y = rng.integers(BACK_EDGE + 30, FRONT_EDGE - 10)
        pp = persp(y)
        pebble(L, x, y, 2.5 + pp * 4, 1.6 + pp * 2.4, rng)
    # kępy trawy na środku drogi
    for _ in range(26):
        x = rng.integers(0, W); y = rng.integers(BACK_EDGE + 12, FRONT_EDGE - 6)
        tuft(L, x, y, 1 + int(persp(y) * 2), rng, dry=0.5)

    for (x, y, w) in ((300, 74, 26), (790, 140, 34)):
        puddle(L, x, y, w, max(3, w // 7), rng)

    grass_band(L, 0, BACK_EDGE, rng, back=True)
    grass_band(L, FRONT_EDGE, H, rng, back=False)
    return L

def grass_band(L, y0, y1, rng, back, x_range=None, dry=0.28):
    """Pobocze z poszarpaną krawędzią przy drodze, kępami wchodzącymi na drogę i kamieniami w trawie."""
    xs0, xs1 = x_range if x_range else (0, L.w)
    w = xs1 - xs0
    grass_fill(L, y0, y1, xs0, xs1, 31 if back else 41, back, dry=dry, density=0.30 if back else 0.22)
    edge = BACK_EDGE if back else FRONT_EDGE
    for x in range(xs0, xs1):
        j = rng.integers(0, 2)
        if back:
            L.put(edge - 1 + j, x, GRASS[1])
            L.put(edge + j, x, GRASS[0])
            L.put(edge + 1 + j, x, EARTH[1])          # cień trawy na drodze
        else:
            L.put(edge - 2 + j, x, EARTH[7])          # jasna, ubita krawędź drogi
            L.put(edge - 1 + j, x, EARTH[5])
            L.put(edge + j, x, GRASS[0])
    for _ in range(int(w / 7)):
        x = rng.integers(xs0, xs1)
        if back:
            tuft(L, x, edge + rng.integers(1, 4), rng.integers(1, 3), rng, dry=dry)
        else:
            tuft(L, x, edge + rng.integers(1, 6), rng.integers(2, 4), rng, dry=dry)
    for _ in range(int(w / 60)):
        x = rng.integers(xs0, xs1); y = rng.integers(y0 + 5, y1 - 2)
        pp = (y - y0) / max(y1 - y0, 1)
        r = (1.4 + pp * 1.4) if back else (2.5 + pp * 2.5)
        pebble(L, x, y, r * 1.2, r * 0.7, rng)
        for k in range(4):
            blade(L, x + rng.integers(-int(r) - 1, int(r) + 2), y + int(r * 0.6) + 1, 2 + rng.integers(0, 3), GRASS[1:], rng)

def puddle(L, cx, cy, w, h, rng):
    """Kałuża z odbiciem nieba: ciemny brzeg, jaśniejszy środek, refleks."""
    m = L.ellipse_mask(cx, cy, w / 2, h / 2)
    inner = L.ellipse_mask(cx - 1, cy - 0.5, w / 2 - 2, h / 2 - 1)
    yy, xx = np.where(m)
    for y, x in zip(yy, xx):
        if inner[y, x]:
            t = (y - (cy - h / 2)) / max(h, 1)
            c = WATER[2] if t < 0.5 else WATER[3]
            if rng.random() < 0.05:
                c = WATER[1]
        else:
            c = WATER[0] if y > cy else EARTH[1]
        L.put(y, x, c)
    for k in range(int(w * 0.35)):
        L.put(int(cy - h * 0.15), int(cx - w * 0.25 + k), WATER[4] if k % 5 else WATER[3])
    for x in range(int(cx - w / 2), int(cx + w / 2) + 1):          # wilgotny brzeg
        L.put(int(cy + h / 2) + 1, x, EARTH[6])

# ---------------------------------------------------------------- nakładki
def decal_layer(w, h):
    return Layer(h, w, wrap=False)

def finish_decal(L, fade_x=0):
    """Obcięcie do treści (bez przesuwania w pionie: y nakładki = wiersz pod horyzontem)."""
    a = L.a.copy()
    rgb = np.clip(L.rgb, 0, 255).astype(np.uint8)
    out = np.dstack([rgb, np.where(a, 255, 0).astype(np.uint8)])
    return Image.fromarray(out, "RGBA")

def crossroad(seed, down):
    """Rozdroże: boczna droga przez tylne pobocze ku horyzontowi (+ opcjonalnie w dół przez przednie)."""
    rng = np.random.default_rng(seed)
    w = 250
    L = decal_layer(w, H)
    cx = w / 2
    lean = rng.uniform(-34, 34)              # w którą stronę droga odbija w głąb
    MID = (BACK_EDGE + FRONT_EDGE) / 2
    def half(y):                             # półszerokość ścieżki w wierszu y (perspektywa)
        if y < MID:
            return 13 + min(y, BACK_EDGE) / BACK_EDGE * 47
        return 60 + max(0, y - FRONT_EDGE) * 0.6
    def center(y):
        if y < MID:
            return cx + lean * (1 - min(y, BACK_EDGE) / BACK_EDGE) ** 1.5
        return cx - lean * 0.7 * max(0, y - FRONT_EDGE) / (H - FRONT_EDGE)
    rows = list(range(0, BACK_EDGE + 3)) + (list(range(FRONT_EDGE - 2, H)) if down else [])
    mask = np.zeros((H, w), bool)
    jit = vnoise(H, 2, 2, 1, seed + 3, wrap=False)
    for y in rows:
        c = center(y); hw = half(y)
        l = int(c - hw + (jit[y, 0] - 0.5) * 4); r = int(c + hw + (jit[y, 1] - 0.5) * 4)
        mask[y, max(0, l):min(w, r + 1)] = True
    earth_fill(L, mask, seed, light=0.02)
    # koleiny bocznej drogi + trawa pośrodku
    for y in rows:
        c = center(y); hw = half(y)
        for s in (-0.42, 0.42):
            xr = int(round(c + s * hw))
            L.put(y, xr, EARTH[1]); L.put(y, xr + 1, EARTH[6])
        if rng.random() < 0.35:
            blade(L, int(c + rng.uniform(-2, 2)), y, 1 + int(hw / 22), GRASS[1:6], rng, lean=rng.uniform(-1, 1))
    # ciemna linia trawy przy brzegach i źdźbła nachodzące na ścieżkę
    for y in rows:
        row = np.where(mask[y])[0]
        if len(row) == 0:
            continue
        for x, side in ((row[0] - 1, -1), (row[-1] + 1, 1)):
            if 0 <= x < w:
                L.put(y, x, GRASS[0])
            if rng.random() < 0.55:
                hg = 2 + int(rng.random() * (3 + (y > MID) * 4))
                blade(L, x - side * rng.integers(0, 3), y, hg, GRASS[1:], rng, lean=-side * 1.3)
    # łagodne wejście na drogę (dithered przejście)
    by = np.tile(BAYER, (H // 4 + 1, w // 4 + 1))[:H, :w]
    for y in range(BACK_EDGE - 1, BACK_EDGE + 3):
        f = (y - BACK_EDGE + 1) / 4
        L.a[y] &= ~(by[y] < f)
    if down:
        for y in range(FRONT_EDGE - 2, FRONT_EDGE + 2):
            f = (FRONT_EDGE + 2 - y) / 4
            L.a[y] &= ~(by[y] < f)
    for _ in range(26 if down else 10):
        y = int(rng.choice(rows)); c = center(y); hw = half(y)
        x = c + rng.uniform(-hw * 0.8, hw * 0.8)
        r = 0.9 + (3.0 if y > MID else min(1.0, y / BACK_EDGE) * 1.2) * rng.random()
        pebble(L, x, y, r * 1.3, r * 0.8, rng)
    return finish_decal(L)

def bank_back(seed, stone_wall=False):
    """Skarpa za drogą: podniesione pobocze z odsłoniętą ziemią, warstwami i korzeniami (albo kamienny murek)."""
    rng = np.random.default_rng(seed)
    w = 320
    L = decal_layer(w, BACK_EDGE + 6)
    prof = vnoise(1, w, 1, 56, seed, wrap=False)[0]
    xs = np.arange(w)
    taper = np.clip(np.minimum(xs, w - 1 - xs) / 56.0, 0, 1)
    taper = taper * taper * (3 - 2 * taper)
    wall_h = (17 + prof * 8) * taper                     # wysokość ściany skarpy (px)
    foot = BACK_EDGE + 2                                 # stopa skarpy = krawędź drogi
    strata = vnoise(BACK_EDGE + 6, w, 2, 24, seed + 1, wrap=False)
    grain = vnoise(BACK_EDGE + 6, w, 1, 1, seed + 2, wrap=False)
    tops = np.round(foot - wall_h).astype(int)
    # korona skarpy: trawa od horyzontu do krawędzi
    crown = np.zeros((BACK_EDGE + 6, w), bool)
    for x in range(w):
        if wall_h[x] >= 1:
            crown[:tops[x], x] = True
    m = crown
    sub = Layer(BACK_EDGE + 6, w, wrap=False)
    grass_fill(sub, 0, BACK_EDGE + 6, 0, w, seed + 9, True, dry=0.3, density=0.34)
    L.rgb[m] = sub.rgb[m]; L.a[m] = True
    for x in range(w):
        if wall_h[x] < 1:
            continue
        gb = tops[x]
        for y in range(gb, foot + 1):
            t = (y - gb) / max(foot - gb, 1)
            if stone_wall:
                L.put(y, x, SOIL[0])
                continue
            band = (strata[y, x] - 0.5) * 0.5 + (grain[y, x] - 0.5) * 0.22
            v = 0.86 - t * 0.62 + band
            L.put(y, x, FACE[int(np.clip(v, 0, 0.999) * len(FACE))])
        L.put(gb, x, GRASS[6] if rng.random() < 0.6 else GRASS[5])     # oświetlona krawędź korony
        L.put(gb - 1, x, GRASS[4])
        L.put(gb + 1, x, GRASS[1])                                     # trawa przewieszona nad ścianą
        L.put(foot + 1, x, EARTH[0]); L.put(foot + 2, x, EARTH[1]); L.put(foot + 3, x, EARTH[2])   # cień na drodze
    if stone_wall:
        x = 3.0
        while x < w - 3:
            hcol = wall_h[int(x)]
            if hcol < 4:
                x += 3; continue
            y = foot - 0.5
            top = foot - hcol
            k = 0
            while y - 1.5 > top:
                rh = rng.uniform(1.8, 2.8); rw = rng.uniform(3.2, 5.2)
                pebble(L, x + (k % 2) * 2.2 + rng.uniform(-0.6, 0.6), y - rh, rw, rh, rng)
                y -= rh * 2 + 0.4; k += 1
            x += rng.uniform(6.2, 8.8)
        for x in range(w):                                             # mech i trawa na koronie murku
            if wall_h[x] > 4 and rng.random() < 0.4:
                L.put(tops[x] + 1, x, GRASS[3])
    else:
        for _ in range(int(w / 10)):
            x = rng.integers(12, w - 12)
            if wall_h[x] < 6:
                continue
            y = tops[x] + rng.uniform(3, wall_h[x] - 1.5)
            if rng.random() < 0.6:
                pebble(L, x, y, rng.uniform(1.6, 3.4), rng.uniform(1.1, 2.1), rng)
            else:                                                      # korzeń
                ln = rng.integers(5, 12); d = rng.choice([-1, 1]); yy0 = tops[x] + 1
                for k in range(ln):
                    L.put(int(yy0 + k * 0.55), int(x + d * k), (44, 30, 20))
                    L.put(int(yy0 + k * 0.55) - 1, int(x + d * k), (98, 73, 50))
    for x in range(0, w):
        if wall_h[x] >= 3 and rng.random() < 0.18:
            for k in range(rng.integers(1, 5)):                       # zwisające źdźbła
                L.put(tops[x] + 1 + k, x, GRASS[2 + (k == 0)])
    for x in range(0, w):                                             # kępy u stopy skarpy
        if wall_h[x] >= 2 and rng.random() < 0.05:
            tuft(L, x, foot + 1, rng.integers(1, 3), rng, dry=0.3)
    return finish_decal(L)

def bank_front(seed):
    """Uskok przy przedniej krawędzi drogi: droga wyżej, pobocze niżej (odsłonięta ściana z kamieniami)."""
    rng = np.random.default_rng(seed)
    w = 300
    y0 = FRONT_EDGE - 3
    hh = 40
    L = decal_layer(w, y0 + hh)
    prof = vnoise(1, w, 1, 60, seed, wrap=False)[0]
    xs = np.arange(w)
    taper = np.clip(np.minimum(xs, w - 1 - xs) / 50.0, 0, 1)
    taper = taper * taper * (3 - 2 * taper)
    drop = (15 + prof * 9) * taper
    sn = fbm(y0 + hh, w, seed + 2, ((3, 14, 0.6), (1, 3, 0.4)), wrap=False)
    for x in range(w):
        if drop[x] < 1:
            continue
        top = FRONT_EDGE - 1
        bot = int(round(top + drop[x]))
        L.put(top - 1, x, EARTH[7])                        # jasna krawędź uskoku
        L.put(top, x, EARTH[6])
        for y in range(top + 1, bot + 1):
            t = (y - top) / max(bot - top, 1)
            v = 0.80 - t * 0.62 + (sn[y, x] - 0.5) * 0.45
            L.put(y, x, FACE[int(np.clip(v, 0, 0.999) * len(FACE))])
        L.put(bot + 1, x, GRASS[0]); L.put(bot + 2, x, GRASS[1])
        for y in range(bot + 3, min(bot + 3 + int(drop[x] * 0.4), y0 + hh)):
            L.put(y, x, GRASS[1])
    for _ in range(int(w / 12)):
        x = rng.integers(8, w - 8)
        if drop[x] < 5:
            continue
        y = FRONT_EDGE + rng.uniform(2, drop[x] - 1)
        pebble(L, x, y, rng.uniform(1.8, 3.8), rng.uniform(1.2, 2.4), rng)
    for x in range(0, w, 3):
        if drop[x] > 3 and rng.random() < 0.45:
            blade(L, x, int(FRONT_EDGE + drop[x] + 3), 3 + rng.integers(0, 5), GRASS, rng, lean=rng.uniform(-1.5, 1.5))
    return finish_decal(L)

def cobble(seed, w=200, hgt=90):
    """Resztki starego bruku: zwarte kamienie w rzędach (spoiny z ziemi), ubytki, brzegi zapadnięte w ziemię."""
    rng = np.random.default_rng(seed)
    y_top = 58
    L = decal_layer(w, y_top + hgt)
    cx, cy = w / 2, y_top + hgt / 2
    shape = fbm(y_top + hgt, w, seed, ((10, 26, 0.7), (3, 6, 0.3)), wrap=False)
    yy, xx = np.mgrid[0:y_top + hgt, 0:w]
    d = ((xx - cx) / (w / 2)) ** 2 + ((yy - cy) / (hgt / 2)) ** 2
    region = (d + (shape - 0.5) * 1.0) < 0.72
    core = (d + (shape - 0.5) * 1.0) < 0.45
    # spoiny: ciemna ziemia pod całym brukiem
    for y, x in zip(*np.where(region)):
        L.put(y, x, EARTH[1] if (y + x) % 3 else EARTH[2])
    y = float(y_top + 1)
    row = 0
    while y < y_top + hgt:
        pp = persp(y)
        rh = 1.3 + pp * 1.4
        rw0 = 2.4 + pp * 2.4
        x = -rw0 + rng.uniform(0, rw0 * 1.5)
        while x < w + rw0:
            rw = rw0 * rng.uniform(0.7, 1.35)
            xi, yi = int(np.clip(x, 0, w - 1)), int(np.clip(y, 0, region.shape[0] - 1))
            if region[yi, xi]:
                keep = core[yi, xi] or rng.random() < 0.55
                if keep and rng.random() > 0.05:
                    pebble(L, x, y + rng.uniform(-0.4, 0.4), rw * 0.92, rh * rng.uniform(0.8, 1.05), rng,
                           ramp=STONE[:6], outline=False)
                elif not keep:
                    L.put(yi, xi, EARTH[5]); L.put(yi, xi + 1, EARTH[5])   # piach w miejscu wyrwanego kamienia
            x += rw * 2 + 0.5
        y += rh * 2 + 0.45
        row += 1
    # krawędź: ziemia nasypana na brzeg bruku (miękkie przejście)
    edge = region & ~core
    for yv, xv in zip(*np.where(edge)):
        if rng.random() < 0.18:
            L.put(yv, xv, EARTH[4 + rng.integers(0, 3)])
    ys, xs = np.where(L.a)
    for _ in range(22):                                       # źdźbła w szczelinach
        k = rng.integers(0, len(ys))
        blade(L, xs[k], ys[k], 2 + rng.integers(0, 2), GRASS[1:6], rng)
    return finish_decal(L)

def rocks(seed, y_base, n, big):
    """Głazy przy krawędzi drogi z kępami trawy; y_base = wiersz styku z ziemią."""
    rng = np.random.default_rng(seed)
    w = 80 if big else 56
    L = decal_layer(w, y_base + 8)
    xs = np.linspace(w * 0.25, w * 0.75, n) + rng.uniform(-5, 5, n)
    order = np.argsort(rng.random(n))
    for i in order:
        rx = rng.uniform(6, 10) if big else rng.uniform(3.5, 6.5)
        ry = rx * rng.uniform(0.6, 0.8)
        cy = y_base - ry + rng.uniform(0, 2)
        contact_shadow(L, xs[i], y_base + 1, rx)
        pebble(L, xs[i], cy, rx, ry, rng)
        # mech na górze dużych
        if big and rng.random() < 0.7:
            for k in range(int(rx)):
                L.put(int(cy - ry * 0.8), int(xs[i] - rx * 0.4 + k), GRASS[3 + (k % 2)])
    for _ in range(4 + n):
        tuft(L, rng.uniform(4, w - 4), y_base + 1, rng.integers(1, 3), rng, dry=0.3)
    return finish_decal(L)

def puddle_decal(seed, y, w):
    rng = np.random.default_rng(seed)
    L = decal_layer(w + 10, y + w // 6 + 8)
    puddle(L, (w + 10) / 2, y, w, max(4, w // 7), rng)
    # druga, mniejsza obok
    puddle(L, (w + 10) / 2 + w * 0.42, y + 3, w * 0.35, max(3, w // 14), rng)
    return finish_decal(L)

def obstacle_puddle(seed):
    """Przeszkoda 'kałuża' (trzeba ją przeskoczyć): rozlewisko na całej głębi drogi, w stylu podłoża.
    Środek PNG = środek przeszkody (obstacle.gd rysuje ją wyśrodkowaną na x i na środku pasa walki)."""
    rng = np.random.default_rng(seed)
    w, h = 224, 172
    L = decal_layer(w, h)
    cx, cy = w / 2, h / 2
    yy, xx = np.mgrid[0:h, 0:w]
    edge_n = fbm(h, w, seed, ((12, 20, 0.7), (4, 6, 0.3)), wrap=False)
    d = ((xx - cx) / (w / 2 - 6)) ** 2 + ((yy - cy) / (h / 2 - 4)) ** 2 + (edge_n - 0.5) * 0.35
    water = d < 0.78
    rim = (d < 1.0) & ~water
    # błotnisty brzeg: mokra ziemia, jaśniejszy połysk przy wodzie
    rn = fbm(h, w, seed + 1, ((3, 8, 0.6), (1, 2, 0.4)), wrap=False)
    for y, x in zip(*np.where(rim)):
        t = (d[y, x] - 0.78) / 0.22
        v = 0.25 + t * 0.35 + (rn[y, x] - 0.5) * 0.35
        L.put(y, x, EARTH[int(np.clip(v, 0, 0.999) * 6)])
    # woda: odbicie nieba jaśniejsze w głębi, ciemny pas cienia pod tylnym brzegiem
    wn = fbm(h, w, seed + 2, ((6, 40, 0.6), (2, 10, 0.4)), wrap=False)
    top = np.zeros(w, int)
    for x in range(w):
        col = np.where(water[:, x])[0]
        top[x] = col.min() if len(col) else h
    by = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]
    for y, x in zip(*np.where(water)):
        depth = y - top[x]
        v = 0.30 + (1 - y / h) * 0.35 + (wn[y, x] - 0.5) * 0.25
        if depth < 3:
            v = 0.08
        elif depth < 6:
            v -= 0.12
        v += (by[y, x] - 0.5) * 0.18
        L.put(y, x, WATER[int(np.clip(v, 0, 0.999) * 4)])
    # refleksy nieba: poziome kreski
    for _ in range(26):
        y = rng.integers(int(h * 0.25), int(h * 0.8)); x = rng.integers(int(w * 0.2), int(w * 0.8))
        ln = rng.integers(4, 16)
        for k in range(ln):
            if water[y, min(x + k, w - 1)]:
                L.put(y, x + k, WATER[4] if k % 4 else WATER[3])
    # zanurzone kamienie i liście
    for _ in range(7):
        y = rng.integers(int(h * 0.3), int(h * 0.85)); x = rng.integers(int(w * 0.2), int(w * 0.8))
        if water[y, x]:
            pebble(L, x, y, rng.uniform(2, 4), rng.uniform(1.2, 2.2), rng, ramp=[(30, 36, 44), (46, 54, 62), (66, 74, 80), (90, 98, 104)], outline=False)
    for _ in range(9):
        y = rng.integers(10, h - 10); x = rng.integers(10, w - 10)
        if water[y, x]:
            L.put(y, x, DRY[3]); L.put(y, x + 1, DRY[2])
    # kamienie i kępy na brzegu
    ys, xs = np.where(rim)
    for _ in range(14):
        k = rng.integers(0, len(ys))
        pebble(L, xs[k], ys[k], rng.uniform(2, 4.5), rng.uniform(1.3, 2.6), rng)
    for _ in range(26):
        k = rng.integers(0, len(ys))
        tuft(L, xs[k], ys[k], rng.integers(1, 4), rng, dry=0.35)
    # trzcina przy tylnym brzegu
    for _ in range(18):
        x = rng.integers(int(w * 0.15), int(w * 0.85))
        y = top[x] + rng.integers(-2, 2)
        hg = rng.integers(6, 14)
        for k in range(hg):
            L.put(y - k, x + int(k * 0.15), GRASS[2 + min(4, k // 3)])
        if rng.random() < 0.4:
            L.put(y - hg, x + int(hg * 0.15), (78, 54, 34)); L.put(y - hg - 1, x + int(hg * 0.15), (78, 54, 34))
    return finish_decal(L)

# ---------------------------------------------------------------- zapis
DECALS = {
    # nazwa: (lista (funkcja, argumenty)), y nakładki = wiersz pod horyzontem (górna krawędź PNG)
    "crossroad":  [(crossroad, (401, False)), (crossroad, (402, True)), (crossroad, (403, True))],
    "bank_back":  [(bank_back, (501, False)), (bank_back, (502, False)), (bank_back, (503, True))],
    "bank_front": [(bank_front, (601,)), (bank_front, (602,))],
    "cobble":     [(cobble, (701,)), (cobble, (702, 160, 64)), (cobble, (703, 260, 104))],
    "rocks_back": [(rocks, (801, BACK_EDGE + 2, 3, True)), (rocks, (802, BACK_EDGE + 2, 2, True)), (rocks, (803, BACK_EDGE + 1, 4, False))],
    "rocks_front": [(rocks, (811, FRONT_EDGE + 8, 3, True)), (rocks, (812, FRONT_EDGE + 6, 4, False))],
    "puddle":     [(puddle_decal, (901, 78, 44)), (puddle_decal, (902, 140, 60)), (puddle_decal, (903, 104, 36))],
}

MANIFEST = {
    "note": "Nakładki terenu rysowane na podłożu (pod rekwizytami i postaciami, nic nie blokują). "
            "y = wiersz pod horyzontem (px obrazu) górnej krawędzi PNG. Sloty: co 'step' jednostek świata gra losuje "
            "(deterministycznie) jedną nakładkę wg 'chance'. clear_props = promień (jedn. świata) bez drzew/płotów; "
            "prop = rekwizyt stawiany obok (np. drogowskaz na rozdrożu). Generator: tools/build_road.py",
    "slots": [
        {"step": 620, "salt": 71, "jitter": 0.3, "items": [
            {"name": "crossroad", "chance": 0.22, "clear_props": 170, "prop": "signpost", "prop_dx": -125, "prop_dy": 12},
            {"name": "bank_back", "chance": 0.30, "clear_props": 0},
            {"name": "bank_front", "chance": 0.22},
        ]},
        {"step": 290, "salt": 83, "jitter": 0.35, "items": [
            {"name": "cobble", "chance": 0.16},
            {"name": "puddle", "chance": 0.16},
            {"name": "rocks_back", "chance": 0.18},
            {"name": "rocks_front", "chance": 0.16},
        ]},
    ],
    "decals": {},
}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default=None)
    a = ap.parse_args()
    P = np.array(Image.open(os.path.join(HERE, "assets/palette/hufduhof_256.png")).convert("RGB")).reshape(-1, 3)
    plab = BP.mp.srgb2lab(P)
    rng = np.random.default_rng(7)
    L = road_base(rng)
    g = Image.fromarray(np.dstack([np.clip(L.rgb, 0, 255).astype(np.uint8), np.full((H, W), 255, np.uint8)]), "RGBA")
    g = BP.quantize(g, P, plab)
    g.save(os.path.join(OUT, "ground.png"))
    print("ground.png", g.size)
    ddir = os.path.join(OUT, "decals")
    os.makedirs(ddir, exist_ok=True)
    man = json.loads(json.dumps(MANIFEST))
    for name, makers in DECALS.items():
        files = []
        for i, (fn, args) in enumerate(makers):
            im = fn(*args)
            bb = im.getbbox()
            top = bb[1]
            im = im.crop((0, top, im.width, bb[3]))
            q = BP.quantize(im, P, plab)
            f = f"{name}.png" if i == 0 else f"{name}_{i + 1}.png"
            q.save(os.path.join(ddir, f))
            files.append({"file": f, "y": int(top)})
            print(f"decals/{f} {q.width}x{q.height} y={top}")
        man["decals"][name] = files
    op = BP.quantize(obstacle_puddle(951), P, plab)
    op.save(os.path.join(HERE, "assets/stages/common/props/obstacle_puddle.png"))
    print("common/props/obstacle_puddle.png", op.size)
    with open(os.path.join(OUT, "decals.json"), "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
    if a.preview:
        preview(a.preview, man)

def preview(d, man):
    """Scena 1280x720 jak w grze (skala 4/3 -> tu 1.333 px na px obrazu, zaokrąglone do x1.33 NEAREST)."""
    os.makedirs(d, exist_ok=True)
    WPT = 4 / 3
    HOR = 345
    VW = 2400
    world = Image.new("RGBA", (int(VW / WPT), int(720 / WPT)))
    sky = Image.open(os.path.join(OUT, "sky.png")).convert("RGBA")
    far1 = Image.open(os.path.join(OUT, "far1.png")).convert("RGBA")
    far2 = Image.open(os.path.join(OUT, "far2.png")).convert("RGBA")
    gnd = Image.open(os.path.join(OUT, "ground.png")).convert("RGBA")
    hor = int(HOR / WPT)
    for x in range(0, world.width, sky.width):
        world.alpha_composite(sky, (x, hor - sky.height))
    for x in range(0, world.width, far2.width):
        world.alpha_composite(far2, (x, hor - far2.height))
        world.alpha_composite(far1, (x, hor - far2.height - 0 - 110 + 110 - far1.height + 0))
    for x in range(0, world.width, gnd.width):
        world.alpha_composite(gnd, (x, hor))
    # nakładki w ustalonych miejscach (podgląd)
    def dec(name, k, xw):
        f = man["decals"][name][k]
        im = Image.open(os.path.join(OUT, "decals", f["file"])).convert("RGBA")
        world.alpha_composite(im, (int(xw - im.width / 2), hor + f["y"]))
    props = os.path.join(OUT, "props")
    def prop(fn, xw, dy=8):
        im = Image.open(os.path.join(props, fn)).convert("RGBA")
        world.alpha_composite(im, (int(xw - im.width / 2), hor + dy - im.height))
    dec("bank_back", 0, 180); dec("crossroad", 1, 620); dec("bank_back", 2, 1000); dec("bank_front", 0, 1300)
    dec("cobble", 0, 330); dec("puddle", 1, 900); dec("rocks_back", 0, 1450); dec("rocks_front", 1, 760)
    dec("cobble", 2, 1420); dec("crossroad", 0, 1650)
    prop("tree_oak.png", 120, 6); prop("fence.png", 330, 14); prop("signpost.png", 520, 16); prop("tree_oak_5.png", 840, 7)
    prop("bush_2.png", 960, 12); prop("tree_oak_3.png", 1120, 7); prop("fence_broken.png", 1300, 14); prop("bush.png", 1540, 12)
    prop("tree_dead.png", 1760, 7)
    for i, x in enumerate(range(0, world.width, 600)):
        sc = world.crop((x, 0, x + 960, 540)).resize((1280, 720), Image.NEAREST)
        sc.convert("RGB").save(os.path.join(d, f"road_view_{i + 1}.png"))
        if x + 960 >= world.width:
            break

if __name__ == "__main__":
    main()
