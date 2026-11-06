#!/usr/bin/env python3
"""Ikony przedmiotów 32x32 (assets/ui/items/<ikona>.png) i ściany karczmy (assets/levels/tavern/props/wall_*.png).
Uruchom: python3 tools/gen_items.py"""
import math
from PIL import Image, ImageDraw
from pixlib import R, outline, save, Canvas

OUT = "assets/ui/items/"


def new():
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def blade(d, a, b, w, col, hi):
    d.line([a, b], fill=col, width=w)
    d.line([(a[0] - 1, a[1] - 1), (b[0] - 1, b[1] - 1)], fill=hi, width=1)


def icons():
    im, d = new()
    blade(d, (8, 25), (27, 4), 4, R("steel", 4), R("steel", 6))
    d.line([(4, 22), (11, 29)], fill=R("gold", 3), width=3)
    d.line([(3, 30), (8, 25)], fill=R("wood", 3), width=3)
    save(outline(im), OUT + "greatsword.png")
    im, d = new()
    blade(d, (10, 22), (25, 7), 3, R("steel", 4), R("steel", 6))
    d.line([(7, 19), (13, 25)], fill=R("gold", 2), width=2)
    d.line([(5, 27), (10, 22)], fill=R("wood", 3), width=3)
    save(outline(im), OUT + "sword.png")
    im, d = new()
    d.line([(8, 29), (22, 5)], fill=R("wood", 3), width=3)
    d.polygon([(22, 1), (27, 6), (22, 11), (17, 6)], fill=R("gold", 4))
    d.point((22, 6), fill=R("white", 2))
    save(outline(im), OUT + "staff.png")
    im, d = new()
    d.line([(8, 29), (22, 5)], fill=R("wood", 2), width=3)
    d.ellipse([17, 1, 27, 11], fill=R("warp", 5))
    save(outline(im), OUT + "warpstaff.png")
    im, d = new()
    d.line([(5, 29), (25, 5)], fill=R("wood", 3), width=2)
    d.polygon([(25, 2), (29, 6), (23, 9)], fill=R("steel", 5))
    save(outline(im), OUT + "spear.png")
    im, d = new()
    d.line([(6, 28), (16, 14)], fill=R("wood", 2), width=3)
    d.polygon([(14, 6), (26, 4), (24, 16), (14, 16)], fill=R("steel", 3))
    d.line([(14, 6), (26, 4)], fill=R("blood", 3))
    save(outline(im), OUT + "cleaver.png")
    im, d = new()
    d.line([(8, 29), (20, 5)], fill=R("wood", 3), width=3)
    d.polygon([(18, 3), (28, 6), (27, 16), (19, 11)], fill=R("steel", 4))
    save(outline(im), OUT + "axe.png")
    for name, col, col2 in (("jerkin", R("blood", 3), R("blood", 1)), ("fur", R("straw", 4), R("straw", 2)),
                            ("robe", R("sky", 3), R("sky", 1)), ("mail", R("steel", 3), R("steel", 1)),
                            ("plate", R("steel", 5), R("steel", 3))):
        im, d = new()
        d.polygon([(8, 5), (24, 5), (29, 12), (25, 14), (25, 29), (7, 29), (7, 14), (3, 12)], fill=col)
        d.polygon([(16, 5), (24, 5), (29, 12), (25, 14), (25, 29), (16, 29)], fill=col2)
        if name == "mail":
            for y in range(8, 29, 3):
                for x in range(8 + (y % 2), 25, 3):
                    d.point((x, y), fill=R("steel", 5))
        d.line([(8, 20), (24, 20)], fill=R("wood", 2), width=2)
        save(outline(im), OUT + name + ".png")
    im, d = new()
    d.ellipse([5, 10, 27, 22], fill=R("blood", 4))
    d.ellipse([9, 6, 23, 18], fill=R("blood", 5))
    d.line([(20, 6), (26, 2)], fill=R("bone", 4), width=2)
    save(outline(im), OUT + "beret.png")
    im, d = new()
    d.polygon([(16, 3), (27, 14), (26, 28), (6, 28), (5, 14)], fill=R("mud", 3))
    d.ellipse([10, 13, 22, 26], fill=R("ink", 1))
    save(outline(im), OUT + "hood.png")
    im, d = new()
    d.pieslice([5, 6, 27, 30], 180, 360, fill=R("steel", 4))
    d.rectangle([3, 17, 29, 20], fill=R("steel", 3))
    d.line([(16, 6), (16, 17)], fill=R("steel", 6))
    save(outline(im), OUT + "helmet.png")
    for name, gem in (("amulet", R("gold", 4)), ("wolf", R("grey", 7)), ("warpeye", R("warp", 5))):
        im, d = new()
        d.arc([6, 2, 26, 22], 200, 340, fill=R("bone", 3), width=1)
        d.line([(8, 6), (16, 18)], fill=R("bone", 2))
        d.line([(24, 6), (16, 18)], fill=R("bone", 2))
        d.ellipse([10, 16, 22, 28], fill=R("gold", 3))
        d.ellipse([13, 19, 19, 25], fill=gem)
        save(outline(im), OUT + name + ".png")
    im, d = new()
    d.line([(16, 2), (16, 10)], fill=R("mud", 3))
    d.polygon([(12, 10), (20, 10), (18, 28), (14, 28)], fill=R("bone", 4))
    save(outline(im), OUT + "tooth.png")
    for name, c1, c2 in (("potion_red", R("blood", 5), R("blood", 7)), ("potion_blue", R("sky", 4), R("sky", 6))):
        im, d = new()
        d.rectangle([13, 4, 19, 10], fill=R("bone", 3))
        d.rectangle([12, 2, 20, 5], fill=R("wood", 3))
        d.ellipse([6, 9, 26, 29], fill=R("steel", 5))
        d.ellipse([8, 13, 24, 28], fill=c1)
        d.ellipse([11, 15, 15, 19], fill=c2)
        save(outline(im), OUT + name + ".png")
    im, d = new()
    d.rectangle([7, 8, 22, 29], fill=R("wood", 4))
    for x in (11, 15, 19):
        d.line([(x, 9), (x, 28)], fill=R("wood", 2))
    d.arc([18, 11, 29, 24], 270, 90, fill=R("wood", 3), width=3)
    d.ellipse([6, 3, 23, 12], fill=R("bone", 5))
    d.ellipse([9, 2, 17, 8], fill=R("white", 2))
    save(outline(im), OUT + "beer.png")
    im, d = new()
    for i, (x, y) in enumerate(((9, 18), (17, 20), (13, 12), (20, 13))):
        d.ellipse([x - 6, y - 4, x + 6, y + 4], fill=R("gold", 3))
        d.ellipse([x - 4, y - 3, x + 3, y + 1], fill=R("gold", 4))
    save(outline(im), OUT + "gold.png")


