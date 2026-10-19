#!/usr/bin/env python3
"""Buduje rekwizyty (props) wszystkich etapów w stylu panoramy Hufduhofu i wkłada je tam, gdzie gra ich szuka:
    assets/stages/<etap>/props/<nazwa>.png (+ warianty <nazwa>_2.png)
Pliki źródłowe (wycięcia z panoramy w pełnej rozdzielczości albo powiększony podgląd wygenerowanych) trafiają do:
    assets/stages/source/elements/<etap>/<nazwa>/<nazwa>_source.png

  python3 tools/build_props.py                 # wszystko
  python3 tools/build_props.py --preview DIR   # dodatkowo arkusze podglądu (powiększone)
  python3 tools/build_props.py --only barrel,well

Chata, wóz i studnia to wycięcia z panoramy (maska wielokąta + GrabCut); reszta jest rysowana kodem (tools/pixart.py)
rampami kolorów z panoramy i ciemnym konturem. Wszystko jest dopasowywane do palety 256 (bez ditheringu, alfa 0/255)."""
import argparse, os, sys
import numpy as np
import cv2
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixart import Canvas, RAMPS, OUTLINE
import importlib.util

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(HERE, "assets/stages/source/hufduhof_panorama.png")
spec = importlib.util.spec_from_file_location("mp", os.path.join(HERE, "tools/make_palette.py"))
mp = importlib.util.module_from_spec(spec); spec.loader.exec_module(mp)

LIGHT = np.array([-0.55, -0.8]); LIGHT = LIGHT / np.linalg.norm(LIGHT)

# ------------------------------------------------------------------------------------------ wspólne elementy
def crown(c, cx, cy, rx, ry, ramp, seed, n, rmin, rmax):
    """Korona z kęp liści/igieł: koła cieniowane od strony światła, ciemny rąb od dołu-prawej."""
    rng = np.random.default_rng(seed)
    pts = []
    for _ in range(n):
        a = rng.random() * 2 * np.pi; d = np.sqrt(rng.random())
        pts.append((cx + np.cos(a) * rx * d, cy + np.sin(a) * ry * d, rmin + rng.random() * (rmax - rmin)))
    pts.sort(key=lambda p: p[1])
    yy, xx = np.mgrid[0:c.h, 0:c.w]
    for (x, y, r) in pts:
        m = c.ellipse(x, y, r, r * 0.9)
        px = (xx - x) / r; py = (yy - y) / r
        s = 0.5 + 0.55 * (px * LIGHT[0] + py * LIGHT[1])
        c.paint(m, ramp, s, 0.18)
        rim = m & ~c.ellipse(x - 1.3, y - 1.6, r, r * 0.9)
        c.paint(rim, ramp, 0.0, 0.0)

def trunk(c, x_bottom, y_bottom, y_top, w_bottom, w_top, ramp="wood", flare=3, lean=0.0, seed=0):
    rng = np.random.default_rng(seed)
    pts_l, pts_r = [], []
    steps = int(y_bottom - y_top) + 1
    for i in range(steps):
        t = i / max(1, steps - 1)
        y = y_bottom - i
        w = w_bottom + (w_top - w_bottom) * t + (flare * (1 - t) ** 3)
        cx = x_bottom + lean * t * (y_bottom - y_top) + np.sin(t * 5 + seed) * 1.0
        pts_l.append((cx - w / 2, y)); pts_r.append((cx + w / 2, y))
    poly = pts_l + pts_r[::-1]
    m = c.poly(poly)
    yy, xx = np.mgrid[0:c.h, 0:c.w]
    # cieniowanie poprzeczne (lewa strona jasna) + słoje pionowe
    xs = np.array([p[0] for p in poly]); cxm = xs.mean()
    s = 0.72 - (xx - (x_bottom - w_bottom / 2)) / max(1.0, w_bottom + flare * 2) * 0.9
    s += ((xx % 3 == 0) * -0.08)
    c.paint(m, ramp, s, 0.15)
    return m

def branch_line(c, p0, p1, w0, w1, ramp="dry", shade=0.6):
    n = int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1]))) + 1
    for i in range(n + 1):
        t = i / max(1, n)
        x = p0[0] + (p1[0] - p0[0]) * t; y = p0[1] + (p1[1] - p0[1]) * t
        w = w0 + (w1 - w0) * t
        m = c.ellipse(x, y, w / 2, w / 2)
        c.paint(m, ramp, shade - 0.25 * (1 - t) * 0 - (w / 8.0) * 0.1, 0.2)

# ------------------------------------------------------------------------------------------ drzewa i krzewy
def tree_oak(w, h, seed=1, tint=None):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    tx = w / 2 + (seed % 3 - 1) * 2
    trunk(c, tx, h - 2, h * 0.52, w * 0.13, w * 0.09, "wood", flare=6, lean=-0.03 + 0.02 * (seed % 3), seed=seed)
    # konary w koronę
    branch_line(c, (tx, h * 0.62), (tx - w * 0.18, h * 0.42), 5, 3, "wood", 0.5)
    branch_line(c, (tx, h * 0.60), (tx + w * 0.2, h * 0.40), 5, 3, "wood", 0.45)
    crown(c, tx, h * 0.34, w * 0.36, h * 0.2, "oak", seed, 26, w * 0.09, w * 0.15)
    c.outline()
    return c.image()

def tree_dead(w, h, seed=1):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    rng = np.random.default_rng(seed + 10)
    tx = w / 2
    trunk(c, tx, h - 2, h * 0.45, w * 0.12, w * 0.05, "dry", flare=5, lean=0.02 * (seed % 3 - 1), seed=seed)
    def br(p, ang, ln, wd, depth):
        if depth == 0 or ln < 4:
            return
        q = (p[0] + np.cos(ang) * ln, p[1] - np.sin(ang) * ln)
        while (q[0] < 4 or q[0] > w - 5 or q[1] < 4) and ln > 3:     # nie wychodzimy poza płótno
            ln *= 0.85
            q = (p[0] + np.cos(ang) * ln, p[1] - np.sin(ang) * ln)
        branch_line(c, p, q, wd, max(1.2, wd * 0.6), "dry", 0.6)
        for k in range(2):
            a2 = ang + (rng.random() - 0.5) * 1.5 + (0.5 if k else -0.5)
            br(q, a2, ln * (0.62 + rng.random() * 0.15), wd * 0.65, depth - 1)
    top = (tx, h * 0.5)
    for ang, ln in ((1.9, h * 0.24), (1.2, h * 0.24), (1.55, h * 0.3), (2.5, h * 0.18), (0.7, h * 0.18)):
        br((top[0], top[1] + rng.random() * 8), ang + (rng.random() - 0.5) * 0.2, ln, 4.0, 3)
    c.outline()
    return c.image()

