# ETAP 2: WIEŚ

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
| `house_thatch` | `props/house_thatch.png` (warianty: `house_thatch_2.png` ... `house_thatch_6.png`) | 130x150 | chata ze strzechą |
| `house_shingle` | `props/house_shingle.png` (warianty: `house_shingle_2.png` ... `house_shingle_6.png`) | 130x150 | chata z gontem |
| `house_burnt` | `props/house_burnt.png` (warianty: `house_burnt_2.png` ... `house_burnt_6.png`) | 130x150 | spalona chata |
| `barn` | `props/barn.png` (warianty: `barn_2.png` ... `barn_6.png`) | 150x160 | stodoła |
| `fence` | `props/fence.png` (warianty: `fence_2.png` ... `fence_6.png`) | 110x40 | płot (5 przęseł) |
| `fence_broken` | `props/fence_broken.png` (warianty: `fence_broken_2.png` ... `fence_broken_6.png`) | 110x40 | zniszczony płot |
| `gate` | `props/gate.png` (warianty: `gate_2.png` ... `gate_6.png`) | 60x60 | brama |
| `cart` | `props/cart.png` (warianty: `cart_2.png` ... `cart_6.png`) | 75x50 | wóz |
| `well` | `props/well.png` (warianty: `well_2.png` ... `well_6.png`) | 45x70 | studnia |
| `crates` | `props/crates.png` (warianty: `crates_2.png` ... `crates_6.png`) | 60x50 | skrzynie i worek |
| `scarecrow` | `props/scarecrow.png` (warianty: `scarecrow_2.png` ... `scarecrow_6.png`) | 40x85 | strach na wróble |

Sprawdzenie plików: `python3 tools/check_assets.py`.
