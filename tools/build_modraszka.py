#!/usr/bin/env python3
"""Modraszka z obrazu autora: assets/characters/modraszka/source/modraszka_source.webp (oryginał - nie jest zmieniany).

Obraz ma wtopioną szachownicę zamiast przezroczystości, więc tło jest usuwane wypełnieniem od krawędzi
(jasne, szare piksele połączone z brzegiem). Z jednego rysunku powstają:
  idle/<kierunek>/0..1.png, walk/<kierunek>/0..3.png, attack/<kierunek>/0..2.png, hurt/<kierunek>/0.png,
  death/<kierunek>/0..3.png  (płótno 320x128 - szerokie, żeby zmieściła się leżąca postać; pivot = stopy w (160, 126)) oraz portrait.png.
Rysunek jest jeden (postać zwrócona w lewo), więc kierunki "w prawo" to odbicie lustrzane, a klatki ruchu
powstają przez przekształcenia rysunku (kołysanie, pochylenie, obrót). Własne klatki: podmień pliki o tych samych nazwach.
Uruchom: python3 tools/build_modraszka.py
"""
import os
import shutil
from collections import deque

from PIL import Image
from pixlib import ROOT, save, to_palette

SRC = os.path.join(ROOT, "assets/characters/modraszka/source/modraszka_source.webp")
OUT = "assets/characters/modraszka/"
CW, CH, PX, PY = 320, 128, 160, 126
FIG_H = 120
LEFT = ["south", "south-west", "west", "north-west", "north"]
RIGHT = ["south-east", "east", "north-east"]


def is_bg(p):
    r, g, b = p[:3]
    return min(r, g, b) >= 196 and max(r, g, b) - min(r, g, b) <= 18


def cutout():
    im = Image.open(SRC).convert("RGB")
    w, h = im.size
    px = im.load()
    mask = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or mask[y * w + x]:
            continue
        if not is_bg(px[x, y]):
            continue
        mask[y * w + x] = 1
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    # zamknięte "okna" tła (np. między łukiem a cięciwą): duże jasnoszare obszary niepołączone z brzegiem
    seen = bytearray(w * h)
    for sy in range(h):
        for sx in range(w):
            i0 = sy * w + sx
            if seen[i0] or mask[i0] or not is_bg(px[sx, sy]):
                continue
            comp = []
            q = deque([(sx, sy)])
            seen[i0] = 1
            while q:
                x, y = q.popleft()
                comp.append(y * w + x)
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and not mask[ny * w + nx] and is_bg(px[nx, ny]):
                        seen[ny * w + nx] = 1
                        q.append((nx, ny))
            if len(comp) >= 1500:
                for i in comp:
                    mask[i] = 1
    out = im.convert("RGBA")
    op = out.load()
    for y in range(h):
        for x in range(w):
            if mask[y * w + x]:
                op[x, y] = (0, 0, 0, 0)
    return out.crop(out.getbbox())


def base_sprite(fig):
    scale = FIG_H / fig.height
    small = fig.resize((max(1, round(fig.width * scale)), FIG_H), Image.LANCZOS)
    # alfa 0/255 i kontur zostają ostre
    a = small.split()[3].point(lambda v: 255 if v >= 128 else 0)
    small.putalpha(a)
    return small


def place(sprite, dx=0, dy=0, angle=0.0, squash=1.0):
    """Wstawia sprite na płótno: stopy w pivocie; opcjonalny obrót wokół stóp i spłaszczenie."""
    s = sprite
    if squash != 1.0:
        s = s.resize((s.width, max(1, round(s.height * squash))), Image.NEAREST)
    canvas = Image.new("RGBA", (CW * 3, CH * 3), (0, 0, 0, 0))
    ox, oy = CW + PX, CH + PY
    # stopy postaci są nieco na prawo od środka rysunku (łuk wystaje w lewo)
    foot_x = round(s.width * 0.60)
    canvas.alpha_composite(s, (ox - foot_x, oy - s.height))
    if angle:
        canvas = canvas.rotate(angle, resample=Image.NEAREST, center=(ox, oy))
    return canvas.crop((CW - dx, CH - dy, CW * 2 - dx, CH * 2 - dy))


def tint(im, col, k):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (int(r + (col[0] - r) * k), int(g + (col[1] - g) * k), int(b + (col[2] - b) * k), 255)
    return im


def frames(sprite):
    f = {}
    f["idle"] = [place(sprite), place(sprite, dy=1, squash=0.99)]
    f["walk"] = [place(sprite, dy=0, angle=2), place(sprite, dy=-2), place(sprite, dy=0, angle=-2), place(sprite, dy=-2)]
    # atak: odchylenie do tyłu (naciąg łuku), jeszcze głębiej, wypad do przodu (strzał / dźgnięcie)
    f["attack"] = [place(sprite, dx=2, angle=-4), place(sprite, dx=3, angle=-7), place(sprite, dx=-4, angle=6)]
    f["hurt"] = [tint(place(sprite, dx=4, angle=-10), (255, 255, 255), 0.35)]
    death = [place(sprite, angle=-25), place(sprite, dy=4, angle=-55), place(sprite, dy=6, angle=-88)]
    last = tint(death[-1].copy(), (40, 10, 10), 0.25)
    f["death"] = death + [last]
    return f


def main():
    fig = cutout()
    sprite = base_sprite(fig)
    for anim in ("idle", "walk", "attack", "hurt", "death"):
        d = os.path.join(ROOT, OUT, anim)
        if os.path.isdir(d):
            shutil.rmtree(d)
    fr = frames(sprite)
    for anim, lst in fr.items():
        for i, im in enumerate(lst):
            q = to_palette(im)
            for d in LEFT:
                save(q, "%s%s/%s/%d.png" % (OUT, anim, d, i), quantize=False)
            m = q.transpose(Image.FLIP_LEFT_RIGHT)
            for d in RIGHT:
                save(m, "%s%s/%s/%d.png" % (OUT, anim, d, i), quantize=False)
    # portret: cała postać, 2x większa niż w grze, bez sprowadzania do małej rozdzielczości
    ph = 300
    port = fig.resize((round(fig.width * ph / fig.height), ph), Image.LANCZOS)
    port.putalpha(port.split()[3].point(lambda v: 255 if v >= 128 else 0))
    save(port, OUT + "portrait.png")
    import json
    json.dump({"canvas": [CW, CH], "pivot": [PX, PY],
               "fps": {"idle": 2, "walk": 8, "attack": 0, "hurt": 1, "death": 6},
               "_opis": "Pivot = punkt stóp. fps=0 dla attack: klatki rozkładane na czas zamachu (ostatnia = strzał/cios)."},
              open(os.path.join(ROOT, OUT, "sprite.json"), "w"), indent=1)
    print("Modraszka: sprite %dx%d, klatki: %s" % (sprite.width, sprite.height, {k: len(v) for k, v in fr.items()}))


if __name__ == "__main__":
    main()
