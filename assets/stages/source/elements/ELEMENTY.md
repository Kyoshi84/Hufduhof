# Ruchome elementy świata (rekwizyty)

Elementy, które przesuwają się razem ze sceną podczas przechodzenia etapów (rysowane za postaciami, nie blokują ruchu),
oraz obiekty, z którymi gracz wchodzi w interakcję (beczka, mikstura). Każdy ma własny folder na surowe grafiki:
`assets/stages/source/elements/<etap>/<element>/`. Elementy „zapas” leżą w podfolderach `_dodatkowe/`.

| etap | element | opis | rozmiar px | podłączony do gry |
|---|---|---|---|---|
| stage1_road | `fence` | płot (4 przęsła) | 96x40 | tak |
| stage1_road | `fence_broken` | zniszczony płot | 96x40 | tak |
| stage1_road | `tree_oak` | drzewo liściaste | 100x150 | tak |
| stage1_road | `tree_dead` | martwe drzewo | 100x150 | tak |
| stage1_road | `signpost` | drogowskaz | 60x60 | tak |
| stage1_road | `bush` | krzew | 50x32 | tak |
| stage1_road | `milestone` | kamień milowy | 28x32 | tak |
| stage1_road | `stump_axe` | pieniek z toporem | 40x45 | tak |
| stage2_village | `house_thatch` | chata ze strzechą | 130x150 | tak |
| stage2_village | `house_shingle` | chata z gontem | 130x150 | tak |
| stage2_village | `house_burnt` | spalona chata | 130x150 | tak |
| stage2_village | `barn` | stodoła | 150x160 | tak |
| stage2_village | `fence` | płot (5 przęseł) | 110x40 | tak |
| stage2_village | `fence_broken` | zniszczony płot | 110x40 | tak |
| stage2_village | `gate` | brama | 60x60 | tak |
| stage2_village | `cart` | wóz | 75x50 | tak |
| stage2_village | `well` | studnia | 45x70 | tak |
| stage2_village | `crates` | skrzynie i worek | 60x50 | tak |
| stage2_village | `scarecrow` | strach na wróble | 40x85 | tak |
| stage3_fields_forest | `tree_oak` | drzewo liściaste | 110x150 | tak |
| stage3_fields_forest | `tree_dead` | martwe drzewo | 110x150 | tak |
| stage3_fields_forest | `tree_pine` | świerk | 80x170 | tak |
| stage3_fields_forest | `bush` | krzew | 50x32 | tak |
| stage3_fields_forest | `stone_big` | głaz | 45x38 | tak |
| stage3_fields_forest | `fence_broken` | zniszczony płot | 80x40 | tak |
| stage3_fields_forest | `tent` | namiot obozowy | 70x50 | tak |
| stage3_fields_forest | `banner_torn` | podarty sztandar | 35x72 | tak |
| stage4_lair | `obelisk` | obelisk z runą | 40x100 | tak |
| stage4_lair | `brazier` | kocioł z ogniem Chaosu | 30x65 | tak |
| stage4_lair | `tree_twisted` | skażone drzewo | 110x150 | tak |
| stage4_lair | `bones` | kości i pal z czaszką | 70x70 | tak |
| stage4_lair | `crystals` | kryształy Chaosu | 45x50 | tak |
| common | `barrel` | beczka (zniszczalna) | 36x44 | tak |
| common | `potion` | mikstura lecząca | 22x28 | tak |
| stage1_road | `puddle` | kałuża z odbiciem nieba (dziś wmalowana w ground.png) | 60x14 | nie (zapas) |
| stage2_village | `puddle` | kałuża z odbiciem nieba (dziś wmalowana w ground.png) | 60x14 | nie (zapas) |
| stage3_fields_forest | `puddle` | kałuża z odbiciem nieba (dziś wmalowana w ground.png) | 60x14 | nie (zapas) |
| stage4_lair | `puddle` | kałuża z odbiciem nieba (dziś wmalowana w ground.png) | 60x14 | nie (zapas) |
| stage2_village | `haystack` | stóg siana | 50x60 | nie (zapas) |
| stage3_fields_forest | `haystack` | stóg siana | 50x60 | nie (zapas) |
| stage2_village | `windmill` | wiatrak | 90x140 | nie (zapas) |
| stage3_fields_forest | `windmill` | wiatrak | 90x140 | nie (zapas) |
| stage1_road | `church` | kościół z wieżą | 80x150 | nie (zapas) |
| stage2_village | `church` | kościół z wieżą | 80x150 | nie (zapas) |
| stage1_road | `gate_sign` | brama-szyld „Hufduhof” ze słupem i krukiem | 90x180 | nie (zapas) |
| stage3_fields_forest | `chaos_hut` | chata Chaosu z fioletowym sztandarem | 110x120 | nie (zapas) |
| stage4_lair | `chaos_hut` | chata Chaosu z fioletowym sztandarem | 110x120 | nie (zapas) |
| stage4_lair | `chaos_pole` | słup z czaszkami i czerwonym sztandarem | 70x170 | nie (zapas) |
| stage1_road | `grass_tuft` | kępa trawy / chwastów | 30x18 | nie (zapas) |
| stage2_village | `grass_tuft` | kępa trawy / chwastów | 30x18 | nie (zapas) |
| stage3_fields_forest | `grass_tuft` | kępa trawy / chwastów | 30x18 | nie (zapas) |
| stage4_lair | `grass_tuft` | kępa trawy / chwastów | 30x18 | nie (zapas) |
| stage1_road | `wagon` | wóz z drewnem (większy niż `cart`) | 110x60 | nie (zapas) |
| stage2_village | `wagon` | wóz z drewnem (większy niż `cart`) | 110x60 | nie (zapas) |

## Elementy nieruchome (tło, nie rekwizyty)
Niebo, `far1`, `far2`, podłoże i pierwszy plan to warstwy tła, a nie rekwizyty: patrz `assets/stages/source/README.md`
i `tools/build_stage_backgrounds.py`.

## Poza folderem etapów
Postacie (Ivo, wrogowie, boss) i ich animacje mają osobne foldery: `assets/characters/<postać>/`.
