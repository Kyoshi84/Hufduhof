# Zwierzoczłek

Folder grafik postaci. Gra ładuje klatki z `anim/<animacja>/<animacja>_00.png`, `_01.png`, ... Brakująca animacja = zapas
(proceduralna grafika tymczasowa lub pozy). Podmieniasz po jednej animacji; reszta działa bez zmian.

## Zasady klatek
- Płótno **288x224 px**, przezroczyste tło, ta sama wielkość płótna we **wszystkich** klatkach tej postaci.
- Pivot (punkt styku stóp z podłożem) w **(144, 222)** na każdej klatce - dzięki temu postać nie "skacze".
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
| `idle` | 4 | 5 | tak | - |  |
| `run` | 6 | 9 | tak | - |  |
| `chop` | 6 | wg czasu ataku | nie | 3-3 | cios z góry; zasięg 112 px świata |
| `wide` | 7 | wg czasu ataku | nie | 3-4 | szeroki zamach; zasięg 160 px świata |
| `hurt` | 2 | 10 | nie | - |  |
| `die` | 6 | 8 | nie | - |  |

Sprawdzenie plików: `python3 tools/check_assets.py`. Po dodaniu PNG otwórz projekt w Godot (import) lub uruchom `godot --headless --import`.
