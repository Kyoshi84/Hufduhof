#!/usr/bin/env python3
"""Rekwizyty izometryczne wioski i karczmy (placeholdery w palecie 256 kolorów).

Konwencja (patrz docs/ASSETY.md): dolny środek obrazka = punkt kotwicy rekwizytu:
  * budynki ("anchor": "south") - południowy (najniższy na ekranie) narożnik podstawy,
  * małe obiekty ("anchor": "center") - środek komórki, na której stoją.
Uruchom: python3 tools/gen_props.py
"""
import math
import random

from PIL import Image, ImageDraw
from pixlib import R, Canvas, outline, save, HW, HH

rnd = random.Random(11)
L1 = "assets/levels/level1/props/"
TV = "assets/levels/tavern/props/"
FX = "assets/levels/common/fx/"
CP = "assets/levels/common/props/"


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


# ---------------------------------------------------------------- budynek z muru pruskiego
def wall_face(cv, a, b, z0, z1, plaster, beam, plinth, windows=(), door=None, timber=True, boards=False):
    """Ściana między punktami siatki a->b (gx, gy), od wysokości z0 do z1 px."""
    ax, ay = a
    bx, by = b
    cv.gpoly([(ax, ay, z0), (bx, by, z0), (bx, by, z1), (ax, ay, z1)], plaster)
    L = math.hypot(bx - ax, by - ay)

    def at(u, z):
        t = u / L
        return (ax + (bx - ax) * t, ay + (by - ay) * t, z)

    if boards:
        n = int(L * 9)
        for i in range(1, n):
            u = L * i / n
            cv.line(cv.P(*at(u, z0)), cv.P(*at(u, z1)), beam)
    # cokół z kamienia
    cv.gpoly([at(0, z0), at(L, z0), at(L, z0 + 12), at(0, z0 + 12)], plinth)
    for i in range(int(L * 6)):
        u = L * (i + 0.5) / (L * 6)
        p = cv.P(*at(u, z0 + 6))
        cv.d.point((round(p[0]), round(p[1])), fill=R("grey", 2))
    if timber:
        # słupy narożne i pośrednie, belka środkowa i górna, zastrzały
        posts = [0.0] + [L * k / max(1, round(L * 1.5)) for k in range(1, max(1, round(L * 1.5)))] + [L]
        for u in posts:
            cv.gpoly([at(max(0, u - 0.04), z0 + 12), at(min(L, u + 0.04), z0 + 12),
                      at(min(L, u + 0.04), z1), at(max(0, u - 0.04), z1)], beam)
        for zz in (z0 + 12, (z0 + z1) / 2 + 4, z1 - 3):
            cv.gpoly([at(0, zz - 2), at(L, zz - 2), at(L, zz + 2), at(0, zz + 2)], beam)
        for i in range(len(posts) - 1):
            u0, u1 = posts[i], posts[i + 1]
            if (i % 2) == 0:
                cv.line(cv.P(*at(u0, z0 + 14)), cv.P(*at(u1, (z0 + z1) / 2 + 2)), beam, 3)
    for (u, wz, ww, wh) in windows:
        cv.gpoly([at(u - ww / 2 - 0.05, wz - 3), at(u + ww / 2 + 0.05, wz - 3),
                  at(u + ww / 2 + 0.05, wz + wh + 3), at(u - ww / 2 - 0.05, wz + wh + 3)], beam)
        cv.gpoly([at(u - ww / 2, wz), at(u + ww / 2, wz), at(u + ww / 2, wz + wh), at(u - ww / 2, wz + wh)],
                 R("fire", 1) if rnd.random() < 0.5 else R("ink", 2))
        cv.line(cv.P(*at(u, wz)), cv.P(*at(u, wz + wh)), beam)
    if door is not None:
        u, dw, dh = door
        cv.gpoly([at(u - dw / 2 - 0.05, z0), at(u + dw / 2 + 0.05, z0), at(u + dw / 2 + 0.05, z0 + dh + 4),
                  at(u - dw / 2 - 0.05, z0 + dh + 4)], beam)
        cv.gpoly([at(u - dw / 2, z0), at(u + dw / 2, z0), at(u + dw / 2, z0 + dh), at(u - dw / 2, z0 + dh)],
                 R("wood", 3))
        for k in range(1, 4):
            uu = u - dw / 2 + dw * k / 4
            cv.line(cv.P(*at(uu, z0)), cv.P(*at(uu, z0 + dh)), R("wood", 1))


