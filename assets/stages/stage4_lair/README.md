# ETAP 4: LEGOWISKO CHAOSU

Grafiki etapu. Każdy brakujący plik jest zastępowany proceduralną grafiką tymczasową; podmieniasz po jednym pliku.

## Zasady
- PNG z przezroczystością (alfa 0/255), 1 piksel grafiki = 1 piksel obrazu wewnętrznego gry (4/3 jednostki świata).
- Warstwy tła powtarzane poziomo muszą mieć **niewidoczny szew** (lewa krawędź łączy się z prawą).
- **Rekwizyty są wyłącznie dekoracją**: nie blokują ruchu i rysują się ZA postaciami. Pivot = środek dolnej krawędzi PNG (punkt styku z podłożem).
- Warianty rekwizytu (`nazwa_2.png`, ...) gra dobiera losowo (stałe dla danego miejsca), opcjonalnie odbijając lustrzanie.
- Pas walki to y = 385-600 (świat 1280x720); nie umieszczaj tam elementów zasłaniających postacie.
- Kolory ze wspólnej palety (`assets/palette/`); obraz i tak jest na końcu dopasowywany do palety 256 kolorów.

## Warstwy tła
| warstwa | plik | równoległość | rozmiar | opis |
|---|---|---|---|---|
| sky | `sky.png` | 0.0 | 128x320 (szeroki 64-512, wysokość 320) | niebo; powtarzane poziomo, dolna krawędź na horyzoncie |
| far1 | `far1.png` | 0.15 | 640x140, szew poziomy niewidoczny | daleki plan (wolny paralaks), powtarzany poziomo, dolna krawędź na horyzoncie |
| far2 | `far2.png` | 0.32 | 640x110, szew niewidoczny | bliższy plan sylwetek (średni paralaks), powtarzany poziomo |
| ground | `ground.png` | 0.0 | 128x320 | podłoże w pasie walki, powtarzane poziomo, górna krawędź na horyzoncie |
| foreground | `foreground.png` | 1.25 | 640x60, max 67 px wysokości | opcjonalny pierwszy plan przy dolnej krawędzi ekranu (poza pasem walki!) |

Paralaksa i `y_offset` (przesunięcie pionowe, px) można zmienić w `stage.json`.

## Rekwizyty
| rekwizyt | plik | rozmiar px | opis |
|---|---|---|---|
| `obelisk` | `props/obelisk.png` (warianty: `obelisk_2.png` ... `obelisk_6.png`) | 40x100 | obelisk z runą |
| `brazier` | `props/brazier.png` (warianty: `brazier_2.png` ... `brazier_6.png`) | 30x65 | kocioł z ogniem Chaosu |
| `tree_twisted` | `props/tree_twisted.png` (warianty: `tree_twisted_2.png` ... `tree_twisted_6.png`) | 110x150 | skażone drzewo |
| `bones` | `props/bones.png` (warianty: `bones_2.png` ... `bones_6.png`) | 70x70 | kości i pal z czaszką |
| `crystals` | `props/crystals.png` (warianty: `crystals_2.png` ... `crystals_6.png`) | 45x50 | kryształy Chaosu |

Sprawdzenie plików: `python3 tools/check_assets.py`.
