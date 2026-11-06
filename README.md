# Hufduhof

Izometryczny hack and slash w stylu Diablo 1/2, w klimacie Warhammer Fantasy (grimdark). Godot 4.3 + GDScript, Android (poziomo).
Szczuroludzie napadli wioskę Hufduhof — trzeba ugasić płonącą barykadę przy bramie i wydostać się z wioski.

> Poprzednia wersja (boczna gra arcade) jest zachowana na gałęzi **`archiwum/arcade-v1`** i działa w obecnej postaci.

**Autorzy:** Janek M. i Franek W.

## Przebieg gry
1. **Menu główne** (wygląd jak w poprzedniej wersji) → 2. **Wybór postaci**: Ivo, Ursa, Modraszka (portret, opis, tabela cech)
→ 3. **Karczma** (minigra: łapanie kufli, potem skaveny wyważają drzwi — samouczek walki)
→ 4. **Poziom 1: wioska Hufduhof** → 5. **Poziom 2**: na razie ekran „Ciąg dalszy nastąpi” i zapis gry.

## Uruchomienie na komputerze
1. Godot **4.3** (Standard): https://godotengine.org/download/archive/4.3-stable/
2. Otwórz `project.godot`, naciśnij **F5**.

| PC | Telefon | Akcja |
|---|---|---|
| WASD / strzałki | joystick (lewa strona) | ruch |
| lewy przycisk myszy / J / Spacja | ATAK | atak (przytrzymaj = kolejne zamachy), mysz celuje |
| prawy przycisk myszy / K | UMIEJ. | umiejętność / czar |
| Q / 1 | ŻYCIE | mikstura życia (gdy brak — piwo) |
| R / 2 | MANA | mikstura many |
| E / F | UŻYJ | interakcja (skrzynia, studnia, kapliczka, Borubar…) |
| M / Tab, C, I, Esc | przyciski u góry | mapa, postać, plecak, pauza |
| kółko myszy | — | zoom kamery |
| F3 (tylko debug) | — | diagnostyka kolizji (domyślnie wyłączona) |

## Testy (GUT)
```bash
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json
```
50 testów: formuły walki i cech, rozwój postaci (w tym „ok. 5 punktów w Poziomie 1”), łupy i ekwipunek, zadanie z wiadrami
(logika i pełne przejście na prawdziwej scenie), walka ze skavenem, zapowiedzi ataków, kapliczki, PP, zapis/wczytanie.
Zrzuty ekranu (wymaga `xvfb-run`): `xvfb-run -a godot --path . -s res://tests/tools/shots.gd -- /katalog`.

## Gdzie co jest
| Co | Gdzie |
|---|---|
| Balans (cechy, wrogowie, łupy, ceny, kapliczki, XP) | `data/*.json` |
| Poziomy (mapa znakowa, obiekty, grupy wrogów) | `data/levels/wioska.json`, `data/levels/karczma.json` |
| Wzory (jedyny skrypt formuł) | `scripts/core/rules.gd` |
| Logika bez sceny: cechy, ekwipunek, łupy, rozwój, zadanie | `scripts/core/` |
| Bohater, wrogowie (AI), animacja 8 kierunków | `scripts/actors/` |
| Mapa izometryczna, nawigacja, mgła, obiekty | `scripts/world/` |
| Poziomy, karczma | `scripts/levels/` |
| Interfejs (HUD, dotyk, minimapa, ekrany) | `scripts/ui/` |
| Grafika, dźwięk | `assets/` — opis rozmiarów i nazw: **`docs/ASSETY.md`** |
| Założenia do poprawienia | **`docs/DECYZJE.md`** |
| Budowanie APK | **`docs/BUDOWANIE_APK.md`** |
| Generatory placeholderów (Python + Pillow) | `tools/` |