def roof_gable(cv, w, h, wall, rh, cols, over=0.18, along_x=True, thatch=True):
    """Dach dwuspadowy. along_x: kalenica równoległa do osi x (widoczny szczyt od strony x=w)."""
    c_front, c_end_dark, c_line = cols
    if along_x:
        ridge0, ridge1 = (-over, h / 2, wall + rh), (w + over, h / 2, wall + rh)
        eave0, eave1 = (-over, h + over, wall - 6), (w + over, h + over, wall - 6)
        back0, back1 = (-over, -over, wall - 6), (w + over, -over, wall - 6)
        # tylna połać (widoczna przy kalenicy), szczyt (trójkąt na ścianie x=w), przednia połać
        cv.gpoly([back0, back1, ridge1, ridge0], shade(c_front, 0.7))
        cv.gpoly([(w, 0, wall), (w, h, wall), (w, h / 2, wall + rh - 4)], c_end_dark)
        cv.gpoly([eave0, eave1, ridge1, ridge0], c_front)
        cv.gpoly([back1, (w + over, h + over, wall - 6), ridge1], shade(c_front, 0.82))
        n = int((w + 2 * over) * (10 if thatch else 6))
        for i in range(n + 1):
            gx = -over + (w + 2 * over) * i / n
            a = cv.P(gx, h / 2, wall + rh)
            b = cv.P(gx, h + over, wall - 6)
            if thatch:
                cv.line(a, b, c_line if i % 2 else shade(c_front, 1.12))
        if not thatch:
            for k in range(1, 6):
                t = k / 6
                a = cv.P(-over, h / 2 + (h / 2 + over) * t, wall + rh - (rh + 6) * t)
                b = cv.P(w + over, h / 2 + (h / 2 + over) * t, wall + rh - (rh + 6) * t)
                cv.line(a, b, c_line)
        cv.line(cv.P(*ridge0), cv.P(*ridge1), shade(c_front, 1.25), 2)
    else:
        ridge0, ridge1 = (w / 2, -over, wall + rh), (w / 2, h + over, wall + rh)
        eave_s0, eave_s1 = (w + over, -over, wall - 6), (w + over, h + over, wall - 6)
        eave_n0, eave_n1 = (-over, -over, wall - 6), (-over, h + over, wall - 6)
        cv.gpoly([eave_n0, eave_n1, ridge1, ridge0], shade(c_front, 0.7))
        cv.gpoly([(0, h, wall), (w, h, wall), (w / 2, h, wall + rh - 4)], c_end_dark)
        cv.gpoly([eave_s0, eave_s1, ridge1, ridge0], shade(c_front, 0.85))
        cv.gpoly([eave_n1, ridge1, (w + over, h + over, wall - 6)], c_front)
        n = int((h + 2 * over) * (10 if thatch else 6))
        for i in range(n + 1):
            gy = -over + (h + 2 * over) * i / n
            a = cv.P(w / 2, gy, wall + rh)
            b = cv.P(w + over, gy, wall - 6)
            cv.line(a, b, c_line if i % 2 else shade(c_front, 0.95))
        cv.line(cv.P(*ridge0), cv.P(*ridge1), shade(c_front, 1.2), 2)


def chimney(cv, gx, gy, z, hgt):
    s = 0.22
    cv.gpoly([(gx, gy + s, z), (gx + s, gy + s, z), (gx + s, gy + s, z + hgt), (gx, gy + s, z + hgt)], R("grey", 4))
    cv.gpoly([(gx + s, gy, z), (gx + s, gy + s, z), (gx + s, gy + s, z + hgt), (gx + s, gy, z + hgt)], R("grey", 2))
    cv.gpoly([(gx, gy, z + hgt), (gx + s, gy, z + hgt), (gx + s, gy + s, z + hgt), (gx, gy + s, z + hgt)], R("ink", 1))


def house(name, w, h, wall=70, rh=60, thatch=True, along_x=True, burnt=False, windows_l=None, door=True,
          chim=True, plaster=None):
    cv = Canvas()
    plaster = plaster or R("bone", 2)
    beam = R("wood", 2)
    pl_l = plaster
    pl_r = shade(plaster, 0.72)
    if burnt:
        pl_l, pl_r, beam = R("grey", 3), R("grey", 2), R("ink", 2)
    # ściana lewa-przednia (od W do S, wzdłuż x przy y=h) i prawa-przednia (od S do E, przy x=w)
    wins_l = windows_l if windows_l is not None else [(w * 0.25, 30, 0.3, 16), (w * 0.75, 30, 0.3, 16)]
    wall_face(cv, (0, h), (w, h), 0, wall, pl_l, beam, R("grey", 4), windows=wins_l,
              door=(w * 0.5, 0.42, 38) if door else None)
    wall_face(cv, (w, h), (w, 0), 0, wall, pl_r, shade(beam, 0.8), R("grey", 3),
              windows=[(h * 0.5, 30, 0.3, 16)])
    if burnt:
        # zawalony, osmalony dach - kikuty krokwi
        for i in range(5):
            gx = w * (i + 0.5) / 5
            cv.line(cv.P(gx, h, wall), cv.P(gx + 0.1, h / 2, wall + rh * (0.4 + 0.4 * rnd.random())), R("ink", 1), 3)
        for _ in range(140):
            gx, gy = rnd.random() * w, rnd.random() * h
            p = cv.P(gx, gy, wall + rnd.random() * 8)
            cv.d.point((round(p[0]), round(p[1])), fill=rnd.choice([R("ink", 1), R("ember", 1), R("grey", 2)]))
        for _ in range(60):
            p = cv.P(rnd.random() * w, h, rnd.random() * wall)
            cv.d.point((round(p[0]), round(p[1])), fill=R("ink", 1))
    else:
        cols = (R("straw", 3), R("wood", 4), R("straw", 1)) if thatch else (R("blood", 1), R("wood", 3), R("ink", 2))
        if not thatch:
            cols = (R("wood", 4), R("wood", 2), R("wood", 1))
        roof_gable(cv, w, h, wall, rh, cols, along_x=along_x, thatch=thatch)
        if chim:
            chimney(cv, w * 0.7, h * 0.35, wall + rh * 0.55, 34)
    outline(cv.im)
    ax, ay = cv.P(w, h, 0)
    save(cv.crop_anchor(ax, ay + 1), L1 + name + ".png")