def tree_pine(w, h, seed=1):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    rng = np.random.default_rng(seed)
    tx = w / 2
    trunk(c, tx, h - 2, h * 0.8, w * 0.1, w * 0.07, "wood", flare=3, seed=seed)
    tiers = 6
    yy, xx = np.mgrid[0:c.h, 0:c.w]
    for k in range(tiers):
        top = 3 + k * (h * 0.78 / tiers) * 0.95
        bot = top + h * 0.78 / tiers * 1.7
        half = w * (0.16 + 0.34 * (k + 1) / tiers)
        pts = [(tx, top)]
        n = 7
        for i in range(n + 1):  # prawa krawędź poszarpana
            t = i / n
            pts.append((tx + half * (0.2 + 0.8 * t) + (rng.random() - 0.5) * 3 * (i % 2), top + (bot - top) * t))
        for i in range(n, -1, -1):
            t = i / n
            pts.append((tx - half * (0.2 + 0.8 * t) - (rng.random() - 0.5) * 3 * (i % 2), top + (bot - top) * t))
        m = c.poly(pts)
        s = 0.55 + 0.5 * (-(xx - tx) / max(1.0, half)) * 0.8 - 0.25 * (yy - top) / max(1.0, bot - top)
        c.paint(m, "pine", s, 0.2)
        under = m & ~c.poly([(x, y - 2.2) for (x, y) in pts])
        c.paint(under, "pine", 0.02, 0.0)
    c.outline()
    return c.image()

def tree_twisted(w, h, seed=1):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    rng = np.random.default_rng(seed)
    # skręcony pień: sinusoida
    pts = []
    for i in range(int(h * 0.62)):
        t = i / (h * 0.62)
        x = w / 2 + np.sin(t * 6.0 + seed) * (w * 0.07) * (1 - t * 0.4)
        wd = (w * 0.11) * (1 - t * 0.62)
        pts.append((x, h - 2 - i, wd))
    for (x, y, wd) in pts:
        m = c.rect(x - wd / 2, y, x + wd / 2 + 1, y + 1)
        c.paint(m, "dry", 0.7 - (np.arange(c.w)[None, :] - (x - wd / 2)) / max(1.0, wd) * 0.7, 0.2)
    def br(p, ang, ln, wd, depth):
        if depth == 0 or ln < 4:
            return
        ang += 0.35 * np.sin(ln) * (1 if rng.random() < 0.5 else -1)
        q = (p[0] + np.cos(ang) * ln, p[1] - np.sin(ang) * ln)
        while (q[0] < 4 or q[0] > w - 5 or q[1] < 4) and ln > 3:
            ln *= 0.85
            q = (p[0] + np.cos(ang) * ln, p[1] - np.sin(ang) * ln)
        branch_line(c, p, q, wd, max(1.5, wd * 0.6), "dry", 0.6)
        for k in range(2):
            br(q, ang + (rng.random() - 0.5) * 1.4 + (0.6 if k else -0.6), ln * 0.7, wd * 0.66, depth - 1)
        if depth == 1 and rng.random() < 0.7:   # fioletowa poświata na końcach gałęzi
            c.flat(c.ellipse(q[0], q[1], 1.5, 1.5), RAMPS["purple"][3])
    top = (pts[-1][0], pts[-1][1] + 4)
    for ang, ln in ((1.9, h * 0.22), (1.3, h * 0.24), (1.6, h * 0.28), (2.5, h * 0.17), (0.7, h * 0.17)):
        br(top, ang, ln, 4.0, 3)
    # sęk z fioletowym "okiem"
    c.flat(c.ellipse(w / 2 + 1, h * 0.7, 3, 2.2), RAMPS["purple"][1])
    c.flat(c.ellipse(w / 2 + 1, h * 0.7, 1.2, 1.0), RAMPS["purple"][4])
    c.outline()
    return c.image()

def bush(w, h, seed=1):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    crown(c, w / 2, h * 0.55, w * 0.38, h * 0.3, "bush", seed, 11, w * 0.12, w * 0.2)
    rng = np.random.default_rng(seed + 3)
    for _ in range(4):   # jagody
        x = rng.integers(int(w * 0.25), int(w * 0.75)); y = rng.integers(int(h * 0.3), int(h * 0.75))
        if c.a[y, x]:
            c.flat(c.rect(x, y, x + 2, y + 2), RAMPS["red"][2])
    c.outline()
    return c.image()

def stone(w, h, seed=1):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    rng = np.random.default_rng(seed)
    cx, cy = w / 2, h * 0.58
    pts = []
    n = 11
    for i in range(n):
        a = i / n * 2 * np.pi
        rx = w * (0.44 + rng.random() * 0.06); ry = h * (0.42 + rng.random() * 0.08)
        pts.append((cx + np.cos(a) * rx, min(h - 2, cy + np.sin(a) * ry * (1.0 if np.sin(a) < 0 else 0.7))))
    m = c.poly(pts)
    c.volume(m, "stone", bulge=5.0, noise=0.2, base=0.55)
    for _ in range(3):  # pęknięcia
        x = rng.integers(int(w * 0.25), int(w * 0.7)); y = rng.integers(int(h * 0.3), int(h * 0.7))
        for k in range(rng.integers(5, 10)):
            if m[min(h - 1, y), min(w - 1, x)]:
                c.rgb[y, x] = RAMPS["stone"][0]
            x += int(rng.integers(0, 2)); y += int(rng.integers(0, 2))
    top = m & (np.mgrid[0:h, 0:w][0] < cy - h * 0.12) & ((np.mgrid[0:h, 0:w][1] % 3) < 2)
    c.paint(top & (c.rng.random((h, w)) < 0.45), "moss", 0.45, 0.3)
    c.outline()
    return c.image()

