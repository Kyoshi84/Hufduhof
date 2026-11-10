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
    "P": "palisada (blokuje)", "D": "martwe drzewo (blokuje)", "t": "ciernie (blokują)", "R": "głaz (blokuje)",
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
    """Wioska Hufduhof: ciasna, zaniedbana osada na skraju Drakwaldu. Układ pisany ręcznie (współrzędne),
    drobna roślinność i błoto losowane ze stałym ziarnem. Funkcje put/building sprawdzają kolizje z drogami i obiektami."""
    rnd = random.Random(2024)
    W = H = 64
    m = Map(W, H)
    objs = []
    taken = set()          # komórki zajęte przez budynki i obiekty
    keep_clear = set()     # komórki, które muszą zostać wolne (drogi, place boju, okolice obiektów)
    warnings = []

    def reserve(x, y, r=1):
        for yy in range(y - r, y + r + 1):
            for xx in range(x - r, x + r + 1):
                keep_clear.add((xx, yy))

    def free(x, y):
        return m.get(x, y) in ".,~" and (x, y) not in taken

    def building(sprite, x, y, w, h, name=None):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if m.get(xx, yy) in ":=" or (xx, yy) in taken:
                    warnings.append("budynek %s koliduje w (%d,%d)" % (sprite, xx, yy))
                taken.add((xx, yy))
                m.set(xx, yy, ".")
        objs.append({"typ": "budynek", "grafika": sprite, "komorka": [x, y], "rozmiar": [w, h]} |
                    ({"nazwa": name} if name else {}))

    def put(typ, x, y, **kw):
        """Obiekt na jednej komórce (skrzynia, kapliczka, wiadro...). Czyści roślinność i rezerwuje otoczenie."""
        if (x, y) in taken:
            warnings.append("%s koliduje w (%d,%d)" % (typ, x, y))
        if m.get(x, y) in "TbDtR-|":
            m.set(x, y, ".")
        taken.add((x, y))
        reserve(x, y, kw.pop("wolne", 1))
        objs.append({"typ": typ, "komorka": [x, y]} | kw)

    def deco(g, x, y, block=True, flat=False, flip=False, plac=False):
        if (x, y) in taken or m.get(x, y) in "#P" or (block and not plac and m.get(x, y) in ":="):
            warnings.append("dekoracja %s koliduje w (%d,%d)" % (g, x, y))
            return
        if m.get(x, y) in "TbDtR-|":
            m.set(x, y, ".")
        if block:
            taken.add((x, y))
        o = {"typ": "dekoracja", "grafika": g, "komorka": [x, y], "blokuje": block}
        if flat:
            o["plaska"] = True
        if flip:
            o["odbicie"] = True
        objs.append(o)

    # ---- skraj Drakwaldu (2 komórki) i palisada z bramą na północy
    for y in range(H):
        for x in range(W):
            if x < 2 or y < 2 or x >= W - 2 or y >= H - 2:
                m.set(x, y, "#")
    # ---- drogi (błotniste ścieżki, bruk tylko na placu i przy bramie)
    m.line((3, 50), (30, 47), ":", 3)              # od karczmy na zachodzie do placu
    m.rect(29, 28, 39, 37, "=")                    # plac ze studnią
    m.line((34, 47), (34, 37), ":", 3)
    m.line((30, 47), (34, 47), ":", 3)
    m.line((39, 31), (48, 31), ":", 3)             # na wschód
    m.line((48, 31), (48, 12), ":", 3)             # droga do bramy
    m.line((48, 12), (48, 0), "=", 3)
    m.line((48, 31), (50, 43), ":", 3)             # do stodoły
    m.line((29, 31), (18, 31), ":", 3)             # do kuźni
    m.line((18, 31), (16, 14), ":", 2)             # do młyna
    m.line((33, 28), (32, 12), ":", 2)             # na cmentarz
    m.line((39, 36), (52, 54), ":", 2)             # do chaty zielarki
    for x in range(47, 50):
        for y in range(0, 3):
            m.set(x, y, "=")
    # palisada w poprzek całej północnej krawędzi: jedyne przejście to brama zamknięta płonącą barykadą
    GATE_Y = 3
    for x in range(2, W - 2):
        if x not in (47, 48, 49):
            m.set(x, GATE_Y, "P")
    for y in range(H):
        for x in range(W):
            if m.get(x, y) in ":=":
                reserve(x, y, 0)
    # ---- pola przy młynie i błoto
    m.rect(6, 5, 12, 9, "~")
    m.rect(18, 5, 24, 8, "~")
    for _ in range(26):                            # kałuże błota przy drogach i na podwórkach
        cx, cy = rnd.randint(4, 59), rnd.randint(5, 59)
        for _k in range(rnd.randint(3, 8)):
            x, y = cx + rnd.randint(-1, 1), cy + rnd.randint(-1, 1)
            if m.get(x, y) == ".":
                m.set(x, y, "~")
    for _ in range(60):
        x, y = rnd.randint(3, 60), rnd.randint(4, 60)
        if m.get(x, y) == ".":
            m.set(x, y, ",")

    # ---- budynki: ciasna zabudowa wokół placu i dróg (komórka = narożnik północny)
    building("tavern_outside", 3, 52, 4, 3, "Karczma")
    building("house_a", 22, 40, 3, 3)
    building("house_b", 26, 22, 3, 2)
    building("house_c", 41, 24, 2, 3)
    building("house_a", 36, 38, 3, 3)
    building("house_burnt", 36, 42, 3, 3)
    building("house_b", 10, 42, 3, 2)
    building("house_c", 54, 20, 2, 3)
    building("house_a", 24, 54, 3, 3)
    building("smithy", 16, 33, 3, 2, "Kuźnia")
    building("mill", 13, 10, 2, 2, "Młyn")
    building("barn", 49, 46, 4, 3, "Stodoła")
    building("herbalist_hut", 54, 55, 2, 2, "Chata zielarki")
    # nowe: zawalone i zabite deskami chaty, więcej chałup
    building("house_ruin", 29, 40, 3, 3, "Zawalona chata")
    building("house_boarded", 36, 23, 3, 2, "Dom zabity deskami")
    building("house_c", 22, 25, 2, 3)
    building("house_ruin", 43, 14, 3, 3)
    building("house_a", 52, 26, 3, 3)
    building("house_b", 40, 57, 3, 2)
    building("house_burnt", 8, 22, 3, 3)
    building("house_boarded", 25, 34, 3, 2)
    building("house_ruin", 56, 36, 3, 3)
    building("house_c", 11, 27, 2, 3)
    building("house_b", 52, 12, 3, 2)
    building("house_boarded", 12, 55, 3, 2)
    building("house_c", 44, 50, 2, 3)

    # ---- płoty wokół podwórek
    def yard(x0, y0, x1, y1, gap=()):
        for x in range(x0, x1 + 1):
            for y in (y0, y1):
                if (x, y) not in gap and m.get(x, y) in ".,~":
                    m.set(x, y, "-")
        for y in range(y0 + 1, y1):
            for x in (x0, x1):
                if (x, y) not in gap and m.get(x, y) in ".,~":
                    m.set(x, y, "|")

    yard(20, 38, 26, 44, gap={(23, 38), (24, 38), (26, 41), (26, 42)})
    yard(40, 22, 44, 28, gap={(40, 25), (40, 26)})
    yard(8, 40, 14, 45, gap={(11, 40), (12, 40)})
    yard(47, 44, 55, 50, gap={(48, 44), (49, 44), (50, 44)})
    yard(27, 5, 36, 12, gap={(32, 12), (31, 12), (33, 12)})          # cmentarz
    yard(51, 24, 56, 30, gap={(51, 27), (51, 28)})
    yard(6, 20, 12, 26, gap={(9, 26), (10, 26), (12, 22)})

    # ---- obiekty zadania
    put("studnia", 34, 32)
    for i, x in enumerate((47, 48, 49)):
        objs.append({"typ": "barykada", "id": "barykada_%d" % i, "komorka": [x, GATE_Y]})
        taken.add((x, GATE_Y))
    objs.append({"typ": "wyjscie", "komorka": [48, 1], "promien": 1.5})
    put("wiadro", 19, 35, id="wiadro_kuznia")
    put("wiadro", 16, 13, id="wiadro_mlyn")
    put("wiadro", 50, 51, id="wiadro_stodola")
    put("npc", 10, 52, id="borubar")                                   # przed karczmą
    objs.append({"typ": "start", "komorka": [8, 50]})
    reserve(8, 50, 2)
    for cid, x, y in [("skrzynia_kuznia", 20, 36), ("skrzynia_mlyn", 12, 13), ("skrzynia_stodola", 54, 51),
                      ("skrzynia_cmentarz", 34, 6), ("skrzynia_zielarka", 57, 57), ("skrzynia_sad", 17, 59)]:
        put("skrzynia", x, y, id=cid)
    for sid, kind, x, y in [("ulryk_1", "ulryk", 40, 52), ("ulryk_2", "ulryk", 24, 18),
                            ("rhya_1", "rhya", 30, 14), ("rhya_2", "rhya", 6, 30)]:
        put("kapliczka", x, y, id=sid, rodzaj=kind)

    # ---- wrogowie: grupy stojące przy lokacjach i tunele skavenów (wrogowie wychodzą z nor, gdy bohater podejdzie)
    groups = [
        ("kuznia", [19, 37], ["skaven_spear"] * 3),
        ("mlyn", [16, 15], ["skaven_spear", "skaven_spear", "skaven_slinger"]),
        ("stodola", [51, 52], ["skaven_spear"] * 3 + ["skaven_slinger"]),
        ("cmentarz", [32, 9], ["skaven_spear", "skaven_spear", "skaven_warlock"]),
        ("zielarka", [55, 58], ["skaven_spear", "skaven_spear", "skaven_warlock"]),
        ("brama", [48, 8], ["skaven_spear", "skaven_spear", "skaven_slinger"]),
    ]
    tunnels = [
        ("droga_zachod", 21, 45, ["skaven_spear", "skaven_spear", "skaven_slinger"]),
        ("plac_wschod", 45, 35, ["skaven_spear"] * 3),
        ("polnoc", 40, 18, ["skaven_spear", "skaven_spear", "skaven_slinger"]),
        ("sad", 19, 56, ["skaven_spear", "skaven_slinger"]),
        ("ruina", 32, 45, ["skaven_spear", "skaven_spear"]),          # nora pod zawaloną chatą
    ]
    out_groups = []
    for gid, c, lst in groups:
        reserve(c[0], c[1], 2)
        out_groups.append({"id": gid, "komorka": c, "promien": 2, "wrogowie": lst})
    for tid, x, y, lst in tunnels:
        if not free(x, y):
            warnings.append("tunel %s na zajętej komórce (%d,%d): %s" % (tid, x, y, m.get(x, y)))
        reserve(x, y, 2)
        objs.append({"typ": "tunel", "id": tid, "komorka": [x, y], "wrogowie": lst})

    # ---- opowieść otoczeniem
    # cmentarz: nagrobki, czaszki, zniszczona kapliczka przy wejściu
    for (x, y) in [(29, 7), (31, 7), (33, 7), (29, 9), (33, 10), (35, 8), (30, 10), (35, 10)]:
        deco("grave_%d" % rnd.randint(0, 2), x, y)
    deco("skull_pile", 28, 6); deco("bones_0", 34, 9, block=False, flat=True)
    deco("shrine_broken", 34, 13); deco("bones_1", 35, 14, block=False, flat=True)
    # zawalona chata po napadzie: gruz, kości, nora obok, rozrzucone skrzynie
    for g, x, y, fl in [("rubble_0", 32, 43, True), ("rubble_1", 28, 43, True), ("bones_0", 31, 44, True), ("bones_1", 35, 45, True)]:
        deco(g, x, y, block=False, flat=fl)
    deco("crate", 28, 39); deco("skull_pile", 32, 39)
    # porzucony, rozbity wóz w błocie na zachodniej drodze i drugi przy bramie
    for (x, y) in [(15, 46), (16, 46), (14, 47)]:
        if m.get(x, y) in ".,":
            m.set(x, y, "~")
    deco("cart_broken", 15, 46); deco("barrel", 17, 46); deco("puddle", 14, 47, block=False, flat=True)
    deco("cart_broken", 45, 10, flip=True); deco("crate", 44, 11); deco("bones_0", 46, 9, block=False, flat=True)
    # dom zabity deskami: kozły, sterta drewna, beczki - desperacka obrona
    deco("spikes", 37, 26); deco("spikes", 35, 26); deco("firewood", 39, 24); deco("barrel", 39, 25)
    deco("spikes", 26, 37); deco("firewood", 28, 36); deco("spikes", 13, 58)
    # podejrzane wejście do piwnicy przy spalonym domu
    deco("cellar", 39, 45); deco("bones_1", 40, 46, block=False, flat=True)
    # martwe drzewo otoczone kośćmi
    m.set(37, 46, "D"); taken.add((37, 46))
    deco("bones_0", 36, 47, block=False, flat=True); deco("bones_1", 38, 47, block=False, flat=True); deco("skull_pile", 38, 46)
    # szubienica i kozły przy bramie, chorągwie wyjścia
    deco("gibbet", 45, 6); deco("spikes", 46, 5); deco("spikes", 50, 5); deco("skull_pile", 51, 6)
    deco("exit_banner", 46, 4); deco("exit_banner", 50, 4)
    # plac: beczki, skrzynie, wóz, kałuże
    for g, x, y in [("barrel", 37, 33), ("barrel", 37, 34), ("crate", 30, 36), ("firewood", 30, 29)]:
        deco(g, x, y, plac=True)                   # na skraju bruku placu
    deco("cart", 44, 33)
    deco("puddle", 32, 35, block=False, flat=True); deco("puddle", 36, 30, block=False, flat=True)
    # kuźnia, młyn, stodoła, karczma, zielarka
    for g, x, y in [("barrel", 21, 35), ("crate", 20, 33), ("stump", 15, 36), ("firewood", 15, 35),
                    ("haystack", 10, 7), ("scarecrow", 8, 6), ("scarecrow", 21, 6), ("crate", 15, 12), ("stump", 12, 15),
                    ("haystack", 53, 49), ("crate", 54, 47), ("firewood", 48, 46),
                    ("barrel", 7, 55), ("crate", 8, 55), ("firewood", 9, 55),
                    ("barrel", 56, 54), ("skull_pile", 53, 58), ("stump", 57, 55)]:
        deco(g, x, y)
    deco("signpost", 30, 46, block=False); deco("signpost", 46, 13, block=False)
    deco("rat_hole", 38, 48, block=False); deco("rat_hole", 15, 17, block=False); deco("rat_hole", 57, 40, block=False)
    # drobne kości i gruz przy ruinach
    for g, x, y in [("rubble_0", 46, 16), ("rubble_1", 42, 17), ("bones_0", 44, 18), ("rubble_0", 58, 39), ("bones_1", 55, 39),
                    ("rubble_1", 10, 25), ("bones_0", 9, 26), ("puddle", 22, 30), ("puddle", 47, 22), ("puddle", 26, 49)]:
        deco(g, x, y, block=False, flat=True)

    # ---- światło: latarnie przy drogach i na placu, palenisko kuźni, kilka okien, w których jeszcze się świeci
    def lantern(x, y, plac=False):
        if (x, y) in taken or m.get(x, y) in "#P" or (not plac and m.get(x, y) in ":="):
            warnings.append("latarnia koliduje w (%d,%d): %s" % (x, y, m.get(x, y)))
            return
        if m.get(x, y) in "TbDtR":
            m.set(x, y, ".")
        taken.add((x, y))
        objs.append({"typ": "latarnia", "komorka": [x, y]})

    for (x, y) in [(29, 28), (39, 28), (29, 37), (39, 37), (32, 33)]:
        lantern(x, y, plac=True)
    for (x, y) in [(8, 52), (46, 8), (50, 8), (29, 13), (46, 43), (53, 57), (20, 29), (15, 19), (26, 45), (46, 24), (17, 51), (42, 44)]:
        lantern(x, y)
    for kind, x, y in [("palenisko", 17, 34), ("okno", 23, 43), ("okno", 27, 24), ("okno", 5, 55), ("okno", 25, 57),
                       ("swieca", 34, 14), ("swieca", 31, 8)]:
        objs.append({"typ": "swiatlo", "rodzaj": kind, "komorka": [x, y]})

    # ---- roślinność: martwe drzewa i ciernie gęstnieją ku skrajowi lasu; głazy
    def near(x, y, chars, r=1):
        return any(m.get(x + dx, y + dy) in chars for dx in range(-r, r + 1) for dy in range(-r, r + 1))

    placed = 0
    for _ in range(900):
        if placed >= 170:
            break
        x, y = rnd.randint(2, 61), rnd.randint(4, 61)
        if not free(x, y) or (x, y) in keep_clear or near(x, y, ":=", 1):
            continue
        edge = min(x - 2, y - 4, 61 - x, 61 - y)
        if edge > 9 and rnd.random() < 0.6:
            continue                       # środek wsi rzadziej zarośnięty
        # nie zamykamy przejść: obok może stać najwyżej jedna inna przeszkoda
        blocked_n = sum(1 for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx or dy) and (m.get(x + dx, y + dy) in "TbDtR-|#P" or (x + dx, y + dy) in taken))
        if blocked_n > 1:
            continue
        roll = rnd.random()
        dead_p = 0.55 if edge < 6 else 0.3
        ch = "D" if roll < dead_p else ("t" if roll < dead_p + 0.2 else ("R" if roll < dead_p + 0.3 else ("T" if roll < 0.93 else "b")))
        m.set(x, y, ch)
        placed += 1
    for (x, y) in taken:
        if m.get(x, y) in "TbDtR-|" and (x, y) != (37, 46):
            m.set(x, y, ".")
    for w_ in warnings:
        print("UWAGA:", w_)
    return {
        "_opis": "Poziom 1: wioska Hufduhof. 'mapa' = wiersze znaków (y), znak = komórka (x). Legenda w 'legenda'. "
                 "Obiekty: komorka [x, y]; budynek zajmuje rozmiar [w, h] komórek od komórki (narożnik północny); "
                 "dekoracja: blokuje = przeszkoda, plaska = leży na ziemi pod postaciami; tunel = nora skavenów z listą wrogów. "
                 "odcien = mnożnik koloru świata (przygaszone światło). Grafiki: assets/levels/level1/props/<grafika>.png.",
        "nazwa": "Wioska Hufduhof",
        "kafle": "res://assets/levels/level1/tiles/",
        "rekwizyty": "res://assets/levels/level1/props/",
        "muzyka": "wioska",
        "odcien": [0.5, 0.5, 0.62],
        "odcien_bez_swiatel": [0.86, 0.84, 0.88],
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
        {"typ": "bohater_gosc", "komorka": [9, 7]},
        {"typ": "swiatlo", "rodzaj": "palenisko", "komorka": [2, 5]},
        {"typ": "swiatlo", "rodzaj": "swieca", "komorka": [4, 8]},
        {"typ": "swiatlo", "rodzaj": "swieca", "komorka": [10, 4]},
        {"typ": "swiatlo", "rodzaj": "swieca", "komorka": [10, 8]},
        {"typ": "swiatlo", "rodzaj": "latarnia", "komorka": [6, 1]},
        {"typ": "swiatlo", "rodzaj": "latarnia", "komorka": [11, 2]},
        {"typ": "swiatlo", "rodzaj": "latarnia", "komorka": [1, 9]},
        {"typ": "swiatlo", "rodzaj": "latarnia", "komorka": [7, 10]},
    ]
    return {
        "_opis": "Minigra: impreza w karczmie. Faza 1: łapanie kufli (stań w cieniu, zanim kufel spadnie). Faza 2: skaveny "
                 "wpadają drzwiami - fale w 'fale'. Liczby w 'impreza'.",
        "nazwa": "Karczma 'Pod Złotym Kuflem'",
        "kafle": "res://assets/levels/tavern/tiles/",
        "rekwizyty": "res://assets/levels/tavern/props/",
        "muzyka": "karczma",
        "odcien": [0.6, 0.52, 0.48],
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
    print("\n".join(json.load(open(os.path.join(ROOT, "data", "levels", "wioska.json")))["mapa"]))


if __name__ == "__main__":
    main()