def mill(name):
    cv = Canvas(1400, 1600, 700, 1300)
    w = h = 2
    wall = 150
    wall_face(cv, (0, h), (w, h), 0, wall, R("grey", 6), R("grey", 3), R("grey", 4),
              windows=[(1.0, 90, 0.25, 18)], door=(1.0, 0.4, 36), timber=False)
    wall_face(cv, (w, h), (w, 0), 0, wall, R("grey", 4), R("grey", 2), R("grey", 3),
              windows=[(1.0, 70, 0.25, 18)], timber=False)
    for i in range(70):
        p = cv.P(rnd.random() * w, h, rnd.random() * wall)
        cv.d.point((round(p[0]), round(p[1])), fill=R("grey", 4))
    apex = (w / 2, h / 2, wall + 80)
    cv.gpoly([(-0.15, h + 0.15, wall - 4), (w + 0.15, h + 0.15, wall - 4), apex], R("wood", 4))
    cv.gpoly([(w + 0.15, h + 0.15, wall - 4), (w + 0.15, -0.15, wall - 4), apex], R("wood", 2))
    # skrzydła wiatraka na ścianie przedniej
    hub = cv.P(1.0, h + 0.3, wall - 20)
    for k in range(4):
        ang = math.radians(25 + 90 * k)
        tip = (hub[0] + math.cos(ang) * 120, hub[1] + math.sin(ang) * 120)
        cv.line(hub, tip, R("wood", 2), 4)
        nrm = (-math.sin(ang), math.cos(ang))
        mid0 = (hub[0] + math.cos(ang) * 40, hub[1] + math.sin(ang) * 40)
        cv.poly([mid0, tip, (tip[0] + nrm[0] * 18, tip[1] + nrm[1] * 18),
                 (mid0[0] + nrm[0] * 18, mid0[1] + nrm[1] * 18)], R("bone", 1))
        for j in range(1, 5):
            a = (mid0[0] + (tip[0] - mid0[0]) * j / 5, mid0[1] + (tip[1] - mid0[1]) * j / 5)
            cv.line(a, (a[0] + nrm[0] * 18, a[1] + nrm[1] * 18), R("wood", 3))
    cv.d.ellipse([hub[0] - 6, hub[1] - 6, hub[0] + 6, hub[1] + 6], fill=R("wood", 1))
    outline(cv.im)
    ax, ay = cv.P(w, h, 0)
    save(cv.crop_anchor(ax, ay + 1), L1 + name + ".png")


def barn(name):
    cv = Canvas()
    w, h, wall, rh = 4, 3, 80, 70
    wall_face(cv, (0, h), (w, h), 0, wall, R("wood", 5), R("wood", 3), R("grey", 3), timber=False, boards=True,
              door=(w * 0.5, 1.3, 64))
    wall_face(cv, (w, h), (w, 0), 0, wall, R("wood", 3), R("wood", 1), R("grey", 2), timber=False, boards=True)
    roof_gable(cv, w, h, wall, rh, (R("wood", 4), R("wood", 2), R("wood", 1)), thatch=False)
    outline(cv.im)
    ax, ay = cv.P(w, h, 0)
    save(cv.crop_anchor(ax, ay + 1), L1 + name + ".png")


def smithy(name):
    cv = Canvas()
    w, h, wall, rh = 3, 2, 72, 40
    # tylna ściana kamienna z paleniskiem
    wall_face(cv, (0, 0), (w, 0), 0, wall, R("grey", 3), R("grey", 2), R("grey", 3), timber=False)
    wall_face(cv, (0, 0), (0, h), 0, wall, R("grey", 4), R("grey", 2), R("grey", 3), timber=False)
    # palenisko
    cv.gpoly([(0.4, 0.05, 0), (1.4, 0.05, 0), (1.4, 0.05, 30), (0.4, 0.05, 30)], R("ink", 1))
    cv.gpoly([(0.5, 0.06, 0), (1.3, 0.06, 0), (1.3, 0.06, 14), (0.5, 0.06, 14)], R("fire", 3))
    for i in range(10):
        p = cv.P(0.5 + rnd.random() * 0.8, 0.06, rnd.random() * 12)
        cv.d.point((round(p[0]), round(p[1])), fill=R("fire", 6))
    # słupy i dach jednospadowy
    for (gx, gy) in ((w, h), (w, 0), (0, h)):
        cv.gpoly([(gx - 0.06, gy, 0), (gx + 0.0, gy, 0), (gx, gy, wall), (gx - 0.06, gy, wall)], R("wood", 2))
        cv.gpoly([(gx, gy - 0.06, 0), (gx, gy, 0), (gx, gy, wall), (gx, gy - 0.06, wall)], R("wood", 1))
    cv.gpoly([(-0.1, -0.1, wall + rh), (w + 0.1, -0.1, wall + rh), (w + 0.1, h + 0.15, wall - 4),
              (-0.1, h + 0.15, wall - 4)], R("wood", 3))
    for k in range(1, 7):
        t = k / 7
        cv.line(cv.P(-0.1, -0.1 + (h + 0.25) * t, wall + rh - (rh + 4) * t),
                cv.P(w + 0.1, -0.1 + (h + 0.25) * t, wall + rh - (rh + 4) * t), R("wood", 1))
    chimney(cv, 0.6, 0.0, wall + rh - 10, 40)
    # kowadło
    a = (1.9, 1.1)
    cv.gpoly([(a[0], a[1] + 0.2, 0), (a[0] + 0.15, a[1] + 0.2, 0), (a[0] + 0.15, a[1] + 0.2, 14),
              (a[0], a[1] + 0.2, 14)], R("wood", 2))
    cv.gpoly([(a[0] - 0.15, a[1] + 0.1, 14), (a[0] + 0.3, a[1] + 0.1, 14), (a[0] + 0.3, a[1] + 0.3, 14),
              (a[0] - 0.15, a[1] + 0.3, 14), (a[0] - 0.15, a[1] + 0.3, 22), (a[0] + 0.3, a[1] + 0.3, 22),
              (a[0] + 0.3, a[1] + 0.1, 22)], R("steel", 2))
    outline(cv.im)
    ax, ay = cv.P(w, h, 0)
    save(cv.crop_anchor(ax, ay + 1), L1 + name + ".png")


