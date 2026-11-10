# Specyfikacja animacji postaci

Co dostarczyć, żeby postacie miały prawdziwe, narysowane klatki zamiast póz „ożywianych” w kodzie.
Zasady rysunku (format, kontur, światło z lewej-góry, bez cienia na ziemi) — jak w `docs/SPECYFIKACJA_GRAFIK.md`.

## 1. Układ plików

```
assets/characters/<postać>/<animacja>/<kierunek>/0.png, 1.png, 2.png ...     ivo, ursa, modraszka, borubar
assets/enemies/<wróg>/<animacja>/<kierunek>/0.png, 1.png ...                 skaven_spear, skaven_slinger, skaven_warlock
<postać>/sprite.json                                                         płótno, pivot, klatki na sekundę
```
Klatki numerowane od 0, bez przerw. Gra używa tylu klatek, ile znajdzie.

## 2. Płótno i pivot

| Kto | Płótno | Pivot (punkt stóp) | Wysokość postaci |
|---|---|---|---|
| Bohater | **160×160 px** (zalecane) | (80, 150) | ok. 120 px |
| Skaven | 96×112 px | (48, 108) | ok. 85 px (zgarbiony) |
| Borubar (NPC) | 92×144 px | (46, 143) | ok. 100 px + beczka |

- **Wszystkie klatki wszystkich animacji jednej postaci mają to samo płótno i ten sam pivot** — inaczej postać „skacze”.
- Pivot to punkt na ziemi między stopami. Wpisujesz go w `sprite.json`: `{"canvas": [160, 160], "pivot": [80, 150]}`.
- Zostaw margines na broń w pełnym wyproście (miecz Ivo, łuk Modraszki) — nic nie może być ucięte krawędzią płótna.
  Jeśli leżąca postać (śmierć) się nie mieści, poszerz płótno we wszystkich klatkach (Modraszka ma teraz 320×128).
- Hitbox nie zależy od rysunku — rozmiar płótna możesz zmieniać swobodnie.

## 3. Kierunki

8 folderów: `south` (twarzą do gracza), `south-east`, `east`, `north-east`, `north` (plecami), `north-west`, `west`, `south-west`.
To kierunek na ekranie, w który postać patrzy.

**Minimum: 5 kierunków** — `south`, `south-east`, `east`, `north-east`, `north`. Brakujące `west`, `south-west`, `north-west`
gra zrobi sama jako lustrzane odbicie. Wada odbicia: broń zmienia rękę i znika asymetria stroju — dla Ivo (miecz na ramieniu,
tarcza herbowa) lepiej narysować wszystkie 8.

## 4. Animacje bohatera

| Animacja | Folder | Klatek | Tempo | Pętla | Opis |
|---|---|---|---|---|---|
| Stanie | `idle` | 2–4 | 3 kl./s | tak | oddech, lekki ruch płaszcza |
| Chód | `walk` | 6 lub 8 | 10 kl./s | tak | pełny cykl kroku; klatka 0 = kontakt lewej stopy. Bohater idzie 130–148 px/s |
| Atak | `attack` | **4** (3 zamachu + 1 trafienia) | wg czasu ataku | nie | patrz niżej |
| Trafiony | `hurt` | 1–2 | — | nie | odchylenie do tyłu, grymas; trwa 0,3 s |
| Śmierć | `death` | 5–6 | 6 kl./s | nie | upadek; **ostatnia klatka zostaje** (leżące ciało) |

**Jak działa `attack`:** wszystkie klatki oprócz ostatniej rozkładają się równo na czas zamachu, a **ostatnia klatka to moment
trafienia / wystrzału** i zostaje widoczna przez czas powrotu. Czasy zamachu są krótkie:

| Postać | Slot 1 (najczęstszy) | Slot 2 | Slot 3 | Zwykły atak bronią |
|---|---|---|---|---|
| Ivo | cięcie 0,14 s | wir 0,22 s | okrzyk 0,30 s | ok. 0,32 s |
| Ursa | ognisty pocisk 0,12 s | kula ognia 0,30 s | płomień 0,20 s | kostur ok. 0,32 s |
| Modraszka | strzała 0,12 s | grad strzał 0,22 s | sieć 0,25 s | nóż ok. 0,27 s |

Dlatego 3 klatki zamachu wystarczą; więcej nie będzie widać. Na ostatniej klatce broń ma być w pełnym wyproście w kierunku,
w który postać patrzy (gra dorysowuje łuk cięcia i pocisk).

Co pokazać w `attack`:
- **Ivo** — zamach dwuręcznym mieczem znad ramienia, ostatnia klatka: miecz wyciągnięty w przód, ciężar na przedniej nodze.
- **Ursa** — uniesienie ręki / kostura, ostatnia klatka: dłoń wyrzucona w przód (stąd wylatuje pocisk ognia).
- **Modraszka** — naciąg łuku, ostatnia klatka: cięciwa puszczona, ręka cofnięta.

