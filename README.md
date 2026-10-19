# Ivo Eggert: Obrona Hufduhofu

2D side-scrolling arcade beat 'em up (Warhammer Fantasy, grimdark) na Androida. Godot 4.3 + GDScript.
Jeden poziom: 4 etapy, 10 fal, boss w 3 fazach. Oprawa: pixel-art w **jednej palecie 256 kolorów**.

## Uruchomienie na komputerze
1. Godot 4.3 (standard, nie .NET): https://godotengine.org/download
2. Otwórz `project.godot`, naciśnij **F5** (pierwsze otwarcie sam importuje zasoby).

Sterowanie PC: `WASD`/strzałki - ruch (także w głąb sceny), `J` - cięcie, `K` - mocny atak, `L`/`Spacja` - unik, `Esc` - pauza, **`F3` - diagnostyka kolizji**.
Combo: cięcie → cięcie → szeroki zamach obszarowy. Telefon: joystick po lewej, przyciski po prawej.

## Testy
```
godot --headless --path . --import                       # raz (cache klas i zasobów)
godot --headless --path . res://tests/test_runner.tscn   # kod wyjścia 0 = OK
```
Testy obejmują m.in.: geometrię i okna czasowe trafień, **12 scenariuszy kolizji miecza**, wspomaganie kierunku, nietykalność, AI wrogów,
poise, fazy bossa, fale, zapis, sterowanie dotykowe (w tym multi-touch), paletę i sprite'y Ivo (rozmiar, pivot, kolory, alfa),
wybór kierunku 8-stronnego oraz pełne przejście poziomu przez bota.
Zrzuty ekranu z prawdziwym renderowaniem (np. `xvfb-run`): `res://tests/shots.tscn`, `res://tests/shots2.tscn` → `/home/claude/shots`.

## Ekrany fabularne
Między etapami gra pokazuje ekrany z ilustracją i tekstem (las, czempion; prolog opisany niżej). Treść, tytuły i miejsce wyświetlenia
(`before_stage` = numer etapu od 0) są w `data/story.json`; ilustracje w `assets/ui/story/` (generator: `tools/build_story_art.py`,
każdą można podmienić własną 1280x720). Sterowanie: dotyk/klik/Enter/Spacja = dalej (pierwsze dotknięcie dopisuje stronę do końca),
„Pomiń” albo Esc kończy cały ekran. Po „Kontynuuj” z checkpointu ekrany etapów za graczem się nie powtarzają.
Kod: `scripts/ui/story_screen.gd`, wyzwalanie w `scripts/level/level.gd` (`update_stage_banner`). Testy i zrzuty ekranu wyłączają fabułę
przez `GameState.story_enabled = false`.

## Prolog (Etap 0): karczma
„Nowa gra” zaczyna się prologiem: ekran fabularny `karczma` -> minigra -> ekran `szczury` -> etap 1. W karczmie gracz steruje pijakiem
Borubarem, który łapie kufle zrzucane z balkonu przez karczmarza (A/D, strzałki, joystick albo przeciągnięcie palcem). Złoty kufel
Bugmana liczy się za 3, rozbity kufel pod nogami ogłusza Borubara na chwilę (nie ma „game over”), tempo rośnie z postępem. Po 50 kuflach
drzwi wylatują z zawiasów, wskakują szczuroludzie, a Ivo - jeden z gości pod ścianą - rusza do walki. „Pomiń prolog” (albo Esc) przeskakuje
od razu do etapu 1; „Kontynuuj” i ponowna próba po porażce w ogóle pomijają prolog.
- Kod: `scripts/minigame/tavern_game.gd` (logika `step()` oddzielona od wyglądu, parametry w stałych na górze pliku, np. `GOAL`),
  przełączanie w `scripts/main.gd` (`start_game`, `show_prologue`, `show_tavern`).
- Teksty: wpisy z `"phase": "pre"` / `"post"` w `data/story.json`.
- Grafiki: `assets/minigame/*.png`, generator `tools/build_tavern_art.py` (w razie potrzeby podmień pliki własnymi o tych samych nazwach).
- Zrzuty: `tests/shots_tavern.tscn` (wymaga xvfb), testy: `t_tavern` w `tests/test_runner.gd`.

