# Zasoby graficzne i dźwiękowe — jak podmieniać

Gra ładuje pliki z poniższych ścieżek. **Placeholdery leżą dokładnie tam, gdzie mają trafić Twoje grafiki** —
podmieniasz plik o tej samej nazwie i od razu widzisz efekt (kod się nie zmienia).
Po podmianie otwórz projekt w Godocie (sam zaimportuje plik) albo uruchom `godot --headless --import`.

## Zasady ogólne
- PNG z przezroczystością, **alfa tylko 0 albo 255** (bez półprzezroczystych krawędzi), pixel-art z konturem.
- Kolory najlepiej z palety `assets/palette/hufduhof_256.png` (256 kolorów). Inne kolory i tak zostaną sprowadzone do palety
  przez filtr końcowy, ale rysunek w palecie wygląda przewidywalnie.
- Bez wygładzania (gra rysuje piksele „nearest”).

## Postacie bohaterów
```
assets/characters/<postać>/              ivo, ursa, modraszka, borubar
  sprite.json                            płótno i pivot (punkt stóp), np. {"canvas":[96,128], "pivot":[48,126]}
  portrait.png                           portret na ekranie wyboru (Ivo: assets/ui/ivo_portrait.png)
  <animacja>/<kierunek>/<n>.png          klatki: 0.png, 1.png, 2.png ...
  source/                                ORYGINAŁY (nie są zmieniane ani wczytywane przez grę)
```
- **Kierunki** (8): `south`, `south-east`, `east`, `north-east`, `north`, `north-west`, `west`, `south-west`
  (kierunek na ekranie, w który patrzy postać).
- **Animacje**: `idle` (stoi), `walk` (chód), `attack` (atak: klatki rozkładane na czas zamachu, **ostatnia klatka = moment trafienia**),
  `hurt` (trafiony), `death` (śmierć, ostatnia klatka zostaje).
- **Płótno bohatera 96×128 px**, stopy w punkcie (48, 126) na każdej klatce. Postać ok. 110–120 px wysokości.
- Brakujący plik = zapas: najpierw lustrzane odbicie kierunku (np. `west` z `east`), potem animacja `idle`.
  Dlatego wystarczy np. dorysować `walk/east/0..3.png` — zachód gra odbije sama.
- **Ivo**: `assets/characters/ivo/source/*.png` to Twoje 8 oryginałów (160×256, nazwy bez zmian).
  Kopie dla gry (96×128) są w `assets/characters/ivo/idle/<kierunek>/0.png`.
- **Ursa**: kopie w `idle/<kierunek>/0.png` (zrobione z `source/ursa_source.webp`; jeden rysunek, więc kierunki są odbiciami).
- **Modraszka**: z obrazu autora `source/modraszka_source.webp` (`tools/build_modraszka.py`): idle 2 klatki, walk 4, attack 3, hurt 1,
  death 4 w 8 kierunkach; płótno 320×128 (szerokie, żeby zmieściła się leżąca postać), pivot (160, 126).

## Wrogowie
```
assets/enemies/<wróg>/                   skaven_spear, skaven_slinger, skaven_warlock
  sprite.json                            płótno 96×112, pivot (48, 108), fps animacji
  idle|walk|attack|hurt|death/<kierunek>/<n>.png
```
Placeholdery: idle 2 klatki, walk 4, attack 3 (zamach, zamach, pchnięcie), hurt 1, death 4 — w 8 kierunkach.

## Poziomy
```
assets/levels/level1/tiles/<nazwa>.png   kafle podłoża 128×64 (romb izometryczny, przezroczyste rogi)
   grass_0..3, grass_flowers, dirt_0..1, cobble_0..1, mud_0, forest_0
assets/levels/level1/props/<nazwa>.png   rekwizyty wioski
assets/levels/level1/fx/                 (zarezerwowane na efekty tylko tego poziomu)
assets/levels/tavern/tiles/              floor_0..1, rug_0, stone_0
assets/levels/tavern/props/              table, bench, bar_counter, fireplace, door_closed, door_broken, wall_x, wall_y,
                                         wall_x_window, wall_y_window, innkeeper, guest_1..6, mug, splash, borubar
assets/levels/common/tiles/              fog_full, fog_soft (mgła wojny)
assets/levels/common/props/              chest_closed, chest_open, bucket_empty, bucket_full
assets/levels/common/fx/                 stone, warp_orb, magic_bolt, fireball, fire_lance, arrow, net_arrow,
                                         poison_pool_0..1, fire_0..3 (pocisk: grafika skierowana w prawo)
```
**Kotwica rekwizytu = środek dolnej krawędzi obrazka:**
- małe obiekty (drzewa, płoty, beczki, skrzynie, kapliczki, studnia, barykada): dolny środek = **środek komórki**, na której stoją;
- budynki: dolny środek = **południowy (najniższy na ekranie) narożnik podstawy**. Szerokość obrazka może być dowolna.