**Opcjonalnie (dziś gra tego nie rozróżnia — dodam obsługę, gdy klatki powstaną):** osobne animacje `cast` (czar Ursy),
`melee` (cios nożem Modraszki i kosturem Ursy), `whirl` (wirujący miecz Ivo), `shout` (okrzyk Ivo). Bez nich wszystkie ataki
używają `attack`.

## 5. Animacje skavenów (3 rodzaje wrogów)

| Animacja | Klatek | Tempo | Opis |
|---|---|---|---|
| `idle` | 2 | 3 kl./s | węszenie, drganie ogona |
| `walk` | 4–6 | 7–8 kl./s | zgarbiony bieg, 112 px/s |
| `attack` | **3–5** (ostatnia = cios) | wg zamachu | zapowiedź ataku — ma być wyraźnie czytelna dla gracza |
| `hurt` | 1 | — | skulenie |
| `death` | 4 | 6 kl./s | upadek; ostatnia klatka zostaje ok. 8 s, potem znika |

Zamach wrogów jest długi, więc warto dać więcej klatek zapowiedzi:
- **Skaven z dzidą** — 0,75 s: cofnięcie dzidy (3–4 klatki), ostatnia: pchnięcie na pełną długość (zasięg ok. 64 px).
- **Skaven procarz** — 0,9 s: kręcenie procą nad głową (4 klatki, może być pętla ruchu), ostatnia: wyrzut ręki.
- **Czarownik skaveński** — 1,3 s: uniesienie kostura, narastająca zielona poświata kamienia (4 klatki), ostatnia: kostur w dół.

Wychodzenie z tunelu nie wymaga osobnych klatek (gra „wysuwa” postać z ziemi), ale możesz dodać animację `emerge`
(4 klatki) — dopiszę jej użycie.

## 6. Borubar

- W karczmie gracz nim steruje: potrzebne `idle` (2 klatki) i `walk` (6 klatek) w co najmniej 5 kierunkach, z beczką nad głową.
- W wiosce stoi w miejscu: wystarczy `idle/south`. Dziś ma jedną pozę (`idle/south/0.png`).
- Opcjonalnie `catch` (2 klatki: kufel wpada do beczki) i `dizzy` (ogłuszony) — dziś nieużywane.

## 7. Ile to plików

Bohater w wersji minimalnej (5 kierunków): idle 2 + walk 6 + attack 4 + hurt 1 + death 5 = **18 klatek × 5 = 90 plików**;
w pełnej (8 kierunków): 144. Skaven w wersji minimalnej: 2 + 4 + 3 + 1 + 4 = 14 klatek × 5 = **70 plików** na rodzaj.

Jeśli wolisz rysować arkusze (sprite sheet) zamiast pojedynczych plików: jeden PNG na animację, **wiersze = kierunki**
w kolejności `south, south-east, east, north-east, north, north-west, west, south-west`, **kolumny = klatki**, komórka = rozmiar
płótna, bez odstępów. Potnę je skryptem do właściwych folderów.

## 8. Kolejność — co da największą różnicę

1. `walk` bohaterów (dziś postać „sunie” z kołysaniem) — najbardziej widoczne.
2. `attack` bohaterów.
3. Ursa z kosturem zamiast miecza (wszystkie pozy) oraz widoki z tyłu i z boku Ursy i Modraszki — dziś każda ma jeden rysunek,
   więc „plecami” wygląda tak samo jak „przodem”.
4. Skaveny: `walk`, `attack`, `death`.
5. `death` i `hurt` bohaterów, Borubar.

## 9. Stan obecny (co jest placeholderem)

| Postać | Co jest | Czego brakuje |
|---|---|---|
| Ivo | 8 póz kierunkowych z Twoich oryginałów (`idle`, 1 klatka) | walk, attack, hurt, death |
| Ursa | 1 rysunek (z mieczem), odbijany lustrzanie | wersja z kosturem, pozostałe kierunki, wszystkie animacje |
| Modraszka | 1 rysunek; klatki walk/attack/hurt/death to jego przekształcenia | prawdziwe klatki i kierunki |
| Borubar | 1 poza z beczką | kierunki, chód |
| Skaveny | generowane skryptem (3 widoki) | wszystko docelowe |

## 10. Jak sprawdzić

Wrzuć klatki do folderów, uruchom grę. Gdy istnieje folder `walk` albo `attack`, gra przestaje „ożywiać” postać w kodzie
i odtwarza Twoje klatki. Tempo zmienisz w `sprite.json`, np. `"fps": {"idle": 3, "walk": 10, "death": 6}`.
`F3` pokazuje punkt stóp — jeśli postać stoi obok swojego cienia, popraw pivot.