def milestone(w, h, seed=1):
    c = Canvas(w, h)
    m = c.poly([(w * 0.12, h - 2), (w * 0.16, h * 0.34), (w * 0.3, h * 0.14), (w * 0.82, h * 0.2), (w * 0.88, h * 0.4), (w * 0.9, h - 2)])
    c.volume(m, "stone", bulge=4.0, noise=0.2)
    base = c.rect(w * 0.1, h - 6, w * 0.92, h - 1)
    c.paint(base & ~m, "stone", 0.3, 0.2)
    yy, xx = np.mgrid[0:h, 0:w]
    c.paint(m & (yy > h - 9) & (c.rng.random((h, w)) < 0.6), "moss", 0.4, 0.3)
    # wykuty znak: poziome kreski i X
    for k in range(5):     # wykuty znak (strzałka)
        c.rgb[int(h * 0.5) + k // 2, int(w * 0.3) + k * 2:int(w * 0.3) + k * 2 + 2] = RAMPS["stone"][0]
    c.rgb[int(h * 0.42), int(w * 0.36):int(w * 0.62)] = RAMPS["stone"][0]
    c.outline()
    return c.image()

def stump_axe(w, h, seed=1):
    c = Canvas(w, h)
    cx = w * 0.42
    body = c.rect(cx - 9, h * 0.5, cx + 10, h - 2) | c.ellipse(cx, h - 3, 9.5, 2.5)
    yy, xx = np.mgrid[0:h, 0:w]
    c.paint(body, "wood", 0.75 - (xx - (cx - 9)) / 19.0 * 0.8 + ((xx % 3) == 0) * -0.1, 0.2)
    top = c.ellipse(cx, h * 0.5, 10, 4)
    c.paint(top, "woodpale", 0.7 - ((xx - cx) ** 2 / 100.0 + (yy - h * 0.5) ** 2 / 16.0) * 0.5, 0.1)
    for r in (3, 6):   # słoje
        ring = c.ellipse(cx, h * 0.5, r, r * 0.4) & ~c.ellipse(cx, h * 0.5, r - 1, (r - 1) * 0.4)
        c.paint(ring, "woodpale", 0.2, 0.0)
    # topór wbity w pieniek
    handle = c.line((cx + 5, h * 0.5), (cx + 14, h * 0.08), 3)
    c.paint(handle, "wood", 0.6 - ((xx - cx) % 3) * 0.1, 0.15)
    head = c.poly([(cx + 1, h * 0.46), (cx + 8, h * 0.4), (cx + 9, h * 0.52), (cx + 2, h * 0.58)])
    c.paint(head, "iron", 0.7 - (xx - cx) * 0.02, 0.1)
    c.flat(c.rect(cx + 1, h * 0.46, cx + 3, h * 0.58), RAMPS["iron"][4])
    c.outline()
    return c.image()

# ------------------------------------------------------------------------------------------ konstrukcje drewniane
def post(c, x, y0, y1, wd=5, lean=0.0, cap=True):
    pts = [(x - wd / 2, y1), (x - wd / 2 + lean, y0), (x + wd / 2 + lean, y0), (x + wd / 2, y1)]
    m = c.poly(pts)
    yy, xx = np.mgrid[0:c.h, 0:c.w]
    c.paint(m, "wood", 0.8 - (xx - (x - wd / 2)) / max(1.0, wd) * 0.9, 0.18)
    if cap:
        c.paint(c.rect(x - wd / 2 + lean, y0, x + wd / 2 + lean + 1, y0 + 2) & m, "woodpale", 0.8, 0.1)
    return m

def rail(c, p0, p1, th=3.0):
    pts = [(p0[0], p0[1] - th / 2), (p1[0], p1[1] - th / 2), (p1[0], p1[1] + th / 2), (p0[0], p0[1] + th / 2)]
    m = c.poly(pts)
    yy, xx = np.mgrid[0:c.h, 0:c.w]
    c.paint(m, "wood", 0.9 - (yy - (p0[1] - th / 2)) / max(1.0, th) * 0.8, 0.15)
    return m

def fence(w, h, n=4, broken=False, seed=1):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    rng = np.random.default_rng(seed)
    step = (w - 8) / (n - 1)
    xs = [4 + i * step for i in range(n)]
    top = h * 0.12
    # szczeble (za słupkami)
    ry = (h * 0.38, h * 0.7)
    for j, y in enumerate(ry):
        for i in range(n - 1):
            if broken and ((i == 1 and j == 0) or (i == n - 2 and j == 1 and n > 3)):
                # złamany szczebel zwisa jednym końcem
                if (i + j) % 2:
                    rail(c, (xs[i], y), (xs[i] + step * 0.5, y + 9), 3)
                else:
                    rail(c, (xs[i + 1] - step * 0.5, y + 8), (xs[i + 1], y), 3)
                continue
            rail(c, (xs[i], y), (xs[i + 1], y + (1 if broken and i % 2 else 0)), 3)
    for i, x in enumerate(xs):
        if broken and i == n // 2:
            post(c, x + 2, top + 10, h - 2, 5, lean=-5, cap=True)      # przechylony i złamany słupek
        elif broken and i == n - 1 and n > 3:
            post(c, x, top + 5, h - 2, 5, cap=True)
        else:
            post(c, x, top + (rng.random() * 2), h - 2, 5)
    c.outline()
    return c.image()

def gate(w, h, seed=1):
    c = Canvas(w, h)
    post(c, 5, h * 0.08, h - 2, 6); post(c, w - 6, h * 0.08, h - 2, 6)
    # skrzydło bramy
    for (y0, y1) in ((h * 0.28, h * 0.4), (h * 0.66, h * 0.78)):
        rail(c, (8, (y0 + y1) / 2), (w - 9, (y0 + y1) / 2), y1 - y0)
    brace = c.poly([(9, h * 0.72), (13, h * 0.78), (w - 9, h * 0.34), (w - 13, h * 0.28)])
    yy, xx = np.mgrid[0:h, 0:w]
    c.paint(brace, "wood", 0.55 - (xx % 4) * 0.04, 0.2)
    for x in range(14, w - 12, 8):    # pionowe deski
        c.paint(c.rect(x, h * 0.3, x + 3, h * 0.76), "wood", 0.5, 0.15)
    c.outline()
    return c.image()

def crates(w, h, seed=1):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    def crate(x0, y0, x1, y1):
        m = c.rect(x0, y0, x1, y1)
        c.paint(m, "wood", 0.62 - ((yy - y0) % 5 == 0) * 0.2, 0.18)
        c.paint(m & ~c.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2), "woodpale", 0.45, 0.12)
        c.rgb[(yy >= y0 + 2) & (yy < y1 - 2) & (np.abs((xx - x0) - (yy - y0)) < 1.2) & m] = RAMPS["wood"][1]
        c.rgb[(yy >= y0 + 2) & (yy < y1 - 2) & (np.abs((x1 - xx) - (yy - y0)) < 1.2) & m] = RAMPS["wood"][1]
    crate(2, h * 0.42, 30, h - 2)
    crate(8, 2, 24, h * 0.44)
    sack = c.ellipse(w - 15, h - 13, 12, 11) | c.poly([(w - 22, h - 20), (w - 18, h - 31), (w - 12, h - 31), (w - 8, h - 20)])
    c.volume(sack, "cloth", bulge=6, noise=0.22)
    c.flat(c.rect(w - 19, h - 28, w - 11, h - 26), RAMPS["wood"][1])      # sznurek
    c.paint(c.poly([(w - 19, h - 31), (w - 21, h - 34), (w - 17, h - 33), (w - 13, h - 35), (w - 11, h - 31)]), "cloth", 0.6, 0.2)
    c.outline()
    return c.image()