| Rekwizyt | Plik | Podstawa (komórki) | Placeholder (px) |
|---|---|---|---|
| Dom kryty strzechą | `house_a.png` | 3×3 | 436×284 |
| Dom z gontem | `house_b.png` | 3×2 | 434×254 |
| Dom szczytem do drogi | `house_c.png` | 2×3 | 436×255 |
| Spalony dom | `house_burnt.png` | 3×3 | 390×263 |
| Karczma (z zewnątrz) | `tavern_outside.png` | 4×3 | 562×330 |
| Kuźnia | `smithy.png` | 3×2 | 420×287 |
| Młyn | `mill.png` | 2×2 | 390×298 |
| Stodoła | `barn.png` | 4×3 | 562×336 |
| Chata zielarki | `herbalist_hut.png` | 2×2 | 308×210 |
| Studnia | `well.png` | 1×1 | 126×144 |
| Część barykady (płonąca / spalona) | `barricade.png`, `barricade_burnt.png` | 1×1 | 110×70 |
| Kapliczka Ulryka / Rhyi (+ `_used`) | `shrine_ulric.png`, `shrine_rhya.png` | 1×1 | 82×124 |
| Drzewa, krzaki | `tree_0..2.png`, `tree_dead.png`, `bush_0..1.png` | 1×1 | ok. 110×124 |
| Płoty | `fence_x.png` (wzdłuż „\”), `fence_y.png` (wzdłuż „/”), `fence_x_broken.png` | 1×1 | 76×60 |
| Drobne | `barrel`, `crate`, `cart`, `haystack`, `grave_0..2`, `signpost`, `rat_hole`, `exit_banner` | 1×1 | — |
| Zawalona chata, dom zabity deskami | `house_ruin.png`, `house_boarded.png` | 3×3, 3×2 | 390×260, 370×250 |
| Palisada, tunel skavenów | `palisade_x.png`, `skaven_tunnel.png` (leży na ziemi, środek obrazka = środek komórki) | 1×1 | 80×110, 120×64 |
| Grimdark | `tree_dead_1`, `thorns_0..1`, `rock_0..1`, `skull_pile`, `firewood`, `stump`, `cart_broken`, `cellar`, `shrine_broken`, `gibbet`, `spikes`, `scarecrow` | 1×1 | — |
| Płaskie (pod postaciami) | `bones_0..1`, `rubble_0..1`, `puddle` | — | ok. 60×30 |

Rozmieszczenie (mapa znakowa, budynki, skrzynie, kapliczki, grupy wrogów): `data/levels/wioska.json` i `data/levels/karczma.json`.

## Interfejs
```
assets/ui/ivo_portrait.png               portret w menu głównym i na karcie Ivo
assets/ui/crest/                         herb Carroburga (menu)
assets/ui/items/<ikona>.png              ikony przedmiotów 32×32 (nazwa ikony: pole "ikona" w data/items.json)
assets/ui/skills/<postać>/<id>.png       ikony umiejętności na pasku, 48×48 (ścieżka: pole "ikona" umiejętności w data/heroes.json)
                                         ivo: potezne_ciecie, wirujacy_miecz, okrzyk_gwardii
                                         ursa: ognisty_pocisk, kula_ognia, przebijajacy_plomien
                                         modraszka: strzala, grad_strzal, strzala_z_siecia
```

## Dźwięk
```
assets/audio/music/                      menu_theme.ogg, stage_theme.ogg, boss_theme.ogg (lista i głośność: data/music.json)
assets/audio/sfx/<nazwa>.ogg|wav|mp3     efekty; brak pliku = dźwięk tymczasowy syntezowany w kodzie
```
Nazwy efektów: `swing, swing_heavy, hit, miss, hurt, skaven_die, skaven_alert, stone, warp, bolt, lightning, fire, pickup,
coin, potion, chest, splash, fill, shrine, levelup, ui_click, door, mug_catch, mug_break, death, no_mana`.

## Generatory placeholderów (Python 3 + Pillow)
```
python3 tools/make_palette.py      # paleta 256 + LUT
python3 tools/gen_tiles.py         # kafle i mgła
python3 tools/gen_props.py         # budynki, rekwizyty, efekty
python3 tools/gen_characters.py    # skaveny
python3 tools/build_modraszka.py   # Modraszka z obrazu autora (klatki + portret)
python3 tools/gen_items.py         # ikony przedmiotów, ściany karczmy, strzała
python3 tools/gen_skills.py        # ikony umiejętności, ognista włócznia, strzała z siecią
python3 tools/build_levels.py      # data/levels/*.json (UWAGA: nadpisuje ręczne zmiany w tych plikach)
```
Generatory **nadpisują** placeholdery — jeśli podmieniłeś plik na własny, nie uruchamiaj generatora tej grupy.
