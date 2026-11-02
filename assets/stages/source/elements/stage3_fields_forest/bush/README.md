# bush

Krzew

- Docelowy rozmiar w grze: **50x32 px** (1 piksel = 4/3 jednostki świata).
- Pivot: środek dolnej krawędzi PNG (punkt styku z podłożem).
- Element **podłączony do gry** – gra wczyta gotowy plik z folderu `props/` automatycznie.

Tu wrzucasz **surowe** pliki (wycięcie z panoramy, obraz w wyższej rozdzielczości, warstwy robocze).
Gotowy plik w rozmiarze docelowym trafia do `assets/stages/stage3_fields_forest/props/` (nazwa `bush.png`, kolejne warianty `bush_2.png` ... `bush_6.png`).

## Źródło obecnych grafik (6 wariantów)
`bush.png` … `bush_6.png` powstają z obrazu autora `stage1_road/tree_oak/oak_reference_autor.png`
(wycięcie z czarnego tła, paleta 256, ciemny kontur): `python3 tools/build_oak_from_source.py`.
Krzewy to kępy liści wycięte z korony tego samego dębu (te same piksele), zaokrąglone i przyciemnione przy ziemi.
`tools/build_props.py` ich nie nadpisuje (chyba że z flagą `--generated-oak`). Pliki `*_source.png` = 4x powiększone podglądy.
