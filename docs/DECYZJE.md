# Decyzje i założenia (do poprawienia przez autora)

Ten plik zbiera rzeczy, które ustaliłem sam, bo nie było ich w opisie albo opisy się różniły.
Wszystko, co dotyczy liczb, zmienisz w plikach `data/*.json` — bez dotykania kodu.

## 1. Postacie (poprawione wg uwag autora)

| Postać | Klasa | Walka |
|---|---|---|
| **Ivo Eggert** | Wojownik, Szkarłatna Gwardia z Carroburga | Dwuręczny miecz, szerokie cięcia (do 3 wrogów). Bez magii. Umiejętność *Cios Gwardzisty*: zamach dookoła, bez many, odnowienie 7 s. |
| **Ursa** | **Czarodziejka ognia** (Mag 2) | Z dystansu **ognisty pocisk** (2 many), z bliska **cios kosturem** (bez many). Czar *Kula ognia*: wybuch w promieniu, podpala (12 many). Dużo many (67), mniej zdrowia (60). |
| **Modraszka** | **Łuczniczka**, czarne włosy (Mag 0, bez many) | Z dystansu **strzały z łuku** (rzut na US, obrażenia łuku + S − Wt), z bliska **krótki nóż**. Umiejętność *Grad strzał*: 5 strzał w wachlarzu, odnowienie 6 s. |

Atak „mieszany” (Ursa, Modraszka): jeśli wróg stoi tuż obok — cios wręcz, w przeciwnym razie pocisk. Gdy Ursie zabraknie many,
z dystansu nie strzela (z bliska nadal bije kosturem).

**Grafika:** Ursa ma na Twoim obrazie miecz (`source/ursa_source.webp`) — w grze używam tych póz bez zmian, więc na sprite'ach
wciąż widać miecz. Dorysuj wersję z kosturem i podmień `assets/characters/ursa/idle/<kierunek>/0.png` (oraz `portrait.png`).
Modraszka ma nową grafikę tymczasową: czarne włosy, skórzana kurta, zielony płaszcz, łuk, nóż u pasa.

**Prędkość:** bohaterowie mają Sz 5 (Modraszka 6), skaveny Sz 4 — każdy bohater jest szybszy od każdego szczura
(130–148 px/s wobec 112 px/s; test `test_heroes_faster_than_all_rats`).

## 2. Profile startowe (styl Warhammera)

Cechy główne 0–100 (człowiek ~25–45), drugorzędne 0–10. `S` = K/10, `Wt` = Odp/10 (liczone, nie wpisywane).

| | WW | US | K | Odp | Zr | Int | SW | Ogd | A | Żyw | S | Wt | Sz | Mag | PO | PP |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Ivo | 41 | 30 | 38 | 36 | 31 | 28 | 32 | 29 | 6 | 9 | 3 | 3 | 5 | 0 | 0 | 2 |
| Ursa | 28 | 34 | 28 | 30 | 33 | 47 | 42 | 30 | 6 | 6 | 2 | 3 | 5 | 2 | 0 | 2 |
| Modraszka | 31 | 46 | 29 | 30 | 43 | 30 | 31 | 36 | 7 | 7 | 2 | 3 | 6 | 0 | 0 | 3 |
| Skaven z dzidą | 30 | 20 | 30 | 30 | 34 | 20 | 18 | 10 | 5 | 2 | 3 | 3 | 4 | 0 | 0 | 0 |
| Skaven procarz | 24 | 34 | 24 | 26 | 38 | 22 | 18 | 10 | 4 | 2 | 2 | 2 | 4 | 0 | 0 | 0 |
| Czarownik skaveński | 22 | 30 | 22 | 28 | 30 | 40 | 35 | 15 | 3 | 3 | 2 | 2 | 4 | 1 | 0 | 0 |

Pliki: `data/heroes.json` (bohaterowie), `data/enemies.json` (wrogowie).

## 3. Przełożenie cech na grę akcji (dokładne wzory: `scripts/core/rules.gd`)

- **WW** — szansa trafienia wręcz = **40 + WW − (WW celu / 4) − obrona pancerza celu**, w granicach 10–95%.
  Zmieniłem „WW% minus obrona” na wersję z premią bazową +40, bo przy WW 40 bohater trafiałby za rzadko
  (ok. 30%), a w grze akcji ciągłe pudła frustrują. Ivo przeciw skavenowi z dzidą: **72%**.
  Liczby `bazowe` i `obrona_dzielnik_ww` są w `data/balance.json` → `trafienie_wrecz`.
- **US** — szansa trafienia pociskiem = 40 + US − Zr celu / 4 (10–95%). Rzut następuje, gdy pocisk dotknie celu;
  przy pudle pocisk leci dalej. Pocisk zawsze jest widoczny i można z niego zejść.
- **Zr** — szansa uniku = Zr / 5 (maks. 30%) oraz skrócenie odstępu między atakami o Zr × 0,25% (maks. 25%).
- **A** — liczba ataków na 10 sekund: odstęp = 10 / A sekund. W profilu WFRP A to zwykle 1–3, ale tu skala jest
  inna (A 6 = atak co ok. 1,5 s). Każdy atak ma **zamach (42% czasu)** → uderzenie → powrót.
