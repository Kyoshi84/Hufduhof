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
HW_K = 1.0                                         # mnożnik szerokości rozpadliny (szeroka wersja pod most: 2.2)

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
        hw = ((40 + 14 * p) + (R.persp(y) * 4)) * HW_K
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


# ---------------------------------------------------------------- przeszkody-zadania (etap 1 zadań): rysunek tymczasowy
# Płonący wóz (gasić wodą ze studni), barykada (rąbać mocnym atakiem), studnia, most z cegieł, nora szczurów,
# wiaderko i cegła (znajdźki). Proste bryły z obrysem w palecie gry - do podmiany na rysunki autora (te same nazwy plików).
from PIL import ImageDraw
from scipy import ndimage as _ndi

WOOD = [(30, 20, 12), (52, 34, 20), (78, 52, 30), (104, 72, 42), (132, 96, 58), (160, 122, 78)]
STRAW = [(74, 58, 24), (110, 88, 36), (150, 122, 52), (186, 156, 72), (214, 188, 100)]
STONE = [(34, 32, 34), (52, 50, 52), (72, 70, 70), (96, 92, 88), (122, 118, 110), (150, 144, 134)]
BRICK = [(58, 22, 16), (92, 36, 24), (126, 52, 32), (158, 74, 44), (186, 104, 66)]
WATER = [(24, 44, 70), (40, 70, 104), (66, 108, 146), (120, 166, 196)]
IRON = [(30, 30, 34), (58, 58, 64), (96, 96, 104)]
DIRT = [(28, 20, 14), (46, 34, 22), (66, 50, 32), (88, 68, 44), (110, 88, 58)]

def _canvas(w, h):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)

def _outline(im):
    """1 px obrys wokół nieprzezroczystych pikseli (jak w reszcie grafik)."""
    a = np.array(im)
    m = a[..., 3] > 0
    e = _ndi.binary_dilation(m, structure=_ndi.generate_binary_structure(2, 1)) & ~m
    a[e] = OUTLINE + (255,)
    return Image.fromarray(a, "RGBA")

