# Portrety mówiących postaci na planszach fabularnych

Plansze po etapie wsi (Borubar przy studni) i po etapie lasu (Czempion Chaosu) mają czarne okno nad tekstem.
Wrzuć tu grafikę, a gra sama ją pokaże (skalowanie z zachowaniem proporcji, piksele ostre):

| plik | postać | plansza |
|---|---|---|
| `borubar.png` | Borubar, mówiący | po etapie 2 (wieś), `data/story.json` -> `las` |
| `czempion.png` | Czempion Chaosu, mówiący | po etapie 3 (las), `data/story.json` -> `czempion` |

Okno ma 508x288 px wnętrza (proporcje ok. 16:9). Imię mówiącego jest wypisane na dole okna.
Brak pliku = puste czarne okno. Ścieżkę zmienisz w `data/story.json` (pole `portrait`).

`borubar.png` (254x144, w oknie 2x) jest generowany z obrazu autora: `python3 tools/build_borubar.py`.