- **Żyw** — życie = Żyw × 10 (mnożnik `zycie_mnoznik`).
- **Obrażenia** = obrażenia broni + S − Wt celu (min. 1). Czary: bazowe + siła czarów (Int/10 + Mag×3) − Wt/2.
- **Int** — mana = Int + Mag × 10 (tylko gdy Mag > 0). **SW** — regeneracja many = SW × 0,02/s i odporność na truciznę = SW/2 % (maks. 75%).
- **Ogd** — kupno: cena × (1,5 − Ogd × 0,01, min. 0,8); sprzedaż: cena × (0,15 + Ogd × 0,005, maks. 0,6).
- **Sz** — prędkość = 40 + Sz × 18 px/s (odległość na podłodze; ruch w pionie ekranu jest o połowę wolniejszy — tak działa rzut izometryczny).
- **Mag** — 0 = brak czarów i many. **PO** — tylko wyświetlane. **PP** — przy śmierci −1 PP i odrodzenie z połową życia; bez PP: ekran śmierci i wczytanie ostatniego zapisu.

## 4. Rozwój

- Punkty rozwoju za progi doświadczenia: `rozwoj.progi_xp` = 60, 150, 260, 390, **540**, 720…
- W karczmie i Poziomie 1 do zdobycia jest ok. **604 XP → 5 punktów** (test `test_level1_gives_about_5_points` liczy to z plików danych).
- Punkt = +5 do cechy głównej (limit 70) albo +1 do drugorzędnej. Rozwijać można A, Żyw, Sz, Mag i PP (limity w `limity_drugorzedne`).
  S i Wt rosną same z K i Odp. **Do decyzji:** czy PP ma być do kupienia za punkt (teraz: tak, limit 5).

## 5. Tempo i walka (dlaczego tak)

- Zabicie jednego skavena z dzidą zajmuje Ivo ok. **4 s** (test mierzy). Ataki mają widoczny zamach (odchylenie postaci, potem łuk cięcia).
- Każdy wróg **zapowiada atak**: dzida — czerwony pas na ziemi, procarz — żółta linia celowania, czarownik — zielone koło
  (tam spadnie kula spaczenia i zostanie trująca kałuża). Zapowiedź wypełnia się do momentu uderzenia — można odejść.
- Mocne trafienie (≥12% życia) przerywa zamach przeciwnika (zachwianie).
- Karczma uczy tego samego języka: cienie kufli to te same koła, które później zapowiadają ataki.

## 6. Decyzje techniczne (krótko)

- **Godot 4.3, GDScript, renderer Compatibility** — działa na starszych telefonach z Androidem.
- **Wszystko budowane w kodzie z plików JSON** (mapa poziomu jako tekst znaków w `data/levels/*.json`) — łatwo zmieniać bez edytora scen.
- **Rzut izometryczny**: `TileMapLayer` (romb 128×64, DIAMOND_DOWN), Y-sort dla postaci i rekwizytów.
- **Nawigacja**: `NavigationRegion2D` wypiekany przy wczytaniu poziomu z mapy przeszkód, wrogowie używają `NavigationAgent2D`.
- **Hitboxy** to promienie na podłodze (elipsy 2:1), niezależne od rozmiaru grafiki. Diagnostyka: `F3` (tylko build debug, domyślnie wyłączona).
- **Paleta 256 kolorów**: grafika tymczasowa jest generowana od razu w palecie, a filtr końcowy (shader + LUT) sprowadza cały obraz do palety.
  Paleta = rampy z poprzedniej wersji + niebieska (magia) + zielona (spaczenie) + 92 kolory wyłuskane z Twoich obrazów.
- **Grafika postaci**: Ivo i Ursa mają tylko pozy w 8 kierunkach (bez klatek ruchu). Ruch i ataki są „ożywione” w kodzie
  (kołysanie, wypad, łuk cięcia). Gdy dorysujesz klatki `walk/` i `attack/`, gra użyje ich automatycznie.
- **Zapis**: jeden slot w `user://zapis.json` (postać, cechy, ekwipunek, zadanie, otwarte skrzynie, użyte kapliczki, zabici wrogowie, odkryta mapa).
  Autozapis: wejście do wioski, rozmowa z Borubarem, wiadra, studnia, każda ugaszona część barykady, Poziom 2. W karczmie się nie zapisuje.
- **Menu**: wygląd i klimat bez zmian (portret Ivo, herb Carroburga, czerwono-złote przyciski, autorzy). Zmieniłem tylko napis:
  „HUFDUHOF / Szczury w wiosce” zamiast „IVO EGGERT / Obrona Hufduhofu”, bo teraz są trzy postacie. Zmiana w `scripts/main.gd`.
- **Muzyka**: trzy utwory z poprzedniej wersji (menu, wioska, walka w karczmie) — `data/music.json`.
- **Minigra (prolog)**: gramy **Borubarem**, który łapie kufle do beczki nad głową (cień na podłodze = miejsce upadku kufla).
  Wybrany bohater siedzi wśród gości. Gdy skaveny wyważają drzwi, Borubar w panice wybiega z karczmy, a sterowanie przejmuje bohater
  (dwie fale skavenów jako samouczek walki). W wiosce Borubar czeka **przed karczmą**. Minigrę można pominąć przyciskiem „Pomiń minigrę”.
- **Okna (dialog, pauza, postać, plecak)**: Esc zamyka okno (w rozmowie = „Do widzenia”), E / Enter / Spacja naciska podświetlony
  przycisk (np. „Dalej”). Działa też myszą i dotykiem.

## 7. Znane ograniczenia (uczciwie)

- Grafika wrogów, rekwizytów, kafli i Modraszki to **placeholdery** generowane skryptami `tools/gen_*.py`.
- Łupy leżące na ziemi nie są zapisywane (po wczytaniu znikają; skrzynie i wrogowie pamiętają stan).
- APK nie był budowany w tym środowisku (brak Android SDK) — instrukcja i automat w GitHub Actions: `docs/BUDOWANIE_APK.md`.