# ---------------------------------------------------------------- małe obiekty (kotwica = środek komórki)
def small_canvas():
    return Canvas(300, 400, 150, 330)


def save_center(cv, rel):
    outline(cv.im)
    save(cv.crop_anchor(150, 330 + 1), rel)


def box(cv, cx, cy, sx, sy, z0, z1, top, left, right):
    """Prostopadłościan wyśrodkowany w punkcie siatki (cx, cy) o wymiarach sx, sy (w komórkach)."""
    x0, x1, y0, y1 = cx - sx / 2, cx + sx / 2, cy - sy / 2, cy + sy / 2
    cv.gpoly([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], left)
    cv.gpoly([(x1, y1, z0), (x1, y0, z0), (x1, y0, z1), (x1, y1, z1)], right)
    cv.gpoly([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], top)


def tree(rel, seed, dead=False, size=1.0):
    r = random.Random(seed)
    cv = small_canvas()
    base = cv.P(0, 0, 0)
    tw = 7 * size
    th = 70 * size
    cv.poly([(base[0] - tw, base[1]), (base[0] + tw, base[1]), (base[0] + tw * 0.6, base[1] - th),
             (base[0] - tw * 0.6, base[1] - th)], R("wood", 2))
    cv.line((base[0] + tw * 0.3, base[1]), (base[0] + tw * 0.2, base[1] - th), R("wood", 0), 2)
    if dead:
        for k in range(6):
            ang = math.radians(-160 + k * 28 + r.randint(-10, 10))
            y0 = base[1] - th * (0.5 + 0.5 * r.random())
            ln = (30 + r.randint(0, 25)) * size
            cv.line((base[0], y0), (base[0] + math.cos(ang) * ln, y0 + math.sin(ang) * ln), R("wood", 1), 3)
        save_center(cv, rel)
        return
    blobs = []
    for k in range(9):
        a = r.random() * math.tau
        d = r.random() * 28 * size
        blobs.append((base[0] + math.cos(a) * d * 1.3, base[1] - th - 10 * size + math.sin(a) * d * 0.8,
                      (22 + r.randint(0, 12)) * size))
    for (x, y, rr) in blobs:
        cv.d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=R("grass", 1))
    for (x, y, rr) in blobs:
        cv.d.ellipse([x - rr * 0.8 - 2, y - rr * 0.8 - 3, x + rr * 0.6, y + rr * 0.5], fill=R("grass", 3))
        cv.d.ellipse([x - rr * 0.6 - 4, y - rr * 0.7 - 5, x + rr * 0.1, y - rr * 0.1], fill=R("grass", 5))
    px = cv.im.load()
    for _ in range(int(500 * size)):
        x, y = r.randint(0, 299), r.randint(0, 399)
        if px[x, y][3] and px[x, y][:3] != R("wood", 2)[:3]:
            px[x, y] = r.choice([R("grass", 2), R("grass", 4), R("moss", 2), R("grass", 6)])
    save_center(cv, rel)


def bush(rel, seed):
    r = random.Random(seed)
    cv = small_canvas()
    b = cv.P(0, 0, 0)
    for k in range(6):
        x = b[0] + r.randint(-26, 26)
        y = b[1] - 14 - r.randint(0, 14)
        rr = 14 + r.randint(0, 8)
        cv.d.ellipse([x - rr, y - rr, x + rr, y + rr * 0.8], fill=R("grass", 2))
        cv.d.ellipse([x - rr * 0.7, y - rr, x + rr * 0.3, y], fill=R("grass", 4))
    save_center(cv, rel)


def fence(rel, axis, broken=False):
    cv = small_canvas()
    # płot wzdłuż osi x siatki (na ekranie "\") albo y ("/") przez środek komórki
    if axis == "x":
        a, b = (-0.5, 0), (0.5, 0)
    else:
        a, b = (0, -0.5), (0, 0.5)
    for t in (0.0, 0.5, 1.0):
        gx, gy = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        p0, p1 = cv.P(gx, gy, 0), cv.P(gx, gy, 40)
        cv.poly([(p0[0] - 3, p0[1]), (p0[0] + 3, p0[1]), (p1[0] + 3, p1[1]), (p1[0] - 3, p1[1])], R("wood", 3))
        cv.line((p0[0] + 1, p0[1]), (p1[0] + 1, p1[1]), R("wood", 1))
    for z in (14, 30):
        if broken and z == 30:
            continue
        cv.gpoly([(a[0], a[1], z - 3), (b[0], b[1], z - 3), (b[0], b[1], z + 3), (a[0], a[1], z + 3)], R("wood", 4))
        cv.line(cv.P(a[0], a[1], z - 3), cv.P(b[0], b[1], z - 3), R("wood", 2))
    save_center(cv, rel)


