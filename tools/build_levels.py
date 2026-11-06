#!/usr/bin/env python3
"""Buduje pliki poziomów data/levels/karczma.json i data/levels/wioska.json (mapa znakowa + obiekty).

Po wygenerowaniu pliki można edytować ręcznie (to zwykły JSON). Legenda mapy - pole "legenda" w pliku.
Współrzędne: [x, y] komórki siatki izometrycznej. x rośnie w prawo-w dół ekranu, y w lewo-w dół.
Uruchom: python3 tools/build_levels.py
"""
import json
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEGEND = {
    ".": "trawa", ",": "trawa z kwiatami", ":": "ścieżka (ziemia)", "=": "bruk", "~": "błoto",
    "T": "drzewo (blokuje)", "#": "skraj lasu (blokuje)", "-": "płot wzdłuż osi x (blokuje)",
    "|": "płot wzdłuż osi y (blokuje)", "b": "krzak (blokuje)", "W": "ściana (blokuje)", "o": "podłoga karczmy",
    "r": "dywan", "s": "kamienna posadzka", "x": "niewidzialna ściana (blokuje)",
}


class Map:
    def __init__(self, w, h, fill="."):
        self.w, self.h = w, h
        self.g = [[fill] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = c

    def get(self, x, y):
        return self.g[y][x] if 0 <= x < self.w and 0 <= y < self.h else "#"

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def line(self, a, b, c, width=1):
        (x0, y0), (x1, y1) = a, b
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n)
            y = round(y0 + (y1 - y0) * i / n)
            for dx in range(-(width // 2), width - width // 2):
                for dy in range(-(width // 2), width - width // 2):
                    self.set(x + dx, y + dy, c)

    def rows(self):
        return ["".join(r) for r in self.g]


def village():
    rnd = random.Random(2024)
    W = H = 64
    m = Map(W, H)
    objs = []
    blocked_by_building = set()

    def building(sprite, x, y, w, h, name=None):
        objs.append({"typ": "budynek", "grafika": sprite, "komorka": [x, y], "rozmiar": [w, h]} |
                    ({"nazwa": name} if name else {}))
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                blocked_by_building.add((xx, yy))

    # skraj lasu (2 komórki)
    for y in range(H):
        for x in range(W):
            if x < 2 or y < 2 or x >= W - 2 or y >= H - 2:
                m.set(x, y, "#")
    # drogi
    m.line((3, 50), (30, 47), ":", 3)              # od karczmy na zachodzie do placu
    m.rect(29, 28, 39, 37, "=")                    # plac ze studnią
    m.line((34, 47), (34, 37), ":", 3)
    m.line((30, 47), (34, 47), ":", 3)
    m.line((39, 31), (48, 31), ":", 3)             # na wschód
    m.line((48, 31), (48, 2), "=", 3)              # droga do bramy (północny wschód)
    m.line((48, 31), (50, 45), ":", 3)             # do stodoły
    m.line((29, 31), (18, 31), ":", 3)             # do kuźni
    m.line((18, 31), (16, 14), ":", 2)             # do młyna
    m.line((33, 28), (32, 12), ":", 2)             # na cmentarz
    m.line((39, 36), (52, 54), ":", 2)             # do chaty zielarki
    m.line((48, 4), (48, 0), "=", 3)
    # wyjście: przerwa w lesie przy drodze
    for x in range(47, 50):
        for y in range(0, 3):
            m.set(x, y, "=")
    # pola przy młynie (błoto/zaorane)
    m.rect(6, 4, 12, 9, "~")
    m.rect(18, 4, 24, 8, "~")
    # łąka z kwiatami
    for _ in range(140):
        x, y = rnd.randint(3, 60), rnd.randint(3, 60)
        if m.get(x, y) == ".":
            m.set(x, y, ",")

    # budynki (komórka = narożnik północny, rozmiar w komórkach)
    building("tavern_outside", 3, 52, 4, 3, "Karczma")
    building("house_a", 22, 40, 3, 3)
    building("house_b", 26, 22, 3, 2)
    building("house_c", 41, 24, 2, 3)
    building("house_a", 41, 38, 3, 3)
    building("house_burnt", 36, 42, 3, 3)
    building("house_b", 10, 42, 3, 2)
    building("house_c", 54, 20, 2, 3)
    building("house_a", 24, 54, 3, 3)
    building("smithy", 16, 33, 3, 2, "Kuźnia")
    building("mill", 13, 10, 2, 2, "Młyn")
    building("barn", 49, 46, 4, 3, "Stodoła")
    building("herbalist_hut", 54, 55, 2, 2, "Chata zielarki")

    # płoty wokół podwórek
    def yard(x0, y0, x1, y1, gap=None):
        for x in range(x0, x1 + 1):
            for y in (y0, y1):
                if gap and (x, y) in gap:
                    continue
                m.set(x, y, "-")
        for y in range(y0 + 1, y1):
            for x in (x0, x1):
                if gap and (x, y) in gap:
                    continue
                m.set(x, y, "|")

    yard(20, 38, 26, 44, gap={(23, 38), (24, 38), (26, 41), (26, 42)})
    yard(40, 22, 44, 28, gap={(40, 25), (40, 26)})
    yard(8, 40, 14, 45, gap={(11, 40), (12, 40)})
    yard(47, 44, 55, 50, gap={(48, 44), (49, 44), (50, 44)})
    # cmentarz
    yard(27, 5, 36, 12, gap={(32, 12), (31, 12), (33, 12)})
    # wnętrze cmentarza zostaje trawą, nagrobki jako dekoracje
    for (x, y) in [(29, 7), (31, 7), (33, 7), (29, 9), (33, 9), (35, 8), (30, 10)]:
        objs.append({"typ": "dekoracja", "grafika": "grave_%d" % rnd.randint(0, 2), "komorka": [x, y], "blokuje": True})

    # drzewa: sad na południu i rozrzucone
    for (x, y) in [(14, 56), (16, 58), (18, 56), (14, 60), (18, 60), (16, 54), (20, 58)]:
        m.set(x, y, "T")
    for _ in range(90):
        x, y = rnd.randint(3, 60), rnd.randint(3, 60)
        if m.get(x, y) in ".," and (x, y) not in blocked_by_building:
            near_road = any(m.get(x + dx, y + dy) in ":=-|" for dx in (-1, 0, 1) for dy in (-1, 0, 1))
            if not near_road:
                m.set(x, y, "T" if rnd.random() < 0.8 else "b")
    # wyczyść drzewa z miejsc obiektów
    def clear(x, y, r=1):
        for yy in range(y - r, y + r + 1):
            for xx in range(x - r, x + r + 1):
                if m.get(xx, yy) in "Tb":
                    m.set(xx, yy, ".")

    # obiekty zadania
    objs.append({"typ": "studnia", "komorka": [34, 32]})
    for i, x in enumerate((47, 48, 49)):
        objs.append({"typ": "barykada", "id": "barykada_%d" % i, "komorka": [x, 6]})
    objs.append({"typ": "wyjscie", "komorka": [48, 1], "promien": 2})
    buckets = [("wiadro_kuznia", 19, 35), ("wiadro_mlyn", 16, 13), ("wiadro_stodola", 50, 51)]
    for bid, x, y in buckets:
        objs.append({"typ": "wiadro", "id": bid, "komorka": [x, y]})
        clear(x, y)
    objs.append({"typ": "npc", "id": "borubar", "komorka": [36, 34]})
    objs.append({"typ": "start", "komorka": [8, 50]})
    clear(8, 50, 2)
    # skrzynie
    chests = [("skrzynia_kuznia", 20, 36), ("skrzynia_mlyn", 12, 13), ("skrzynia_stodola", 54, 51),
              ("skrzynia_cmentarz", 34, 6), ("skrzynia_zielarka", 57, 57), ("skrzynia_sad", 17, 57)]
    for cid, x, y in chests:
        objs.append({"typ": "skrzynia", "id": cid, "komorka": [x, y]})
        clear(x, y)
    # kapliczki
    for sid, kind, x, y in [("ulryk_1", "ulryk", 40, 52), ("ulryk_2", "ulryk", 24, 18),
                            ("rhya_1", "rhya", 30, 13), ("rhya_2", "rhya", 6, 30)]:
        objs.append({"typ": "kapliczka", "id": sid, "rodzaj": kind, "komorka": [x, y]})
        clear(x, y)
    # dekoracje
    deco = [("barrel", 21, 35), ("crate", 20, 34), ("barrel", 37, 33), ("barrel", 37, 34), ("haystack", 52, 50),
            ("haystack", 47, 48), ("cart", 44, 32), ("crate", 33, 37), ("signpost", 30, 46), ("signpost", 47, 12),
            ("haystack", 10, 8), ("cart", 26, 47), ("barrel", 7, 53), ("crate", 8, 53), ("tree_dead", 37, 45),
            ("barrel", 56, 54), ("rat_hole", 38, 44), ("rat_hole", 15, 16), ("exit_banner", 46, 3), ("exit_banner", 50, 3)]
    for g, x, y in deco:
        objs.append({"typ": "dekoracja", "grafika": g, "komorka": [x, y], "blokuje": g not in ("rat_hole", "signpost")})
        clear(x, y, 0)

    # grupy wrogów (środek, promień rozstawienia w komórkach)
    groups = [
        ("kuznia", [19, 37], ["skaven_spear"] * 3),
        ("mlyn", [16, 15], ["skaven_spear", "skaven_spear", "skaven_slinger"]),
        ("stodola", [51, 52], ["skaven_spear"] * 3 + ["skaven_slinger"]),
        ("cmentarz", [32, 9], ["skaven_spear", "skaven_spear", "skaven_warlock"]),
        ("zielarka", [55, 58], ["skaven_spear", "skaven_spear", "skaven_warlock"]),
        ("droga_zachod", [20, 48], ["skaven_spear", "skaven_spear", "skaven_slinger"]),
        ("plac_wschod", [44, 34], ["skaven_spear"] * 3),
        ("polnoc", [40, 16], ["skaven_spear", "skaven_spear", "skaven_slinger"]),
        ("brama", [48, 10], ["skaven_spear", "skaven_spear", "skaven_slinger"]),
        ("sad", [18, 56], ["skaven_spear", "skaven_slinger"]),
    ]
    out_groups = []
    for gid, c, lst in groups:
        clear(c[0], c[1], 2)
        out_groups.append({"id": gid, "komorka": c, "promien": 2, "wrogowie": lst})
    # komórki budynków nie mogą mieć drzew
    for (x, y) in blocked_by_building:
        if m.get(x, y) in "Tb-|":
            m.set(x, y, ".")
    return {
        "_opis": "Poziom 1: wioska Hufduhof. 'mapa' = wiersze znaków (y), znak = komórka (x). Legenda w 'legenda'. "
                 "Obiekty: komorka [x, y]; budynek zajmuje rozmiar [w, h] komórek od komórki (narożnik północny). "
                 "Grafiki: assets/levels/level1/props/<grafika>.png, kafle: assets/levels/level1/tiles/.",
        "nazwa": "Wioska Hufduhof",
        "kafle": "res://assets/levels/level1/tiles/",
        "rekwizyty": "res://assets/levels/level1/props/",
        "muzyka": "wioska",
        "legenda": LEGEND,
        "mapa": m.rows(),
        "obiekty": objs,
        "grupy": out_groups,
    }


def tavern():
    W, H = 14, 12
    m = Map(W, H, "o")
    for x in range(W):
        m.set(x, 0, "W")
        m.set(x, H - 1, "x")
    for y in range(H):
        m.set(0, y, "W")
        m.set(W - 1, y, "x")
    m.rect(5, 5, 8, 7, "r")
    m.rect(1, 4, 2, 6, "s")
    objs = [
        {"typ": "start", "komorka": [7, 8]},
        {"typ": "drzwi", "id": "drzwi", "komorka": [7, 0]},
        {"typ": "budynek", "grafika": "bar_counter", "komorka": [2, 1], "rozmiar": [2, 1]},
        {"typ": "budynek", "grafika": "fireplace", "komorka": [1, 4], "rozmiar": [1, 1]},
        {"typ": "dekoracja", "grafika": "table", "komorka": [4, 8], "blokuje": True},
        {"typ": "dekoracja", "grafika": "bench", "komorka": [4, 9], "blokuje": True},
        {"typ": "dekoracja", "grafika": "table", "komorka": [10, 4], "blokuje": True},
        {"typ": "dekoracja", "grafika": "bench", "komorka": [10, 5], "blokuje": True},
        {"typ": "dekoracja", "grafika": "table", "komorka": [10, 8], "blokuje": True},
        {"typ": "dekoracja", "grafika": "bench", "komorka": [10, 9], "blokuje": True},
        {"typ": "dekoracja", "grafika": "barrel", "komorka": [1, 1], "blokuje": True, "zestaw": "level1"},
        {"typ": "dekoracja", "grafika": "barrel", "komorka": [1, 2], "blokuje": True, "zestaw": "level1"},
        {"typ": "dekoracja", "grafika": "barrel", "komorka": [12, 1], "blokuje": True, "zestaw": "level1"},
        {"typ": "goscie", "komorki": [[3, 9], [5, 9], [11, 6], [11, 9], [9, 4], [3, 7]]},
        {"typ": "karczmarz", "komorka": [3, 2]},
        {"typ": "npc", "id": "borubar_karczma", "komorka": [9, 7]},
    ]
    return {
        "_opis": "Minigra: impreza w karczmie. Faza 1: łapanie kufli (stań w cieniu, zanim kufel spadnie). Faza 2: skaveny "
                 "wpadają drzwiami - fale w 'fale'. Liczby w 'impreza'.",
        "nazwa": "Karczma 'Pod Złotym Kuflem'",
        "kafle": "res://assets/levels/tavern/tiles/",
        "rekwizyty": "res://assets/levels/tavern/props/",
        "muzyka": "karczma",
        "legenda": LEGEND,
        "mapa": m.rows(),
        "obiekty": objs,
        "impreza": {"kufle_cel": 6, "odstep": 1.9, "czas_lotu": 1.35, "promien_zlapania": 30, "rozrzut": 150,
                    "leczenie_za_kufel": 0},
        "fale": [
            {"wrogowie": ["skaven_spear", "skaven_spear"], "podpowiedz": "Skaveny! Atak: przycisk ATAK (PC: lewy przycisk myszy albo J). Patrz na zamach wroga i odsuń się!"},
            {"wrogowie": ["skaven_spear", "skaven_spear", "skaven_slinger"], "podpowiedz": "Procarz rzuca kamienie - zejdź z linii lotu. Umiejętność: przycisk UMIEJĘTNOŚĆ (PC: prawy przycisk albo K)."}
        ],
        "grupy": [],
    }


def main():
    os.makedirs(os.path.join(ROOT, "data", "levels"), exist_ok=True)
    for name, d in (("wioska", village()), ("karczma", tavern())):
        path = os.path.join(ROOT, "data", "levels", name + ".json")
        with open(path, "w") as f:
            json.dump(d, f, ensure_ascii=False, indent=1)
        print(path)
    print("\n".join(village()["mapa"]))


if __name__ == "__main__":
    main()
