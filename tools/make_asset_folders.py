#!/usr/bin/env python3
"""Tworzy (idempotentnie) foldery grafik z manifestami i instrukcjami. Nie nadpisuje istniejących PNG.
  assets/characters/<id>/{character.json, README.md, anim/<animacja>/}
  assets/stages/<etap>/{stage.json, README.md, props/}
Uruchom ponownie po zmianie tools/asset_spec.py."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_spec as S

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w", encoding="utf-8").write(text)

def make_character(cid, c):
    base = os.path.join(ROOT, "assets/characters", cid)
    for a in c["anims"]:
        os.makedirs(os.path.join(base, "anim", a), exist_ok=True)
        gk = os.path.join(base, "anim", a, ".gitkeep")
        if not os.path.exists(gk): open(gk, "w").close()
    manifest = {"id": cid, "display_name": c["name"], "frame_size": c["frame"], "pivot": c["pivot"],
                "world_per_texel": S.WORLD_PER_TEXEL, "facing": "right", "animations": c["anims"]}
    json.dump(manifest, open(os.path.join(base, "character.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    rows = ["| animacja | klatek | fps | pętla | kontakt (hitbox) | uwagi |", "|---|---|---|---|---|---|"]
    for name, a in c["anims"].items():
        fps = "wg czasu ataku" if "contact" in a else a["fps"]
        ct = "%d-%d" % tuple(a["contact"]) if "contact" in a else "-"
        rows.append(f"| `{name}` | {a['frames']} | {fps} | {'tak' if a['loop'] else 'nie'} | {ct} | {a['note']} |")
    fw, fh = c["frame"]; px, py = c["pivot"]
    extra = ""
    if cid == "ivo":
        extra = ("\n## Pozy 8-kierunkowe (zapas)\n`poses/` zawiera 8 statycznych póz (E, SE, S, SW, W, NW, N, NE) używanych, gdy brakuje animacji "
                 "albo przy ruchu w głąb sceny. Oryginały: `source/` (nie modyfikowane), kopie do gry generuje `tools/prepare_ivo.py`.\n")
    write(os.path.join(base, "README.md"), f"""# {c['name']}

Folder grafik postaci. Gra ładuje klatki z `anim/<animacja>/<animacja>_00.png`, `_01.png`, ... Brakująca animacja = zapas
(proceduralna grafika tymczasowa lub pozy). Podmieniasz po jednej animacji; reszta działa bez zmian.

## Zasady klatek
- Płótno **{fw}x{fh} px**, przezroczyste tło, ta sama wielkość płótna we **wszystkich** klatkach tej postaci.
- Pivot (punkt styku stóp z podłożem) w **({px}, {py})** na każdej klatce - dzięki temu postać nie "skacze".
  Pivot i rozmiar można zmienić w `character.json` (pole `pivot`, `frame_size`).
- Postać **zwrócona w prawo**. W lewo gra odbija lustrzanie.
- 1 piksel grafiki = 1 piksel obrazu wewnętrznego gry (4/3 jednostki świata). Skala dotyczy wszystkich klatek jednakowo.
- Kolory ze wspólnej palety (`assets/palette/`). Obraz i tak jest na końcu dopasowywany do palety 256 kolorów, ale rysunek
  w palecie daje przewidywalny efekt. Bez gładkich gradientów i półprzezroczystości (alfa 0 lub 255).
- Zostaw marginesy na broń w pełnym wyproście (czubek miecza nie może dotykać krawędzi płótna).
- Numeracja ciągła: `light1_00.png`, `light1_01.png`, ... (liczba klatek w tabeli to zalecenie; gra użyje tylu, ile znajdzie).

## Klatka kontaktu (animacje ataków)
Kolumna "kontakt" wskazuje klatki pokazywane w oknie AKTYWNEGO hitboxa. Wcześniejsze klatki są rozłożone na czas zamachu, późniejsze na czas powrotu.
Broń na klatce kontaktu powinna sięgać zasięgu z `data/balance.json`. Hitbox się nie zmienia, więc rysunek ma się do niego dopasować.
Czasy: `balance.json` -> `windup/active/recover`.

## Animacje
{chr(10).join(rows)}
{extra}
Sprawdzenie plików: `python3 tools/check_assets.py`. Po dodaniu PNG otwórz projekt w Godot (import) lub uruchom `godot --headless --import`.
""")

def make_stage(sid, s):
    base = os.path.join(ROOT, "assets/stages", sid)
    os.makedirs(os.path.join(base, "props"), exist_ok=True)
    gk = os.path.join(base, "props", ".gitkeep")
    if not os.path.exists(gk): open(gk, "w").close()
    layers = {} if s.get("no_layers") else {k: {"file": v[0], "parallax": v[1], "y_offset": 0, "note": v[2], "size": v[3]} for k, v in S.LAYERS.items()}
    props = {k: {"note": v[0], "size": v[1]} for k, v in s["props"].items()}
    json.dump({"id": sid, "name": s["name"], "world_per_texel": S.WORLD_PER_TEXEL, "layers": layers, "props": props},
              open(os.path.join(base, "stage.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    lrows = ["| warstwa | plik | równoległość | rozmiar | opis |", "|---|---|---|---|---|"]
    for k, v in layers.items():
        lrows.append(f"| {k} | `{v['file']}` | {v['parallax']} | {v['size']} | {v['note']} |")
    prow = ["| rekwizyt | plik | rozmiar px | opis |", "|---|---|---|---|"]
    for k, v in props.items():
        prow.append(f"| `{k}` | `props/{k}.png` (warianty: `{k}_2.png` ... `{k}_6.png`) | {v['size']} | {v['note']} |")
    layer_txt = "" if not layers else "## Warstwy tła\n" + "\n".join(lrows) + "\n\nParalaksa i `y_offset` (przesunięcie pionowe, px) można zmienić w `stage.json`.\n"
    write(os.path.join(base, "README.md"), f"""# {s['name']}

Grafiki etapu. Każdy brakujący plik jest zastępowany proceduralną grafiką tymczasową; podmieniasz po jednym pliku.

## Zasady
- PNG z przezroczystością (alfa 0/255), 1 piksel grafiki = 1 piksel obrazu wewnętrznego gry (4/3 jednostki świata).
- Warstwy tła powtarzane poziomo muszą mieć **niewidoczny szew** (lewa krawędź łączy się z prawą).
- **Rekwizyty są wyłącznie dekoracją**: nie blokują ruchu i rysują się ZA postaciami. Pivot = środek dolnej krawędzi PNG (punkt styku z podłożem).
- Warianty rekwizytu (`nazwa_2.png`, ...) gra dobiera losowo (stałe dla danego miejsca), opcjonalnie odbijając lustrzanie.
- Pas walki to y = 385-600 (świat 1280x720); nie umieszczaj tam elementów zasłaniających postacie.
- Kolory ze wspólnej palety (`assets/palette/`); obraz i tak jest na końcu dopasowywany do palety 256 kolorów.

{layer_txt}
## Rekwizyty
{chr(10).join(prow)}

Sprawdzenie plików: `python3 tools/check_assets.py`.
""")

def main():
    for cid, c in S.CHARACTERS.items(): make_character(cid, c)
    for sid, s in S.STAGES.items(): make_stage(sid, s)
    print("postaci:", ", ".join(S.CHARACTERS), "| etapy:", ", ".join(S.STAGES))

if __name__ == "__main__":
    main()