def scarecrow(w, h, seed=1):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    cx = w / 2
    post(c, cx, h * 0.18, h - 2, 4)
    rail(c, (3, h * 0.3), (w - 3, h * 0.3), 3)
    # koszula
    shirt = c.poly([(cx - 9, h * 0.28), (cx + 9, h * 0.28), (cx + 8, h * 0.58), (cx + 6, h * 0.62), (cx + 3, h * 0.58), (cx, h * 0.64),
                    (cx - 3, h * 0.58), (cx - 6, h * 0.63), (cx - 8, h * 0.57)])
    arms = c.poly([(3, h * 0.28), (cx - 8, h * 0.28), (cx - 8, h * 0.4), (6, h * 0.36), (2, h * 0.4)]) | \
           c.poly([(w - 3, h * 0.28), (cx + 8, h * 0.28), (cx + 8, h * 0.4), (w - 6, h * 0.36), (w - 2, h * 0.4)])
    c.volume(shirt | arms, "cloth", bulge=5, noise=0.25)
    c.paint(c.rect(cx - 2, h * 0.4, cx + 3, h * 0.55), "cloth", 0.15, 0.1)       # łata
    # głowa z worka
    head = c.ellipse(cx, h * 0.17, 7, 7.5)
    c.volume(head, "straw", bulge=5, noise=0.2)
    c.rgb[int(h * 0.15), int(cx - 3)] = OUTLINE; c.rgb[int(h * 0.15), int(cx + 2)] = OUTLINE
    for i in range(-3, 4):
        c.rgb[int(h * 0.21) + (i % 2), int(cx + i)] = OUTLINE
    # kapelusz
    hat = c.poly([(cx - 11, h * 0.1), (cx + 11, h * 0.1), (cx + 6, h * 0.1), (cx + 5, h * 0.0 + 1), (cx - 5, h * 0.0 + 1), (cx - 6, h * 0.1)])
    c.volume(hat | c.rect(cx - 11, h * 0.09, cx + 11, h * 0.12), "wood", bulge=3, noise=0.2)
    # słoma z rękawów
    for (x, y) in ((3, h * 0.4), (6, h * 0.42), (w - 3, h * 0.4), (w - 6, h * 0.42), (cx - 4, h * 0.63), (cx + 4, h * 0.63)):
        c.paint(c.rect(x - 1, y, x + 1, y + 6), "straw", 0.6, 0.3)
    c.outline()
    return c.image()

