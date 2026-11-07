#!/usr/bin/env python3
"""Ikony umiejętności 48x48 (assets/ui/skills/<postać>/<id>.png) i grafiki pocisków (fire_lance, net_arrow).
Placeholdery do podmiany - te same nazwy plików. Uruchom: python3 tools/gen_skills.py"""
import math
from PIL import Image, ImageDraw
from pixlib import R, outline, save

S = 48


def base(bg):
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, S - 1, S - 1], fill=bg)
    for i in range(0, S, 6):
        d.line([(i, 0), (0, i)], fill=tuple(max(0, c - 12) for c in bg[:3]) + (255,))
    return im, d


def finish(im, d, path):
    d.rectangle([0, 0, S - 1, S - 1], outline=R("ink", 0))
    d.rectangle([1, 1, S - 2, S - 2], outline=R("gold", 1))
    save(im, path)


def sword(d, a, b, w=4):
    d.line([a, b], fill=R("steel", 5), width=w)
    d.line([(a[0] + 1, a[1] - 1), (b[0] + 1, b[1] - 1)], fill=R("steel", 6), width=1)


def fireball(d, cx, cy, r):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=R("fire", 2))
    d.ellipse([cx - r * 0.7, cy - r * 0.7, cx + r * 0.6, cy + r * 0.6], fill=R("fire", 4))
    d.ellipse([cx - r * 0.35, cy - r * 0.4, cx + r * 0.2, cy + r * 0.2], fill=R("fire", 6))


def arrow(d, a, b):
    d.line([a, b], fill=R("wood", 5), width=2)
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    tip = [b, (b[0] - 7 * math.cos(ang - 0.5), b[1] - 7 * math.sin(ang - 0.5)), (b[0] - 7 * math.cos(ang + 0.5), b[1] - 7 * math.sin(ang + 0.5))]
    d.polygon(tip, fill=R("steel", 5))
    for k in (0.4, -0.4):
        d.line([a, (a[0] + 6 * math.cos(ang + k), a[1] + 6 * math.sin(ang + k))], fill=R("bone", 4), width=2)


def main():
    o = "assets/ui/skills/"
    im, d = base(R("blood", 1))
    d.arc([6, 6, 44, 44], 200, 330, fill=R("white", 2), width=3)
    sword(d, (10, 40), (38, 10))
    d.line([(8, 34), (16, 42)], fill=R("gold", 3), width=3)
    finish(im, d, o + "ivo/potezne_ciecie.png")
    im, d = base(R("blood", 1))
    for k in range(3):
        d.arc([5 + k * 3, 5 + k * 3, 43 - k * 3, 43 - k * 3], 20 + k * 120, 120 + k * 120, fill=R("white", 1), width=2)
    sword(d, (24, 24), (40, 10), 3)
    sword(d, (24, 24), (8, 38), 3)
    finish(im, d, o + "ivo/wirujacy_miecz.png")
    im, d = base(R("blood", 2))
    d.polygon([(14, 6), (34, 6), (34, 30), (24, 24), (14, 30)], fill=R("blood", 6))
    d.line([(14, 6), (14, 44)], fill=R("wood", 3), width=3)
    for i, r in enumerate((10, 16, 22)):
        d.arc([24 - r, 30 - r, 24 + r, 30 + r], 300, 60, fill=R("gold", 4 - i), width=2)
    finish(im, d, o + "ivo/okrzyk_gwardii.png")
    im, d = base(R("ink", 2))
    fireball(d, 30, 18, 9)
    for k in range(4):
        d.line([(8 + k * 3, 40 - k * 2), (22, 26)], fill=R("fire", 3 - k % 2), width=2)
    finish(im, d, o + "ursa/ognisty_pocisk.png")
    im, d = base(R("ink", 2))
    for k in range(10):
        a = k * math.tau / 10
        d.line([(24, 24), (24 + 20 * math.cos(a), 24 + 20 * math.sin(a))], fill=R("fire", 3), width=2)
    fireball(d, 24, 24, 13)
    finish(im, d, o + "ursa/kula_ognia.png")
    im, d = base(R("ink", 2))
    for x in (14, 24, 34):
        d.ellipse([x - 4, 26, x + 4, 34], fill=R("fur", 3))
    d.polygon([(4, 28), (40, 24), (46, 30), (40, 36), (4, 32)], fill=R("fire", 3))
    d.line([(6, 30), (44, 30)], fill=R("fire", 6), width=2)
    finish(im, d, o + "ursa/przebijajacy_plomien.png")
    im, d = base(R("grass", 0))
    arrow(d, (8, 40), (40, 8))
    finish(im, d, o + "modraszka/strzala.png")
    im, d = base(R("grass", 0))
    for ang in (-0.45, 0.0, 0.45):
        a = (24 - 18 * math.sin(ang), 44)
        arrow(d, a, (24 + 22 * math.sin(ang) * 1.6, 8))
    finish(im, d, o + "modraszka/grad_strzal.png")
    im, d = base(R("grass", 0))
    for i in range(5):
        d.line([(18 + i * 6, 14), (12 + i * 6, 44)], fill=R("bone", 3))
        d.line([(10, 18 + i * 6), (44, 16 + i * 6)], fill=R("bone", 3))
    arrow(d, (6, 40), (30, 14))
    finish(im, d, o + "modraszka/strzala_z_siecia.png")
    # grafiki pocisków
    im = Image.new("RGBA", (44, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(0, 5), (34, 2), (43, 7), (34, 12), (0, 9)], fill=R("fire", 3))
    d.polygon([(6, 6), (34, 5), (40, 7), (34, 9), (6, 8)], fill=R("fire", 6))
    save(outline(im, R("ember", 0)), "assets/levels/common/fx/fire_lance.png")
    im = Image.new("RGBA", (32, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.line([(2, 7), (25, 7)], fill=R("wood", 4))
    d.polygon([(25, 5), (31, 7), (25, 9)], fill=R("steel", 5))
    d.ellipse([10, 2, 20, 12], fill=R("bone", 2))
    for x in range(11, 20, 3):
        d.line([(x, 3), (x, 11)], fill=R("bone", 4))
    save(outline(im), "assets/levels/common/fx/net_arrow.png")
    print("ikony umiejętności gotowe")


if __name__ == "__main__":
    main()
