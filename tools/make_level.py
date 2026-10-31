#!/usr/bin/env python3
"""Generuje data/level_1.json (długi poziom: fale, beczki, przeszkody, mikstury, spaczenie).
Uruchom: python3 tools/make_level.py"""
import json, os

STARTS = [0, 4300, 8900, 13400]
LENGTH = 17800
NAMES = ["ETAP 1: DROGA DO HUFDUHOFU", "ETAP 2: WIEŚ", "ETAP 3: POLA I LAS", "ETAP 4: LEGOWISKO CHAOSU"]
FOLDERS = ["stage1_road", "stage2_village", "stage3_fields_forest", "stage4_lair"]

def sp(t, c, side="right", **kw):
    d = {"type": t, "count": c, "side": side}
    d.update(kw)
    return d

W = [
 # etap 1 - szczuroludzie
 (900,  [sp("skaven", 2)]),
 (1700, [sp("skaven", 2), sp("skaven", 1, "left", delay=2.0)]),
 (2500, [sp("skaven", 3, "both")]),
 (3300, [sp("skaven", 3, "both"), sp("chaos_hound", 1, delay=3.0)]),
 (3950, [sp("skaven", 4, "both", delay=1.0, interval=0.8)]),
 # etap 2 - wieś, ogary
 (4900, [sp("skaven", 3, "both"), sp("chaos_hound", 1, delay=3.0)]),
 (5700, [sp("chaos_hound", 2, "both"), sp("skaven", 3, "both", delay=2.0, interval=0.8)]),
 (6500, [sp("skaven", 4, "both", interval=0.7), sp("chaos_hound", 2, delay=3.5, interval=1.2)]),
 (7300, [sp("skaven", 3, "both"), sp("chaos_hound", 2, "both", delay=2.5)]),
 (8300, [sp("skaven", 4, "both", interval=0.7), sp("chaos_hound", 2, delay=4.0)]),
 # etap 3 - las, zwierzoludzie
 (9400,  [sp("beastman", 1), sp("skaven", 2, "both", delay=3.0)]),
 (10200, [sp("beastman", 1, "left"), sp("chaos_hound", 2, delay=3.0)]),
 (11000, [sp("beastman", 2, "both"), sp("chaos_hound", 2, "right", delay=4.0)]),
 (11900, [sp("skaven", 4, "both", interval=0.7), sp("beastman", 1, delay=2.0)]),
 (12700, [sp("beastman", 2, "both"), sp("skaven", 3, "both", delay=3.0, interval=0.7), sp("chaos_hound", 1, delay=5.0)]),
 # etap 4 - legowisko
 (13800, [sp("beastman", 2, "both"), sp("skaven", 3, "both", delay=2.0)]),
 (14600, [sp("beastman", 1, "left"), sp("skaven", 4, "both", delay=1.0, interval=0.7), sp("chaos_hound", 2, delay=5.0)]),
 (15500, [sp("beastman", 2, "both"), sp("chaos_hound", 3, "both", delay=3.0, interval=1.0)]),
 (16200, [sp("beastman", 2, "both"), sp("skaven", 4, "both", delay=2.0, interval=0.7), sp("chaos_hound", 2, delay=6.0)]),
 (16700, [sp("beastman", 3, "both"), sp("skaven", 3, "both", delay=3.0)]),
]
OBST = [("puddle", 1500), ("puddle", 3100),
        ("puddle", 5200), ("fire", 6100), ("puddle", 6900), ("fire", 7800),
        ("log", 9900), ("river", 10700), ("log", 11500), ("river", 12300),
        ("chasm", 14200), ("chasm", 15050), ("river", 15850), ("chasm", 16500)]
SLIMES = [13650, 14000, 14900, 15300, 15700, 16050, 16400, 16900]

def build():
    waves = [{"trigger": t, "spawns": s} for t, s in W]
    waves.append({"trigger": LENGTH - 700, "final": True, "spawns": [sp("chaos_champion", 1)]})
    barrels = list(range(620, LENGTH - 900, 560))
    potions = list(range(1250, LENGTH - 800, 1100))
    return {"name": "Hufduhof", "length": LENGTH, "player_start": 120,
            "stages": [{"name": n, "start": s, "folder": f} for n, s, f in zip(NAMES, STARTS, FOLDERS)],
            "waves": waves, "barrels": barrels,
            "obstacles": [{"type": t, "x": x} for t, x in OBST],
            "potions": potions, "slimes": SLIMES}

if __name__ == "__main__":
    out = os.path.join(os.path.dirname(__file__), "..", "data", "level_1.json")
    old = json.load(open(out))
    d = build()
    d["name"] = old.get("name", d["name"])
    json.dump(d, open(out, "w"), indent=1, ensure_ascii=False)
    print("waves", len(d["waves"]), "barrels", len(d["barrels"]), "potions", len(d["potions"]))