def barn(w, h, seed=1):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    wall_top = h * 0.4
    wall = c.rect(8, wall_top, w - 8, h - 2)
    c.paint(wall, "wood", 0.55 - ((xx % 6) == 0) * 0.22 - (yy - wall_top) / (h - wall_top) * 0.15, 0.2)
    c.paint(c.rect(8, h - 8, w - 8, h - 1), "stone", 0.35, 0.3)      # fundament
    roof = c.poly([(2, wall_top + 4), (w / 2, 3), (w - 2, wall_top + 4), (w - 8, wall_top + 8), (w / 2, 12), (8, wall_top + 8)])
    roof_full = c.poly([(2, wall_top + 5), (w / 2, 2), (w - 2, wall_top + 5), (w - 6, wall_top + 11), (6, wall_top + 11)])
    c.paint(roof_full, "dry", 0.55 + (-(xx - w / 2) / w) * 0.5 - ((yy // 4) % 2) * 0.12, 0.2)
    # deski szczytu
    gable = c.poly([(8, wall_top + 9), (w / 2, 14), (w - 8, wall_top + 9)])
    c.paint(gable, "wood", 0.5 - ((xx % 5) == 0) * 0.2, 0.2)
    # duże wrota z krzyżem
    dx0, dx1, dy0 = w / 2 - 22, w / 2 + 22, h * 0.56
    door = c.rect(dx0, dy0, dx1, h - 2)
    c.paint(door, "wood", 0.3 - ((xx % 11) == 0) * 0.12, 0.15)
    c.paint(door & ~c.rect(dx0 + 3, dy0 + 3, dx1 - 3, h - 5), "woodpale", 0.4, 0.1)
    c.rgb[(np.abs((xx - dx0) * (h - 2 - dy0) / (dx1 - dx0) - (yy - dy0)) < 1.6) & door] = RAMPS["wood"][3]
    c.rgb[(np.abs((dx1 - xx) * (h - 2 - dy0) / (dx1 - dx0) - (yy - dy0)) < 1.6) & door] = RAMPS["wood"][3]
    c.rgb[door & (xx == int(w / 2))] = RAMPS["wood"][0]
    # okienko na stryszku
    c.flat(c.rect(w / 2 - 6, wall_top + 14, w / 2 + 6, wall_top + 26), RAMPS["wood"][0])
    c.flat(c.rect(w / 2 - 4, wall_top + 16, w / 2 + 4, wall_top + 24), (250, 170, 50))
    c.rgb[int(wall_top + 20), int(w / 2 - 4):int(w / 2 + 4)] = RAMPS["wood"][1]
    c.outline()
    return c.image()

def tent(w, h, seed=1):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    cx = w * 0.5
    left = c.poly([(cx, 4), (3, h - 3), (cx - 3, h - 3)])
    right = c.poly([(cx, 4), (cx + 3, h - 3), (w - 3, h - 3)])
    c.paint(left, "cloth", 0.78 - (yy - 4) / h * 0.3, 0.2)
    c.paint(right, "cloth", 0.3 - (yy - 4) / h * 0.15, 0.2)
    door = c.poly([(cx - 3, h - 3), (cx, h * 0.38), (cx + 3, h - 3)])
    c.flat(door, RAMPS["char"][0])
    # łaty i szwy
    c.paint(c.rect(cx - 17, h * 0.55, cx - 9, h * 0.7) & left, "red", 0.5, 0.2)
    c.paint(c.rect(cx + 10, h * 0.5, cx + 20, h * 0.62) & right, "straw", 0.4, 0.2)
    c.rgb[(np.abs(xx - cx) < 0.7) & (yy < h * 0.4)] = RAMPS["cloth"][0]
    # żerdź i liny
    c.paint(c.line((cx, 4), (cx, 0), 2), "wood", 0.5, 0.1)
    c.outline()
    for (x0, y0, x1, y1) in ((cx - 18, h * 0.5, 2, h - 2), (cx + 18, h * 0.5, w - 2, h - 2)):
        pass
    c.rgb[h - 2, 1:3] = RAMPS["wood"][2]; c.rgb[h - 2, w - 3:w - 1] = RAMPS["wood"][2]
    return c.image()

def banner_torn(w, h, seed=1):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    pole_x = w * 0.18
    post(c, pole_x, 2, h - 2, 4)
    rail(c, (pole_x - 2, 6), (w - 3, 6), 3)
    # płachta z poszarpanym brzegiem
    x0, x1 = pole_x + 2, w - 4
    bottom = h * 0.78
    pts = [(x0, 8), (x1, 8)]
    n = 6
    rng = np.random.default_rng(seed)
    for i in range(n + 1):
        t = i / n
        pts.append((x1 - (x1 - x0) * t, bottom - (rng.random() * 9 if i % 2 else 0) - (14 if i == 2 else 0)))
    m = c.poly(pts)
    c.paint(m, "red", 0.7 - (xx - x0) / max(1.0, x1 - x0) * 0.4 - (yy - 8) / h * 0.2 + ((xx % 5) == 0) * -0.1, 0.2)
    # dziury i godło (ośmioramienna gwiazda chaosu)
    c.a &= ~c.rect(x1 - 7, h * 0.55, x1 - 3, h * 0.6)
    gx, gy = (x0 + x1) / 2, h * 0.38
    for a in range(8):
        ang = a * np.pi / 4
        for r in range(1, 7):
            px, py = int(gx + np.cos(ang) * r * 0.9), int(gy + np.sin(ang) * r * 1.1)
            if 0 <= px < w and 0 <= py < h and c.a[py, px]:
                c.rgb[py, px] = RAMPS["straw"][2]
    c.outline()
    return c.image()

# ------------------------------------------------------------------------------------------ legowisko Chaosu
def obelisk(w, h, seed=1):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    cx = w / 2
    body = c.poly([(cx - 11, h - 8), (cx - 8, h * 0.16), (cx, 2), (cx + 8, h * 0.16), (cx + 11, h - 8)])
    c.paint(body, "stone", 0.45 - (xx - cx) / 24.0 * 0.9, 0.2)
    plinth = c.rect(cx - 16, h - 8, cx + 16, h - 1)
    c.paint(plinth, "stone", 0.5 - (xx - cx) / 36.0, 0.2)
    c.rgb[(yy == h - 8) & plinth] = RAMPS["stone"][0]
    # runy
    glyphs = [(h * 0.3, 'A'), (h * 0.46, 'B'), (h * 0.62, 'C')]
    for (gy, k) in glyphs:
        gy = int(gy)
        pat = {'A': [(0, 0), (1, 1), (2, 2), (2, 0), (0, 2), (1, 0), (1, 2)], 'B': [(0, 0), (0, 1), (0, 2), (1, 1), (2, 0), (2, 2), (1, 2)],
               'C': [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (0, 2), (2, 0)]}[k]
        for (px, py) in pat:
            x, y = int(cx - 2 + px * 2), gy + py * 2
            c.flat(c.rect(x, y, x + 1, y + 2), RAMPS["purple"][4])
            c.rgb[y:y + 2, x - 1] = RAMPS["purple"][2] if x - 1 >= 0 else c.rgb[y:y + 2, x - 1]
    # poświata (kreskowana) wokół run
    halo = c.rect(cx - 7, h * 0.26, cx + 7, h * 0.8) & body & ((xx + yy) % 2 == 0) & (c.rgb.sum(-1) < 400)
    c.paint(halo, "purple", 0.35, 0.1)
    c.outline()
    return c.image()

def brazier(w, h, seed=1):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    cx = w / 2
    for dx in (-9, 0, 9):          # trójnóg
        c.paint(c.line((cx + dx * 0.4, h * 0.5), (cx + dx, h - 2), 3), "iron", 0.4, 0.2)
    bowl = c.poly([(cx - 13, h * 0.48), (cx + 13, h * 0.48), (cx + 9, h * 0.62), (cx - 9, h * 0.62)]) | c.ellipse(cx, h * 0.62, 9, 3)
    c.volume(bowl, "iron", bulge=4, noise=0.15)
    c.paint(c.ellipse(cx, h * 0.48, 13, 3), "iron", 0.85, 0.1)
    # płomień chaosu (zielono-fioletowy)
    flame = c.poly([(cx - 10, h * 0.48), (cx - 7, h * 0.26), (cx - 3, h * 0.36), (cx, h * 0.04), (cx + 3, h * 0.3), (cx + 7, h * 0.18), (cx + 10, h * 0.48)])
    s = 0.2 + (h * 0.5 - yy) / (h * 0.5) * 0.9
    c.paint(flame, "chaosfire", np.clip(s, 0, 1), 0.2)
    core = c.poly([(cx - 4, h * 0.48), (cx - 2, h * 0.3), (cx, h * 0.16), (cx + 2, h * 0.32), (cx + 4, h * 0.48)])
    c.paint(core, "chaosfire", 0.97, 0.0)
    c.outline()
    return c.image()

def bones(w, h, seed=1):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    sx = w * 0.62
    post(c, sx, h * 0.18, h - 2, 4)
    # czaszka na palu
    sk = c.ellipse(sx, h * 0.16, 8, 7.5) | c.rect(sx - 5, h * 0.2, sx + 5, h * 0.3)
    c.volume(sk, "bone", bulge=5, noise=0.18)
    c.flat(c.ellipse(sx - 3, h * 0.17, 2.2, 2.6), OUTLINE); c.flat(c.ellipse(sx + 3, h * 0.17, 2.2, 2.6), OUTLINE)
    c.flat(c.rect(sx - 1, h * 0.22, sx + 1, h * 0.25), OUTLINE)
    for x in range(int(sx - 4), int(sx + 5), 2):
        c.rgb[int(h * 0.29), x] = OUTLINE
    # stos kości
    rng = np.random.default_rng(seed)
    for i in range(7):
        x0 = rng.integers(2, int(w * 0.5)); y0 = h - 4 - rng.integers(0, 8)
        ang = rng.random() * 0.6 - 0.3
        x1 = x0 + 16 + rng.integers(0, 8); y1 = y0 + (x1 - x0) * ang
        bone = c.line((x0, y0), (x1, y1), 3)
        c.paint(bone, "bone", 0.7, 0.2)
        for (ex, ey) in ((x0, y0), (x1, y1)):
            c.paint(c.ellipse(ex, ey - 1, 2.5, 2.5) | c.ellipse(ex, ey + 1.5, 2.5, 2.2), "bone", 0.75, 0.15)
    small = c.ellipse(w * 0.22, h - 8, 6, 5.5) | c.rect(w * 0.22 - 4, h - 7, w * 0.22 + 4, h - 3)
    c.volume(small, "bone", bulge=4, noise=0.2)
    c.flat(c.ellipse(w * 0.22 - 2.5, h - 9, 1.6, 1.8), OUTLINE); c.flat(c.ellipse(w * 0.22 + 2.5, h - 9, 1.6, 1.8), OUTLINE)
    c.outline()
    return c.image()

def crystals(w, h, seed=1):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    rng = np.random.default_rng(seed)
    base = c.poly([(2, h - 2), (6, h - 8), (w * 0.4, h - 10), (w * 0.7, h - 9), (w - 4, h - 7), (w - 2, h - 2)])
    c.volume(base, "stone", bulge=3, noise=0.25)
    specs = [(w * 0.5, h - 8, 7, h * 0.78, 0.0), (w * 0.28, h - 7, 5, h * 0.52, -0.3), (w * 0.74, h - 7, 5.5, h * 0.58, 0.25), (w * 0.4, h - 8, 4, h * 0.36, 0.12)]
    for (x, y, wd, ht, lean) in specs:
        tip = (x + lean * ht, y - ht)
        L = c.poly([(x - wd, y), (x - wd + lean * ht * 0.2, y - ht * 0.72), tip, (x + lean * ht * 0.2, y - ht * 0.6), (x, y)])
        R = c.poly([(x, y), (x + lean * ht * 0.2, y - ht * 0.6), tip, (x + wd + lean * ht * 0.2, y - ht * 0.72), (x + wd, y)])
        c.paint(L, "purple", 0.8, 0.18)
        c.paint(R, "purple", 0.35, 0.18)
        c.paint(c.line((x - wd + 1, y - 2), (tip[0] - 1, tip[1] + 2), 1) & L, "purple", 1.0, 0.0)
    c.outline()
    return c.image()

# ------------------------------------------------------------------------------------------ wspólne
def barrel(w, h, seed=1):
    c = Canvas(w, h)
    yy, xx = np.mgrid[0:h, 0:w]
    cx = w / 2
    pts_l, pts_r = [], []
    for y in range(4, h - 2):
        t = (y - 4) / (h - 6)
        bulge = np.sin(t * np.pi) * 3.5
        half = w * 0.36 + bulge
        pts_l.append((cx - half, y)); pts_r.append((cx + half, y))
    m = c.poly(pts_l + pts_r[::-1]) | c.ellipse(cx, h - 4, w * 0.36, 3)
    plank = ((xx - 1) // 5)
    c.paint(m, "wood", 0.9 - (xx - (cx - w * 0.4)) / (w * 0.8) * 0.55 - ((xx - 1) % 5 == 0) * 0.3 + (plank % 2) * 0.06, 0.12)
    top = c.ellipse(cx, 5, w * 0.34, 3)
    c.paint(top, "woodpale", 0.65, 0.12)
    c.paint(top & ~c.ellipse(cx, 5, w * 0.34 - 1.5, 1.8), "wood", 0.2, 0.0)
    for hy in (h * 0.22, h * 0.75):
        t = (hy - 4) / (h - 6); bulge = np.sin(t * np.pi) * 3.5; half = w * 0.36 + bulge
        hoop = c.rect(cx - half - 1, hy - 1.5, cx + half + 1, hy + 2.5)
        c.paint(hoop, "iron", 0.7 - (xx - cx) / (2 * half) * 0.5, 0.1)
        c.paint(c.rect(cx - half - 1, hy - 1.5, cx + half + 1, hy - 0.5), "iron", 1.0, 0.0)
    c.outline()
    return c.image()

def potion(w, h, seed=1):
    c = Canvas(w, h)
    yy, xx = np.mgrid[0:h, 0:w]
    cx = w / 2
    body = c.ellipse(cx, h * 0.68, w * 0.4, h * 0.27)
    neck = c.rect(cx - 3, h * 0.2, cx + 3, h * 0.5)
    c.volume(body | neck, "glass", bulge=5, noise=0.1, base=0.55)
    c.paint(c.rect(cx - 3, h * 0.2, cx + 3, h * 0.28), "cloth", 0.9, 0.0)               # szkło szyjki
    c.paint(c.rect(cx - 2.5, h * 0.06, cx + 3, h * 0.22), "wood", 0.7, 0.1)             # korek
    c.flat(c.rect(cx - 4, h * 0.2, cx + 4, h * 0.23), RAMPS["wood"][1])                   # sznurek
    c.flat(c.rect(cx - 4, h * 0.6, cx - 2, h * 0.68), (255, 220, 210))                  # odblask
    c.flat(c.rect(cx - 4, h * 0.56, cx - 3, h * 0.58), (255, 245, 240))
    c.outline()
    return c.image()

# ------------------------------------------------------------------------------------------ wycięcia z panoramy
_pan = None
def pan():
    global _pan
    if _pan is None:
        _pan = cv2.imread(SRC)
    return _pan

def grabcut_cut(rect, poly=None, iters=8, pad=12):
    """Wycięcie obiektu z panoramy: GrabCut w prostokącie, opcjonalnie przecięty z wielokątem (współrzędne panoramy)."""
    P = pan()
    x0, y0, x1, y1 = rect
    m = np.zeros(P.shape[:2], np.uint8) + cv2.GC_BGD
    X0, Y0, X1, Y1 = x0 - pad, y0 - pad, x1 + pad, y1 + pad
    m[Y0:Y1, X0:X1] = cv2.GC_PR_BGD
    m[y0:y1, x0:x1] = cv2.GC_PR_FGD
    m[y0 + (y1 - y0) // 3:y1 - (y1 - y0) // 8, x0 + (x1 - x0) // 4:x1 - (x1 - x0) // 4] = cv2.GC_FGD
    if poly is not None:
        pm = np.zeros(P.shape[:2], np.uint8)
        cv2.fillPoly(pm, [np.array(poly, np.int32)], 255)
        m[(pm == 0)] = cv2.GC_BGD
        m[(pm > 0) & (m == cv2.GC_BGD)] = cv2.GC_PR_FGD
    bg = np.zeros((1, 65)); fg = np.zeros((1, 65))
    cv2.grabCut(P, m, None, bg, fg, iters, cv2.GC_INIT_WITH_MASK)
    a = ((m == cv2.GC_FGD) | (m == cv2.GC_PR_FGD))
    if poly is not None:
        a &= pm > 0
    a = a[Y0:Y1, X0:X1]
    # największa spójna część + wypełnienie dziur + wygładzenie krawędzi
    n, lab, stats, _ = cv2.connectedComponentsWithStats(a.astype(np.uint8), connectivity=8)
    if n > 1:
        k = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        a = lab == k
    from scipy import ndimage
    a = ndimage.binary_fill_holes(a)
    a = ndimage.binary_opening(a, structure=np.ones((3, 3)))
    rgb = P[Y0:Y1, X0:X1][..., ::-1]
    im = np.dstack([rgb, np.where(a, 255, 0).astype(np.uint8)])
    return Image.fromarray(im, "RGBA")

def trim(im):
    a = np.array(im)[..., 3]
    ys, xs = np.where(a > 0)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))

def fit(im, W, H):
    """Skaluje obraz tak, by zmieścił się w WxH (zachowując proporcje); stoi na dolnej krawędzi, wyśrodkowany."""
    im = trim(im)
    s = min((W - 2) / im.width, (H - 2) / im.height)
    nw, nh = max(1, round(im.width * s)), max(1, round(im.height * s))
    prem = np.array(im).astype(float)
    prem[..., :3] *= prem[..., 3:4] / 255.0
    r = np.array(Image.fromarray(prem.astype(np.uint8)).resize((nw, nh), Image.LANCZOS)).astype(float)
    ra = np.array(Image.fromarray(np.array(im)[..., 3]).resize((nw, nh), Image.LANCZOS)).astype(float)
    rgb = np.where(ra[..., None] > 0, r[..., :3] / np.maximum(ra[..., None] / 255.0, 1e-3), 0)
    out = np.zeros((H, W, 4), np.uint8)
    x0 = (W - nw) // 2; y0 = H - nh - 0
    out[y0:y0 + nh, x0:x0 + nw, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[y0:y0 + nh, x0:x0 + nw, 3] = np.where(ra > 127, 255, 0)
    return Image.fromarray(out, "RGBA")

def dark_edge(im, color=OUTLINE):
    """Ciemny kontur wokół wycinka (jak w rysowanych rekwizytach)."""
    from scipy import ndimage
    a = np.array(im)
    m = a[..., 3] > 0
    st = ndimage.generate_binary_structure(2, 1)
    edge = ndimage.binary_dilation(m, structure=st) & ~m
    h, w = m.shape
    edge[0, :] = edge[-1, :] = False
    a[edge, :3] = color; a[edge, 3] = 255
    return Image.fromarray(a, "RGBA")

def house_thatch_raw():
    # wielokąt sylwetki chaty (współrzędne panoramy) odcina niebo, słup i kruka po lewej
    ox, oy = 208, 203
    poly = [(ox + x / 2, oy + y / 2) for (x, y) in [(40, 556), (40, 372), (138, 90), (300, 92), (470, 112), (528, 112), (530, 0), (655, 0), (655, 300), (745, 392), (708, 560)]]
    return grabcut_cut((220, 215, 580, 487), poly)

def house_shingle_raw():
    """Chata z gontem: wycięcie chaty ze strzechą, odbite lustrzanie; dach przemalowany na ciemny gont, sztandar zdjęty."""
    im = house_thatch_raw()
    a = np.array(im).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    h, w = r.shape
    thatch = (r > b + 18) & (r > 60) & (g > 45) & (a[..., 3] > 0) & ~((r > 120) & (g < 70))
    thatch[: int(h * 0.62)] |= (r > b + 10)[: int(h * 0.62)] & (a[..., 3] > 0)[: int(h * 0.62)] & (r > 55)[: int(h * 0.62)] & ~((r > 120) & (g < 70))[: int(h * 0.62)]
    lum = 0.3 * r + 0.55 * g + 0.15 * b
    yy = np.arange(h)[:, None]
    rows = 0.82 + 0.22 * np.sin(yy * 1.1)                       # poziome rzędy gontów
    slate = np.stack([lum * 0.62 * rows + 14, lum * 0.55 * rows + 14, lum * 0.52 * rows + 22], -1)
    a[..., :3] = np.where(thatch[..., None], slate, a[..., :3])
    red = (r > 90) & (g < 60) & (b < 70) & (np.arange(w)[None, :] < w * 0.4)          # sztandar z godłem -> kamienna ściana
    gold = (r > 150) & (g > 110) & (b < 110) & (np.arange(w)[None, :] < w * 0.4) & (yy > h * 0.45)
    wall = np.stack([lum * 0.8, lum * 0.82, lum * 0.9], -1)
    a[red | gold, :3] = wall[red | gold]
    out = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    return out.transpose(Image.FLIP_LEFT_RIGHT)

def house_burnt_raw():
    base = house_thatch_raw()
    a = np.array(base).astype(float)
    lum = (0.3 * a[..., 0] + 0.55 * a[..., 1] + 0.15 * a[..., 2])
    h, w = lum.shape
    glow = (a[..., 0] > 150) & (a[..., 1] > 100) & (a[..., 2] < 90)      # okna świecące w oryginale
    # zwęglenie: ciemne, lekko ciepłe barwy
    a[..., 0] = lum * 0.55 + 6; a[..., 1] = lum * 0.42 + 5; a[..., 2] = lum * 0.38 + 5
    alpha = a[..., 3] > 0
    rng = np.random.default_rng(5)
    # dziury w dachu (nieregularne wypalone plamy)
    yy, xx = np.mgrid[0:h, 0:w]
    for (cx, cy, r) in ((w * 0.46, h * 0.36, 28), (w * 0.64, h * 0.42, 20), (w * 0.3, h * 0.3, 14)):
        hole = ((xx - cx) ** 2 + ((yy - cy) * 1.4) ** 2) < r * r * (0.7 + 0.5 * rng.random((h, w)))
        alpha &= ~hole
        ring = (((xx - cx) ** 2 + ((yy - cy) * 1.4) ** 2) < (r + 5) ** 2) & ~hole & alpha
        a[ring, 0] = 30; a[ring, 1] = 18; a[ring, 2] = 14
    # żar w oknach i przy dziurach
    a[glow, :3] = (255, 120, 30)
    # tlące się krawędzie
    from scipy import ndimage
    edge = alpha & ~ndimage.binary_erosion(alpha, iterations=2)
    spark = edge & (rng.random((h, w)) < 0.12)
    a[spark, :3] = (255, 150, 40)
    a[..., 3] = np.where(alpha, 255, 0)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")

def cart_raw():
    im = grabcut_cut((568, 430, 785, 505))
    a = np.array(im); a[:, :34, 3] = 0       # zielone liście z lewej strony kadru
    return Image.fromarray(a, "RGBA")

def well_raw():
    im = grabcut_cut((912, 380, 1025, 487))
    a = np.array(im).astype(int)
    leak = (a[..., 0] > 170) & (a[..., 1] > 110) & (a[..., 2] < 60) & (np.arange(a.shape[1])[None, :] < 36)   # żółte pole zboża
    a[leak, 3] = 0
    return Image.fromarray(a.astype(np.uint8), "RGBA")

# ------------------------------------------------------------------------------------------ definicje
# nazwa: (etap, rozmiar WxH, kind, parametry, [warianty: liczba seedów]); kind 'draw' = funkcja, 'cut' = wycięcie
def D(fn, **kw):
    return ("draw", fn, kw)

PROPS = {
    # etap 1
    ("stage1_road", "fence"):        ((96, 40), D(fence, n=4), 2),
    ("stage1_road", "fence_broken"): ((96, 40), D(fence, n=4, broken=True), 2),
    ("stage1_road", "tree_oak"):     ((100, 150), D(tree_oak), 3),
    ("stage1_road", "tree_dead"):    ((100, 150), D(tree_dead), 2),
    ("stage1_road", "signpost"):     ((60, 60), D(lambda w, h, seed=1: signpost(w, h, seed)), 1),
    ("stage1_road", "bush"):         ((50, 32), D(bush), 2),
    ("stage1_road", "milestone"):    ((28, 32), D(milestone), 1),
    ("stage1_road", "stump_axe"):    ((40, 45), D(stump_axe), 1),
    # etap 2
    ("stage2_village", "house_thatch"):  ((130, 150), ("cut", house_thatch_raw), 1),
    ("stage2_village", "house_shingle"): ((130, 150), ("cut", house_shingle_raw), 1),
    ("stage2_village", "house_burnt"):   ((130, 150), ("cut", house_burnt_raw), 1),
    ("stage2_village", "barn"):          ((150, 160), D(barn), 1),
    ("stage2_village", "fence"):         ((110, 40), D(fence, n=5), 2),
    ("stage2_village", "fence_broken"):  ((110, 40), D(fence, n=5, broken=True), 2),
    ("stage2_village", "gate"):          ((60, 60), D(gate), 1),
    ("stage2_village", "cart"):          ((75, 50), ("cut", cart_raw), 1),
    ("stage2_village", "well"):          ((45, 70), ("cut", well_raw), 1),
    ("stage2_village", "crates"):        ((60, 50), D(crates), 1),
    ("stage2_village", "scarecrow"):     ((40, 85), D(scarecrow), 1),
    # etap 3
    ("stage3_fields_forest", "tree_oak"):     ((110, 150), D(tree_oak), 3),
    ("stage3_fields_forest", "tree_dead"):    ((110, 150), D(tree_dead), 2),
    ("stage3_fields_forest", "tree_pine"):    ((80, 170), D(tree_pine), 3),
    ("stage3_fields_forest", "bush"):         ((50, 32), D(bush), 2),
    ("stage3_fields_forest", "stone_big"):    ((45, 38), D(stone), 3),
    ("stage3_fields_forest", "fence_broken"): ((80, 40), D(fence, n=4, broken=True), 2),
    ("stage3_fields_forest", "tent"):         ((70, 50), D(tent), 1),
    ("stage3_fields_forest", "banner_torn"):  ((35, 72), D(banner_torn), 1),
    # etap 4
    ("stage4_lair", "obelisk"):      ((40, 100), D(obelisk), 1),
    ("stage4_lair", "brazier"):      ((30, 65), D(brazier), 1),
    ("stage4_lair", "tree_twisted"): ((110, 150), D(tree_twisted), 3),
    ("stage4_lair", "bones"):        ((70, 70), D(bones), 2),
    ("stage4_lair", "crystals"):     ((45, 50), D(crystals), 3),
    # wspólne
    ("common", "barrel"): ((36, 44), D(barrel), 1),
    ("common", "potion"): ((22, 28), D(potion), 1),
}

def signpost(w, h, seed=1):
    c = Canvas(w, h); c.rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    cx = w / 2
    post(c, cx, 3, h - 2, 6)
    def board(y0, y1, x0, x1, left):
        pts = [(x0, y0), (x1 - 6, y0), (x1, (y0 + y1) / 2), (x1 - 6, y1), (x0, y1)] if not left else \
              [(x1, y0), (x0 + 6, y0), (x0, (y0 + y1) / 2), (x0 + 6, y1), (x1, y1)]
        m = c.poly(pts)
        c.paint(m, "woodpale", 0.62 - (yy - y0) / max(1.0, y1 - y0) * 0.45, 0.2)
        for k in range(3):     # "napis"
            x = int(x0 + 6 + k * 6) if not left else int(x0 + 10 + k * 6)
            c.rgb[int((y0 + y1) / 2) - 1:int((y0 + y1) / 2) + 2, x:x + 3] = RAMPS["wood"][0]
        c.rgb[int(y0) + 1, int(x0) + 2] = OUTLINE
    board(8, 20, 7, w - 3, False)
    board(24, 36, 3, w - 9, True)
    c.outline()
    return c.image()

def render(stage, name):
    size, rec, variants = PROPS[(stage, name)]
    W, H = size
    outs = []
    kind = rec[0]
    if kind == "cut":
        raw = rec[1]()
        im = dark_edge(fit(raw, W, H))
        outs.append((im, raw))
    else:
        fn, kw = rec[1], rec[2]
        for v in range(variants):
            outs.append((fn(W, H, seed=v + 1, **kw) if "seed" in fn.__code__.co_varnames else fn(W, H, **kw), None))
    return outs

def quantize(im, P, plab):
    a = np.array(im.convert("RGBA"))
    idx = ((mp.srgb2lab(a[..., :3].astype(float))[..., None, :] - plab[None, None]) ** 2).sum(-1).argmin(-1)
    out = np.zeros_like(a)
    out[..., :3] = P[idx]
    out[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
    out[out[..., 3] == 0, :3] = 0
    return Image.fromarray(out, "RGBA")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default=None)
    ap.add_argument("--only", default=None)
    a = ap.parse_args()
    only = set(a.only.split(",")) if a.only else None
    P = np.array(Image.open(os.path.join(HERE, "assets/palette/hufduhof_256.png")).convert("RGB")).reshape(-1, 3)
    plab = mp.srgb2lab(P)
    sheets = {}
    for (stage, name) in PROPS:
        if only and name not in only:
            continue
        outs = render(stage, name)
        pdir = os.path.join(HERE, "assets/stages", stage, "props")
        sdir = os.path.join(HERE, "assets/stages/source/elements", stage, name)
        os.makedirs(pdir, exist_ok=True); os.makedirs(sdir, exist_ok=True)
        for i, (im, raw) in enumerate(outs):
            q = quantize(im, P, plab)
            fn = f"{name}.png" if i == 0 else f"{name}_{i + 1}.png"
            q.save(os.path.join(pdir, fn))
            # źródło: surowe wycięcie (pełna rozdzielczość) albo 4x powiększona wersja wygenerowana
            src = raw if raw is not None else im.resize((im.width * 4, im.height * 4), Image.NEAREST)
            src.save(os.path.join(sdir, f"{name}_source.png" if i == 0 else f"{name}_{i + 1}_source.png"))
            sheets.setdefault(stage, []).append((fn, q))
            print(f"{stage}/props/{fn} {q.width}x{q.height}")
    if a.preview:
        os.makedirs(a.preview, exist_ok=True)
        for stage, items in sheets.items():
            sc = 3
            W = sum(q.width * sc + 12 for _, q in items[:7]) if False else 1500
            rows, x, y, rowh = [], 8, 8, 0
            pos = []
            for fn, q in items:
                w, h = q.width * sc, q.height * sc
                if x + w + 8 > W:
                    x = 8; y += rowh + 12; rowh = 0
                pos.append((x, y, fn, q)); x += w + 14; rowh = max(rowh, h)
            sheet = Image.new("RGBA", (W, y + rowh + 12), (70, 96, 52, 255))
            for (x, y, fn, q) in pos:
                sheet.alpha_composite(q.resize((q.width * sc, q.height * sc), Image.NEAREST), (x, y))
            sheet.convert("RGB").save(os.path.join(a.preview, f"props_{stage}.png"))

if __name__ == "__main__":
    main()