def walls():
    for axis in ("x", "y"):
        for window in (False, True):
            cv = Canvas(300, 400, 150, 330)
            a, b = ((-0.5, 0), (0.5, 0)) if axis == "x" else ((0, -0.5), (0, 0.5))
            hgt = 150
            # ściana z muru pruskiego: tynk + belki
            lite = R("bone", 2) if axis == "x" else R("bone", 1)
            cv.gpoly([(a[0], a[1], 0), (b[0], b[1], 0), (b[0], b[1], hgt), (a[0], a[1], hgt)], lite)
            cv.gpoly([(a[0], a[1], 0), (b[0], b[1], 0), (b[0], b[1], 22), (a[0], a[1], 22)], R("wood", 3))
            for t in (0.0, 1.0):
                gx, gy = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
                p0, p1 = cv.P(gx, gy, 0), cv.P(gx, gy, hgt)
                cv.poly([(p0[0] - 4, p0[1]), (p0[0] + 4, p0[1]), (p1[0] + 4, p1[1]), (p1[0] - 4, p1[1])], R("wood", 2))
            for z in (22, 80, hgt - 4):
                cv.gpoly([(a[0], a[1], z - 3), (b[0], b[1], z - 3), (b[0], b[1], z + 3), (a[0], a[1], z + 3)], R("wood", 2))
            cv.line(cv.P(a[0], a[1], 26), cv.P(b[0], b[1], 76), R("wood", 2), 4)
            if window:
                m0 = (a[0] * 0.4, a[1] * 0.4)
                m1 = (b[0] * 0.4, b[1] * 0.4)
                cv.gpoly([(m0[0], m0[1], 92), (m1[0], m1[1], 92), (m1[0], m1[1], 128), (m0[0], m0[1], 128)], R("wood", 1))
                cv.gpoly([(m0[0] * 0.8, m0[1] * 0.8, 96), (m1[0] * 0.8, m1[1] * 0.8, 96),
                          (m1[0] * 0.8, m1[1] * 0.8, 124), (m0[0] * 0.8, m0[1] * 0.8, 124)], R("night", 3))
            outline(cv.im)
            name = "wall_%s%s.png" % (axis, "_window" if window else "")
            save(cv.crop_anchor(150, 331), "assets/levels/tavern/props/" + name)


if __name__ == "__main__":
    icons()
    walls()
    print("ikony i ściany gotowe")
