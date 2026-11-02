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
OUT = os.path.join(HERE, "assets/stages/stage1_road")      # ustawiane przez set_style()
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
        y = int(y); x = int(x)
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

def tuft(L, x, y, size, rng, ramp=None, dry=0.0):
    ramp = GRASS if ramp is None else ramp
    n = int(3 + size * 1.6)
    for i in range(n):
        r = DRY if rng.random() < dry else ramp
        bx = x + rng.integers(-size, size + 1)
        hg = int(2 + size * (0.6 + rng.random() * 0.9))
        blade(L, bx, y + rng.integers(-1, 2), hg, r, rng, lean=rng.uniform(-1.6, 1.6))

def pebble(L, cx, cy, rx, ry, rng, ramp=None, outline=True):
    """Kamień: kontur, cieniowanie światłem z lewej-góry, połysk."""
    ramp = STONE if ramp is None else ramp
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

def contact_shadow(L, cx, cy, rx, col=None):
    col = EARTH[1] if col is None else col
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
    for _ in range(int(w * hh / 700 * STYLE.get("flowers", 1.0))):
        x = x0 + rng.integers(0, w); y = y0 + rng.integers(2, max(hh - 1, 3))
        L.put(y, x, FLOWER[rng.integers(0, len(FLOWER))]); L.put(y + 1, x, GRASS[1])