## Muzyka
Trzy zapętlone motywy w stylu automatów z lat 90. (FM jak w YM2151, kwadraty, szum, uderzenia orkiestry), zbudowane na **melodii
piosenki „Oath of the Carroburg Guard” (Przysięga Szkarłatnej Gwardii)**. Z piosenki wzięte są tylko: tonacja c-moll, tempo 136 BPM,
progresja c-As-Es-B i linia wokalu (refren „I am the fire that drives out evil…” i zwrotka). Brzmienie jest w całości syntezowane.

| Utwór | Plik | Kiedy gra |
|---|---|---|
| Motyw menu | `assets/audio/music/menu_theme.ogg` (49 s) | menu główne, ustawienia, informacje |
| Motyw rozgrywki | `assets/audio/music/stage_theme.ogg` (78 s) | etapy 1-4 |
| Motyw bossa | `assets/audio/music/boss_theme.ogg` (50 s, 152 BPM) | od pojawienia się Czempiona Chaosu |

**Prolog (Etap 0, karczma) gra bez muzyki** – motyw wchodzi dopiero w etapie 1. Po pokonaniu bossa muzyka cichnie.
- Pliki i głośność (`volume_db`) każdego utworu: `data/music.json`. Podmiana: wrzuć własny OGG/WAV/MP3 i wpisz ścieżkę w `file`.
- Generator: `python3 tools/build_music.py` (syntezator: `tools/chipsynth.py`, melodia zapisana w nutach na górze pliku).
- Kod: `Sfx.play_track("menu"|"stage"|"boss")` w `scripts/autoload/sfx.gd`; test: `t_music`.

## Kolizje miecza i diagnostyka
Cała geometria walki jest w `scripts/combat/hit_shape.gd` (jedno źródło prawdy), liczona na płaszczyźnie podłoża względem **punktu stóp**,
niezależnie od rozmiaru sprite'a i kamery:
- **hitbox ataku**: prostokąt od `hit_start` (przed ciałem) do `reach`, opcjonalnie `back` (ataki obszarowe), pasmo głębi `±depth`;
- **hurtbox celu**: `±body_half` w poziomie, `±foot_half_depth` w głębi;
- hitbox istnieje wyłącznie w fazie ACTIVE ataku, trafia raz na cel na atak; wizualna smuga cięcia (`swing_fx.gd`) jest rysowana z tych samych liczb.
- **wspomaganie kierunku** (`player.facing_assist` w balance.json): bez wciśniętego kierunku Ivo obraca się ku najbliższemu celowi w zasięgu.

**Tryb diagnostyczny** (tylko build debug): `F3` albo Ustawienia → „Diagnostyka kolizji”. Rysuje hitbox (czerwony = aktywny, żółty obrys = zamach),
hurtboxy stóp (zielone), pivot, kierunek ataku, stan hitboxa oraz wynik testu dla każdego celu (`HIT`, `REACH`, `DEPTH`, `DUP`, `INVULN`). Domyślnie wyłączony.

