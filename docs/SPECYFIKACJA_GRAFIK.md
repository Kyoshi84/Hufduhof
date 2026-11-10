# Specyfikacja docelowych grafik (rekwizyty, kafle, efekty, interfejs)

Ten dokument mówi, **co dokładnie narysować i w jakim formacie**, żeby zastąpić placeholdery. Każdy plik podmieniasz pod tą samą
nazwą i w tym samym folderze — kod się nie zmienia. Animacje postaci: osobny dokument `docs/SPECYFIKACJA_ANIMACJI.md`.

## 1. Zasady wspólne

| Zasada | Wartość |
|---|---|
| Format | PNG, 32-bit z kanałem alfa |
| Przezroczystość | tylko 0 albo 255 (bez półprzezroczystych krawędzi, bez wygładzania) |
| Tło | prawdziwa przezroczystość — **nie** szachownica ani białe tło wtopione w obraz |
| Styl | pixel-art jak Ivo/Ursa/Modraszka: ciemny kontur 1 px, 3–4 tony na materiał, bez gradientów i rozmyć |
| Skala | 1 piksel obrazka = 1 piksel gry. Postać ma ok. 120 px wysokości, drzwi domu ok. 40 px, okno ok. 16 px |
| Rzut | izometryczny 2:1 — krawędzie „w głąb” idą 2 piksele w poziomie na 1 w pionie (kąt ok. 26,6°) |
| Światło w rysunku | z **lewej-góry**: ściany lewe-przednie jaśniejsze, prawe-przednie ciemniejsze o 1–2 tony |
| Cień na ziemi | **nie rysuj** — gra dodaje go sama (i dokłada światło latarni/ognia) |
| Poświata ognia, latarni | **nie rysuj** otoczki światła — narysuj tylko sam płomień/szybkę; poświatę dodaje gra |
| Paleta | najlepiej kolory z `assets/palette/hufduhof_256.png`; inne i tak zostaną sprowadzone do palety |
| Kolorystyka | brudne brązy, ciemne szarości, wyblakła zieleń, przygaszona czerwień; błoto, rdza, zgnilizna |

**Kotwica (ważne):** środek dolnej krawędzi obrazka = punkt, którym obiekt „stoi” na mapie.
- małe obiekty (podstawa 1×1): dolny środek = środek komórki; obiekt rysuj wyśrodkowany w poziomie,
- budynki: dolny środek = **najniższy (południowy) narożnik podstawy**. Dla podstawy w×h komórek romb podstawy ma
  szerokość (w+h)×64 px i wysokość (w+h)×32 px; przy w≠h narożnik południowy nie leży na środku rombu, więc dodaj
  przezroczysty margines z jednej strony, żeby wypadł na środku obrazka.

Komórka siatki to romb 128×64 px.

## 2. Kafle podłoża — `assets/levels/level1/tiles/`

Rozmiar **128×64 px**, romb wpisany w prostokąt, rogi przezroczyste. Kafle muszą się **bezszwowo łączyć** ze sobą
i z innymi wariantami (bez ramek, bez wzoru urywającego się na krawędzi).

| Plik | Co | Uwagi |
|---|---|---|
| `grass_0.png` … `grass_3.png` | trawa, 4 warianty | matowa, wydeptana; warianty różnią się drobiazgami |
| `grass_flowers.png` | trawa z chwastami | rzadkie, wyblakłe kwiaty/osty |
| `dirt_0.png`, `dirt_1.png` | błotnista ścieżka | koleiny, kamyki |
| `cobble_0.png`, `cobble_1.png` | bruk placu i bramy | nierówny, z błotem w szczelinach |
| `mud_0.png` | błoto / zaorane pole | ciemne, mokre |
| `forest_0.png` | ściółka pod skrajem Drakwaldu | prawie czarna zieleń, korzenie |

Karczma (`assets/levels/tavern/tiles/`): `floor_0.png`, `floor_1.png` (deski), `rug_0.png` (dywan), `stone_0.png` (posadzka przy kominku).
Mgła wojny (`assets/levels/common/tiles/`): `fog_full.png` (czarny romb), `fog_soft.png` (czarny w szachownicę) — można zostawić.

## 3. Budynki — `assets/levels/level1/props/`

Widoczne dwie ściany frontowe i dach. Wysokość ściany ok. 60–80 px, kalenica ok. 50–65 px nad ścianą.

