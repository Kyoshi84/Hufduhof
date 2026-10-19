# ETAP 3: POLA I LAS

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
| `tree_oak` | `props/tree_oak.png` (warianty: `tree_oak_2.png` ... `tree_oak_6.png`) | 110x150 | drzewo liściaste |
| `tree_dead` | `props/tree_dead.png` (warianty: `tree_dead_2.png` ... `tree_dead_6.png`) | 110x150 | martwe drzewo |
| `tree_pine` | `props/tree_pine.png` (warianty: `tree_pine_2.png` ... `tree_pine_6.png`) | 80x170 | świerk |
| `bush` | `props/bush.png` (warianty: `bush_2.png` ... `bush_6.png`) | 50x32 | krzew |
| `stone_big` | `props/stone_big.png` (warianty: `stone_big_2.png` ... `stone_big_6.png`) | 45x38 | głaz |
| `fence_broken` | `props/fence_broken.png` (warianty: `fence_broken_2.png` ... `fence_broken_6.png`) | 80x40 | zniszczony płot |
| `tent` | `props/tent.png` (warianty: `tent_2.png` ... `tent_6.png`) | 70x50 | namiot obozowy |
| `banner_torn` | `props/banner_torn.png` (warianty: `banner_torn_2.png` ... `banner_torn_6.png`) | 35x72 | podarty sztandar |

Sprawdzenie plików: `python3 tools/check_assets.py`.
