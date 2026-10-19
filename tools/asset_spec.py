"""Jedno źródło prawdy dla struktury folderów grafik (postacie, etapy). Używane przez
make_asset_folders.py (tworzy foldery/manifesty/instrukcje) i check_assets.py (waliduje).
Silnik czyta wyłącznie wygenerowane manifesty JSON, nie ten plik.

Nazwy animacji ataków MUSZĄ odpowiadać kluczom ataków w data/balance.json."""

WORLD_PER_TEXEL = 4.0 / 3.0     # 1 piksel obrazu wewnętrznego (960x540) = 4/3 jednostki świata (1280x720)

def A(frames, fps, loop=False, contact=None, note=""):
    d = {"frames": frames, "fps": fps, "loop": loop, "note": note}
    if contact is not None:
        d["contact"] = list(contact)
    return d

# Konwencje: grafika zwrócona w PRAWO (E); w lewo gra odbija ją lustrzanie. Pivot = punkt styku stóp z podłożem.
# "contact" [od, do] = klatki wyświetlane w oknie AKTYWNEGO hitboxa (klatki przed = zamach, po = powrót).
CONTACT_NOTE = "klatka kontaktu = miecz/broń na maksymalnym wyciągnięciu; musi sięgać zasięgu z balance.json"

CHARACTERS = {
    "ivo": {
        "name": "Ivo Eggert (gwardzista Szkarłatnej Gwardii, miecz dwuręczny)",
        "frame": [320, 192], "pivot": [160, 190],
        "anims": {
            "idle": A(4, 6, True, note="oddychanie, postawa bojowa"),
            "run": A(6, 12, True, note="bieg w profilu; ruch w głąb sceny używa póz 8-kierunkowych (poses/)"),
            "light1": A(5, 0, contact=(2, 2), note="lekki atak 1; " + CONTACT_NOTE + " (zasięg 140 px świata ~ 105 px sprite'a)"),
            "light2": A(5, 0, contact=(2, 2), note="lekki atak 2 (z drugiej strony)"),
            "sweep": A(8, 0, contact=(3, 4), note="szeroki zamach obszarowy (obrót), zasięg 165 px świata w obie strony"),
            "heavy": A(10, 0, contact=(5, 5), note="mocny atak znad głowy, zasięg 180 px świata"),
            "hurt": A(2, 10, note="odchylenie do tyłu (0,35 s)"),
            "dodge": A(4, 14, note="unik / przewrót (0,3 s)"),
            "die": A(6, 8, note="śmierć; ostatnia klatka zostaje na ziemi"),
            "victory": A(4, 6, True, note="miecz w górę po pokonaniu bossa"),
        },
    },
    "skaven": {
        "name": "Skaven", "frame": [160, 112], "pivot": [80, 110],
        "anims": {
            "idle": A(4, 6, True), "run": A(6, 14, True),
            "claw": A(5, 0, contact=(2, 2), note="szybki cios; zasięg 72 px świata"),
            "hurt": A(2, 10), "die": A(5, 10),
        },
    },
    "chaos_hound": {
        "name": "Pies Chaosu", "frame": [176, 96], "pivot": [88, 94],
        "anims": {
            "idle": A(4, 6, True), "run": A(6, 16, True),
            "bite": A(4, 0, contact=(1, 1), note="ugryzienie z bliska"),
            "charge": A(6, 0, contact=(2, 4), note="szarża: zamach (przycupnięcie) -> pęd (klatki 2-4 w pętli) -> hamowanie"),
            "hurt": A(2, 10), "die": A(5, 10),
        },
    },
    "beastman": {
        "name": "Zwierzoczłek", "frame": [288, 224], "pivot": [144, 222],
        "anims": {
            "idle": A(4, 5, True), "run": A(6, 9, True),
            "chop": A(6, 0, contact=(3, 3), note="cios z góry; zasięg 112 px świata"),
            "wide": A(7, 0, contact=(3, 4), note="szeroki zamach; zasięg 160 px świata"),
            "hurt": A(2, 10), "die": A(6, 8),
        },
    },
    "chaos_champion": {
        "name": "Czempion Chaosu (boss)", "frame": [448, 320], "pivot": [224, 318],
        "anims": {
            "idle": A(4, 4, True), "run": A(6, 7, True),
            "slash": A(6, 0, contact=(3, 3), note="zasięg 150 px świata"),
            "backhand": A(5, 0, contact=(2, 2), note="szybki zamach zwrotny"),
            "overhead": A(8, 0, contact=(4, 4), note="ciężki cios znad głowy, długi zamach (telegraf!)"),
            "slam": A(8, 0, contact=(4, 5), note="uderzenie w ziemię, fala obszarowa 230 px w obie strony"),
            "charge": A(6, 0, contact=(2, 4), note="szarża"),
            "hurt": A(3, 8, note="oszołomienie po złamaniu poise (okno kontrataku, 1,5 s)"),
            "roar": A(6, 8, note="ryk przy zmianie fazy (1,2 s)"),
            "die": A(8, 8),
        },
    },
}