| Plik | Podstawa (komórki) | Rozmiar orientacyjny | Opis |
|---|---|---|---|
| `house_a.png` | 3×3 | 436×284 | chata, mur pruski, strzecha, komin |
| `house_b.png` | 3×2 | 434×254 | chata kryta gontem |
| `house_c.png` | 2×3 | 436×255 | chata szczytem do drogi |
| `house_burnt.png` | 3×3 | 390×263 | spalony dom: osmalone ściany, kikuty krokwi |
| `house_ruin.png` | 3×3 | 390×261 | zawalona chata: resztki ścian, gruz i belki w środku |
| `house_boarded.png` | 3×2 | 434×250 | dom zabity deskami (okna i drzwi) |
| `tavern_outside.png` | 4×3 | 562×330 | karczma „Pod Złotym Kuflem”, szyld |
| `smithy.png` | 3×2 | 420×287 | kuźnia: otwarta wiata, palenisko, kowadło |
| `mill.png` | 2×2 | 390×298 | młyn-wiatrak (śmigi mogą wystawać poza podstawę) |
| `barn.png` | 4×3 | 562×336 | stodoła z dużymi wrotami |
| `herbalist_hut.png` | 2×2 | 308×210 | chata zielarki: zioła pod okapem |

Szerokość obrazka może być większa niż w tabeli (okapy, śmigi) — liczy się kotwica.

## 4. Obiekty zadania i interakcji

| Plik | Folder | Rozmiar | Opis |
|---|---|---|---|
| `well.png` | level1/props | ok. 126×144 | studnia z daszkiem |
| `barricade.png` | level1/props | ok. 110×70 | **jedna z trzech części** barykady (belki, wóz) — bez ognia |
| `barricade_burnt.png` | level1/props | ok. 102×30 | ta sama część po ugaszeniu: zwęglone resztki, przez które da się przejść |
| `fire_0.png` … `fire_3.png` | common/fx | 96×112 | 4 klatki płomienia nakładane na barykadę (8 klatek/s), podstawa ognia przy dolnej krawędzi |
| `shrine_ulric.png`, `shrine_ulric_used.png` | level1/props | ok. 82×124 | posąg wilka na cokole; wersja `_used` = zgaszona, szara |
| `shrine_rhya.png`, `shrine_rhya_used.png` | level1/props | ok. 86×124 | kobieta z sierpem na cokole; `_used` = szara |
| `chest_closed.png`, `chest_open.png` | common/props | 52×40, 58×63 | skrzynia zamknięta / otwarta |
| `bucket_empty.png`, `bucket_full.png` | common/props | 40×40 | wiadro puste / z wodą |
| `skaven_tunnel.png` | level1/props | 120×64 | nora skavenów widziana z góry: kopiec ziemi, czarna jama. **Kotwica: środek obrazka = środek komórki** (leży płasko) |
| `lantern_post.png` | level1/props | ok. 54×96 | latarnia na słupie; sama latarnia ok. 60–80 px nad ziemią |
| `palisade_x.png` | level1/props | ok. 82×110 | odcinek palisady długości jednej komórki, biegnący „\” (z lewej-góry w prawo-dół); musi się łączyć z sąsiednim |
| `exit_banner.png` | level1/props | ok. 106×104 | chorągiew przy bramie |

## 5. Roślinność i przeszkody (podstawa 1×1, blokują ruch)

| Plik | Rozmiar | Opis |
|---|---|---|
| `tree_0.png`, `tree_1.png`, `tree_2.png` | 110–160 × 124–148 | drzewa liściaste, ciemna korona |
| `tree_dead.png`, `tree_dead_1.png` | ok. 90×98, 132×139 | martwe, powykręcane drzewa |
| `bush_0.png`, `bush_1.png` | ok. 85×50 | krzaki |
| `thorns_0.png`, `thorns_1.png` | ok. 62–86 × 50 | cierniste zarośla |
| `rock_0.png`, `rock_1.png` | ok. 62×36, 82×44 | głazy z mchem |
| `fence_x.png`, `fence_x_broken.png` | 76×60 | płot biegnący „\”; wersja połamana |
| `fence_y.png` | 76×60 | płot biegnący „/” |

Płoty i palisada: odcinek zaczyna się i kończy dokładnie na środkach krawędzi komórki, żeby kolejne odcinki tworzyły ciągłą linię.

## 6. Drobne rekwizyty (podstawa 1×1)

Blokujące: `barrel` 42×56, `crate` 58×51, `cart` 130×66, `cart_broken` 158×46, `haystack` 94×82, `firewood` 74×45,
`stump` (pniak z siekierą) 40×48, `grave_0`/`grave_1`/`grave_2` (krzyż i dwa nagrobki) ok. 50×35–56, `skull_pile` 44×24,
`cellar` (uchylona klapa piwnicy) 90×56, `shrine_broken` (rozbita przydrożna kapliczka) 52×58, `gibbet` (szubienica z klatką) 98×124,
`spikes` (kozły z zaostrzonych pali) 80×62, `scarecrow` 58×102.