def _noise_tint(im, seed, amt=10):
    """Lekki szum jasności w obrębie kolorów (faktura drewna/kamienia), alfa bez zmian."""
    rng = np.random.default_rng(seed)
    a = np.array(im).astype(int)
    n = rng.integers(-amt, amt + 1, a.shape[:2])
    for c in range(3):
        a[..., c] = np.clip(a[..., c] + n, 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")

# płonący wóz: dyszel i skrzynia ustawione w poprzek drogi (oś = głębia), koła po bliższej (lewej) stronie,
# na wozie sterta siana. Wiersze płótna: CART_TOP.. (px pod horyzontem).
CART_W, CART_TOP, CART_BOT = 104, -60, 236

def _cart(burnt):
    H = CART_BOT - CART_TOP
    im, d = _canvas(CART_W, H)
    oy = -CART_TOP
    ax = lambda y: CART_W / 2 + (y - 120) * 0.10
    y0, y1 = 16, 222
    side = 30 if not burnt else 16                         # wysokość burty
    # cień
    d.polygon([(ax(y0) - 26, y0 + oy + 4), (ax(y0) + 30, y0 + oy + 4), (ax(y1) + 34, y1 + oy + 6), (ax(y1) - 24, y1 + oy + 6)], fill=CHAR[1])
    # bok skrzyni (lewy, widoczny) i wierzch
    for y in range(y0, y1):
        x = ax(y)
        top = y + oy - side
        col = WOOD[2] if not burnt else CHAR[2]
        if (y // 9) % 2 == 0:
            col = WOOD[3] if not burnt else CHAR[3]
        d.line([(x - 22, top), (x - 22, y + oy)], fill=WOOD[1] if not burnt else CHAR[1])
        d.line([(x - 21, top), (x + 21, top)], fill=col)
        if burnt and (y * 7) % 11 < 3:
            d.point((x + ((y * 13) % 30) - 15, top), fill=EMBER[1])
    # deski wzdłuż burty
    for k in range(3):
        yy = lambda y: y + oy - side + 6 + k * (side // 3)
        d.line([(ax(y0) - 22, yy(y0)), (ax(y1) - 22, yy(y1))], fill=WOOD[0])
    # koła (z boku, widziane pod kątem: wąska elipsa) i oś
    for wy in (52, 188):
        x = ax(wy) - 24
        r = 26 if not burnt else 18
        d.ellipse([x - 6, wy + oy - r, x + 6, wy + oy + r // 3], outline=WOOD[0] if not burnt else CHAR[0], width=3, fill=None)
        d.ellipse([x - 2, wy + oy - r // 3 - 3, x + 2, wy + oy - r // 3 + 3], fill=IRON[2])
        for k in range(6):
            yy = wy + oy - r // 3 + int(np.sin(k) * r * 0.6)
            d.line([(x, wy + oy - r // 3), (x + int(np.cos(k * 1.05) * 4), yy)], fill=WOOD[1] if not burnt else CHAR[1])
    # dyszel ku przodowi
    d.line([(ax(y1) - 4, y1 + oy - 6), (ax(y1) + 6, y1 + oy + 12)], fill=WOOD[1] if not burnt else CHAR[1], width=3)
    if not burnt:
        # siano na wozie: kopiec po całej długości (żar na wierzchu)
        for y in range(y0 + 6, y1 - 4):
            x = ax(y)
            hh = 18 + 10 * np.sin((y - y0) / (y1 - y0) * np.pi) + 4 * np.sin(y * 0.4)
            top = y + oy - side - hh
            for k in range(int(hh)):
                t = k / max(hh, 1)
                c = STRAW[min(4, int(t * 4 + ((y * 3 + k) % 5) * 0.2))]
                if k > hh - 4:
                    c = EMBER[(y + k) % 3]
                d.point((x - 18 + ((y * 5 + k * 3) % 36), top + hh - k), fill=c)
            d.line([(x - 18, top + hh), (x + 18, top + hh)], fill=STRAW[1])
    else:
        # zwęglone resztki: kilka sterczących belek, popiół, dym w grze
        for k, y in enumerate((40, 84, 132, 176, 210)):
            x = ax(y) + (k % 2) * 8 - 4
            d.line([(x, y + oy - side), (x + 3, y + oy - side - 12 - k % 3 * 5)], fill=CHAR[2], width=3)
            d.point((x + 3, y + oy - side - 12 - k % 3 * 5), fill=EMBER[0])
    im = _noise_tint(im, 61 if not burnt else 62, 8)
    return _outline(im)

# barykada: palisada zaostrzonych pali i skrzyń w poprzek drogi; 4 stany wysokości (rąbanie mocnym atakiem)
BAR_W, BAR_TOP, BAR_BOT = 120, -126, 238
BAR_STATES = (150, 110, 70, 30)                           # wysokość w jednostkach świata (obstacle.gd: TYPES.barricade)

def _barricade(h_world, seed=71):
    """Kozły z zaostrzonych pali (skrzyżowane na krzyż) na grubej belce biegnącej w poprzek drogi."""
    rng = np.random.default_rng(seed)
    H = BAR_BOT - BAR_TOP
    im, d = _canvas(BAR_W, H)
    oy = -BAR_TOP
    ax = lambda y: BAR_W / 2 + (y - 120) * 0.10
    hp = h_world / (4.0 / 3.0)                              # px
    chopped = h_world < 150
    # cień na ziemi
    d.polygon([(ax(8) - 30, 8 + oy), (ax(8) + 34, 8 + oy), (ax(230) + 38, 230 + oy), (ax(230) - 26, 230 + oy)], fill=CHAR[1])
    # tylna belka (za kozłami)
    def beam(hb, col, w):
        d.line([(ax(6), 6 + oy - hb), (ax(230), 230 + oy - hb)], fill=WOOD[0], width=w + 2)
        d.line([(ax(6), 6 + oy - hb), (ax(230), 230 + oy - hb)], fill=col, width=w)
    if hp > 30:
        beam(min(hp * 0.42, 40), WOOD[2], 6)
    ys = list(range(14, 228, 26))
    for y in ys:
        x = ax(y) + rng.uniform(-2, 2)
        t = 4 + int(R.persp(y) * 2)
        for sgn in (-1, 1):
            x0, y0 = x - sgn * 26, y + oy
            x1, y1 = x + sgn * 22, y + oy - hp * rng.uniform(0.9, 1.04)
            d.line([(x0, y0), (x1, y1)], fill=WOOD[0], width=t + 2)
            d.line([(x0, y0), (x1, y1)], fill=WOOD[2] if sgn < 0 else WOOD[3], width=t)
            d.line([(x0 - 1, y0), (x1 - 1, y1)], fill=WOOD[4], width=1)
            if not chopped:
                d.polygon([(x1 - 3, y1 + 2), (x1 + 3, y1 + 2), (x1 + sgn * 4, y1 - 8)], fill=WOOD[3])
            else:
                for j in range(-3, 4):
                    d.point((x1 + j, y1 - abs(j * 5 + y) % 3), fill=WOODCUT[3] if j % 2 else WOODCUT[2])
    # przednia belka spinająca kozły
    if hp > 30:
        beam(min(hp * 0.3, 28), WOOD[3], 5)
    # wióry na ziemi po rąbaniu
    if chopped:
        for _ in range(int((150 - h_world) * 1.2)):
            y = rng.integers(14, 230)
            x = ax(y) + rng.uniform(-36, 36)
            d.point((x, y + oy + 2), fill=WOODCUT[rng.integers(1, 4)])
    im = _noise_tint(im, seed + int(h_world), 6)
    return _outline(im)

# studnia z daszkiem i korbą (stoi przy tylnej krawędzi drogi, nie blokuje)
WELL_W, WELL_H = 72, 104

def _well():
    im, d = _canvas(WELL_W, WELL_H)
    cx = WELL_W // 2
    base = WELL_H - 4
    # cembrowina: kamienny walec
    d.ellipse([cx - 26, base - 14, cx + 26, base + 2], fill=STONE[2])
    d.rectangle([cx - 26, base - 34, cx + 26, base - 6], fill=STONE[3])
    for r in range(4):
        for c in range(6):
            x = cx - 26 + c * 9 + (4 if r % 2 else 0)
            y = base - 34 + r * 7
            d.rectangle([x, y, x + 7, y + 5], fill=STONE[3 + (r + c) % 3 - 1])
            d.line([(x, y + 6), (x + 8, y + 6)], fill=STONE[1])
    d.ellipse([cx - 26, base - 42, cx + 26, base - 26], fill=STONE[4])
    d.ellipse([cx - 21, base - 39, cx + 21, base - 29], fill=WATER[0])
    # słupy, daszek, korba
    for sx in (-24, 22):
        d.rectangle([cx + sx, base - 84, cx + sx + 3, base - 34], fill=WOOD[2])
    d.polygon([(cx - 34, base - 78), (cx, base - 100), (cx + 34, base - 78)], fill=WOOD[1])
    d.polygon([(cx - 30, base - 80), (cx, base - 96), (cx + 30, base - 80)], fill=STRAW[1])
    d.line([(cx - 22, base - 66), (cx + 22, base - 66)], fill=WOOD[0], width=3)
    d.line([(cx, base - 64), (cx, base - 46)], fill=STRAW[2])
    d.rectangle([cx - 4, base - 48, cx + 4, base - 40], fill=WOOD[3])
    im = _noise_tint(im, 81, 6)
    return _outline(im)

# most z cegieł: pokład na całą głębię drogi; gra odsłania go odcinkami (każda cegła = 1/5 szerokości)
BRIDGE_W, BRIDGE_TOP, BRIDGE_BOT = 260, -2, 238

def _bridge(seed=91):
    """Pokład z cegieł (warstwy wzdłuż kierunku marszu) z niskimi murkami po tylnej i przedniej krawędzi."""
    rng = np.random.default_rng(seed)
    H = BRIDGE_BOT - BRIDGE_TOP
    im, d = _canvas(BRIDGE_W, H)
    oy = -BRIDGE_TOP
    top, bot = 14, 222
    y = top
    row = 0
    while y < bot:
        bh = 5 + int(R.persp(y) * 4)                       # bliżej = grubsze warstwy (perspektywa)
        bw = 14 + int(R.persp(y) * 8)
        off = (row % 2) * (bw // 2)
        for x in range(-off, BRIDGE_W, bw):
            c = BRICK[rng.integers(1, 4)]
            d.rectangle([x + 1, y + oy + 1, x + bw - 1, y + oy + bh - 1], fill=c)
            d.line([(x + 1, y + oy + 1), (x + bw - 2, y + oy + 1)], fill=BRICK[4])
        d.line([(0, y + oy), (BRIDGE_W - 1, y + oy)], fill=STONE[1])
        y += bh
        row += 1
    # murki: tylny (widać przednią ścianę) i przedni (widać wierzch)
    d.rectangle([0, top - 10 + oy, BRIDGE_W - 1, top + oy], fill=STONE[2])
    d.line([(0, top - 10 + oy), (BRIDGE_W - 1, top - 10 + oy)], fill=STONE[4])
    for x in range(0, BRIDGE_W, 12):
        d.line([(x, top - 9 + oy), (x, top + oy)], fill=STONE[1])
    d.rectangle([0, bot + oy, BRIDGE_W - 1, bot + 8 + oy], fill=STONE[4])
    d.rectangle([0, bot + 9 + oy, BRIDGE_W - 1, bot + 15 + oy], fill=STONE[2])
    for x in range(0, BRIDGE_W, 16):
        d.line([(x, bot + 9 + oy), (x, bot + 15 + oy)], fill=STONE[1])
    return _outline(im)

# nora szczuroludzi: kopiec ziemi z czarną dziurą, deski, kości; wersja zawalona
HOLE_W, HOLE_H = 76, 40

def _rat_hole(broken, seed=101):
    rng = np.random.default_rng(seed)
    im, d = _canvas(HOLE_W, HOLE_H)
    cx, cy = HOLE_W // 2, HOLE_H - 12
    d.ellipse([cx - 36, cy - 14, cx + 36, cy + 10], fill=DIRT[2])
    d.ellipse([cx - 30, cy - 18, cx + 30, cy + 4], fill=DIRT[3])
    if not broken:
        d.ellipse([cx - 16, cy - 12, cx + 16, cy + 2], fill=(8, 6, 6))
        d.ellipse([cx - 13, cy - 11, cx + 13, cy - 2], fill=(4, 3, 3))
        d.point((cx - 5, cy - 6), fill=(200, 40, 30)); d.point((cx - 2, cy - 6), fill=(200, 40, 30))   # oczy w ciemności
        for k in range(3):                                                                         # podpory z desek
            x = cx - 18 + k * 18
            d.line([(x, cy - 16), (x + 3, cy + 2)], fill=WOOD[2], width=2)
    else:
        for _ in range(40):
            x = cx + rng.uniform(-18, 18); y = cy + rng.uniform(-10, 2)
            d.point((x, y), fill=STONE[rng.integers(1, 5)])
        d.line([(cx - 20, cy - 2), (cx + 18, cy - 8)], fill=WOOD[1], width=2)
    for _ in range(12):
        x = cx + rng.uniform(-34, 34); y = cy + rng.uniform(-6, 8)
        d.point((x, y), fill=DIRT[rng.integers(0, 2)])
    d.line([(cx + 22, cy + 4), (cx + 30, cy + 2)], fill=(200, 190, 170))                            # kość
    im = _noise_tint(im, seed + broken, 6)
    return _outline(im)

def _bucket():
    im, d = _canvas(24, 26)
    d.polygon([(3, 8), (20, 8), (18, 24), (5, 24)], fill=WOOD[3])
    for x in (7, 11, 15):
        d.line([(x, 9), (x, 23)], fill=WOOD[2])
    d.line([(3, 12), (20, 12)], fill=IRON[1], width=2); d.line([(4, 20), (19, 20)], fill=IRON[1], width=2)
    d.ellipse([3, 5, 20, 11], fill=WATER[2]); d.line([(7, 7), (12, 7)], fill=WATER[3])
    d.arc([3, -2, 20, 14], 180, 360, fill=IRON[2], width=2)
    return _outline(im)

def _brick():
    im, d = _canvas(26, 16)
    d.polygon([(1, 6), (17, 1), (24, 4), (24, 11), (8, 15), (1, 12)], fill=BRICK[2])
    d.polygon([(1, 6), (17, 1), (24, 4), (8, 9)], fill=BRICK[4])
    d.line([(8, 9), (8, 15)], fill=BRICK[1])
    d.point((13, 11), fill=BRICK[1]); d.point((18, 9), fill=BRICK[3])
    return _outline(im)

def puzzle_art(q):
    """Zapisuje grafiki przeszkód-zadań, zwraca wpisy do obstacles.json."""
    global CH_W, HW_K
    out = {}
    q(_cart(False)).save(os.path.join(OUT, "obstacle_cart.png"))
    q(_cart(True)).save(os.path.join(OUT, "obstacle_cart_wreck.png"))
    out["burning_cart"] = {"file": "obstacle_cart.png", "wreck": "obstacle_cart_wreck.png", "y": CART_TOP,
                           "flames": "obstacle_fire_flames.png", "frames": FIRE_FRAMES, "fps": 12, "flames_y": FIRE_TOP - 40}
    states = []
    for i, hw in enumerate(BAR_STATES):
        f = "obstacle_barricade_%d.png" % i
        q(_barricade(hw)).save(os.path.join(OUT, f))
        states.append({"h": hw, "file": f})
    out["barricade"] = {"file": states[0]["file"], "y": BAR_TOP, "states": states}
    q(_well()).save(os.path.join(OUT, "obstacle_well.png"))
    out["well"] = {"file": "obstacle_well.png", "y": -WELL_H + 6}
    q(_bridge()).save(os.path.join(OUT, "obstacle_bridge.png"))
    out["bridge"] = {"file": "obstacle_bridge.png", "y": BRIDGE_TOP}
    q(_rat_hole(False)).save(os.path.join(OUT, "rat_hole.png"))
    q(_rat_hole(True)).save(os.path.join(OUT, "rat_hole_broken.png"))
    q(_bucket()).save(os.path.join(OUT, "bucket.png"))
    q(_brick()).save(os.path.join(OUT, "brick.png"))
    # szeroka rozpadlina pod most (ten sam rysunek co przepaść, ~2.2x szerzej)
    old = (CH_W, HW_K)
    CH_W, HW_K = 360, 2.2
    q(chasm_img(seed=53)).save(os.path.join(OUT, "obstacle_chasm_wide.png"))
    q(chasm_glow(seed=54)).save(os.path.join(OUT, "obstacle_chasm_wide_glow.png"))
    CH_W, HW_K = old
    out["chasm_bridge"] = {"file": "obstacle_chasm_wide.png", "y": CH_TOP, "glow": "obstacle_chasm_wide_glow.png"}
    return out

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
    out.update(puzzle_art(q))
    man = {"note": "Grafika przeszkód (tools/build_obstacles.py, kałuża: tools/build_road.py). y = wiersz (px pod horyzontem) "
                   "górnej krawędzi PNG, x = środek przeszkody. Strefy kolizji: scripts/level/obstacle.gd (TYPES).",
           "obstacles": out}
    with open(os.path.join(OUT, "obstacles.json"), "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
    for k, v in out.items():
        print(k, v)
    if a.preview:
        os.makedirs(a.preview, exist_ok=True)
        sheet = Image.new("RGBA", (1100, 380), (60, 50, 36, 255))
        x = 10
        for f in ("obstacle_fire.png", "obstacle_log.png", "obstacle_chasm.png", "obstacle_cart.png", "obstacle_barricade_0.png", "obstacle_well.png"):
            im = Image.open(os.path.join(OUT, f)).convert("RGBA")
            sheet.alpha_composite(im, (x, 10))
            if f == "obstacle_fire.png":
                fl = Image.open(os.path.join(OUT, "obstacle_fire_flames.png")).convert("RGBA").crop((0, 0, FIRE_W, im.height))
                sheet.alpha_composite(fl, (x, 10))
            x += im.width + 20
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(os.path.join(a.preview, "obstacles.png"))

if __name__ == "__main__":
    main()
