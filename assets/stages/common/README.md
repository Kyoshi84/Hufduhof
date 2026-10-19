# WSPÓLNE (wszystkie etapy)

Grafiki etapu. Każdy brakujący plik jest zastępowany proceduralną grafiką tymczasową; podmieniasz po jednym pliku.

## Zasady
- PNG z przezroczystością (alfa 0/255), 1 piksel grafiki = 1 piksel obrazu wewnętrznego gry (4/3 jednostki świata).
- Warstwy tła powtarzane poziomo muszą mieć **niewidoczny szew** (lewa krawędź łączy się z prawą).
- **Rekwizyty są wyłącznie dekoracją**: nie blokują ruchu i rysują się ZA postaciami. Pivot = środek dolnej krawędzi PNG (punkt styku z podłożem).
- Warianty rekwizytu (`nazwa_2.png`, ...) gra dobiera losowo (stałe dla danego miejsca), opcjonalnie odbijając lustrzanie.
- Pas walki to y = 385-600 (świat 1280x720); nie umieszczaj tam elementów zasłaniających postacie.
- Kolory ze wspólnej palety (`assets/palette/`); obraz i tak jest na końcu dopasowywany do palety 256 kolorów.


## Rekwizyty
| rekwizyt | plik | rozmiar px | opis |
|---|---|---|---|
| `barrel` | `props/barrel.png` (warianty: `barrel_2.png` ... `barrel_6.png`) | 36x44 | beczka (zniszczalna) |
| `potion` | `props/potion.png` (warianty: `potion_2.png` ... `potion_6.png`) | 22x28 | mikstura lecząca |

Sprawdzenie plików: `python3 tools/check_assets.py`.
