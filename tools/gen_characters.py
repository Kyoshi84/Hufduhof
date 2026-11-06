#!/usr/bin/env python3
"""Placeholdery postaci: trzy rodzaje skavenów (klatki animacji w 8 kierunkach) i Modraszka (pozy 8-kierunkowe + portret).

Struktura: assets/enemies/<wróg>/<animacja>/<kierunek>/<n>.png  oraz  assets/characters/modraszka/idle/<kierunek>/0.png
Płótno skavena 96x112, pivot (stopy) = (48, 108). Płótno bohatera 96x128, pivot = (48, 126).
Kierunki W/SW/NW są lustrzanym odbiciem E/SE/NE (gra też umie odbijać sama, gdy pliku brak).
Uruchom: python3 tools/gen_characters.py
"""
import json
import math
import os
import shutil

from PIL import Image, ImageDraw
from pixlib import R, outline, save, ROOT

EW, EH, EPX, EPY = 96, 112, 48, 108
DIRS = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
VIEW = {"south": "front", "north": "back", "east": "side", "south-east": "side", "north-east": "side_back"}
MIRROR = {"west": "east", "south-west": "south-east", "north-west": "north-east"}

KINDS = {
    "skaven_spear": {"fur": "fur", "fur_i": 3, "cloth": ("mud", 2), "weapon": "spear"},
    "skaven_slinger": {"fur": "mud", "fur_i": 4, "cloth": ("blood", 2), "weapon": "sling"},
    "skaven_warlock": {"fur": "grey", "fur_i": 5, "cloth": ("night", 2), "weapon": "staff"},
}


def thick(d, a, b, col, w):
    d.line([a, b], fill=col, width=w)
    r = w / 2 - 0.5
    for p in (a, b):
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=col)


def leg(d, hip, phase, col, lift_k=1.0, flip=1):
    fx = math.sin(phase) * 9
    lift = max(0.0, math.cos(phase)) * 5 * lift_k
    foot = (hip[0] + fx * flip, EPY - 1 - lift)
    knee = (hip[0] + 7 * flip + fx * 0.4 * flip, hip[1] + (foot[1] - hip[1]) * 0.45)
    ankle = (foot[0] - 5 * flip, foot[1] - 7)
    thick(d, hip, knee, col, 6)
    thick(d, knee, ankle, col, 4)
    thick(d, ankle, foot, col, 3)
    d.line([foot, (foot[0] + 4 * flip, foot[1])], fill=R("skin", 3), width=2)