# Warstwy tła: (plik, równoległość, opis, zalecany rozmiar px)
LAYERS = {
    "sky": ("sky.png", 0.0, "niebo; powtarzane poziomo, dolna krawędź na horyzoncie", "128x320 (szeroki 64-512, wysokość 320)"),
    "far1": ("far1.png", 0.15, "daleki plan (wolny paralaks), powtarzany poziomo, dolna krawędź na horyzoncie", "640x140, szew poziomy niewidoczny"),
    "far2": ("far2.png", 0.32, "bliższy plan sylwetek (średni paralaks), powtarzany poziomo", "640x110, szew niewidoczny"),
    "ground": ("ground.png", 1.0, "podłoże w pasie walki, powtarzane poziomo, górna krawędź na horyzoncie", "128x320"),
    "foreground": ("foreground.png", 1.25, "opcjonalny pierwszy plan przy dolnej krawędzi ekranu (poza pasem walki!)", "640x60, max 67 px wysokości"),
}

# Rekwizyty: nazwa -> (opis, zalecany rozmiar px). Pivot = środek dolnej krawędzi (punkt styku z podłożem).
STAGES = {
    "stage1_road": {
        "name": "ETAP 1: DROGA DO HUFDUHOFU",
        "props": {
            "fence": ("płot (4 przęsła)", "96x40"), "fence_broken": ("zniszczony płot", "96x40"),
            "tree_oak": ("drzewo liściaste", "100x150"), "tree_dead": ("martwe drzewo", "100x150"),
            "signpost": ("drogowskaz", "60x60"), "bush": ("krzew", "50x32"),
            "milestone": ("kamień milowy", "28x32"), "stump_axe": ("pieniek z toporem", "40x45"),
        },
    },
    "stage2_village": {
        "name": "ETAP 2: WIEŚ",
        "props": {
            "house_thatch": ("chata ze strzechą", "130x150"), "house_shingle": ("chata z gontem", "130x150"),
            "house_burnt": ("spalona chata", "130x150"), "barn": ("stodoła", "150x160"),
            "fence": ("płot (5 przęseł)", "110x40"), "fence_broken": ("zniszczony płot", "110x40"),
            "gate": ("brama", "60x60"), "cart": ("wóz", "75x50"), "well": ("studnia", "45x70"),
            "crates": ("skrzynie i worek", "60x50"), "scarecrow": ("strach na wróble", "40x85"),
        },
    },
    "stage3_fields_forest": {
        "name": "ETAP 3: POLA I LAS",
        "props": {
            "tree_oak": ("drzewo liściaste", "110x150"), "tree_dead": ("martwe drzewo", "110x150"),
            "tree_pine": ("świerk", "80x170"), "bush": ("krzew", "50x32"), "stone_big": ("głaz", "45x38"),
            "fence_broken": ("zniszczony płot", "80x40"), "tent": ("namiot obozowy", "70x50"),
            "banner_torn": ("podarty sztandar", "35x72"),
        },
    },
    "stage4_lair": {
        "name": "ETAP 4: LEGOWISKO CHAOSU",
        "props": {
            "obelisk": ("obelisk z runą", "40x100"), "brazier": ("kocioł z ogniem Chaosu", "30x65"),
            "tree_twisted": ("skażone drzewo", "110x150"), "bones": ("kości i pal z czaszką", "70x70"),
            "crystals": ("kryształy Chaosu", "45x50"),
        },
    },
    "common": {
        "name": "WSPÓLNE (wszystkie etapy)",
        "props": {"barrel": ("beczka (zniszczalna)", "36x44"), "potion": ("mikstura lecząca", "22x28")},
        "no_layers": True,
    },
}