# ---------------------------------------------------------------- podłoże
def road_base(rng):
    """Zwraca Layer z całym kafelkiem podłoża."""
    L = Layer(H, W, wrap=True)
    road = np.zeros((H, W), bool); road[BACK_EDGE - 2:FRONT_EDGE + 2] = True
    v = earth_fill(L, road, 11 + STYLE["seed"])

    # --- koleiny: dwie pary szerokich rowków; łagodnie wygięte, głębokość zmienna, zanikają ditheringiem
    by = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    for (yc, gap, th, ph, amp, sd) in STYLE["ruts"]:
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
            if d > 0.6 and rng.random() < STYLE["rut_grass"]:      # grzbiet między koleinami: trochę trawy
                yg = int(round(yc + gap * 0.5 + off)) + 2
                blade(L, x, yg, int(1 + gap * 0.18 + rng.random() * 2), GRASS[1:6], rng, lean=rng.uniform(-1, 1))
            if d > 0.92:                              # woda na dnie najgłębszych kolein
                L.put(int(round(yc + gap + off)) + 1, x, WATER[2] if x % 7 else WATER[3])

    # --- ślady kopyt
    for _ in range(STYLE["hooves"]):
        x = rng.integers(0, W); y = rng.integers(BACK_EDGE + 8, FRONT_EDGE - 8)
        s = 1 + int(persp(y) * 2)
        for dx in range(-s, s + 1):
            L.put(y, x + dx, EARTH[1])
        L.put(y - 1, x - s, EARTH[1]); L.put(y - 1, x + s, EARTH[1])
        L.put(y + 1, x, EARTH[7])

    # --- kamyki, większe bliżej
    for _ in range(STYLE["pebbles"]):
        x = rng.integers(0, W); y = rng.integers(BACK_EDGE + 4, FRONT_EDGE - 3)
        r = 0.9 + persp(y) * 2.6 * rng.random() ** 1.5
        pebble(L, x, y, r * 1.3, r * 0.8, rng)
    for _ in range(12):
        x = rng.integers(0, W); y = rng.integers(BACK_EDGE + 30, FRONT_EDGE - 10)
        pp = persp(y)
        pebble(L, x, y, 2.5 + pp * 4, 1.6 + pp * 2.4, rng)
    # kępy trawy na środku drogi
    for _ in range(STYLE["road_tufts"]):
        x = rng.integers(0, W); y = rng.integers(BACK_EDGE + 12, FRONT_EDGE - 6)
        tuft(L, x, y, 1 + int(persp(y) * 2), rng, dry=STYLE["dry"] + 0.2)

    for (x, y, w) in STYLE["puddles"]:
        puddle(L, x, y, w, max(3, w // 7), rng)
    for extra in STYLE.get("extras", []):
        extra(L, rng)

    grass_band(L, 0, BACK_EDGE, rng, back=True, dry=STYLE["dry"])
    grass_band(L, FRONT_EDGE, H, rng, back=False, dry=STYLE["dry"])
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


# ---------------------------------------------------------------- dodatki etapów (podłoże)
WOOD = [(30, 20, 12), (54, 36, 22), (82, 58, 34), (112, 82, 50), (146, 112, 70)]
CHAR = [(10, 8, 8), (22, 18, 16), (38, 32, 28), (58, 52, 46), (86, 80, 72)]
EMBER = [(120, 30, 16), (190, 70, 24), (236, 140, 50)]
LEAF = [(92, 52, 22), (128, 76, 28), (160, 110, 40), (110, 92, 40), (70, 84, 36)]

def straw_bits(L, rng, n=420):
    """Rozwleczona słoma i siano (wieś): krótkie żółte kreski z cieniem."""
    for _ in range(n):
        x = rng.integers(0, L.w); y = rng.integers(BACK_EDGE + 3, FRONT_EDGE - 2)
        ln = 3 + int(rng.random() * (3 + persp(y) * 5))
        dx = rng.choice([-1, 1]); sl = rng.uniform(-0.35, 0.35)
        c = DRY[2 + rng.integers(0, 3)]
        for k in range(ln):
            yk = int(round(y + sl * k))
            L.put(yk, x + dx * k, c if k % 4 else DRY[4])
            L.put(yk + 1, x + dx * k, EARTH[1])

def splinters(L, rng, n=60):
    """Drzazgi, kawałki desek i węgielki po pożarach."""
    for _ in range(n):
        x = rng.integers(0, L.w); y = rng.integers(BACK_EDGE + 6, FRONT_EDGE - 4)
        if rng.random() < 0.5:
            ln = 3 + int(persp(y) * 5 * rng.random())
            for k in range(ln):
                L.put(y, x + k, WOOD[3] if k % 3 else WOOD[2]); L.put(y + 1, x + k, WOOD[0])
        else:
            L.put(y, x, CHAR[0]); L.put(y, x + 1, CHAR[1]); L.put(y - 1, x, CHAR[2])

def leaf_litter(L, rng, n=900, y0=None, y1=None):
    """Opadłe liście i igliwie (las)."""
    y0 = BACK_EDGE + 2 if y0 is None else y0
    y1 = FRONT_EDGE - 2 if y1 is None else y1
    for _ in range(n):
        x = rng.integers(0, L.w); y = rng.integers(y0, y1)
        if rng.random() < 0.55:
            c = LEAF[rng.integers(0, len(LEAF))]
            L.put(y, x, c)
            if persp(y) > 0.4 and rng.random() < 0.6:
                L.put(y, x + 1, c); L.put(y + 1, x, EARTH[1])
        else:                                                        # igła
            d = rng.choice([-1, 1])
            L.put(y, x, (44, 52, 30)); L.put(y + (rng.random() < 0.5), x + d, (60, 64, 36))

def overgrow(L, rng, amount=0.5, seed=91):
    """Dukt zarastający trawą: łaty trawy na drodze (gęściej przy brzegach i na grzbiecie między koleinami)."""
    h, w = L.h, L.w
    n = fbm(h, w, seed, ((10, 60, 0.6), (4, 14, 0.3), (1, 2, 0.1)))
    yy = np.arange(h)[:, None] * np.ones((1, w))
    near_back = np.clip(1 - (yy - BACK_EDGE) / 26, 0, 1)
    near_front = np.clip(1 - (FRONT_EDGE - yy) / 22, 0, 1)
    ridge = np.clip(1 - np.abs(yy - 104) / 14, 0, 1)
    road = (yy > BACK_EDGE) & (yy < FRONT_EDGE)
    score = n + near_back * 0.45 + near_front * 0.35 + ridge * 0.25
    m = road & (score > 1.05 - amount * 0.5)
    col = ramp_map(0.15 + n * 0.35, GRASS[1:], dither=1.0)
    L.rgb[m] = col[m]
    ys, xs = np.where(m)
    for k in rng.integers(0, len(ys), int(len(ys) * 0.22)):
        y, x = ys[k], xs[k]
        blade(L, x, y, 1 + int(rng.random() * (2 + persp(y) * 4)), GRASS[1:], rng, lean=rng.uniform(-1.3, 1.3))
    # ciemniejsza obwódka łat (ziemia przy trawie)
    edge = road & ~m & (np.roll(m, 1, 0) | np.roll(m, -1, 1) | np.roll(m, 1, 1))
    L.rgb[edge] = np.array(EARTH[2], float)

def leaf_clusters(L, rng, n=60):
    """Skupiska liści (las) - widoczne plamy, nie pojedyncze piksele."""
    for _ in range(n):
        cx = rng.integers(0, L.w); cy = rng.integers(BACK_EDGE + 6, FRONT_EDGE - 6)
        r = 4 + persp(cy) * 10 * rng.random()
        for _ in range(int(r * r * 1.2)):
            a = rng.random() * 2 * np.pi; rr = rng.random() ** 0.7 * r
            x = int(cx + np.cos(a) * rr * 1.8); y = int(cy + np.sin(a) * rr * 0.6)
            c = LEAF[rng.integers(0, len(LEAF))]
            L.put(y, x, c)
            if rng.random() < 0.4:
                L.put(y, x + 1, c)
            if rng.random() < 0.3:
                L.put(y + 1, x, EARTH[1])

def moss_edges(L, rng):
    """Mech i trawa wchodzące na drogę (leśny dukt): pas trawy pośrodku i przy brzegach."""
    n = vnoise(1, L.w, 1, 60, 77)[0]
    for x in range(L.w):
        if n[x] > 0.45:
            for k in range(int((n[x] - 0.45) * 14)):
                y = BACK_EDGE + 1 + k + rng.integers(0, 2)
                if rng.random() < 0.6:
                    L.put(y, x, GRASS[2 + rng.integers(0, 3)])
        yc = 104 + int((n[x] - 0.5) * 10)
        if n[x] > 0.35 and rng.random() < 0.35:
            blade(L, x, yc + rng.integers(-3, 4), 2 + rng.integers(0, 3), GRASS[1:6], rng, lean=rng.uniform(-1, 1))

def scorch(seed, w=150, hgt=56, y_top=70):
    """Wypalona plama: popiół, sadza, zwęglone deski, tlące się węgielki."""
    rng = np.random.default_rng(seed)
    L = decal_layer(w, y_top + hgt)
    cx, cy = w / 2, y_top + hgt / 2
    sh = fbm(y_top + hgt, w, seed, ((8, 20, 0.7), (3, 5, 0.3)), wrap=False)
    yy, xx = np.mgrid[0:y_top + hgt, 0:w]
    d = ((xx - cx) / (w / 2)) ** 2 + ((yy - cy) / (hgt / 2)) ** 2 + (sh - 0.5) * 0.8
    gn = vnoise(y_top + hgt, w, 1, 1, seed + 1, wrap=False)
    for y, x in zip(*np.where(d < 1.0)):
        if d[y, x] > 0.75 and gn[y, x] < 0.5:
            continue
        ring = np.clip((d[y, x] - 0.35) / 0.4, 0, 1)                  # popiół na brzegu, sadza w środku
        v = 0.26 + ring * 0.5 + (gn[y, x] - 0.5) * 0.6
        L.put(y, x, CHAR[int(np.clip(v, 0, 0.999) * len(CHAR))])
    for _ in range(rng.integers(2, 5)):                               # zwęglone deski
        x0 = rng.uniform(w * 0.2, w * 0.6); y0 = rng.uniform(cy - hgt * 0.25, cy + hgt * 0.25)
        ln = rng.integers(16, 34); sl = rng.uniform(-0.25, 0.25)
        for k in range(ln):
            yk = int(y0 + sl * k)
            L.put(yk - 1, int(x0 + k), OUTLINE)
            L.put(yk, int(x0 + k), CHAR[3] if k % 5 else CHAR[4])
            L.put(yk + 1, int(x0 + k), CHAR[2] if k % 3 else EMBER[0])
            L.put(yk + 2, int(x0 + k), OUTLINE)
    for _ in range(18):                                               # tlące się węgielki
        ys, xs = np.where(d < 0.6)
        k = rng.integers(0, len(ys))
        L.put(ys[k], xs[k], EMBER[rng.integers(0, 3)])
    return finish_decal(L)

def hay(seed, w=110, hgt=34, y_top=None):
    """Rozsypane siano (spadło z wozu): niski kopczyk ze źdźbeł, jaśniejsza góra, cień u podstawy."""
    rng = np.random.default_rng(seed)
    y_top = rng.integers(40, 140) if y_top is None else y_top
    L = decal_layer(w, y_top + hgt + 4)
    cx, base = w / 2, y_top + hgt
    for x in range(int(cx - w * 0.47), int(cx + w * 0.47)):          # cień
        L.put(base + 1, x, EARTH[0]); L.put(base + 2, x, EARTH[1])
    for _ in range(int(w * hgt * 1.4)):
        u = rng.uniform(-1, 1)
        top = base - hgt * 0.75 * (1 - u * u) ** 0.8 - rng.uniform(0, 3)
        x = cx + u * w * 0.46
        y = rng.uniform(top, base)
        t = (y - top) / max(base - top, 1)                              # 0 = góra kopczyka
        ln = rng.integers(3, 8); dx = rng.choice([-1, 1]); sl = rng.uniform(-0.6, 0.6)
        lv = 4 - int(t * 3.6 + rng.uniform(-0.8, 0.8))
        c = DRY[int(np.clip(lv, 0, 4))] if rng.random() > 0.08 else DRY[0]
        for k in range(ln):
            L.put(int(y + sl * k), int(x + dx * k), c)
    for _ in range(int(w * 0.8)):                                       # pojedyncze źdźbła dookoła
        x = cx + rng.uniform(-w * 0.5, w * 0.5); y = base + rng.uniform(-3, 3)
        for k in range(rng.integers(3, 7)):
            L.put(int(y), int(x + k), DRY[3])
    return finish_decal(L)

def planks(seed, y_base):
    """Połamane deski i klepki przy krawędzi drogi."""
    rng = np.random.default_rng(seed)
    w = 90
    L = decal_layer(w, y_base + 10)
    for _ in range(rng.integers(3, 6)):
        x0 = rng.uniform(6, w - 40); y0 = y_base - rng.uniform(0, 8)
        ln = rng.integers(18, 36); sl = rng.uniform(-0.2, 0.2); th = rng.integers(2, 4)
        for k in range(ln):
            yk = y0 + sl * k
            for t in range(th):
                c = WOOD[3] if t == 0 else (WOOD[2] if t < th - 1 else WOOD[1])
                if k == ln - 1 or (k > ln - 4 and rng.random() < 0.5):
                    c = WOOD[4]                                         # jasny złom
                L.put(int(yk) + t, int(x0 + k), c)
            L.put(int(yk) - 1, int(x0 + k), OUTLINE); L.put(int(yk) + th, int(x0 + k), OUTLINE)
        L.put(int(y0), int(x0 + 3), STONE[5])                           # gwóźdź
    for _ in range(4):
        tuft(L, rng.uniform(4, w - 4), y_base + 2, rng.integers(1, 3), rng, dry=0.5)
    return finish_decal(L)

def roots(seed, w=200):
    """Korzenie drzewa wychodzące z tylnego pobocza na dukt."""
    rng = np.random.default_rng(seed)
    L = decal_layer(w, 90)
    for _ in range(rng.integers(3, 6)):
        x = rng.uniform(w * 0.25, w * 0.75); y = rng.uniform(4, BACK_EDGE - 4)
        ang = rng.uniform(0.25, 1.1) * rng.choice([-1, 1])
        th = rng.uniform(2.5, 4.5)
        ln = rng.integers(30, 70)
        for k in range(ln):
            ang += rng.uniform(-0.12, 0.12)
            x += np.sin(ang) * 1.2; y += np.cos(ang) * 0.75
            t = th * (1 - k / ln)
            for j in range(-int(t), int(t) + 1):
                yy = int(y + j * 0.6)
                if j == -int(t):
                    c = (44, 30, 20)
                elif j < 0:
                    c = (118, 88, 58) if k % 5 else (98, 73, 50)
                elif j == int(t):
                    c = OUTLINE
                else:
                    c = (74, 52, 34)
                L.put(yy, int(x), c)
            if k % 9 == 0 and t > 1.5:
                L.put(int(y + t * 0.6) + 1, int(x), EARTH[0])            # cień pod korzeniem
    return finish_decal(L)

def branch(seed, y_base):
    """Złamana gałąź leżąca przy krawędzi duktu."""
    rng = np.random.default_rng(seed)
    w = 120
    L = decal_layer(w, y_base + 16)
    x = 8.0; y = float(y_base); sl = rng.uniform(-0.15, 0.1)
    pts = []
    for k in range(rng.integers(70, 100)):
        x += 1; y += sl + rng.uniform(-0.2, 0.2)
        pts.append((x, y))
        th = 3 if k < 40 else 2
        for t in range(th):
            L.put(int(y) + t, int(x), (112, 84, 54) if t == 0 else (62, 44, 28))
        L.put(int(y) - 1, int(x), OUTLINE); L.put(int(y) + th, int(x), OUTLINE)
        L.put(int(y) + th + 1, int(x), EARTH[1])
    for _ in range(rng.integers(4, 8)):                               # gałązki
        px, py = pts[rng.integers(10, len(pts) - 5)]
        d = rng.choice([-1, 1]); ln = rng.integers(6, 16)
        for k in range(ln):
            L.put(int(py - d * k * 0.55), int(px + k * 0.8), (78, 56, 36))
        if rng.random() < 0.6:
            for j in range(3):
                L.put(int(py - d * ln * 0.55) + rng.integers(-1, 2), int(px + ln * 0.8) + rng.integers(-1, 2), LEAF[rng.integers(0, len(LEAF))])
    return finish_decal(L)

def leaves_patch(seed, w=130, hgt=50, y_top=None):
    """Kopczyk opadłych liści (las)."""
    rng = np.random.default_rng(seed)
    y_top = rng.integers(36, 130) if y_top is None else y_top
    L = decal_layer(w, y_top + hgt)
    cx, cy = w / 2, y_top + hgt / 2
    for _ in range(int(w * hgt * 0.7)):
        a = rng.random() * 2 * np.pi; r = rng.random() ** 0.7
        x = cx + np.cos(a) * r * w * 0.48; y = cy + np.sin(a) * r * hgt * 0.45
        c = LEAF[rng.integers(0, len(LEAF))]
        L.put(int(y), int(x), c)
        if rng.random() < 0.5:
            L.put(int(y), int(x) + 1, c); L.put(int(y) + 1, int(x), EARTH[1])
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
NOTE = ("Nakładki terenu rysowane na podłożu (pod rekwizytami i postaciami, nic nie blokują). "
        "y = wiersz pod horyzontem (px obrazu) górnej krawędzi PNG. Sloty: co 'step' jednostek świata gra losuje "
        "(deterministycznie) jedną nakładkę wg 'chance'. clear_props = promień (jedn. świata) bez drzew/płotów; "
        "prop = rekwizyt stawiany obok (np. drogowskaz na rozdrożu). Generator: tools/build_road.py")

PAL1 = dict(GRASS=GRASS, DRY=DRY, EARTH=EARTH, FACE=FACE, STONE=STONE)
STAGES = {
    "stage1_road": dict(
        pal=PAL1,
        style=dict(seed=0, ruts=((70, 10, 2, 0.0, 4.0, 21), (134, 17, 4, 1.3, 6.0, 23)), rut_grass=0.14, hooves=90,
                   pebbles=150, road_tufts=26, puddles=((300, 74, 26), (790, 140, 34)), dry=0.28, flowers=1.0, extras=[]),
        decals={
            "crossroad":  [(crossroad, (401, False)), (crossroad, (402, True)), (crossroad, (403, True))],
            "bank_back":  [(bank_back, (501, False)), (bank_back, (502, False)), (bank_back, (503, True))],
            "bank_front": [(bank_front, (601,)), (bank_front, (602,))],
            "cobble":     [(cobble, (701,)), (cobble, (702, 160, 64)), (cobble, (703, 260, 104))],
            "rocks_back": [(rocks, (801, BACK_EDGE + 2, 3, True)), (rocks, (802, BACK_EDGE + 2, 2, True)), (rocks, (803, BACK_EDGE + 1, 4, False))],
            "rocks_front": [(rocks, (811, FRONT_EDGE + 8, 3, True)), (rocks, (812, FRONT_EDGE + 6, 4, False))],
            "puddle":     [(puddle_decal, (901, 78, 44)), (puddle_decal, (902, 140, 60)), (puddle_decal, (903, 104, 36))],
        },
        slots=[
            {"step": 620, "salt": 71, "jitter": 0.3, "items": [
                {"name": "crossroad", "chance": 0.22, "clear_props": 170, "prop": "signpost", "prop_dx": -125, "prop_dy": 12},
                {"name": "bank_back", "chance": 0.30, "clear_props": 0},
                {"name": "bank_front", "chance": 0.22}]},
            {"step": 290, "salt": 83, "jitter": 0.35, "items": [
                {"name": "cobble", "chance": 0.16}, {"name": "puddle", "chance": 0.16},
                {"name": "rocks_back", "chance": 0.18}, {"name": "rocks_front", "chance": 0.16}]},
        ],
        preview=[("bank_back", 0, 180), ("crossroad", 1, 620), ("bank_back", 2, 1000), ("bank_front", 0, 1300),
                 ("cobble", 0, 330), ("puddle", 1, 900), ("rocks_back", 0, 1450), ("rocks_front", 1, 760),
                 ("cobble", 2, 1420), ("crossroad", 0, 1650)],
    ),
    # wieś: ubłocona, cieplejsza ulica, słoma, drzazgi i sadza; więcej bruku i kamiennych murków, wypalone plamy
    "stage2_village": dict(
        pal=dict(
            GRASS=[(18, 22, 10), (34, 38, 18), (48, 52, 24), (63, 66, 32), (78, 80, 38), (94, 94, 45), (110, 108, 52), (126, 122, 60)],
            DRY=DRY,
            EARTH=[(28, 18, 11), (42, 28, 17), (56, 38, 24), (70, 48, 30), (86, 60, 38), (104, 74, 47), (122, 88, 58), (140, 104, 70), (160, 124, 86)],
            FACE=FACE, STONE=STONE),
        style=dict(seed=100, ruts=((64, 9, 3, 0.7, 5.0, 31), (128, 16, 4, 2.1, 7.0, 33), (168, 14, 3, 0.2, 4.0, 35)),
                   rut_grass=0.05, hooves=160, pebbles=170, road_tufts=12, puddles=((180, 92, 30), (640, 150, 40), (900, 60, 22)),
                   dry=0.45, flowers=0.35, extras=[lambda L, rng: straw_bits(L, rng, 1400), lambda L, rng: splinters(L, rng, 140)]),
        decals={
            "crossroad":  [(crossroad, (411, False)), (crossroad, (412, True))],
            "bank_back":  [(bank_back, (511, True)), (bank_back, (512, True)), (bank_back, (513, False))],
            "bank_front": [(bank_front, (611,))],
            "cobble":     [(cobble, (711, 280, 110)), (cobble, (712, 220, 90)), (cobble, (713, 180, 70))],
            "scorch":     [(scorch, (1011,)), (scorch, (1012, 120, 44, 120)), (scorch, (1013, 170, 60, 50))],
            "hay":        [(hay, (1111,)), (hay, (1112, 90, 28))],
            "planks_back": [(planks, (1211, BACK_EDGE + 3)), (planks, (1212, BACK_EDGE + 2))],
            "planks_front": [(planks, (1221, FRONT_EDGE + 6))],
            "puddle":     [(puddle_decal, (911, 96, 50)), (puddle_decal, (912, 150, 64))],
            "rocks_front": [(rocks, (821, FRONT_EDGE + 8, 3, True))],
        },
        slots=[
            {"step": 600, "salt": 91, "jitter": 0.3, "items": [
                {"name": "crossroad", "chance": 0.24, "clear_props": 170, "prop": "signpost", "prop_dx": -125, "prop_dy": 12},
                {"name": "bank_back", "chance": 0.34, "clear_props": 0},
                {"name": "bank_front", "chance": 0.18}]},
            {"step": 260, "salt": 97, "jitter": 0.35, "items": [
                {"name": "cobble", "chance": 0.22}, {"name": "scorch", "chance": 0.18}, {"name": "puddle", "chance": 0.14},
                {"name": "hay", "chance": 0.12}, {"name": "planks_back", "chance": 0.10}, {"name": "planks_front", "chance": 0.08},
                {"name": "rocks_front", "chance": 0.06}]},
        ],
        preview=[("cobble", 0, 330), ("bank_back", 0, 200), ("crossroad", 1, 700), ("scorch", 0, 1050),
                 ("hay", 0, 860), ("planks_back", 0, 1150), ("puddle", 1, 1450), ("bank_back", 2, 1600), ("bank_front", 0, 1400)],
    ),
    # pola i las: ciemniejsza, chłodniejsza ziemia, trawa i mech na dukcie, liście, korzenie, gałęzie
    "stage3_fields_forest": dict(
        pal=dict(
            GRASS=[(10, 22, 12), (20, 36, 20), (30, 50, 26), (42, 64, 32), (54, 78, 38), (68, 94, 44), (82, 108, 50), (98, 124, 58)],
            DRY=DRY,
            EARTH=[(20, 16, 11), (32, 26, 18), (44, 36, 25), (56, 46, 32), (70, 58, 40), (86, 72, 50), (102, 86, 60), (118, 100, 70), (136, 116, 82)],
            FACE=[(26, 20, 14), (44, 34, 24), (62, 50, 34), (82, 66, 44), (102, 84, 56), (124, 104, 70)],
            STONE=[(20, 22, 20), (38, 42, 38), (58, 62, 56), (80, 84, 76), (104, 108, 98), (130, 134, 122), (156, 160, 146)]),
        style=dict(seed=200, ruts=((72, 9, 2, 0.4, 4.0, 41), (136, 15, 3, 1.9, 5.0, 43)), rut_grass=0.35, hooves=50,
                   pebbles=110, road_tufts=70, puddles=((420, 96, 28),), dry=0.12, flowers=0.7,
                   extras=[lambda L, rng: overgrow(L, rng, 0.55), lambda L, rng: leaf_litter(L, rng, 1400),
                           lambda L, rng: leaf_clusters(L, rng), lambda L, rng: moss_edges(L, rng)]),
        decals={
            "crossroad":  [(crossroad, (421, False)), (crossroad, (422, True))],
            "bank_back":  [(bank_back, (521, False)), (bank_back, (522, False)), (bank_back, (523, True))],
            "bank_front": [(bank_front, (621,)), (bank_front, (622,))],
            "roots":      [(roots, (1311,)), (roots, (1312,)), (roots, (1313, 160))],
            "branch_back": [(branch, (1411, BACK_EDGE + 4)), (branch, (1412, BACK_EDGE + 6))],
            "branch_front": [(branch, (1421, FRONT_EDGE - 2))],
            "leaves":     [(leaves_patch, (1511,)), (leaves_patch, (1512, 100, 40))],
            "rocks_back": [(rocks, (831, BACK_EDGE + 2, 3, True)), (rocks, (832, BACK_EDGE + 1, 4, False))],
            "rocks_front": [(rocks, (841, FRONT_EDGE + 8, 3, True))],
            "puddle":     [(puddle_decal, (921, 90, 40))],
            "cobble":     [(cobble, (731, 150, 60))],
        },
        slots=[
            {"step": 600, "salt": 101, "jitter": 0.3, "items": [
                {"name": "crossroad", "chance": 0.22, "clear_props": 170, "prop": "signpost", "prop_dx": -125, "prop_dy": 12},
                {"name": "bank_back", "chance": 0.32, "clear_props": 0},
                {"name": "bank_front", "chance": 0.22}]},
            {"step": 250, "salt": 107, "jitter": 0.35, "items": [
                {"name": "roots", "chance": 0.18}, {"name": "branch_back", "chance": 0.10}, {"name": "branch_front", "chance": 0.08},
                {"name": "leaves", "chance": 0.14}, {"name": "rocks_back", "chance": 0.12}, {"name": "rocks_front", "chance": 0.10},
                {"name": "puddle", "chance": 0.08}, {"name": "cobble", "chance": 0.05}]},
        ],
        preview=[("roots", 0, 200), ("bank_back", 0, 520), ("crossroad", 1, 980), ("leaves", 0, 760),
                 ("branch_front", 0, 1300), ("rocks_back", 0, 1450), ("bank_front", 0, 1600), ("branch_back", 0, 1250)],
    ),
}
STYLE = STAGES["stage1_road"]["style"]

def set_style(stage):
    """Ustawia palety i parametry etapu (funkcje rysujące czytają globalne rampy w chwili wywołania)."""
    global STYLE, OUT
    st = STAGES[stage]
    for k, v in st["pal"].items():
        globals()[k] = v
    STYLE = st["style"]
    OUT = os.path.join(HERE, "assets/stages", stage)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default=None)
    ap.add_argument("--stage", default=None, help="tylko ten etap (np. stage2_village)")
    a = ap.parse_args()
    P = np.array(Image.open(os.path.join(HERE, "assets/palette/hufduhof_256.png")).convert("RGB")).reshape(-1, 3)
    plab = BP.mp.srgb2lab(P)
    for stage, st in STAGES.items():
        if a.stage and stage != a.stage:
            continue
        set_style(stage)
        rng = np.random.default_rng(7 + st["style"]["seed"])
        L = road_base(rng)
        g = Image.fromarray(np.dstack([np.clip(L.rgb, 0, 255).astype(np.uint8), np.full((H, W), 255, np.uint8)]), "RGBA")
        g = BP.quantize(g, P, plab)
        g.save(os.path.join(OUT, "ground.png"))
        print(f"{stage}/ground.png", g.size)
        ddir = os.path.join(OUT, "decals")
        os.makedirs(ddir, exist_ok=True)
        man = {"note": NOTE, "slots": st["slots"], "decals": {}}
        for name, makers in st["decals"].items():
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
            man["decals"][name] = files
        print(f"{stage}/decals: {sum(len(v) for v in man['decals'].values())} plików")
        if stage == "stage1_road":
            op = BP.quantize(obstacle_puddle(951), P, plab)
            op.save(os.path.join(HERE, "assets/stages/common/props/obstacle_puddle.png"))
        with open(os.path.join(OUT, "decals.json"), "w", encoding="utf-8") as fh:
            json.dump(man, fh, ensure_ascii=False, indent=1)
        if a.preview:
            preview(a.preview, man, stage, st["preview"])

def preview(d, man, stage, placements):
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
    for (name, k, xw) in placements:
        dec(name, k, xw)
    pdir = os.path.join(OUT, "props")
    pr = sorted(f for f in os.listdir(pdir) if f.endswith(".png") and not f.startswith(("fence", "gate")))
    for j, xw in enumerate(range(120, world.width, 260)):
        im = Image.open(os.path.join(pdir, pr[(j * 7) % len(pr)])).convert("RGBA")
        world.alpha_composite(im, (int(xw - im.width / 2), hor + 8 - im.height))
    for i, x in enumerate(range(0, world.width, 600)):
        sc = world.crop((x, 0, x + 960, 540)).resize((1280, 720), Image.NEAREST)
        sc.convert("RGB").save(os.path.join(d, f"{stage}_view_{i + 1}.png"))
        if x + 960 >= world.width:
            break

if __name__ == "__main__":
    main()
