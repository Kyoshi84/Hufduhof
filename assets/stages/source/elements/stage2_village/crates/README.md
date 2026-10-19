# crates

Skrzynie i worek

- Docelowy rozmiar w grze: **60x50 px** (1 piksel = 4/3 jednostki świata).
- Pivot: środek dolnej krawędzi PNG (punkt styku z podłożem).
- Element **podłączony do gry** – gra wczyta gotowy plik z folderu `props/` automatycznie.

Tu wrzucasz **surowe** pliki (wycięcie z panoramy, obraz w wyższej rozdzielczości, warstwy robocze).
Gotowy plik w rozmiarze docelowym trafia do `assets/stages/stage2_village/props/` (nazwa `crates.png`, kolejne warianty `crates_2.png` ... `crates_6.png`).