def well(rel, full_bucket=True):
    cv = Canvas(300, 400, 150, 330)
    c = cv.P(0, 0, 0)
    # kamienna cembrowina (elipsy)
    for z, col in ((0, R("grey", 3)), (10, R("grey", 4)), (20, R("grey", 5)), (30, R("grey", 6))):
        cv.d.ellipse([c[0] - 46, c[1] - 24 - z, c[0] + 46, c[1] + 22 - z], fill=col)
    cv.d.ellipse([c[0] - 34, c[1] - 47, c[0] + 34, c[1] - 13], fill=R("ink", 1))
    cv.d.ellipse([c[0] - 28, c[1] - 42, c[0] + 28, c[1] - 18], fill=R("sky", 1))
    for k in range(18):
        a = math.tau * k / 18
        x, y = c[0] + math.cos(a) * 44, c[1] - 30 + math.sin(a) * 22
        cv.d.point((round(x), round(y)), fill=R("grey", 2))
    # daszek na dwóch słupach
    for dx in (-40, 40):
        cv.line((c[0] + dx, c[1] - 30), (c[0] + dx, c[1] - 110), R("wood", 2), 5)
    cv.poly([(c[0] - 60, c[1] - 100), (c[0] + 60, c[1] - 100), (c[0], c[1] - 140)], R("wood", 4))
    cv.poly([(c[0] - 60, c[1] - 100), (c[0], c[1] - 140), (c[0] - 4, c[1] - 96)], R("wood", 5))
    cv.line((c[0] - 40, c[1] - 84), (c[0] + 40, c[1] - 84), R("wood", 1), 3)
    cv.line((c[0], c[1] - 84), (c[0], c[1] - 56), R("bone", 1), 1)
    cv.poly([(c[0] - 7, c[1] - 58), (c[0] + 7, c[1] - 58), (c[0] + 5, c[1] - 46), (c[0] - 5, c[1] - 46)], R("wood", 3))
    save_center(cv, rel)


def bucket_icon(full):
    im = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(9, 12), (31, 12), (28, 34), (12, 34)], fill=R("wood", 4))
    for x in (14, 20, 26):
        d.line([(x, 13), (x - (1 if x < 20 else -1), 33)], fill=R("wood", 2))
    d.line([(10, 17), (30, 17)], fill=R("steel", 3), width=2)
    d.line([(11, 29), (29, 29)], fill=R("steel", 3), width=2)
    d.arc([10, 2, 30, 22], 180, 360, fill=R("steel", 4), width=2)
    d.ellipse([9, 9, 31, 15], fill=R("sky", 4) if full else R("wood", 1))
    if full:
        d.line([(13, 11), (20, 11)], fill=R("sky", 7))
    return outline(im)


def chest(rel, opened=False):
    cv = small_canvas()
    box(cv, 0, 0, 0.42, 0.3, 0, 22, R("wood", 5), R("wood", 4), R("wood", 2))
    for gx in (-0.12, 0.12):
        cv.gpoly([(gx - 0.02, 0.15, 0), (gx + 0.02, 0.15, 0), (gx + 0.02, 0.15, 22), (gx - 0.02, 0.15, 22)], R("gold", 2))
    if opened:
        cv.gpoly([(-0.21, -0.15, 22), (0.21, -0.15, 22), (0.21, 0.15, 22), (-0.21, 0.15, 22)], R("ink", 1))
        cv.gpoly([(-0.21, -0.15, 22), (0.21, -0.15, 22), (0.21, -0.2, 46), (-0.21, -0.2, 46)], R("wood", 3))
    else:
        cv.gpoly([(-0.21, 0.15, 22), (0.21, 0.15, 22), (0.21, 0.08, 32), (-0.21, 0.08, 32)], R("wood", 6))
        cv.gpoly([(-0.21, 0.08, 32), (0.21, 0.08, 32), (0.21, -0.15, 32), (-0.21, -0.15, 22)], R("wood", 5))
        p = cv.P(0, 0.15, 14)
        cv.d.rectangle([p[0] - 3, p[1] - 4, p[0] + 3, p[1] + 3], fill=R("gold", 4))
    save_center(cv, rel)


def statue_base(cv, used):
    box(cv, 0, 0, 0.6, 0.6, 0, 24, R("grey", 6) if not used else R("grey", 4), R("grey", 4), R("grey", 2))
    box(cv, 0, 0, 0.44, 0.44, 24, 34, R("grey", 5), R("grey", 3), R("grey", 2))


def shrine_ulric(rel, used=False):
    cv = small_canvas()
    statue_base(cv, used)
    c = cv.P(0, 0, 34)
    col, dark = (R("grey", 7), R("grey", 4)) if not used else (R("grey", 4), R("grey", 2))
    # siedzący, wyjący wilk (sylwetka z wieloboków)
    cv.poly([(c[0] - 22, c[1]), (c[0] + 20, c[1]), (c[0] + 16, c[1] - 30), (c[0] + 4, c[1] - 52),
             (c[0] - 10, c[1] - 40), (c[0] - 22, c[1] - 14)], col)
    cv.poly([(c[0] + 2, c[1] - 50), (c[0] + 14, c[1] - 74), (c[0] + 26, c[1] - 86), (c[0] + 22, c[1] - 70),
             (c[0] + 16, c[1] - 52)], col)
    cv.poly([(c[0] + 6, c[1] - 64), (c[0] + 4, c[1] - 82), (c[0] + 12, c[1] - 70)], dark)
    cv.poly([(c[0] - 22, c[1] - 4), (c[0] - 38, c[1] - 2), (c[0] - 34, c[1] - 10), (c[0] - 20, c[1] - 12)], col)
    cv.line((c[0] + 8, c[1]), (c[0] + 10, c[1] - 26), dark, 2)
    cv.line((c[0] - 6, c[1] - 40), (c[0] + 8, c[1] - 30), dark)
    if not used:
        for k in range(10):
            a = math.tau * k / 10
            cv.d.point((round(c[0] + math.cos(a) * 34), round(c[1] - 40 + math.sin(a) * 40)), fill=R("gold", 4))
    save_center(cv, rel)


