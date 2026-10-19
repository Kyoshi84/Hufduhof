# ETAP 1: DROGA DO HUFDUHOFU

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
| `fence` | `props/fence.png` (warianty: `fence_2.png` ... `fence_6.png`) | 96x40 | płot (4 przęsła) |
| `fence_broken` | `props/fence_broken.png` (warianty: `fence_broken_2.png` ... `fence_broken_6.png`) | 96x40 | zniszczony płot |
| `tree_oak` | `props/tree_oak.png` (warianty: `tree_oak_2.png` ... `tree_oak_6.png`) | 100x150 | drzewo liściaste |
| `tree_dead` | `props/tree_dead.png` (warianty: `tree_dead_2.png` ... `tree_dead_6.png`) | 100x150 | martwe drzewo |
| `signpost` | `props/signpost.png` (warianty: `signpost_2.png` ... `signpost_6.png`) | 60x60 | drogowskaz |
| `bush` | `props/bush.png` (warianty: `bush_2.png` ... `bush_6.png`) | 50x32 | krzew |
| `milestone` | `props/milestone.png` (warianty: `milestone_2.png` ... `milestone_6.png`) | 28x32 | kamień milowy |
| `stump_axe` | `props/stump_axe.png` (warianty: `stump_axe_2.png` ... `stump_axe_6.png`) | 40x45 | pieniek z toporem |

Sprawdzenie plików: `python3 tools/check_assets.py`.
