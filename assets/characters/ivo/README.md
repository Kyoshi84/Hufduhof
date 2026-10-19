# Ivo Eggert (gwardzista Szkarłatnej Gwardii, miecz dwuręczny)

Folder grafik postaci. Gra ładuje klatki z `anim/<animacja>/<animacja>_00.png`, `_01.png`, ... Brakująca animacja = zapas
(proceduralna grafika tymczasowa lub pozy). Podmieniasz po jednej animacji; reszta działa bez zmian.

## Zasady klatek
- Płótno **320x192 px**, przezroczyste tło, ta sama wielkość płótna we **wszystkich** klatkach tej postaci.
- Pivot (punkt styku stóp z podłożem) w **(160, 190)** na każdej klatce - dzięki temu postać nie "skacze".
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
| animacja | klatek | fps | pętla | kontakt (hitbox) | uwagi |
|---|---|---|---|---|---|
| `idle` | 4 | 6 | tak | - | oddychanie, postawa bojowa |
| `run` | 6 | 12 | tak | - | bieg w profilu; ruch w głąb sceny używa póz 8-kierunkowych (poses/) |
| `light1` | 5 | wg czasu ataku | nie | 2-2 | lekki atak 1; klatka kontaktu = miecz/broń na maksymalnym wyciągnięciu; musi sięgać zasięgu z balance.json (zasięg 140 px świata ~ 105 px sprite'a) |
| `light2` | 5 | wg czasu ataku | nie | 2-2 | lekki atak 2 (z drugiej strony) |
| `sweep` | 8 | wg czasu ataku | nie | 3-4 | szeroki zamach obszarowy (obrót), zasięg 165 px świata w obie strony |
| `heavy` | 10 | wg czasu ataku | nie | 5-5 | mocny atak znad głowy, zasięg 180 px świata |
| `hurt` | 2 | 10 | nie | - | odchylenie do tyłu (0,35 s) |
| `dodge` | 4 | 14 | nie | - | unik / przewrót (0,3 s) |
| `die` | 6 | 8 | nie | - | śmierć; ostatnia klatka zostaje na ziemi |
| `victory` | 4 | 6 | tak | - | miecz w górę po pokonaniu bossa |

## Pozy 8-kierunkowe (zapas)
`poses/` zawiera 8 statycznych póz (E, SE, S, SW, W, NW, N, NE) używanych, gdy brakuje animacji albo przy ruchu w głąb sceny. Oryginały: `source/` (nie modyfikowane), kopie do gry generuje `tools/prepare_ivo.py`.

Sprawdzenie plików: `python3 tools/check_assets.py`. Po dodaniu PNG otwórz projekt w Godot (import) lub uruchom `godot --headless --import`.
