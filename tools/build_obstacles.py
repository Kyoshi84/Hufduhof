#!/usr/bin/env python3
"""Przeszkody do przeskoczenia w pixel-arcie 1:1 (ten sam styl co droga): ogień, powalony pień, przepaść.

Strefy kolizji są w scripts/level/obstacle.gd (TYPES) i się nie zmieniają; grafika jest tylko większa i bardziej
"trójwymiarowa" (ściany, przekroje, cienie). Wynik w assets/stages/common/props/:
  obstacle_fire.png            zwęglone belki i żar (statyczne)
  obstacle_fire_flames.png     płomienie: arkusz FIRE_FRAMES klatek obok siebie (animacja w grze)
  obstacle_log.png             powalony pień z bryłą korzeni
  obstacle_chasm.png           przepaść: skalne krawędzie, ściany z warstwami, ciemność
  obstacle_chasm_glow.png      poświata spaczenia z dna (gra pulsuje jej przezroczystością)
  obstacles.json               dla każdej przeszkody: pliki i 'y' = wiersz (px pod horyzontem) górnej krawędzi PNG

    python3 tools/build_obstacles.py [--preview DIR]
"""
import argparse, json, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_props as BP
import build_road as R

HERE = BP.HERE
OUT = os.path.join(HERE, "assets/stages/common/props")
OUTLINE = R.OUTLINE
FIRE_FRAMES = 8

CHAR = R.CHAR
EMBER = [(96, 22, 12), (150, 40, 18), (206, 84, 26), (240, 146, 48), (252, 214, 110)]
FLAME = [(70, 14, 10), (140, 30, 14), (200, 64, 20), (238, 120, 32), (252, 182, 64), (255, 232, 150), (255, 250, 220)]
SMOKE = [(30, 28, 30), (46, 44, 46), (64, 62, 62)]
BARK = [(18, 12, 8), (34, 24, 15), (52, 37, 23), (72, 52, 32), (94, 70, 44), (118, 90, 58)]
WOODCUT = [(70, 48, 28), (110, 80, 48), (146, 110, 68), (176, 138, 88), (200, 164, 108)]
MOSS = [(26, 40, 18), (40, 58, 24), (58, 78, 30), (80, 98, 40)]
ROCK = [(16, 15, 18), (30, 28, 32), (46, 43, 46), (64, 60, 60), (86, 80, 76), (110, 104, 96), (136, 130, 118)]
CHAOS = [(26, 10, 42), (52, 20, 72), (86, 34, 110), (124, 52, 156), (166, 72, 204), (210, 120, 240)]
LAIR_EARTH = [(30, 24, 16), (44, 36, 24), (55, 44, 30), (68, 55, 38), (86, 70, 44), (104, 86, 52)]

def L_(w, h):
    return R.Layer(h, w, wrap=False)

def to_img(L):
    rgb = np.clip(L.rgb, 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, np.where(L.a, 255, 0).astype(np.uint8)]), "RGBA")

def ramp(r, v):
    return r[int(np.clip(v, 0, 0.999) * len(r))]

# ---------------------------------------------------------------- ogień
FIRE_W, FIRE_TOP, FIRE_BOT = 132, -78, 230        # płótno: szerokość, wiersz górny/dolny (px pod horyzontem)

def fire_axis(y):
    """Oś rumowiska (lekko po skosie = głębia)."""
    return FIRE_W / 2 + (y - 120) * 0.10

