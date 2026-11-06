# Jak zbudować APK (Android)

Są dwie drogi. **Droga A jest najprostsza** — nic nie instalujesz.

## Droga A: automatycznie na GitHubie
Po każdym wypchnięciu zmian na gałąź `main` GitHub sam uruchamia testy i buduje APK (plik `.github/workflows/apk.yml`).
1. Wejdź na https://github.com/Kyoshi84/Hufduhof → zakładka **Actions**.
2. Kliknij ostatnie uruchomienie **„Testy i APK”** (zielony znaczek = sukces).
3. Na dole strony, w sekcji **Artifacts**, pobierz **hufduhof-apk** (plik ZIP z `hufduhof.apk` w środku).
4. Skopiuj `hufduhof.apk` na telefon i otwórz. Telefon zapyta o zgodę na instalację z nieznanego źródła — zezwól.

Budowę można też uruchomić ręcznie: Actions → „Testy i APK” → **Run workflow**.
To jest wersja *debug* (do testów) — do sklepu Google Play potrzebna jest wersja podpisana kluczem *release* (patrz niżej).

## Droga B: na własnym komputerze
1. Zainstaluj **Godot 4.3** (wersja *Standard*, nie .NET): https://godotengine.org/download/archive/4.3-stable/
2. Zainstaluj **JDK 17** (np. Eclipse Temurin 17) i **Android Studio** (z niego bierze się Android SDK).
   W Android Studio → *SDK Manager* doinstaluj: *Android SDK Platform 34*, *Build-Tools 34*, *Platform-Tools*, *Command-line Tools*.
3. Otwórz Godot → *Import* → wskaż plik `project.godot` z tego repozytorium.
4. **Editor → Manage Export Templates → Download and Install** (szablony dla 4.3).
5. **Editor → Editor Settings → Export → Android**:
   - *Java SDK Path*: folder JDK 17,
   - *Android SDK Path*: folder SDK (Android Studio pokazuje go w *SDK Manager*),
   - *Debug Keystore*: Godot zwykle tworzy go sam; jeśli nie — w terminalu:
     ```bash
     keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999
     ```
     i wskaż ten plik (użytkownik `androiddebugkey`, hasło `android`).
6. **Project → Export…** → wybierz gotowy preset **Android** → **Export Project** → zapisz jako `hufduhof.apk`.
   (Albo podłącz telefon kablem z włączonym *debugowaniem USB* i kliknij ikonę Androida w prawym górnym rogu edytora — gra uruchomi się na telefonie.)

Z wiersza poleceń (gdy kroki 4–5 są zrobione):
```bash
godot --headless --path . --export-debug "Android" build/hufduhof.apk
```

### Wersja do Google Play (release)
Utwórz własny klucz (zachowaj go — bez niego nie wydasz aktualizacji):
```bash
keytool -genkeypair -v -keystore hufduhof-release.keystore -alias hufduhof -keyalg RSA -keysize 2048 -validity 10000
```
W *Project → Export → Android → Keystore → Release* wskaż plik, alias i hasło, potem **Export Project** z odznaczonym *Export With Debug*.
Google Play wymaga formatu AAB: zaznacz *Gradle Build → Use Gradle Build* i *Export Format: AAB* (wymaga też *Android Build Template*: Project → Install Android Build Template).
**Nie wrzucaj pliku `.keystore` do repozytorium** (jest w `.gitignore`).

## Ustawienia w presecie (`export_presets.cfg`)
- nazwa paczki `com.hufduhof.gra`, nazwa aplikacji „Hufduhof”, wersja 0.2.0 (kod 2),
- orientacja: pozioma z obracaniem (Ustawienia projektu → Display → Handheld → Orientation = Sensor Landscape),
- architektury arm64-v8a i armeabi-v7a, tryb pełnoekranowy,
- do APK nie trafiają: testy, narzędzia, dokumentacja, GUT, oryginały grafik (`source/`).
