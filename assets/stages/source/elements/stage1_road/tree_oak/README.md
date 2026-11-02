# tree_oak

Drzewo liściaste

- Docelowy rozmiar w grze: **100x150 px** (1 piksel = 4/3 jednostki świata).
- Pivot: środek dolnej krawędzi PNG (punkt styku z podłożem).
- Element **podłączony do gry** – gra wczyta gotowy plik z folderu `props/` automatycznie.

Tu wrzucasz **surowe** pliki (wycięcie z panoramy, obraz w wyższej rozdzielczości, warstwy robocze).
Gotowy plik w rozmiarze docelowym trafia do `assets/stages/stage1_road/props/` (nazwa `tree_oak.png`, kolejne warianty `tree_oak_2.png` ... `tree_oak_6.png`).

## Źródło obecnych grafik (6 wariantów)
`tree_oak.png` … `tree_oak_6.png` powstają z obrazu autora `stage1_road/tree_oak/oak_reference_autor.png`
(wycięcie z czarnego tła, paleta 256, ciemny kontur): `python3 tools/build_oak_from_source.py`.
Dęby: oryginał, krępy (symetryczna korona), wysoki pień, młody pochylony, stary rozłożysty z żółknącymi liśćmi, niski ciemny.
`tools/build_props.py` ich nie nadpisuje (chyba że z flagą `--generated-oak`). Pliki `*_source.png` = 4x powiększone podglądy.
