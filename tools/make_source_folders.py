#!/usr/bin/env python3
"""Tworzy w assets/stages/source/elements/ miejsca na surowe grafiki ruchomych elementów świata
(rekwizyty przesuwające się podczas chodzenia po etapie) oraz spis ELEMENTY.md.
Źródłem prawdy jest tools/asset_spec.py (rekwizyty podłączone do gry) + lista EXTRAS poniżej (jeszcze niepodłączone).
Bezpieczne do wielokrotnego uruchamiania: istniejące pliki nie są ruszane.
  python3 tools/make_source_folders.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_spec as S

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.join(HERE, "assets/stages/source/elements")

# Elementy widoczne na panoramie, których gra jeszcze NIE ładuje jako osobnych ruchomych rekwizytów
# (dziś są wmalowane w tło albo rysowane proceduralnie). Nazwa -> (etapy, opis, rozmiar)
EXTRAS = {
    "puddle":     (["stage1_road", "stage2_village", "stage3_fields_forest", "stage4_lair"], "kałuża z odbiciem nieba (dziś wmalowana w ground.png)", "60x14"),
    "haystack":   (["stage2_village", "stage3_fields_forest"], "stóg siana", "50x60"),
    "windmill":   (["stage2_village", "stage3_fields_forest"], "wiatrak", "90x140"),
    "church":     (["stage1_road", "stage2_village"], "kościół z wieżą", "80x150"),
    "gate_sign":  (["stage1_road"], "brama-szyld „Hufduhof” ze słupem i krukiem", "90x180"),
    "chaos_hut":  (["stage3_fields_forest", "stage4_lair"], "chata Chaosu z fioletowym sztandarem", "110x120"),
    "chaos_pole": (["stage4_lair"], "słup z czaszkami i czerwonym sztandarem", "70x170"),
    "grass_tuft": (["stage1_road", "stage2_village", "stage3_fields_forest", "stage4_lair"], "kępa trawy / chwastów", "30x18"),
    "wagon":      (["stage1_road", "stage2_village"], "wóz z drewnem (większy niż `cart`)", "110x60"),
}

README_ELEMENT = """# {name}

{note}

- Docelowy rozmiar w grze: **{size} px** (1 piksel = 4/3 jednostki świata).
- Pivot: środek dolnej krawędzi PNG (punkt styku z podłożem).
- {where}

Tu wrzucasz **surowe** pliki (wycięcie z panoramy, obraz w wyższej rozdzielczości, warstwy robocze).
Gotowy plik w rozmiarze docelowym trafia do `{target}` (nazwa `{name}.png`, kolejne warianty `{name}_2.png` ... `{name}_6.png`).
"""

def main():
    rows = []
    n = 0
    for sid, st in S.STAGES.items():
        for name, (note, size) in st["props"].items():
            d = os.path.join(ROOT, sid, name)
            os.makedirs(d, exist_ok=True)
            open(os.path.join(d, ".gitkeep"), "a").close()
            p = os.path.join(d, "README.md")
            if not os.path.exists(p):
                open(p, "w", encoding="utf-8").write(README_ELEMENT.format(
                    name=name, note=note.capitalize(), size=size, target=f"assets/stages/{sid}/props/" if sid != "common" else "assets/stages/common/props/",
                    where="Element **podłączony do gry** – gra wczyta gotowy plik z folderu `props/` automatycznie."))
            rows.append((sid, name, note, size, "tak"))
            n += 1
    for name, (stages, note, size) in EXTRAS.items():
        for sid in stages:
            d = os.path.join(ROOT, sid, "_dodatkowe", name)
            os.makedirs(d, exist_ok=True)
            open(os.path.join(d, ".gitkeep"), "a").close()
            p = os.path.join(d, "README.md")
            if not os.path.exists(p):
                open(p, "w", encoding="utf-8").write(README_ELEMENT.format(
                    name=name, note=note.capitalize(), size=size, target=f"assets/stages/{sid}/props/",
                    where="Element **jeszcze niepodłączony do gry** (dziś część tła lub rysowany proceduralnie); folder czeka na przyszłe rozszerzenie."))
            rows.append((sid, name, note, size, "nie (zapas)"))
            n += 1
    lines = ["# Ruchome elementy świata (rekwizyty)", "",
             "Elementy, które przesuwają się razem ze sceną podczas przechodzenia etapów (rysowane za postaciami, nie blokują ruchu),",
             "oraz obiekty, z którymi gracz wchodzi w interakcję (beczka, mikstura). Każdy ma własny folder na surowe grafiki:",
             "`assets/stages/source/elements/<etap>/<element>/`. Elementy „zapas” leżą w podfolderach `_dodatkowe/`.", "",
             "| etap | element | opis | rozmiar px | podłączony do gry |", "|---|---|---|---|---|"]
    for r in rows:
        lines.append("| {} | `{}` | {} | {} | {} |".format(*r))
    lines += ["", "## Elementy nieruchome (tło, nie rekwizyty)",
              "Niebo, `far1`, `far2`, podłoże i pierwszy plan to warstwy tła, a nie rekwizyty: patrz `assets/stages/source/README.md`",
              "i `tools/build_stage_backgrounds.py`.", "",
              "## Poza folderem etapów",
              "Postacie (Ivo, wrogowie, boss) i ich animacje mają osobne foldery: `assets/characters/<postać>/`.", ""]
    open(os.path.join(ROOT, "ELEMENTY.md"), "w", encoding="utf-8").write("\n".join(lines))
    print(f"zapisano {n} folderów i {os.path.relpath(os.path.join(ROOT, 'ELEMENTY.md'), HERE)}")

if __name__ == "__main__":
    main()
