# Grafika i dźwięk: jak podmieniać na docelowe

Gra ładuje grafikę z tych folderów. **Każdy brakujący plik jest zastępowany grafiką tymczasową**, więc podmieniasz po jednym PNG
i od razu widzisz efekt (nic nie trzeba przepisywać w kodzie). Szczegółowe instrukcje są w `README.md` wewnątrz każdego folderu.

```
assets/
  characters/<postać>/        ivo, skaven, chaos_hound, beastman, chaos_champion
    character.json              rozmiar płótna, pivot, lista animacji (fps, pętla, klatki kontaktu)
    anim/<animacja>/<animacja>_00.png, _01.png, ...
    README.md                   tabela animacji i zasady
  stages/<etap>/              stage1_road, stage2_village, stage3_fields_forest, stage4_lair, common
    stage.json                  warstwy (paralaksa, y_offset) i lista rekwizytów
    sky.png far1.png far2.png ground.png foreground.png
    props/<rekwizyt>.png (+ warianty _2 ... _6)
    README.md
  palette/                    wspólna paleta 256 kolorów (+ tablica LUT dla shadera)
  audio/sfx                   dźwięki (nazwy w scripts/autoload/sfx.gd)
  audio/music                 motywy menu / etapów / bossa (lista i głośność w data/music.json)
  ui/                         portret w menu
```

## Postacie (animacje)
- Klatki **zwrócone w prawo**; w lewo gra odbija je lustrzanie. Pivot = punkt styku stóp z podłożem, ten sam na każdej klatce.
- **Animacje ataków muszą mieć klatkę kontaktu** (`contact` w `character.json`): jest pokazywana dokładnie w oknie aktywnego hitboxa;
  klatki wcześniejsze rozkładają się na czas zamachu, późniejsze na czas powrotu. Nazwy ataków = klucze w `data/balance.json`.
- Można podmienić **jedną animację**: brakujące stany używają zapasu (wróg: animacja `idle`, a gdy i jej brak, grafika proceduralna;
  Ivo: pozy 8-kierunkowe z `characters/ivo/poses`).
- Boss: `hurt` = oszołomienie po złamaniu poise, `roar` = ryk przy zmianie fazy.

## Etapy (tło i rekwizyty)
- Warstwy `sky`, `far1`, `far2`, `ground`, `foreground` powtarzane są poziomo (szew musi być niewidoczny); paralaksę ustawia `stage.json`.
- Rekwizyty są **tylko dekoracją**: nie blokują ruchu i rysują się za postaciami; pivot = środek dolnej krawędzi PNG.
  Gra dobiera losowo warianty (`nazwa_2.png` ...) i czasem odbija je lustrzanie.
- `common/props`: `barrel.png` (beczka) i `potion.png` (mikstura).

## Narzędzia
```
python3 tools/make_asset_folders.py     # (re)generuje foldery, manifesty i instrukcje z tools/asset_spec.py (nie nadpisuje PNG)
python3 tools/check_assets.py           # raport: co jest, czego brakuje, błędy rozmiaru/numeracji/szwu/krawędzi
python3 tools/quantize_png.py IN --out OUT   # opcjonalnie: dopasowanie PNG do palety 256 kolorów (oryginały nietknięte)
```
Po dodaniu PNG: otwórz projekt w Godot (import) albo `godot --headless --path . --import`.
Obraz końcowy i tak jest dopasowywany do palety 256 kolorów shaderem, więc kolory spoza palety nie psują efektu, tylko zmieniają się na najbliższe.
