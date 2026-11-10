# Decyzje i założenia (do poprawienia przez autora)

Ten plik zbiera rzeczy, które ustaliłem sam, bo nie było ich w opisie albo opisy się różniły.
Wszystko, co dotyczy liczb, zmienisz w plikach `data/*.json` — bez dotykania kodu.

## 1. Postacie i umiejętności

| Postać | Klasa |
|---|---|
| **Ivo Eggert** | Wojownik, Szkarłatna Gwardia z Carroburga, dwuręczny miecz |
| **Ursa** | Czarodziejka ognia (Mag 2): pociski ognia, z bliska kostur. Dużo many, mniej zdrowia |
| **Modraszka** | Łuczniczka (ruda, czerwono-czarna suknia, chusta) - grafika z obrazu autora: łuk, z bliska krótki nóż |

**Uwaga o propozycji z zadania „trzy umiejętności”:** w propozycji Ursa miała strzały, a Modraszka była maginią — odwrotnie niż
ustaliłeś wcześniej (Ursa = mag ognia, Modraszka = łuczniczka). Zostawiłem Twoje wcześniejsze ustalenie, zachowałem
istniejące umiejętności (Kula ognia, Grad strzał) i dopasowałem resztę propozycji do klas:

| Slot | Ivo | Ursa | Modraszka |
|---|---|---|---|
| 1 (szybka, tania) | **Potężne cięcie** - łuk 130° przed sobą, do 3 wrogów | **Ognisty pocisk** | **Strzała** |
| 2 | **Wirujący miecz** - obszar dookoła, droższy | **Kula ognia** - wybuch i podpalenie (było) | **Grad strzał** - 5 strzał w wachlarzu (było) |
| 3 | **Okrzyk Szkarłatnej Gwardii** - odrzut wrogów i +40% obrażeń na 6 s | **Przebijający płomień** - przelatuje przez kilku wrogów | **Strzała z siecią** - spowalnia grupę o połowę na 4 s (odpowiednik „spowolnienia grupy”) |

Każda umiejętność ma w `data/heroes.json` (pole `umiejetnosci`): obrażenia (`obrazenia_bazowe`, `skalowanie`, `mnoznik`),
`koszt_many`, `odnowienie`, `zamach`/`powrot`, `zasieg`, `predkosc`, `promien_trafienia` (hitbox pocisku), `ikona`.
Ikony to placeholdery w `assets/ui/skills/<postać>/<id>.png` (48×48) — podmień pliki o tych samych nazwach.
Kolejność na pasku: `pasek` (10 pozycji; `""` = pusty slot).

**Mana dla wszystkich:** umiejętności Ivo i Modraszki też kosztują manę (jak w Diablo). Mana = Int + Mag × 10 + `mana_premia`
(Ivo +22, Modraszka +20). Mag nadal oznacza magię: wzmacnia czary Ursy. Bez many atak główny przechodzi na zwykły atak bronią.

**Grafika:** Ursa ma na Twoim obrazie miecz — na sprite'ach wciąż go widać; wersję z kosturem podmienisz w
`assets/characters/ursa/idle/<kierunek>/0.png`.
Modraszka powstaje z Twojego obrazu (`assets/characters/modraszka/source/modraszka_source.webp`, `tools/build_modraszka.py`):
rysunek jest jeden, więc kierunki „w prawo” to odbicie lustrzane, a klatki chodu, ataku, trafienia i śmierci to przekształcenia
tego rysunku (kołysanie, pochylenie, obrót) - nie osobno narysowane klatki. Własne klatki podmienisz pod tymi samymi nazwami.

**Prędkość:** bohaterowie Sz 5–6, skaveny Sz 4 — każdy bohater jest szybszy od każdego szczura.

## 1a. Sterowanie walką

| PC | Telefon | Działanie |
|---|---|---|
| LPM / J / Spacja (przytrzymaj) | ATAK | umiejętność ze slotu 1; bez many - zwykły atak bronią |
| PPM / K (przytrzymaj) | - | slot 2 |
| 1-9, 0 (górny rząd i numeryczna) | dotknięcie slotu | sloty paska (przytrzymanie = ciągłe używanie) |
| Q / R | sloty 4 / 5 | mikstura zdrowia / many |

Celowanie: mysz (klik w korpus wroga = cel w jego stopy; klik w ziemię - z korektą wysokości lotu), joystick (kierunek ruchu
+ pomoc w celowaniu), bez ruchu - najbliższy wróg. Kierunek liczony w chwili wystrzału, nie zaokrąglany do 8 kierunków.

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

- **Trafienie bohatera:** zetknięcie hitboxu zawsze rani. Rzut na WW/US (i unik wroga ze Zr) decyduje tylko, czy to pełne
  trafienie, czy **draśnięcie** (połowa obrażeń, szara liczba) - dzięki temu cios, który wizualnie trafił, nigdy nie daje „Pudła”.
  Wrogowie nadal mogą chybić bohatera (pełny rzut Warhammera).
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
- **Int** — mana = Int + Mag × 10 + premia postaci (mana zasila umiejętności wszystkich postaci). **SW** — regeneracja many = SW × 0,02/s i odporność na truciznę = SW/2 % (maks. 75%).
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

## 8. Aktualizacja: wioska Hufduhof (grimdark), tunele, brama

- **Brama:** palisada biegnie w poprzek całej północnej krawędzi wsi (od lasu do lasu), a jedyne przejście to brama zamknięta
  płonącą barykadą. Wcześniej barykadę dało się obejść trawą obok drogi. Dodatkowo cała mapa ma niewidzialną granicę
  (nie da się wyjść poza obszar gry), a strefa wyjścia działa dopiero po ugaszeniu trzech części barykady.
- **Tunele skavenów:** 5 nor (`"typ": "tunel"` w `data/levels/wioska.json`). Gdy bohater podejdzie (`tunele/wyzwalacz_px`),
  skaveny wychodzą pojedynczo, „wyrastając” z ziemi; nie pojawiają się w przeszkodach ani tuż przy bohaterze. Cztery dawne grupy
  stojące na drogach zamieniłem na tunele, piąta nora jest pod zawaloną chatą (+2 skaveny; XP w Poziomie 1: 624, nadal 5 punktów).
- **Otoczenie:** 13 nowych budynków (zawalone chaty, domy zabite deskami, chałupy), martwe drzewa i ciernie gęstniejące ku
  Drakwaldowi, głazy, błoto, kałuże, kości, stosy czaszek, szubienica przy bramie, kozły i sterty drewna przy zabitych deskami
  domach, rozbite wozy, wejście do piwnicy, zniszczona przydrożna kapliczka, strachy na wróble. Drogi i miejsca walk zostają wolne
  (generator `tools/build_levels.py` sprawdza kolizje i dojścia).
- **Kolory:** trawa i drzewa w matowej zieleni, ciemna strzecha, brudny tynk, plus `"odcien"` poziomu (zimne, przygaszone światło).
- **Ruch:** rozpęd i hamowanie (`ruch/rozped_sekund`, `ruch/hamowanie_sekund`, `ruch/wrog_rozped_sekund`); skos znormalizowany.
- **Trafienia:** większe hitboxy strzał i pocisków ognia (`promien_trafienia` 17-22), jedno trafienie na cel na pocisk.