def fire_base(seed=31):
    """Zwęglone belki rzucone w poprzek drogi (od pobocza do pobocza) na łożu żaru i popiołu."""
    rng = np.random.default_rng(seed)
    H = FIRE_BOT - FIRE_TOP
    L = L_(FIRE_W, H)
    oy = -FIRE_TOP                                        # wiersz płótna = y + oy
    n = R.fbm(H, FIRE_W, seed, ((6, 12, 0.6), (2, 3, 0.4)), wrap=False)
    # poświata ognia na ziemi wokół (rzadki dithering ciepłych pikseli)
    by = np.tile(R.BAYER, (H // 4 + 1, FIRE_W // 4 + 1))[:H, :FIRE_W]
    for y in range(10, 230):
        cx = fire_axis(y)
        for x in range(FIRE_W):
            d = np.hypot((x - cx) / 60.0, (y - 120) / 122.0)
            if d < 1 and by[y + oy, x] < (1 - d) ** 1.5 * 0.45:
                L.put(y + oy, x, (150, 86, 40) if by[y + oy, x] < 0.12 else (112, 66, 34))
    # łoże: popiół na brzegach, żar w środku (postrzępione brzegi)
    for y in range(14, 226):
        cx = fire_axis(y); hw = 30 + 6 * np.sin(y * 0.07) + R.persp(y) * 6
        for x in range(int(cx - hw), int(cx + hw) + 1):
            d = abs(x - cx) / hw
            v = n[y + oy, x]
            if d > 0.7 and v < 0.35 + (d - 0.7) * 1.5:
                continue
            if d < 0.55 and v > 0.58:
                c = ramp(EMBER[:4], (v - 0.58) * 3 + (0.55 - d))
            else:
                c = ramp(CHAR, 0.15 + (d * 0.6) + (v - 0.5) * 0.5)
            L.put(y + oy, x, c)
    # belki: bryły z jasną górną ścianą i ciemnym bokiem, na końcach przekrój z żarem
    beams = []
    for i in range(11):
        y0 = rng.uniform(20, 218)
        ln = rng.uniform(30, 64) * (0.7 + R.persp(y0) * 0.5)
        ang = rng.uniform(-0.7, 0.7) + (np.pi / 2 if rng.random() < 0.35 else 0)
        beams.append((y0, ln, ang))
    beams.sort(key=lambda b: b[0])
    for (y0, ln, ang) in beams:
        cx = fire_axis(y0) + rng.uniform(-14, 14)
        th = 4 + R.persp(y0) * 4
        dx, dy = np.cos(ang), np.sin(ang) * 0.45            # spłaszczenie w głąb
        x0, y0b = cx - dx * ln / 2, y0 - dy * ln / 2
        steps = int(ln)
        for k in range(steps):
            px = x0 + dx * k; py = y0b + dy * k
            burnt = (rng.random() < 0.25) or k < 3 or k > steps - 4
            for t in range(int(th) + 2):
                yy = int(py - th + t)
                if t == 0:
                    c = OUTLINE
                elif t < th * 0.45:                          # górna ściana: zwęglone drewno, ciepły odblask
                    c = (92, 62, 40) if not burnt else EMBER[2]
                    if k % 7 == 0:
                        c = (60, 40, 26)
                elif t <= th:
                    c = (44, 30, 20) if k % 6 else CHAR[0]   # bok belki, pęknięcia co kilka pikseli
                    if burnt and rng.random() < 0.3:
                        c = EMBER[2]
                else:
                    c = OUTLINE
                L.put(yy + oy, int(px), c)
        # przekrój na bliższym końcu: słoje i żar
        ex, ey = (x0 + dx * steps, y0b + dy * steps) if dy >= 0 else (x0, y0b)
        for j in range(int(th)):
            L.put(int(ey - th + 1 + j) + oy, int(ex), EMBER[3] if j % 2 else EMBER[2])
    # sterczące, zwęglone słupy (bryły: jasny front, ciemny bok, żarzący się wierzchołek)
    for (py, dx, hg) in ((40, -10, 30), (96, 12, 40), (150, -14, 44), (204, 8, 34)):
        px = fire_axis(py) + dx
        wd = 5 + int(R.persp(py) * 3)
        for k in range(hg):
            yy = py - k
            for j in range(-1, wd + 3):
                if j == -1 or j == wd + 2:
                    c = OUTLINE
                elif j < wd:
                    c = (78, 52, 34) if (k + j) % 5 else (56, 38, 24)          # front
                    if k > hg - 4:
                        c = EMBER[3] if j % 2 else EMBER[2]
                else:
                    c = (36, 24, 16)                                            # bok w cieniu
                L.put(yy + oy, int(px + j), c)
        for j in range(wd + 2):                                                 # cień u podstawy
            L.put(py + 1 + oy, int(px + j + 2), CHAR[0])
    # węgielki i iskry na ziemi
    for _ in range(140):
        y = rng.integers(16, 224); x = int(fire_axis(y) + rng.uniform(-32, 32))
        if L.a[y + oy, x]:
            L.put(y + oy, x, EMBER[rng.integers(1, 5)])
    return to_img(L)

def flame_shape(L, oy, bx, by, hgt, wid, f, s, rng):
    """Jeden język ognia: zwężający się słup z jądrem, falujący w czasie (klatka f, faza s)."""
    ph = 2 * np.pi * f / FIRE_FRAMES
    for k in range(int(hgt)):
        t = k / hgt
        sway = np.sin(ph + s + k * 0.17) * (2 + t * 5) + np.sin(ph * 2 + s * 1.7 + k * 0.31) * t * 2
        hw = wid * (1 - t) ** 0.75 * (0.85 + 0.25 * np.sin(ph + k * 0.4 + s))
        cx = bx + sway
        for x in range(int(cx - hw - 1), int(cx + hw + 2)):
            r = abs(x - cx) / max(hw, 0.6)
            if r > 1.15:
                continue
            heat = (1 - r) * 0.75 + (1 - t) * 0.55 - 0.1
            if r > 0.95:
                c = FLAME[1] if t < 0.75 else FLAME[0]
            else:
                c = ramp(FLAME[1:], heat)
            L.put(int(by - k) + oy, x, c)
    # oderwane języki nad czubkiem
    for j in range(2):
        u = (f / FIRE_FRAMES + j * 0.5 + s * 0.13) % 1.0
        yy = by - hgt - u * hgt * 0.5
        xx = bx + np.sin(ph * 3 + s + j) * 4
        sz = int(2 * (1 - u)) + 1
        for a in range(sz):
            for b in range(sz):
                L.put(int(yy) + a + oy, int(xx) + b, FLAME[3] if u < 0.4 else FLAME[2])

def fire_flames(seed=32):
    """Arkusz klatek płomieni (tylna część rumowiska rysowana najpierw, przednia na wierzchu)."""
    rng = np.random.default_rng(seed)
    H = FIRE_BOT - FIRE_TOP
    oy = -FIRE_TOP
    srcs = []
    for i in range(17):
        y = 22 + i * 12 + rng.uniform(-5, 5)
        srcs.append((fire_axis(y) + rng.uniform(-24, 24), y, (30 + 40 * R.persp(y)) * rng.uniform(0.7, 1.15),
                     (9 + 7 * R.persp(y)) * rng.uniform(0.8, 1.2), rng.uniform(0, 6.28)))
    sheet = Image.new("RGBA", (FIRE_W * FIRE_FRAMES, H))
    for f in range(FIRE_FRAMES):
        L = L_(FIRE_W, H)
        # dym nad pożarem
        for j in range(10):
            u = (f / FIRE_FRAMES + j * 0.1) % 1.0
            sx = FIRE_W / 2 + np.sin(j * 2.1) * 20 + u * 10
            sy = 20 - u * 90
            r = 3 + u * 7
            for a in range(int(-r), int(r) + 1):
                for b in range(int(-r), int(r) + 1):
                    if a * a + b * b <= r * r and (rng.random() < 0.97 - u * 0.4):
                        L.put(int(sy + a) + oy, int(sx + b), SMOKE[0] if a > r * 0.3 else SMOKE[1 + (u < 0.4)])
        for (bx, by, hg, wd, s) in sorted(srcs, key=lambda q: q[1]):
            flame_shape(L, oy, bx, by, hg, wd, f, s, rng)
        sheet.paste(to_img(L), (f * FIRE_W, 0))
    return sheet

# ---------------------------------------------------------------- powalony pień
LOG_W, LOG_TOP, LOG_BOT = 170, -86, 232

def log_img(seed=41):
    """Pień leżący w głąb drogi: bryła korzeni z ziemią z tyłu, walec z korą, przekrój ze słojami z przodu."""
    rng = np.random.default_rng(seed)
    H = LOG_BOT - LOG_TOP
    oy = -LOG_TOP
    L = L_(LOG_W, H)
    D = 46                                                # średnica (px)
    y_back, y_front = 14, 216                             # styk z ziemią: tylny i przedni koniec
    def axis(y):
        return LOG_W / 2 + (y_front - y) * 0.13           # tylny koniec przesunięty w prawo (ukos = głębia)
    # cień na ziemi (po prawej, od światła z lewej-góry)
    for y in range(y_back, y_front + 4):
        cx = axis(y)
        for x in range(int(cx + D / 2 - 2), int(cx + D / 2 + 9)):
            if rng.random() < 0.9:
                L.put(y + oy, x, R.EARTH[0] if x < cx + D / 2 + 5 else R.EARTH[1])
    # bryła korzeni (pionowy dysk ziemi z korzeniami) na tylnym końcu
    rcx, rcy = axis(y_back) + 4, y_back - D * 0.55
    rx, ry = D * 0.95, D * 0.95
    dn = R.fbm(H, LOG_W, seed + 3, ((5, 6, 0.6), (2, 2, 0.4)), wrap=False)
    for y in range(int(rcy - ry - 6), int(rcy + ry * 0.75)):
        for x in range(int(rcx - rx - 6), int(rcx + rx + 6)):
            d = ((x - rcx) / rx) ** 2 + ((y - rcy) / ry) ** 2 + (dn[y + oy, x] - 0.5) * 0.5
            if d < 1.0:
                c = ramp(R.SOIL, 0.25 + (1 - d) * 0.35 + (dn[y + oy, x] - 0.5) * 0.5 - (x - rcx) / rx * 0.15)
                L.put(y + oy, x, c)
            elif d < 1.12:
                L.put(y + oy, x, OUTLINE)
    for _ in range(26):                                   # korzenie sterczące z bryły
        a = rng.uniform(0, 2 * np.pi)
        r0 = rng.uniform(0.3, 0.9)
        x, y = rcx + np.cos(a) * rx * r0, rcy + np.sin(a) * ry * r0
        ln = rng.integers(8, 26); th = rng.uniform(1.0, 2.6)
        for k in range(ln):
            x += np.cos(a) * 1.0 + rng.uniform(-0.4, 0.4); y += np.sin(a) * 0.9 + rng.uniform(-0.4, 0.4)
            t = th * (1 - k / ln)
            for j in range(int(t) + 1):
                L.put(int(y) + j + oy, int(x), BARK[4] if j == 0 else BARK[1])
    for _ in range(8):
        R.pebble(L, rcx + rng.uniform(-rx * 0.6, rx * 0.6), rcy + rng.uniform(-ry * 0.5, ry * 0.5) + oy, rng.uniform(1.5, 3), rng.uniform(1, 2), rng)
    # walec: kora w podłużne bruzdy, światło z lewej-góry
    bn = R.vnoise(H, LOG_W, 40, 2, seed + 5, wrap=False)
    for y in range(int(y_back - D * 0.95), int(y_front - D / 2) + 1):
        cx = axis(y + D / 2)
        for x in range(int(cx - D / 2), int(cx + D / 2) + 1):
            u = (x - cx) / (D / 2)                        # -1 lewy brzeg, 1 prawy
            if abs(u) > 1:
                continue
            shade = 0.62 - u * 0.38 - abs(u) ** 3 * 0.25
            groove = 0.18 if (int(x * 1.0 + bn[y + oy, x] * 6) % 5 == 0) else 0.0
            v = shade - groove + (bn[y + oy, x] - 0.5) * 0.25
            L.put(y + oy, x, ramp(BARK, v))
        L.put(y + oy, int(cx - D / 2) - 1, OUTLINE); L.put(y + oy, int(cx + D / 2) + 1, OUTLINE)
    # mech na grzbiecie i sęki
    for _ in range(40):
        y = rng.uniform(y_back - D * 0.6, y_front - D)
        cx = axis(y + D / 2) - D * 0.18 + rng.uniform(-6, 6)
        for k in range(rng.integers(3, 9)):
            L.put(int(y) + oy, int(cx + k - 3), ramp(MOSS, rng.random()))
    for _ in range(5):
        y = rng.uniform(y_back, y_front - D)
        cx = axis(y + D / 2) + rng.uniform(-D * 0.3, D * 0.3)
        R.pebble(L, cx, y + oy, 2.6, 1.8, rng, ramp=BARK[1:], outline=True)
    # konary sterczące w bok (z przekrojem złamania)
    for side, yy in ((-1, 70), (1, 120), (-1, 160)):
        cx = axis(yy + D / 2) + side * D * 0.4
        ln = rng.integers(18, 30)
        for k in range(ln):
            px = cx + side * k; py = yy - k * 0.35
            for t in range(5):
                c = OUTLINE if t in (0, 4) else (BARK[4] if t == 1 else BARK[2])
                L.put(int(py) + t + oy, int(px), c)
        for t in range(1, 4):
            L.put(int(yy - ln * 0.35) + t + oy, int(cx + side * ln), WOODCUT[3])
    # przekrój (koło) na przednim końcu: słoje, pęknięcia, ciemniejsza kora dookoła
    ccx, ccy = axis(y_front), y_front - D / 2
    for y in range(int(ccy - D / 2) - 1, int(ccy + D / 2) + 2):
        for x in range(int(ccx - D / 2) - 1, int(ccx + D / 2) + 2):
            r = np.hypot(x - ccx, (y - ccy) * 1.06) / (D / 2)
            if r <= 1.0:
                if r > 0.88:
                    c = BARK[1] if r < 0.95 else OUTLINE
                else:
                    ring = (r * 9 + dn[y + oy, x] * 1.2) % 1.0
                    c = WOODCUT[2] if ring < 0.75 else WOODCUT[1]
                    if x - ccx < -D * 0.15 and y - ccy < -D * 0.1:
                        c = WOODCUT[3] if ring < 0.75 else WOODCUT[2]   # oświetlona część
                L.put(y + oy, x, c)
    for _ in range(3):                                    # pęknięcia promieniste
        a = rng.uniform(0, 2 * np.pi)
        for k in range(int(D * 0.38)):
            L.put(int(ccy + np.sin(a) * k) + oy, int(ccx + np.cos(a) * k), WOODCUT[0])
    L.put(int(ccy) + oy, int(ccx), WOODCUT[0])
    # grzyby przy przekroju i trawa u podstawy
    for k in range(3):
        gx, gy = ccx + D * 0.35 + k * 4, ccy + D * 0.3 - k * 3
        L.put(int(gy) + oy, int(gx), (188, 160, 120)); L.put(int(gy) + oy, int(gx) + 1, (188, 160, 120)); L.put(int(gy) + 1 + oy, int(gx), (90, 70, 50))
    for _ in range(30):
        y = rng.uniform(y_back, y_front + 2)
        side = rng.choice([-1, 1])
        R.tuft(L, axis(y) + side * (D / 2 + rng.uniform(-2, 3)), y + oy, rng.integers(1, 3), rng, dry=0.2)
    return to_img(L)

# ---------------------------------------------------------------- przepaść
CH_W, CH_TOP, CH_BOT = 168, -2, 244

def chasm_img(seed=51):
    """Rozpadlina w poprzek drogi: postrzępione skalne krawędzie, oświetlona prawa ściana z warstwami,
    zacieniona lewa, ciemność w głębi, kryształy spaczenia i zwisające korzenie."""
    rng = np.random.default_rng(seed)
    H = CH_BOT - CH_TOP
    oy = -CH_TOP
    L = L_(CH_W, H)
    cx0 = CH_W / 2
    jl = R.vnoise(H, 1, 7, 1, seed, wrap=False)[:, 0]
    jr = R.vnoise(H, 1, 7, 1, seed + 1, wrap=False)[:, 0]
    rn = R.fbm(H, CH_W, seed + 2, ((3, 10, 0.6), (1, 2, 0.4)), wrap=False)
    lips = []
    for y in range(CH_TOP, CH_BOT):
        p = np.clip(y / 26, 0, 1) if y < 26 else 1.0     # zwężenie przy horyzoncie (perspektywa)
        hw = (40 + 14 * p) + (R.persp(y) * 4)
        cx = cx0 + (y - 120) * 0.06
        xl = cx - hw + (jl[y + oy] - 0.5) * 12
        xr = cx + hw + (jr[y + oy] - 0.5) * 12
        wl = 3 + R.persp(y) * 5                            # widoczna szerokość lewej (ciemnej) ściany
        wr = 9 + R.persp(y) * 14                           # prawej (oświetlonej)
        lips.append((y, xl, xr))
        for x in range(int(xl), int(xr) + 1):
            if x < xl + wl:                                # lewa ściana w cieniu
                v = 0.18 + (rn[y + oy, x] - 0.5) * 0.3
                c = ramp(ROCK[:4], v)
            elif x > xr - wr:                              # prawa ściana: warstwy skalne
                u = (xr - x) / wr                          # 0 przy krawędzi, 1 w głębi
                strata = (int((y * 0.9 + x * 0.35 + rn[y + oy, x] * 4)) % 7 == 0)
                v = 0.78 - u * 0.62 + (rn[y + oy, x] - 0.5) * 0.3 - (0.22 if strata else 0)
                c = ramp(ROCK, v)
            else:                                          # głębia: ciemny fiolet -> czerń
                mid = (x - (xl + wl)) / max((xr - wr) - (xl + wl), 1)
                v = 0.30 - abs(mid - 0.5) * 0.5 + (rn[y + oy, x] - 0.5) * 0.12
                c = CHAOS[0] if v > 0.22 else (14, 8, 20)
                if v < 0.1:
                    c = (8, 5, 12)
            L.put(y + oy, x, c)
    # krawędzie: płyty skalne / ziemia drogi pękająca do środka
    for (y, xl, xr) in lips:
        for side, xe in ((-1, xl), (1, xr)):
            lw = 5 + int(R.persp(y) * 4)
            for k in range(lw):
                x = int(xe + side * (k + 1))
                v = 0.55 + (1 - k / lw) * 0.25 + (rn[y + oy, min(max(x, 0), CH_W - 1)] - 0.5) * 0.3
                L.put(y + oy, x, ramp(LAIR_EARTH, v) if k > 1 else ramp(ROCK[2:], v))
            L.put(y + oy, int(xe), OUTLINE)
            L.put(y + 1 + oy, int(xe) - side, ROCK[5] if side < 0 else ROCK[1])
    # pęknięcia w drodze rozchodzące się od krawędzi
    for _ in range(16):
        y0 = rng.integers(8, 236)
        side = rng.choice([-1, 1])
        _, xl, xr = lips[y0 - CH_TOP]
        x = xr if side > 0 else xl
        y = float(y0)
        for k in range(rng.integers(6, 16)):
            x += side * 1; y += rng.uniform(-0.7, 0.7)
            L.put(int(y) + oy, int(x), OUTLINE)
            L.put(int(y) + 1 + oy, int(x), LAIR_EARTH[4])
    # kamienie na krawędziach, kryształy spaczenia w ścianie, zwisające korzenie
    for _ in range(22):
        y = rng.integers(6, 238); side = rng.choice([-1, 1])
        _, xl, xr = lips[y - CH_TOP]
        x = (xr + rng.uniform(2, 9)) if side > 0 else (xl - rng.uniform(2, 9))
        R.pebble(L, x, y + oy, rng.uniform(1.6, 3.6), rng.uniform(1.1, 2.3), rng, ramp=ROCK[1:])
    for _ in range(9):
        y = rng.integers(30, 230)
        _, xl, xr = lips[y - CH_TOP]
        x = xr - rng.uniform(4, 14)
        hgt = rng.integers(4, 9)
        for k in range(hgt):
            for j in range(-(hgt - k) // 3, (hgt - k) // 3 + 1):
                L.put(int(y - k) + oy, int(x + j), CHAOS[min(5, 2 + k * 4 // hgt)] if j <= 0 else CHAOS[2])
    for _ in range(14):
        y = rng.integers(10, 230); side = rng.choice([-1, 1])
        _, xl, xr = lips[y - CH_TOP]
        x = xl + 2 if side < 0 else xr - 2
        for k in range(rng.integers(5, 16)):
            x += side * -0.4 + rng.uniform(-0.4, 0.4)
            L.put(int(y + k) + oy, int(x), BARK[2] if k % 3 else BARK[1])
    return to_img(L)

def chasm_glow(seed=52):
    """Poświata z dna: kilka plam fioletu (dithering), przezroczystość ustawia gra."""
    rng = np.random.default_rng(seed)
    H = CH_BOT - CH_TOP
    L = L_(CH_W, H)
    by = np.tile(R.BAYER, (H // 4 + 1, CH_W // 4 + 1))[:H, :CH_W]
    for i in range(5):
        cy = 30 + i * 46 + rng.uniform(-8, 8)
        cx = CH_W / 2 + (cy - 120) * 0.06 + rng.uniform(-8, 8)
        rx, ry = rng.uniform(14, 22), rng.uniform(5, 9)
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if d < 1 and by[y - CH_TOP, x] > d:
                    L.put(y - CH_TOP, x, CHAOS[4] if d < 0.3 else CHAOS[3])
    return to_img(L)

# ---------------------------------------------------------------- zapis
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default=None)
    a = ap.parse_args()
    P = np.array(Image.open(os.path.join(HERE, "assets/palette/hufduhof_256.png")).convert("RGB")).reshape(-1, 3)
    plab = BP.mp.srgb2lab(P)
    q = lambda im: BP.quantize(im, P, plab)
    R.set_style("stage2_village")
    out = {}
    q(fire_base()).save(os.path.join(OUT, "obstacle_fire.png"))
    q(fire_flames()).save(os.path.join(OUT, "obstacle_fire_flames.png"))
    out["fire"] = {"file": "obstacle_fire.png", "y": FIRE_TOP, "flames": "obstacle_fire_flames.png", "frames": FIRE_FRAMES, "fps": 12}
    R.set_style("stage3_fields_forest")
    q(log_img()).save(os.path.join(OUT, "obstacle_log.png"))
    out["log"] = {"file": "obstacle_log.png", "y": LOG_TOP}
    q(chasm_img()).save(os.path.join(OUT, "obstacle_chasm.png"))
    q(chasm_glow()).save(os.path.join(OUT, "obstacle_chasm_glow.png"))
    out["chasm"] = {"file": "obstacle_chasm.png", "y": CH_TOP, "glow": "obstacle_chasm_glow.png"}
    out["puddle"] = {"file": "obstacle_puddle.png", "center": True}
    man = {"note": "Grafika przeszkód (tools/build_obstacles.py, kałuża: tools/build_road.py). y = wiersz (px pod horyzontem) "
                   "górnej krawędzi PNG, x = środek przeszkody. Strefy kolizji: scripts/level/obstacle.gd (TYPES).",
           "obstacles": out}
    with open(os.path.join(OUT, "obstacles.json"), "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
    for k, v in out.items():
        print(k, v)
    if a.preview:
        os.makedirs(a.preview, exist_ok=True)
        sheet = Image.new("RGBA", (900, 340), (60, 50, 36, 255))
        x = 10
        for f in ("obstacle_fire.png", "obstacle_log.png", "obstacle_chasm.png"):
            im = Image.open(os.path.join(OUT, f)).convert("RGBA")
            sheet.alpha_composite(im, (x, 10))
            if f == "obstacle_fire.png":
                fl = Image.open(os.path.join(OUT, "obstacle_fire_flames.png")).convert("RGBA").crop((0, 0, FIRE_W, im.height))
                sheet.alpha_composite(fl, (x, 10))
            x += im.width + 20
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(os.path.join(a.preview, "obstacles.png"))

if __name__ == "__main__":
    main()
