#!/usr/bin/env python3
"""Kafle izometryczne (128x64, romb) dla wioski, karczmy i mgły wojny.
Wynik: assets/levels/<poziom>/tiles/<nazwa>.png. Uruchom: python3 tools/gen_tiles.py"""
import random
from PIL import Image
from pixlib import R, save, TW, TH


def inside(x, y, grow=0.0):
    return abs(x + 0.5 - TW / 2) / (TW / 2) + abs(y + 0.5 - TH / 2) / (TH / 2) <= 1.0 + grow


def tile(base_cols, speckles, rnd, density=0.35, blades=None, stones=None):
    im = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    px = im.load()
    for y in range(TH):
        for x in range(TW):
            if not inside(x, y, 0.03):
                continue
            # duże plamy: wartość zależna od współrzędnych (bez gradientu - dwa poziomy)
            px[x, y] = base_cols[0] if ((x // 6 + y // 3 + rnd.randint(0, 1)) % 5) else base_cols[1]
            if rnd.random() < density:
                px[x, y] = rnd.choice(speckles)
    if blades:
        for _ in range(blades[0]):
            x, y = rnd.randint(8, TW - 9), rnd.randint(4, TH - 5)
            if inside(x, y, -0.15):
                for k in range(rnd.randint(2, 4)):
                    if inside(x, y - k):
                        px[x, y - k] = blades[1] if k else blades[2]
    if stones:
        for _ in range(stones[0]):
            x, y = rnd.randint(10, TW - 11), rnd.randint(5, TH - 6)
            if inside(x, y, -0.2):
                for dx in range(3):
                    px[x + dx, y] = stones[1]
                    px[x + dx, y + 1] = stones[2]
    return im


def cobble(rnd, dark=False):
    im = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    px = im.load()
    mortar = R("mud", 0 if dark else 1)
    for y in range(TH):
        for x in range(TW):
            if inside(x, y, 0.03):
                px[x, y] = mortar
    # kamienie w siatce izometrycznej (rzędy wzdłuż osi)
    for gy in range(-2, 12):
        for gx in range(-2, 12):
            cx = (gx - gy) * 7 + TW / 2 + rnd.randint(-1, 1)
            cy = (gx + gy) * 3.5 + 2 + rnd.randint(-1, 1)
            c = rnd.choice([R("grey", 2), R("grey", 3), R("grey", 3), R("steel", 1)])
            hi = R("grey", 4)
            for yy in range(-2, 2):
                for xx in range(-5, 5):
                    if abs(xx) / 5.0 + abs(yy + 0.5) / 2.5 > 1.0:
                        continue
                    X, Y = int(cx + xx), int(cy + yy)
                    if 0 <= X < TW and 0 <= Y < TH and inside(X, Y, 0.03):
                        px[X, Y] = hi if yy == -2 or (yy == -1 and xx < -2) else c
    return im


def planks(rnd, base_ramp="wood", lo=4, hi=7):
    im = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    px = im.load()
    for y in range(TH):
        for x in range(TW):
            if not inside(x, y, 0.03):
                continue
            # deski biegną wzdłuż osi x siatki (na ekranie "\"): u = x/2 - y
            u = (x / 2.0 + y)
            board = int(u // 8)
            seam = (u % 8) < 1.0
            r = random.Random(board * 7 + 3)
            shade = lo + r.randint(0, hi - lo)
            px[x, y] = R(base_ramp, shade - 3) if seam else R(base_ramp, shade)
            if not seam and rnd.random() < 0.06:
                px[x, y] = R(base_ramp, shade - 1)
    return im


def main():
    rnd = random.Random(7)
    g = "assets/levels/level1/tiles/"
    grass_base = [R("moss", 2), R("moss", 1)]
    grass_sp = [R("moss", 3), R("moss", 0), R("mud", 1)]
    for i in range(4):
        save(tile(grass_base, grass_sp, rnd, 0.3, blades=(22, R("moss", 4), R("moss", 3))), g + "grass_%d.png" % i)
    flowers = tile(grass_base, grass_sp, rnd, 0.3, blades=(16, R("moss", 4), R("moss", 3)))
    px = flowers.load()
    for _ in range(14):
        x, y = rnd.randint(20, 108), rnd.randint(10, 54)
        if inside(x, y, -0.2):
            px[x, y] = rnd.choice([R("bone", 2), R("blood", 3), R("straw", 3)])
    save(flowers, g + "grass_flowers.png")
    dirt_base = [R("mud", 3), R("mud", 2)]
    dirt_sp = [R("mud", 4), R("mud", 1), R("wood", 6)]
    for i in range(2):
        save(tile(dirt_base, dirt_sp, rnd, 0.35, stones=(6, R("grey", 6), R("grey", 3))), g + "dirt_%d.png" % i)
    for i in range(2):
        save(cobble(rnd), g + "cobble_%d.png" % i)
    save(tile([R("mud", 1), R("mud", 0)], [R("mud", 2), R("night", 1), R("mud", 3)], rnd, 0.4), g + "mud_0.png")
    save(tile([R("moss", 0), R("ink", 2)], [R("moss", 1), R("mud", 0), R("ink", 1)], rnd, 0.45,
              blades=(8, R("moss", 2), R("moss", 1))), g + "forest_0.png")

    t = "assets/levels/tavern/tiles/"
    for i in range(2):
        save(planks(rnd), t + "floor_%d.png" % i)
    rug = planks(rnd)
    px = rug.load()
    for y in range(TH):
        for x in range(TW):
            if inside(x, y, 0.03):
                px[x, y] = R("blood", 3) if ((x // 4 + y // 2) % 3) else R("blood", 2)
    save(rug, t + "rug_0.png")
    save(cobble(rnd, dark=True), t + "stone_0.png")

    f = "assets/levels/common/tiles/"
    black = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    soft = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    bp, sp = black.load(), soft.load()
    for y in range(TH):
        for x in range(TW):
            if inside(x, y, 0.04):
                bp[x, y] = R("ink", 0)
                if (x + y) % 2 == 0 or (x % 4 == 1 and y % 2 == 1):
                    sp[x, y] = R("ink", 0)
    save(black, f + "fog_full.png")
    save(soft, f + "fog_soft.png")
    print("kafle gotowe")


if __name__ == "__main__":
    main()