## Grafika
**Pipeline (nie modyfikuje oryginałów):**
```
python3 tools/make_palette.py    # paleta 256 kolorów + tablica LUT + scripts/art/pal.gd
python3 tools/prepare_ivo.py     # assets/characters/ivo/source (oryginały) -> assets/characters/ivo/poses (kopie do gry + manifest.json)
```
- **Paleta**: `assets/palette/` (rampy zaprojektowane ręcznie + kolory wyłuskane z Twoich sprite'ów Ivo). Kod rysujący używa `Pal.r("ramp", i)`.
- **Renderowanie**: świat idzie do SubViewport w rozdzielczości `render_scale` × ekran (0.75 → 960×540) i jest skalowany filtrem *nearest* (ostre piksele).
  HUD/menu zostają w głównym viewport. Na końcu `PaletteFilter` (shader + LUT 32³) sprowadza **cały obraz** do palety. Wyłączenie: argument `-- --no-palette`.
  Weryfikacja: w 19 wyrenderowanych kadrach max 207 unikalnych kolorów, 0 spoza palety.
- **Ivo**: 8 póz kierunkowych (zapas, gdy brak animacji z folderu) (E, SE, S, SW, W, NW, N, NE), wspólny pivot na stopach. Kierunek wynika z ruchu (także w głąb sceny); podczas ataku to profil E/W.
- **Tło**: `level_background.gd`: dithering Bayera, 2 warstwy paralaksy, rekwizyty zależne od etapu. Wszystko jest wyłącznie dekoracją (nic nie blokuje ruchu, nic nie zasłania postaci).
- **Potwory**: `monster_art.gd` (tymczasowa, proceduralna grafika w stylu sprite'owym).

**Podmiana grafiki bez zmian w kodzie:** foldery `assets/characters/<postać>/` (animacje) i `assets/stages/<etap>/` (warstwy tła, rekwizyty) -
patrz **`assets/README.md`** i instrukcje w każdym folderze. Brakujący plik = grafika tymczasowa, więc podmieniasz po jednym PNG.
Walidacja: `python3 tools/check_assets.py`. Dźwięki: `assets/audio/sfx/<nazwa>.ogg|wav|mp3`, muzyka: `assets/audio/music/battle.ogg`.

## Brakuje (uczciwie)
- Ivo ma **tylko 8 statycznych póz** (turnaround). Brak klatek: chód/bieg, lekki/ciężki atak, zamach obszarowy, obrażenia, unik, śmierć, zwycięstwo.
  Tymczasowo: wahnięcie kroku, wypad/odskok sprite'a, smuga cięcia, obrót o 90° przy śmierci. Nie jest to pełna animacja.
- W 5 z 8 dostarczonych PNG czubek miecza jest **ucięty krawędzią płótna** (east, north-east, north, north-west: lewa krawędź; west: górna). Nie da się go odtworzyć.
- Potwory i tło są proceduralne, nie klatkowe (brak klatek chodu/ataku jako sprite'ów).
- Eksport Android wymaga lokalnego SDK (poniżej); nie był tu budowany.

## Budowanie wersji Android (APK)
1. JDK 17 i Android SDK (platform-tools, build-tools 34, platform android-34, cmdline-tools).
2. Godot: **Editor → Manage Export Templates → Download** (4.3).
3. **Editor Settings → Export → Android**: ścieżki SDK/JDK i debug keystore.
4. **Project → Export → Android** (preset w `export_presets.cfg`) → **Export Project** lub „Run on device”. Do Google Play potrzebny keystore release i AAB.
Uwaga: tryb diagnostyczny jest dostępny tylko w buildach debug; shader palety używa tekstury ekranu (`hint_screen_texture`), zweryfikowanej tutaj na Mesa/OpenGL, nie na fizycznym GPU telefonu.

## Struktura
| Katalog | Zawartość |
|---|---|
| `data/` | `balance.json` (cały balans, `render_scale`), `level_1.json` (etapy, fale, beczki) |
| `scripts/autoload/` | `Balance`, `GameState`, `SaveData`, `Sfx`, `Controls` |
| `scripts/combat/` | `HitShape` (geometria trafień) |
| `scripts/actors/` | `Actor`, `Player`, `Enemy`, `Boss`, `IvoView`, `SwingFx`, `ActorVisual`, `MonsterArt`, `Barrel`, `Pickup` |
| `scripts/level/` | `Level`, `LevelBackground` |
| `scripts/fx/` | `FxLayer`, `DebugOverlay`, `PaletteFilter` |
| `scripts/art/` | `pal.gd` (generowane rampy), `character_sheet.gd`, `sheet_view.gd`, `stage_art.gd` (ładowanie folderów grafik) |
| `assets/` | `characters/<id>` (animacje; Ivo: `source` oryginały, `poses` kopie do gry), `stages/<etap>`, `palette`, `shaders`, `audio` |
| `tools/` | `make_palette.py`, `prepare_ivo.py`, `make_asset_folders.py`, `check_assets.py`, `quantize_png.py`, `asset_spec.py` |
| `tests/` | testy, bot, zrzuty |