def shrine_rhya(rel, used=False):
    cv = small_canvas()
    statue_base(cv, used)
    c = cv.P(0, 0, 34)
    col, dark = (R("bone", 3), R("bone", 1)) if not used else (R("grey", 4), R("grey", 2))
    cv.poly([(c[0] - 16, c[1]), (c[0] + 16, c[1]), (c[0] + 9, c[1] - 52), (c[0] - 9, c[1] - 52)], col)
    cv.line((c[0] - 4, c[1]), (c[0] - 2, c[1] - 48), dark)
    cv.line((c[0] + 6, c[1]), (c[0] + 4, c[1] - 48), dark)
    cv.d.ellipse([c[0] - 8, c[1] - 70, c[0] + 8, c[1] - 52], fill=col)
    cv.poly([(c[0] - 9, c[1] - 64), (c[0] - 12, c[1] - 36), (c[0] - 7, c[1] - 52)], dark)   # włosy
    cv.line((c[0] + 8, c[1] - 44), (c[0] + 22, c[1] - 60), col, 3)                     # ramię
    cv.d.arc([c[0] + 14, c[1] - 86, c[0] + 42, c[1] - 58], 180, 330, fill=R("steel", 5) if not used else dark, width=3)
    cv.line((c[0] + 22, c[1] - 60), (c[0] + 24, c[1] - 72), R("wood", 3), 2)
    for k in range(8):
        p = (c[0] - 26 + k * 7, c[1] + 2)
        cv.d.point(p, fill=R("straw", 5) if not used else dark)
    save_center(cv, rel)


def barricade(rel, burnt=False):
    cv = small_canvas()
    r = random.Random(5 if not burnt else 6)
    for k in range(9):
        a = cv.P(-0.45 + r.random() * 0.3, -0.4 + r.random() * 0.8, r.randint(0, 10))
        b = cv.P(0.15 + r.random() * 0.3, -0.4 + r.random() * 0.8, r.randint(30, 70) if not burnt else r.randint(0, 22))
        col = (R("wood", r.randint(2, 5)) if not burnt else R("ink", r.randint(0, 2)))
        cv.line(a, b, col, 6)
        cv.line(a, b, R("wood", 1) if not burnt else R("grey", 2), 1)
    box(cv, 0.1, 0.1, 0.35, 0.3, 0, 18 if burnt else 30, R("wood", 4) if not burnt else R("ink", 2),
        R("wood", 3) if not burnt else R("ink", 1), R("wood", 1) if not burnt else R("ink", 0))
    if burnt:
        px = cv.im.load()
        for _ in range(80):
            x, y = r.randint(90, 210), r.randint(250, 330)
            if px[x, y][3]:
                px[x, y] = r.choice([R("ember", 1), R("ember", 2), R("grey", 3)])
    save_center(cv, rel)