def skaven_side(kind, pose):
    """Widok z boku (twarzą w prawo). pose: dict(walk, bob, atk, hurt)."""
    k = KINDS[kind]
    im = Image.new("RGBA", (EW, EH), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    fur = R(k["fur"], k["fur_i"])
    fur_d = R(k["fur"], k["fur_i"] - 2)
    fur_l = R(k["fur"], k["fur_i"] + 2)
    bob = pose.get("bob", 0)
    lean = -6 if pose.get("hurt") else (4 if pose.get("atk") == 2 else (-3 if pose.get("atk") == 1 else 0))
    hip = (42, 76 + bob)
    sh = (52 + lean, 54 + bob)
    head = (63 + lean, 44 + bob)
    w = pose.get("walk", 0.0)
    # ogon
    pts = [(hip[0] - 4 + 0, hip[1] + 2)]
    for i in range(1, 9):
        t = i / 8
        pts.append((hip[0] - 4 - t * 30, hip[1] + 2 + t * 22 + math.sin(t * 5 + w * 6) * 4))
    d.line(pts, fill=R("skin", 2), width=3)
    # noga tylna
    leg(d, (hip[0] - 2, hip[1]), w + math.pi, fur_d)
    # ręka tylna / broń w tle
    weapon = k["weapon"]
    atk = pose.get("atk", 0)
    hand = (sh[0] + 10 + (16 if atk == 2 else (-10 if atk == 1 else 0)), sh[1] + 12)
    if weapon == "spear":
        a = (hand[0] - 34, hand[1] + 10)
        b = (hand[0] + 26 + (8 if atk == 2 else 0), hand[1] - 8 + (6 if atk == 2 else 0))
        thick(d, a, b, R("wood", 3), 3)
        d.polygon([b, (b[0] - 6, b[1] - 4), (b[0] + 8, b[1] - 3), (b[0] - 5, b[1] + 4)], fill=R("steel", 5))
        d.polygon([(b[0] - 6, b[1] - 4), (b[0] + 9, b[1] - 2), (b[0] - 5, b[1] + 4)], fill=R("steel", 5))
    if weapon == "staff":
        top = (hand[0] + 4 + (6 if atk == 2 else 0), sh[1] - 26 - (8 if atk == 1 else 0))
        thick(d, (hand[0] - 2, EPY - 2), top, R("wood", 2), 3)
        r = 5 if atk != 1 else 7
        d.ellipse([top[0] - r, top[1] - r, top[0] + r, top[1] + r], fill=R("warp", 5))
        d.ellipse([top[0] - 2, top[1] - 3, top[0] + 1, top[1]], fill=R("warp", 7))
        if atk:
            for i in range(10):
                ang = i * math.tau / 10
                rr = 11 if atk == 1 else 15
                d.point((top[0] + math.cos(ang) * rr, top[1] + math.sin(ang) * rr), fill=R("warp", 6))
    # tułów (zgarbiony)
    if weapon == "staff":
        # szata czarownika
        d.polygon([(sh[0] - 12, sh[1] - 4), (sh[0] + 8, sh[1] - 2), (hip[0] + 16, EPY - 4), (hip[0] - 16, EPY - 4)],
                  fill=R("grey", 3))
        d.polygon([(sh[0] - 12, sh[1] - 4), (sh[0] - 2, sh[1] - 2), (hip[0] - 2, EPY - 4), (hip[0] - 16, EPY - 4)],
                  fill=R("grey", 2))
        for i in range(4):
            d.point((hip[0] - 10 + i * 7, EPY - 5), fill=R("warp", 4))
    else:
        leg(d, (hip[0] + 2, hip[1]), w, fur)
        d.polygon([(hip[0] - 9, hip[1] + 4), (hip[0] + 9, hip[1] + 4), (sh[0] + 10, sh[1] + 2), (sh[0] - 8, sh[1] - 6)],
                  fill=fur)
        d.polygon([(hip[0] - 9, hip[1] + 4), (hip[0] - 2, hip[1] + 4), (sh[0] - 2, sh[1] - 4), (sh[0] - 8, sh[1] - 6)],
                  fill=fur_d)
        d.line([(sh[0] + 6, sh[1] + 2), (hip[0] + 7, hip[1])], fill=fur_l)
        c, ci = k["cloth"]
        d.polygon([(hip[0] - 10, hip[1] - 2), (hip[0] + 10, hip[1] - 2), (hip[0] + 8, hip[1] + 10),
                   (hip[0] + 1, hip[1] + 6), (hip[0] - 7, hip[1] + 11)], fill=R(c, ci))
        d.line([(hip[0] - 10, hip[1] - 2), (hip[0] + 10, hip[1] - 2)], fill=R("wood", 1), width=2)
    # głowa
    hx, hy = head
    if weapon == "staff":
        d.polygon([(hx - 12, hy + 8), (hx - 10, hy - 10), (hx + 4, hy - 13), (hx + 10, hy - 2), (hx + 6, hy + 10)],
                  fill=R("grey", 3))
    d.ellipse([hx - 9, hy - 8, hx + 7, hy + 7], fill=fur)
    d.polygon([(hx + 3, hy - 5), (hx + 20, hy + 2), (hx + 19, hy + 5), (hx + 3, hy + 6)], fill=fur)
    d.polygon([(hx + 3, hy + 2), (hx + 19, hy + 5), (hx + 3, hy + 6)], fill=fur_d)
    d.ellipse([hx + 18, hy + 1, hx + 22, hy + 5], fill=R("skin", 4))
    d.point((hx + 12, hy + 7), fill=R("bone", 4))
    d.point((hx + 14, hy + 7), fill=R("bone", 4))
    d.rectangle([hx + 3, hy - 3, hx + 5, hy - 1], fill=R("blood", 7) if weapon != "staff" else R("warp", 6))
    # uszy
    d.polygon([(hx - 6, hy - 6), (hx - 3, hy - 18), (hx + 2, hy - 6)], fill=fur)
    d.polygon([(hx - 4, hy - 7), (hx - 3, hy - 14), (hx, hy - 7)], fill=R("skin", 3))
    if weapon == "staff":
        d.polygon([(hx - 9, hy - 4), (hx - 16, hy - 12), (hx - 8, hy - 9)], fill=R("bone", 2))   # róg
    # ręka przednia
    arm_col = fur_l if weapon != "staff" else R("grey", 4)
    if weapon == "sling":
        if atk == 1:
            ang = pose.get("spin", 0.0)
            top = (sh[0] + 2, sh[1] - 20)
            thick(d, (sh[0] + 2, sh[1] + 2), top, arm_col, 4)
            st = (top[0] + math.cos(ang) * 14, top[1] + math.sin(ang) * 6)
            d.line([top, st], fill=R("wood", 5), width=1)
            d.ellipse([st[0] - 2, st[1] - 2, st[0] + 2, st[1] + 2], fill=R("grey", 6))
        elif atk == 2:
            thick(d, (sh[0] + 2, sh[1] + 2), (sh[0] + 20, sh[1] - 4), arm_col, 4)
            d.line([(sh[0] + 20, sh[1] - 4), (sh[0] + 30, sh[1] + 2)], fill=R("wood", 5))
        else:
            thick(d, (sh[0] + 2, sh[1] + 2), (sh[0] + 8, sh[1] + 18), arm_col, 4)
            d.line([(sh[0] + 8, sh[1] + 18), (sh[0] + 6, sh[1] + 28)], fill=R("wood", 5))
            d.ellipse([sh[0] + 4, sh[1] + 27, sh[0] + 8, sh[1] + 31], fill=R("mud", 3))
    else:
        thick(d, (sh[0] + 2, sh[1] + 2), hand, arm_col, 4)
        d.ellipse([hand[0] - 2, hand[1] - 2, hand[0] + 2, hand[1] + 2], fill=R("skin", 3))
    return im


def skaven_front(kind, pose, back=False):
    k = KINDS[kind]
    im = Image.new("RGBA", (EW, EH), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    fur = R(k["fur"], k["fur_i"])
    fur_d = R(k["fur"], k["fur_i"] - 2)
    fur_l = R(k["fur"], k["fur_i"] + 2)
    bob = pose.get("bob", 0)
    w = pose.get("walk", 0.0)
    cx = EPX
    hip_y = 78 + bob
    sh_y = 56 + bob
    atk = pose.get("atk", 0)
    weapon = k["weapon"]
    if back:
        pts = [(cx, hip_y + 4)]
        for i in range(1, 7):
            t = i / 6
            pts.append((cx + math.sin(t * 4 + w * 6) * 6, hip_y + 4 + t * 26))
        d.line(pts, fill=R("skin", 2), width=3)
    if weapon != "staff":
        for side in (-1, 1):
            ph = w + (0 if side < 0 else math.pi)
            lift = max(0.0, math.cos(ph)) * 4
            hip = (cx + side * 6, hip_y)
            knee = (cx + side * 9, hip_y + 14)
            foot = (cx + side * 8, EPY - 1 - lift)
            thick(d, hip, knee, fur_d if side > 0 else fur, 6)
            thick(d, knee, foot, fur_d if side > 0 else fur, 4)
            d.line([(foot[0] - 3, foot[1]), (foot[0] + 3, foot[1])], fill=R("skin", 3), width=2)
        d.polygon([(cx - 10, hip_y + 4), (cx + 10, hip_y + 4), (cx + 12, sh_y), (cx - 12, sh_y)], fill=fur)
        d.polygon([(cx + 2, hip_y + 4), (cx + 10, hip_y + 4), (cx + 12, sh_y), (cx + 4, sh_y)], fill=fur_d)
        if not back:
            d.polygon([(cx - 5, hip_y), (cx + 5, hip_y), (cx + 6, sh_y + 6), (cx - 6, sh_y + 6)], fill=fur_l)
        c, ci = k["cloth"]
        d.polygon([(cx - 11, hip_y - 2), (cx + 11, hip_y - 2), (cx + 9, hip_y + 10), (cx, hip_y + 6),
                   (cx - 9, hip_y + 11)], fill=R(c, ci))
    else:
        d.polygon([(cx - 13, sh_y), (cx + 13, sh_y), (cx + 18, EPY - 3), (cx - 18, EPY - 3)], fill=R("grey", 3))
        d.polygon([(cx + 3, sh_y), (cx + 13, sh_y), (cx + 18, EPY - 3), (cx + 6, EPY - 3)], fill=R("grey", 2))
        if not back:
            d.line([(cx, sh_y + 4), (cx, EPY - 4)], fill=R("warp", 3))
    # ramiona i broń
    arm = fur_l if weapon != "staff" else R("grey", 4)
    for side in (-1, 1):
        hand = (cx + side * 16, sh_y + 20 - (10 if (atk and side == 1) else 0))
        thick(d, (cx + side * 11, sh_y + 2), hand, arm, 4)
    rh = (cx + 16, sh_y + 20 - (10 if atk else 0))
    if weapon == "spear":
        top = (rh[0] + 1, rh[1] - 40 - (8 if atk == 2 else 0))
        thick(d, (rh[0] - 1, rh[1] + 20), top, R("wood", 3), 3)
        d.polygon([(top[0] - 3, top[1]), (top[0] + 3, top[1]), (top[0], top[1] - 10)], fill=R("steel", 5))
    elif weapon == "staff":
        top = (rh[0] + 1, sh_y - 26 - (8 if atk == 1 else 0))
        thick(d, (rh[0], EPY - 2), top, R("wood", 2), 3)
        r = 5 if atk != 1 else 7
        d.ellipse([top[0] - r, top[1] - r, top[0] + r, top[1] + r], fill=R("warp", 5))
    elif weapon == "sling" and atk == 1:
        ang = pose.get("spin", 0.0)
        st = (rh[0] + math.cos(ang) * 12, rh[1] - 6 + math.sin(ang) * 5)
        d.line([rh, st], fill=R("wood", 5))
        d.ellipse([st[0] - 2, st[1] - 2, st[0] + 2, st[1] + 2], fill=R("grey", 6))
    # głowa
    hy = sh_y - 10
    if weapon == "staff":
        d.polygon([(cx - 13, hy + 6), (cx - 11, hy - 12), (cx + 11, hy - 12), (cx + 13, hy + 6)], fill=R("grey", 3))
    d.ellipse([cx - 9, hy - 9, cx + 9, hy + 7], fill=fur)
    for side in (-1, 1):
        d.polygon([(cx + side * 4, hy - 6), (cx + side * 10, hy - 20), (cx + side * 11, hy - 4)], fill=fur)
        if not back:
            d.polygon([(cx + side * 6, hy - 6), (cx + side * 9, hy - 15), (cx + side * 9, hy - 5)], fill=R("skin", 3))
    if not back:
        d.polygon([(cx - 5, hy + 1), (cx + 5, hy + 1), (cx, hy + 12)], fill=fur_l)
        d.ellipse([cx - 2, hy + 9, cx + 2, hy + 13], fill=R("skin", 4))
        eye = R("blood", 7) if weapon != "staff" else R("warp", 6)
        d.rectangle([cx - 5, hy - 3, cx - 3, hy - 1], fill=eye)
        d.rectangle([cx + 3, hy - 3, cx + 5, hy - 1], fill=eye)
    return im


def frame(kind, view, pose):
    if view == "front":
        im = skaven_front(kind, pose)
    elif view == "back":
        im = skaven_front(kind, pose, back=True)
    else:
        im = skaven_side(kind, pose)
        if view == "side_back":
            # widok z tyłu-boku: bez oczu (przyciemnione) - wystarczająco czytelne jako placeholder
            px = im.load()
            for y in range(EH):
                for x in range(EW):
                    if px[x, y][3] and px[x, y][:3] in (R("blood", 7)[:3], R("warp", 6)[:3], R("bone", 4)[:3]):
                        px[x, y] = R(KINDS[kind]["fur"], KINDS[kind]["fur_i"])
    return outline(im)


def death_frames(base):
    out = []
    for ang, drop in ((25, 0), (55, 6), (88, 14)):
        im = Image.new("RGBA", (EW, EH), (0, 0, 0, 0))
        rot = base.rotate(ang, resample=Image.NEAREST, center=(EPX, EPY), expand=False)
        im.alpha_composite(rot, (0, 0))
        out.append(im)
    last = out[-1].copy()
    d = ImageDraw.Draw(last)
    d.ellipse([20, EPY - 6, 66, EPY + 2], fill=R("blood", 2))
    last.alpha_composite(out[-1])
    out.append(last)
    return out


def write_enemy(kind):
    base = os.path.join("assets", "enemies", kind)
    full = os.path.join(ROOT, base)
    if os.path.isdir(full):
        shutil.rmtree(full)
    anims = {}
    for d in ("south", "south-east", "east", "north-east", "north"):
        view = VIEW[d]
        a = {}
        a["idle"] = [frame(kind, view, {"bob": 0}), frame(kind, view, {"bob": 1})]
        a["walk"] = [frame(kind, view, {"walk": i * math.pi / 2, "bob": [0, 1, 0, 1][i]}) for i in range(4)]
        a["attack"] = [frame(kind, view, {"atk": 1, "spin": 0.0}), frame(kind, view, {"atk": 1, "spin": 3.0}),
                       frame(kind, view, {"atk": 2})]
        a["hurt"] = [frame(kind, view, {"hurt": True})]
        a["death"] = death_frames(a["hurt"][0])
        anims[d] = a
    for d in DIRS:
        src = MIRROR.get(d)
        for an, frames in (anims[src] if src else anims[d]).items():
            for i, im in enumerate(frames):
                if src:
                    im = im.transpose(Image.FLIP_LEFT_RIGHT)
                save(im, os.path.join(base, an, d, "%d.png" % i))
    json.dump({"canvas": [EW, EH], "pivot": [EPX, EPY],
               "fps": {"idle": 3, "walk": 7, "attack": 0, "hurt": 1, "death": 6},
               "_opis": "fps=0 dla 'attack' oznacza: klatki rozkładane na czas zamachu (ostatnia = moment trafienia)."},
              open(os.path.join(full, "sprite.json"), "w"), indent=1)


# ---------------------------------------------------------------- Modraszka (placeholder)
HW_, HH_, HPX, HPY = 96, 128, 48, 126


def modraszka(view):
    im = Image.new("RGBA", (HW_, HH_), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = HPX
    robe, robe_d, robe_l = R("sky", 3), R("sky", 1), R("sky", 5)
    hair = R("straw", 5)
    skin = R("skin", 5)
    side = view in ("side", "side_back")
    # szata
    if side:
        d.polygon([(cx - 10, 52), (cx + 8, 52), (cx + 16, HPY - 2), (cx - 18, HPY - 2)], fill=robe)
        d.polygon([(cx - 10, 52), (cx - 3, 52), (cx - 6, HPY - 2), (cx - 18, HPY - 2)], fill=robe_d)
    else:
        d.polygon([(cx - 13, 50), (cx + 13, 50), (cx + 22, HPY - 2), (cx - 22, HPY - 2)], fill=robe)
        d.polygon([(cx + 3, 50), (cx + 13, 50), (cx + 22, HPY - 2), (cx + 8, HPY - 2)], fill=robe_d)
        if view == "front":
            d.polygon([(cx - 4, 60), (cx + 4, 60), (cx + 8, HPY - 2), (cx - 8, HPY - 2)], fill=robe_l)
    for i in range(14):
        x = cx - 18 + (i * 37) % 36
        y = 62 + (i * 23) % 60
        if im.getpixel((x, y))[3]:
            d.point((x, y), fill=R("gold", 4))
    d.line([(cx - 13, 70), (cx + 13, 70)], fill=R("gold", 2), width=2)
    # buty
    d.rectangle([cx - 10, HPY - 4, cx - 3, HPY], fill=R("wood", 1))
    d.rectangle([cx + 3, HPY - 4, cx + 10, HPY], fill=R("wood", 1))
    # ręce i kostur
    staff_x = cx + 20 if not side else cx + 14
    d.line([(staff_x, HPY - 1), (staff_x + 2, 20)], fill=R("wood", 3), width=3)
    d.polygon([(staff_x + 2, 10), (staff_x + 6, 18), (staff_x + 2, 26), (staff_x - 2, 18)], fill=R("gold", 4))
    d.point((staff_x + 2, 18), fill=R("white", 2))
    d.line([(cx + 10, 56), (staff_x, 66)], fill=robe, width=5)
    d.ellipse([staff_x - 3, 63, staff_x + 2, 68], fill=skin)
    if not side:
        d.line([(cx - 12, 56), (cx - 16, 80)], fill=robe, width=5)
        d.ellipse([cx - 19, 78, cx - 13, 84], fill=skin)
    # głowa, włosy, kaptur
    d.ellipse([cx - 9, 28, cx + 9, 48], fill=skin if view != "back" else hair)
    d.polygon([(cx - 12, 34), (cx - 10, 22), (cx, 16), (cx + 10, 22), (cx + 12, 34), (cx + 10, 50),
               (cx + 14, 64), (cx - 14, 64), (cx - 10, 50)], fill=robe_d)
    if view == "back":
        d.polygon([(cx - 8, 30), (cx + 8, 30), (cx + 10, 64), (cx - 10, 64)], fill=robe)
    else:
        d.ellipse([cx - 8, 28, cx + 8, 46] if not side else [cx - 4, 28, cx + 10, 46], fill=skin)
        d.polygon([(cx - 8, 30), (cx - 2, 26), (cx + 8, 30), (cx + 8, 34), (cx - 8, 34)], fill=hair)
        ex = [cx - 4, cx + 3] if not side else [cx + 5]
        for x in ex:
            d.rectangle([x, 37, x + 1, 38], fill=R("sky", 2))
        d.line([(cx - 9, 34), (cx - 10, 58)], fill=hair, width=3)
        if not side:
            d.line([(cx + 9, 34), (cx + 10, 58)], fill=hair, width=3)
    return outline(im)


def write_modraszka():
    base = "assets/characters/modraszka/idle/"
    views = {"south": "front", "north": "back", "east": "side", "south-east": "side", "north-east": "side_back",
             "west": "side", "south-west": "side", "north-west": "side_back"}
    for d in DIRS:
        im = modraszka(views[d])
        if d in MIRROR:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        save(im, base + d + "/0.png")
    # portret: powiększony widok z przodu (placeholder)
    im = modraszka("front").crop((14, 6, 82, 130)).resize((168, 304), Image.NEAREST)
    save(im, "assets/characters/modraszka/portrait.png")


def write_borubar():
    src = os.path.join(ROOT, "assets/levels/tavern/props/borubar.png")
    for d in ("south",):
        dst = os.path.join(ROOT, "assets/characters/borubar/idle", d)
        os.makedirs(dst, exist_ok=True)
        shutil.copy(src, os.path.join(dst, "0.png"))


def main():
    for kind in KINDS:
        write_enemy(kind)
    write_modraszka()
    write_borubar()
    print("postacie gotowe")


if __name__ == "__main__":
    main()