Nieblokujące, stojące: `signpost` (drogowskaz) 78×84.

Płaskie, leżące na ziemi pod postaciami (kotwica jak wyżej: dolny środek = środek komórki):
`bones_0`, `bones_1` 60×30, `rubble_0`, `rubble_1` 70×34, `puddle` 90×44, `rat_hole` 86×24.

Warto dorysować (gra użyje, gdy dodam je do mapy — daj znać): płonące/tlące się zgliszcza, wiszące zioła, beczka z deszczówką,
koryto, taczka, drabina, kurnik, sterta gnoju, tablica z ogłoszeniem, krąg kamieni, drugi wariant domu zabitego deskami.

## 7. Karczma — `assets/levels/tavern/props/`

| Plik | Rozmiar | Opis |
|---|---|---|
| `wall_x.png`, `wall_x_window.png` | 78×170 | odcinek ściany wewnętrznej (jedna komórka) biegnący „\”, wersja z oknem |
| `wall_y.png`, `wall_y_window.png` | 78×170 | to samo, biegnący „/” |
| `bar_counter.png` | 260×130, podstawa 2×1 | lada z kuflami |
| `fireplace.png` | 158×182, podstawa 1×1 | kominek (bez poświaty) |
| `table.png`, `bench.png` | 90×57, 72×39 | stół z kuflami, ława |
| `door_closed.png`, `door_broken.png` | 58×107, 88×17 | drzwi w ścianie „\” oraz wyważone drzwi leżące na podłodze |
| `innkeeper.png` | 84×100 | karczmarz (stoi za ladą) |
| `guest_1.png` … `guest_6.png` | ok. 54×92 | goście w widoku 3/4 |
| `mug.png`, `splash.png` | 24×28, 40×16 | lecący kufel i rozbity kufel |
| `tavern_card.png` (folder wyżej) | 960×540 | plansza przed minigrą (pełny obraz, bez przezroczystości) |

## 8. Efekty — `assets/levels/common/fx/`

Pociski rysuj **skierowane w prawo** — gra obraca je w kierunku lotu.

| Plik | Rozmiar | Opis |
|---|---|---|
| `arrow.png` | 30×7 | strzała |
| `net_arrow.png` | 32×14 | strzała z siecią |
| `fireball.png` | 24×24 | ognisty pocisk (okrągły; kula ognia to ten sam plik powiększony 1,8×) |
| `fire_lance.png` | 44×14 | przebijający płomień |
| `stone.png` | 12×12 | kamień procarza |
| `warp_orb.png` | 20×20 | kula spaczenia |
| `poison_pool_0.png`, `poison_pool_1.png` | 112×56 | trująca kałuża, 2 klatki |
| `magic_bolt.png` | 20×20 | zapasowy pocisk magiczny |

## 9. Interfejs

| Plik | Rozmiar | Opis |
|---|---|---|
| `assets/ui/skills/<postać>/<id>.png` | 48×48 | ikony 9 umiejętności (nazwy plików w `docs/ASSETY.md`); pełny kwadrat, bez przezroczystości |
| `assets/ui/items/<ikona>.png` | 32×32 | 26 ikon przedmiotów (lista: pole `ikona` w `data/items.json`), przezroczyste tło |
| `assets/characters/<postać>/portrait.png` | wysokość ok. 300 px | portret na ekranie wyboru (Ivo: `assets/ui/ivo_portrait.png`) |
| `assets/characters/borubar/portrait.png` | ok. 254×144 | twarz Borubara do okna rozmowy |

## 10. Kolejność — co da największą różnicę

1. Kafle podłoża (10 plików) — widać je na całym ekranie.
2. Domy `house_a/b/c`, `house_ruin`, `house_boarded`, `house_burnt` — dominują w kadrze.
3. Drzewa, martwe drzewa, płoty, palisada — powtarzają się setki razy.
4. Barykada z ogniem, studnia, kapliczki, tunel, latarnia — obiekty, na które gracz patrzy najdłużej.
5. Kuźnia, młyn, stodoła, karczma, chata zielarki.
6. Drobne rekwizyty, efekty, ikony.

## 11. Jak sprawdzić po podmianie

1. Wrzuć plik pod właściwą nazwą, otwórz projekt w Godocie (sam zaimportuje) i uruchom grę (F5).
2. `F3` pokazuje hitboxy: sprawdź, czy rysunek stoi na swojej komórce (kotwica), a postać chowa się za nim / przed nim poprawnie.
3. Jeśli obiekt „pływa” albo jest przesunięty — popraw kotwicę (dolny środek obrazka), nie kod.
4. Nie uruchamiaj potem `tools/gen_props.py` ani `tools/gen_tiles.py` — generatory nadpisują pliki o tych samych nazwach.