def flames(rel_prefix, n=4):
    for f in range(n):
        r = random.Random(100 + f)
        im = Image.new("RGBA", (96, 112), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        for layer, (ramp_i, scale) in enumerate(((2, 1.0), (4, 0.7), (6, 0.4))):
            for k in range(7):
                x = 48 + r.randint(-30, 30) * scale
                hgt = (50 + r.randint(0, 45)) * scale
                wdt = (12 + r.randint(0, 8)) * scale
                y0 = 108
                d.polygon([(x - wdt, y0), (x + wdt, y0), (x + r.randint(-6, 6), y0 - hgt)], fill=R("fire", ramp_i))
        for _ in range(6):
            x, y = r.randint(20, 76), r.randint(10, 60)
            d.point((x, y), fill=R("fire", 6))
        save(im, rel_prefix + "%d.png" % f)


def simple_items():
    # beczka, skrzynia drewniana, wóz, stóg, nagrobki, drogowskaz
    cv = small_canvas()
    c = cv.P(0, 0, 0)
    cv.d.rectangle([c[0] - 18, c[1] - 46, c[0] + 18, c[1] - 6], fill=R("wood", 4))
    cv.d.ellipse([c[0] - 18, c[1] - 12, c[0] + 18, c[1]], fill=R("wood", 3))
    cv.d.rectangle([c[0] - 18, c[1] - 40, c[0] + 18, c[1] - 6], fill=R("wood", 4))
    for x in (-10, 0, 10):
        cv.line((c[0] + x, c[1] - 44), (c[0] + x, c[1] - 4), R("wood", 2))
    for y in (-38, -16):
        cv.line((c[0] - 18, c[1] + y), (c[0] + 18, c[1] + y), R("steel", 3), 2)
    cv.d.ellipse([c[0] - 18, c[1] - 52, c[0] + 18, c[1] - 40], fill=R("wood", 5))
    save_center(cv, L1 + "barrel.png")
    cv = small_canvas()
    box(cv, 0, 0, 0.4, 0.4, 0, 34, R("wood", 6), R("wood", 4), R("wood", 2))
    cv.line(cv.P(-0.2, 0.2, 0), cv.P(0.2, 0.2, 34), R("wood", 2), 2)
    cv.line(cv.P(0.2, 0.2, 0), cv.P(0.2, -0.2, 34), R("wood", 1), 2)
    save_center(cv, L1 + "crate.png")
    cv = small_canvas()
    c = cv.P(0, 0, 0)
    for k in range(5):
        cv.d.ellipse([c[0] - 44 + k * 4, c[1] - 50 + k * 2 - k * 9, c[0] + 44 - k * 6, c[1] - k * 9], fill=R("straw", 3 + (k % 3)))
    px = cv.im.load()
    for _ in range(300):
        x, y = rnd.randint(100, 200), rnd.randint(250, 330)
        if px[x, y][3]:
            px[x, y] = rnd.choice([R("straw", 2), R("straw", 6), R("straw", 4)])
    save_center(cv, L1 + "haystack.png")
    for i, kind in enumerate(("cross", "stone", "stone2")):
        cv = small_canvas()
        c = cv.P(0, 0, 0)
        cv.d.ellipse([c[0] - 22, c[1] - 10, c[0] + 22, c[1] + 4], fill=R("mud", 1))
        if kind == "cross":
            cv.d.rectangle([c[0] - 3, c[1] - 52, c[0] + 3, c[1] - 2], fill=R("wood", 3))
            cv.d.rectangle([c[0] - 14, c[1] - 42, c[0] + 14, c[1] - 36], fill=R("wood", 3))
        else:
            hgt = 40 if kind == "stone" else 30
            cv.d.rounded_rectangle([c[0] - 13, c[1] - hgt, c[0] + 13, c[1] - 2], 8, fill=R("grey", 5))
            cv.d.rectangle([c[0] + 6, c[1] - hgt + 6, c[0] + 13, c[1] - 2], fill=R("grey", 3))
            cv.line((c[0] - 5, c[1] - hgt + 12), (c[0] + 3, c[1] - hgt + 12), R("grey", 2))
            cv.line((c[0] - 1, c[1] - hgt + 8), (c[0] - 1, c[1] - hgt + 20), R("grey", 2))
        save_center(cv, L1 + "grave_%d.png" % i)
    cv = small_canvas()
    c = cv.P(0, 0, 0)
    cv.d.rectangle([c[0] - 3, c[1] - 80, c[0] + 3, c[1]], fill=R("wood", 2))
    cv.poly([(c[0] - 34, c[1] - 74), (c[0] + 26, c[1] - 74), (c[0] + 36, c[1] - 66), (c[0] + 26, c[1] - 58),
             (c[0] - 34, c[1] - 58)], R("wood", 5))
    cv.line((c[0] - 26, c[1] - 66), (c[0] + 18, c[1] - 66), R("wood", 2))
    save_center(cv, L1 + "signpost.png")
    # wóz
    cv = small_canvas()
    box(cv, 0, 0, 0.9, 0.5, 18, 40, R("wood", 5), R("wood", 4), R("wood", 2))
    for gx in (-0.3, 0.3):
        p = cv.P(gx, 0.25, 16)
        cv.d.ellipse([p[0] - 14, p[1] - 16, p[0] + 14, p[1] + 16], outline=R("wood", 1), width=4)
        cv.d.point((round(p[0]), round(p[1])), fill=R("wood", 1))
    cv.line(cv.P(0.45, 0, 24), cv.P(0.95, 0, 10), R("wood", 2), 3)
    save_center(cv, L1 + "cart.png")


def tavern_props():
    # stół, ława, lada z beczkami, kominek, drzwi wyważone / zamknięte, beczka piwa
    cv = small_canvas()
    box(cv, 0, 0, 0.8, 0.5, 26, 32, R("wood", 6), R("wood", 4), R("wood", 2))
    for gx, gy in ((-0.35, 0.2), (0.35, 0.2), (0.35, -0.2)):
        p0, p1 = cv.P(gx, gy, 0), cv.P(gx, gy, 26)
        cv.line(p0, p1, R("wood", 2), 4)
    for k, gx in enumerate((-0.2, 0.15)):
        p = cv.P(gx, 0.0, 32)
        cv.d.rectangle([p[0] - 4, p[1] - 10, p[0] + 4, p[1]], fill=R("steel", 4) if k else R("bone", 3))
    save_center(cv, TV + "table.png")
    cv = small_canvas()
    box(cv, 0, 0, 0.8, 0.22, 14, 19, R("wood", 5), R("wood", 3), R("wood", 1))
    for gx in (-0.33, 0.33):
        cv.line(cv.P(gx, 0.08, 0), cv.P(gx, 0.08, 14), R("wood", 1), 3)
    save_center(cv, TV + "bench.png")
    cv = Canvas()
    box(cv, 1.0, 0.25, 2.0, 0.5, 0, 46, R("wood", 6), R("wood", 4), R("wood", 2))
    for k in range(6):
        cv.line(cv.P(k * 0.4, 0.5, 2), cv.P(k * 0.4, 0.5, 44), R("wood", 2))
    for k, gx in enumerate((0.3, 0.9, 1.5)):
        p = cv.P(gx, 0.25, 46)
        cv.d.rectangle([p[0] - 4, p[1] - 10, p[0] + 4, p[1]], fill=R("steel", 4))
    outline(cv.im)
    ax, ay = cv.P(2.0, 0.5, 0)
    save(cv.crop_anchor(ax, ay + 1), TV + "bar_counter.png")
    cv = Canvas()
    box(cv, 0.6, 0.3, 1.2, 0.6, 0, 120, R("grey", 4), R("grey", 5), R("grey", 3))
    cv.gpoly([(0.25, 0.6, 0), (0.95, 0.6, 0), (0.95, 0.6, 50), (0.25, 0.6, 50)], R("ink", 1))
    for k in range(14):
        p = cv.P(0.3 + rnd.random() * 0.6, 0.6, rnd.random() * 30)
        cv.d.ellipse([p[0] - 5, p[1] - 9, p[0] + 5, p[1]], fill=R("fire", rnd.randint(2, 6)))
    for k in range(40):
        p = cv.P(rnd.random() * 1.2, 0.6, 50 + rnd.random() * 70)
        cv.d.point((round(p[0]), round(p[1])), fill=R("grey", 2))
    outline(cv.im)
    ax, ay = cv.P(1.2, 0.6, 0)
    save(cv.crop_anchor(ax, ay + 1), TV + "fireplace.png")
    for broken in (False, True):
        cv = small_canvas()
        if broken:
            cv.gpoly([(-0.4, 0.0, 0), (0.4, 0.0, 0), (0.4, 0.25, 0), (-0.4, 0.25, 0)], R("wood", 3))
            for k in range(4):
                cv.line(cv.P(-0.4 + k * 0.2, 0.0, 0), cv.P(-0.4 + k * 0.2, 0.25, 0), R("wood", 1))
        else:
            cv.gpoly([(-0.4, 0.0, 0), (0.4, 0.0, 0), (0.4, 0.0, 90), (-0.4, 0.0, 90)], R("wood", 3))
            for k in range(1, 4):
                cv.line(cv.P(-0.4 + k * 0.2, 0, 0), cv.P(-0.4 + k * 0.2, 0, 90), R("wood", 1))
            for z in (20, 70):
                cv.gpoly([(-0.4, 0.0, z - 3), (0.4, 0.0, z - 3), (0.4, 0.0, z + 3), (-0.4, 0.0, z + 3)], R("ink", 2))
        save_center(cv, TV + ("door_broken.png" if broken else "door_closed.png"))


def skaven_hole():
    cv = small_canvas()
    c = cv.P(0, 0, 0)
    cv.d.ellipse([c[0] - 40, c[1] - 20, c[0] + 40, c[1] + 6], fill=R("mud", 2))
    cv.d.ellipse([c[0] - 28, c[1] - 14, c[0] + 28, c[1] + 2], fill=R("ink", 0))
    save_center(cv, L1 + "rat_hole.png")


def exit_marker():
    cv = small_canvas()
    c = cv.P(0, 0, 0)
    cv.d.rectangle([c[0] - 4, c[1] - 100, c[0] + 4, c[1]], fill=R("wood", 2))
    cv.poly([(c[0] + 4, c[1] - 100), (c[0] + 50, c[1] - 92), (c[0] + 4, c[1] - 78)], R("blood", 5))
    save_center(cv, L1 + "exit_banner.png")


def fx():
    im = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([2, 2, 9, 9], fill=R("grey", 5))
    d.point((4, 4), fill=R("grey", 8))
    save(outline(im), FX + "stone.png")
    im = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([3, 3, 16, 16], fill=R("warp", 4))
    d.ellipse([6, 5, 12, 11], fill=R("warp", 6))
    d.point((8, 7), fill=R("warp", 7))
    save(outline(im, R("warp", 0)), FX + "warp_orb.png")
    for f in range(2):
        im = Image.new("RGBA", (112, 56), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        r = random.Random(30 + f)
        d.ellipse([2, 2, 109, 53], fill=R("warp", 1))
        d.ellipse([12, 8, 100, 48], fill=R("warp", 2))
        for _ in range(9):
            x, y = r.randint(14, 96), r.randint(10, 44)
            d.ellipse([x - 4, y - 2, x + 4, y + 2], fill=R("warp", 4 + f))
        save(im, FX + "poison_pool_%d.png" % f)
    im = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([3, 3, 16, 16], fill=R("sky", 4))
    d.ellipse([6, 6, 13, 13], fill=R("sky", 7))
    save(outline(im, R("sky", 0)), FX + "magic_bolt.png")
    im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([3, 3, 20, 20], fill=R("fire", 3))
    d.ellipse([7, 7, 16, 16], fill=R("fire", 6))
    save(outline(im, R("ember", 0)), FX + "fireball.png")
    flames(FX + "fire_", 4)


def main():
    house("house_a", 3, 3, thatch=True)
    house("house_b", 3, 2, thatch=False, along_x=True, wall=64, rh=52, windows_l=[(0.7, 30, 0.3, 16), (2.3, 30, 0.3, 16)])
    house("house_c", 2, 3, thatch=True, along_x=False, wall=60, rh=56, windows_l=[(1.0, 28, 0.3, 14)])
    house("house_burnt", 3, 3, burnt=True)
    house("herbalist_hut", 2, 2, thatch=True, wall=54, rh=50, windows_l=[(1.4, 26, 0.25, 12)],
          plaster=R("mud", 4), chim=False)
    house("tavern_outside", 4, 3, thatch=False, wall=80, rh=64,
          windows_l=[(0.6, 34, 0.3, 18), (1.4, 34, 0.3, 18), (3.2, 34, 0.3, 18)])
    mill("mill")
    barn("barn")
    smithy("smithy")
    for i in range(3):
        tree(L1 + "tree_%d.png" % i, 40 + i, size=1.0 + 0.15 * (i % 2))
    tree(L1 + "tree_dead.png", 9, dead=True)
    for i in range(2):
        bush(L1 + "bush_%d.png" % i, 60 + i)
    fence(L1 + "fence_x.png", "x")
    fence(L1 + "fence_y.png", "y")
    fence(L1 + "fence_x_broken.png", "x", broken=True)
    well(L1 + "well.png")
    chest(CP + "chest_closed.png")
    chest(CP + "chest_open.png", opened=True)
    save(bucket_icon(False), CP + "bucket_empty.png")
    save(bucket_icon(True), CP + "bucket_full.png")
    shrine_ulric(L1 + "shrine_ulric.png")
    shrine_ulric(L1 + "shrine_ulric_used.png", used=True)
    shrine_rhya(L1 + "shrine_rhya.png")
    shrine_rhya(L1 + "shrine_rhya_used.png", used=True)
    barricade(L1 + "barricade.png")
    barricade(L1 + "barricade_burnt.png", burnt=True)
    simple_items()
    tavern_props()
    skaven_hole()
    exit_marker()
    fx()
    print("rekwizyty gotowe")


if __name__ == "__main__":
    main()
