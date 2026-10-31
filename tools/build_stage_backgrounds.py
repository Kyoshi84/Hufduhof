#!/usr/bin/env python3
"""Buduje warstwy tła 4 etapów z jednej panoramy: assets/stages/source/hufduhof_panorama.png (2172x724).

  python3 tools/build_stage_backgrounds.py            # zapisuje PNG do assets/stages/<etap>/ i aktualizuje stage.json
  python3 tools/build_stage_backgrounds.py --preview DIR   # dodatkowo składa podglądy do DIR

Rozmiary zgodne z assets/stages/<etap>/README.md:
  sky 512x320 | far1 640x140 | far2 640x110 | ground 128x320 | foreground 640x60

Układ: far1 i far2 to jeden ciągły pas scenerii (250 px wysokości) rozcięty na dwie warstwy.
far1 jest przesunięty o y_offset = -110, więc leży dokładnie nad far2; obie warstwy mają tę samą paralaksę,
dzięki czemu nie "rozjeżdżają się". Dolna krawędź far2 = horyzont (tam zaczyna się podłoże).
Wszystkie warstwy są powtarzane poziomo: szew jest zamazany (cross-fade), a obraz dopasowany do palety
assets/palette/hufduhof_256.png z ditheringiem Bayera (styl 256 kolorów). Oryginał panoramy nie jest zmieniany."""
import argparse, json, os, sys
import numpy as np
from PIL import Image, ImageDraw
import importlib.util

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(HERE, "assets/stages/source/hufduhof_panorama.png")
spec = importlib.util.spec_from_file_location("mp", os.path.join(HERE, "tools/make_palette.py"))
mp = importlib.util.module_from_spec(spec); spec.loader.exec_module(mp)

# --- geometria (px obrazu wewnętrznego gry: 1 px = 4/3 jednostki świata; horyzont = wiersz 259) ---------------
BAND_TOP, BAND_BOT = 68, 492          # wiersze panoramy tworzące pas scenerii (far1+far2) -> 250 wierszy
BAND_H = 250
FAR_W = 640
FAR1_H, FAR2_H = 140, 110
FAR_BLEND = 96                        # szerokość (px gry) zamazywanego szwu
SKY_W, SKY_H = 512, 320
GROUND_Y0 = 495                       # pierwszy wiersz podłoża w panoramie (początek trawnika)
GROUND_W, GROUND_H = 128, 320
GROUND_BLEND = 32
GROUND_SCALE = 1.22
FG_W, FG_H = 640, 60
PARALLAX_FAR = 0.2

# wycinki poziome panoramy (x lewej krawędzi) dla każdego etapu; szerokość wycinka liczy się z rozmiaru warstwy
STAGES = {
    "stage1_road":          {"far_x": 265,  "sky_x": 300,  "ground_x": 880,  "grade": (1.00, 1.00, 1.00), "sat": 1.00, "fg": "fence"},
    "stage2_village":       {"far_x": 560,  "sky_x": 560,  "ground_x": 450,  "grade": (1.07, 0.97, 0.90), "sat": 1.00, "fg": "tufts"},
    "stage3_fields_forest": {"far_x": 700,  "sky_x": 1000, "ground_x": 1000, "grade": (0.95, 1.02, 0.95), "sat": 0.92, "fg": "fence_r"},
    "stage4_lair":          {"far_x": 924,  "sky_x": 1280, "ground_x": 1200, "grade": (0.92, 1.06, 0.95), "sat": 1.05, "fg": "chaos"},
}

# słupki i szczeble płotu z prawego dołu panoramy (współrzędne w panoramie) – do wycięcia pierwszego planu
FENCE_POSTS = [(1482, 640, 1513, 724), (1642, 614, 1673, 716), (1694, 585, 1723, 706), (1849, 597, 1878, 708)]
FENCE_RAILS = [((1447, 693), (1642, 665), 10), ((1722, 624), (1849, 630), 18), ((1722, 666), (1849, 672), 18),
               ((1673, 650), (1694, 640), 10)]

# ------------------------------------------------------------------------------------------------ narzędzia
def bayer4():
    return np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], float) / 16.0 - 0.5

def load_palette():
    P = np.array(Image.open(os.path.join(HERE, "assets/palette/hufduhof_256.png")).convert("RGB")).reshape(-1, 3)
    return P, mp.srgb2lab(P)

def quantize(rgb, alpha, P, plab, strength=10.0):
    """Najbliższy kolor palety w Lab po dodaniu biasu Bayera (dithering uporządkowany). alfa binarna."""
    h, w = rgb.shape[:2]
    bay = np.tile(bayer4(), (h // 4 + 1, w // 4 + 1))[:h, :w, None]
    x = np.clip(rgb.astype(float) + bay * strength, 0, 255)
    lab = mp.srgb2lab(x)
    idx = np.empty((h, w), int)
    for y0 in range(0, h, 32):                         # porcjami, żeby nie zjadać pamięci
        d = ((lab[y0:y0 + 32, :, None, :] - plab[None, None]) ** 2).sum(-1)
        idx[y0:y0 + 32] = d.argmin(-1)
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = P[idx]
    out[..., 3] = np.where(alpha >= 128, 255, 0)
    return Image.fromarray(out, "RGBA")

def grade(rgb, mult, sat):
    a = rgb.astype(float) * np.array(mult)[None, None]
    if sat != 1.0:
        g = a.mean(-1, keepdims=True)
        a = g + (a - g) * sat
    return np.clip(a, 0, 255)

def resize(arr, w, h):
    return np.array(Image.fromarray(arr.astype(np.uint8)).resize((w, h), Image.LANCZOS)).astype(float)

def seamless(a, w, blend):
    """a ma szerokość w+blend. Zwraca szerokość w, w której prawa krawędź płynnie przechodzi w lewą."""
    out = a[:, :w].copy()
    t = np.linspace(0.0, 1.0, blend)[None, :, None]
    out[:, :blend] = a[:, w:w + blend] * (1 - t) + a[:, :blend] * t
    return out

def cut(pan, x0, x1, y0, y1):
    """Wycinek panoramy; poza krawędzią odbicie lustrzane (bezpiecznik)."""
    W = pan.shape[1]
    xs = np.arange(x0, x1)
    xs = np.where(xs >= W, 2 * W - 2 - xs, xs)
    xs = np.clip(xs, 0, W - 1)
    return pan[y0:y1][:, xs]

# ------------------------------------------------------------------------------------------------ warstwy
def make_band(pan, st):
    s = BAND_H / float(BAND_BOT - BAND_TOP)
    src_w = int(round((FAR_W + FAR_BLEND) / s))
    sl = cut(pan, st["far_x"], st["far_x"] + src_w, BAND_TOP, BAND_BOT).astype(float)
    sl = resize(sl, FAR_W + FAR_BLEND, BAND_H)
    sl = grade(sl, st["grade"], st["sat"])
    return seamless(sl, FAR_W, FAR_BLEND)

def make_sky(pan, st):
    """Niebo: górne wiersze panoramy (same chmury) rozciągnięte na całą wysokość; powtarzane poziomo."""
    s = 0.59
    src_w = int(round((SKY_W + 64) / s))
    sl = cut(pan, st["sky_x"], st["sky_x"] + src_w, 0, 64).astype(float)
    # kruk i sygnaturki przy lewej krawędzi panoramy nie wchodzą: wycinki sky_x są poza nimi
    sl = resize(sl, SKY_W + 64, SKY_H)
    sl = grade(sl, st["grade"], st["sat"])
    return seamless(sl, SKY_W, 64)

def make_ground(pan, st):
    """Podłoże: skala 1.22 (grubsze piksele niż tło - to plan bliski), dół odbity lustrzanie poza widocznym obszarem."""
    s = GROUND_SCALE
    src_w = int(round((GROUND_W + GROUND_BLEND) / s)) + 1
    x0 = st["ground_x"]
    sl = cut(pan, x0, x0 + src_w, GROUND_Y0, 724).astype(float)
    rows = int(round(sl.shape[0] * s))
    sl = resize(sl, GROUND_W + GROUND_BLEND, rows)
    need = GROUND_H - rows
    if need > 0:
        sl = np.concatenate([sl, sl[::-1][:need]], 0)
    sl = grade(sl, st["grade"], st["sat"])
    if st["fg"] == "chaos":                                    # skażony grunt przy legowisku: zielony odcień
        g = sl.copy(); g[..., 0] *= 0.82; g[..., 1] *= 1.10; g[..., 2] *= 0.88
        sl = np.clip(g, 0, 255)
    return seamless(sl, GROUND_W, GROUND_BLEND)

def fence_cutout(pan):
    """Płot z panoramy -> RGBA (współrzędne obrazu pierwszego planu w skali 0.5)."""
    x0, y0, x1, y1 = 1440, 575, 1900, 724
    mask = Image.new("L", (x1 - x0, y1 - y0), 0)
    d = ImageDraw.Draw(mask)
    for (ax, ay, bx, by) in FENCE_POSTS:
        d.rounded_rectangle((ax - x0, ay - y0, bx - x0, by - y0), radius=5, fill=255)
    for (a, b, wd) in FENCE_RAILS:
        d.line([(a[0] - x0, a[1] - y0), (b[0] - x0, b[1] - y0)], fill=255, width=wd)
    rgb = pan[y0:y1, x0:x1]
    m = np.array(mask)
    # ucinamy kolory trawy i podłoża wewnątrz maski (zielone/jasne plamy), zostaje drewno
    r, g, b = rgb[..., 0].astype(int), rgb[..., 1].astype(int), rgb[..., 2].astype(int)
    keep = m > 0
    grassy = (g > r + 6) & (g > b + 6)
    keep &= ~grassy
    a = np.dstack([rgb, np.where(keep, 255, 0).astype(np.uint8)])
    im = Image.fromarray(a.astype(np.uint8), "RGBA")
    return im.resize((im.width // 2, im.height // 2), Image.LANCZOS)

def tufts(rng, w, h, kind):
    """Kępki trawy przy dolnej krawędzi (ciemna oliwka/żółta zieleń); kind 'chaos' = trujący odcień."""
    cols = [(24, 34, 16), (38, 52, 22), (60, 72, 28), (92, 100, 36)]
    if kind == "chaos":
        cols = [(16, 30, 22), (24, 52, 34), (40, 86, 44), (88, 130, 52)]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(w // 5):
        x = rng.integers(0, w); bh = int(rng.integers(5, 15))
        c = cols[int(rng.integers(0, len(cols)))]
        lean = int(rng.integers(-2, 3))
        for k in range(bh):
            d.rectangle((x + lean * k // 4, h - 1 - k, x + lean * k // 4 + 1, h - 1 - k), fill=c + (255,))
    # pas ziemi przy samym dole, żeby kępki nie "wisiały"
    d.rectangle((0, h - 4, w, h), fill=cols[0] + (255,))
    return img

def make_foreground(pan, st, fence):
    rng = np.random.default_rng(abs(hash(st["fg"])) % (2 ** 31) if False else {"fence": 1, "tufts": 2, "fence_r": 3, "chaos": 4}[st["fg"]])
    img = tufts(rng, FG_W, FG_H, st["fg"])
    if st["fg"] in ("fence", "fence_r", "chaos"):
        f = fence.copy()
        if st["fg"] == "fence_r":
            f = f.transpose(Image.FLIP_LEFT_RIGHT)
        px = {"fence": 40, "fence_r": 330, "chaos": 200}[st["fg"]]
        # płot od dołu: dolna krawędź płotu = dolna krawędź obrazu
        y = FG_H - f.height
        if y < 0:
            f = f.crop((0, -y, f.width, f.height)); y = 0
        img.alpha_composite(f, (px, y))
        # druga kępa trawy z przodu płotu
        front = tufts(np.random.default_rng(99), FG_W, 14, st["fg"])
        img.alpha_composite(front, (0, FG_H - 14))
    a = np.array(img)
    rgb = grade(a[..., :3], st["grade"], st["sat"])
    return rgb, a[..., 3]

# ------------------------------------------------------------------------------------------------ główna część
def fade_top(alpha, rows=12):
    """Górne wiersze warstwy znikają ditheringiem Bayera (łączenie z niebem, styl pikselowy)."""
    h, w = alpha.shape
    bay = np.tile(bayer4(), (h // 4 + 1, w // 4 + 1))[:h, :w] + 0.5
    out = alpha.copy()
    for y in range(min(rows, h)):
        t = (y + 0.5) / rows
        out[y] = np.where(bay[y] < t, alpha[y], 0)
    return out

def update_manifest(folder):
    p = os.path.join(folder, "stage.json")
    m = json.load(open(p, encoding="utf-8"))
    L = m["layers"]
    L["far1"].update({"parallax": PARALLAX_FAR, "y_offset": -FAR2_H,
                      "note": "górna część ciągłego pasa scenerii (góry, zamek, las); leży nad far2 dzięki y_offset=-110; wygenerowane z panoramy"})
    L["far2"].update({"parallax": PARALLAX_FAR,
                      "note": "dolna część pasa scenerii (las, wieś, pola); dolna krawędź = horyzont; ta sama paralaksa co far1"})
    L["sky"].update({"size": "512x320", "note": "niebo (chmury), powtarzane poziomo; widoczne tylko nad pasem far1"})
    json.dump(m, open(p, "w", encoding="utf-8"), indent=1, ensure_ascii=False)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default=None)
    a = ap.parse_args()
    pan = np.array(Image.open(SRC).convert("RGB"))
    P, plab = load_palette()
    fence = fence_cutout(pan)
    if a.preview:
        os.makedirs(a.preview, exist_ok=True)
    for sid, st in STAGES.items():
        out = os.path.join(HERE, "assets/stages", sid)
        band = make_band(pan, st)
        alpha_full = np.full(band.shape[:2], 255, np.uint8)
        layers = {
            "sky": (make_sky(pan, st), np.full((SKY_H, SKY_W), 255)),
            "far1": (band[:FAR1_H], fade_top(alpha_full[:FAR1_H])),
            "far2": (band[BAND_H - FAR2_H:], alpha_full[BAND_H - FAR2_H:]),
            "ground": (make_ground(pan, st), np.full((GROUND_H, GROUND_W), 255)),
        }
        fg_rgb, fg_a = make_foreground(pan, st, fence)
        layers["foreground"] = (fg_rgb, fg_a)
        for name, (rgb, al) in layers.items():
            im = quantize(rgb, al, P, plab)
            im.save(os.path.join(out, name + ".png"))
            print(f"{sid}/{name}.png {im.size[0]}x{im.size[1]}")
        update_manifest(out)
        if sid == "stage1_road":                      # lewa strona etapu 1: same drzewa (bez chaty z panoramy)
            import fix_stage1_left
            fix_stage1_left.main()
        if a.preview:
            pv = Image.new("RGBA", (960, 540), (0, 0, 0, 255))
            sky = Image.open(os.path.join(out, "sky.png")); pv.alpha_composite(sky.crop((0, SKY_H - 259, 512, SKY_H)), (0, 0)); pv.alpha_composite(sky.crop((0, SKY_H - 259, 448, SKY_H)), (512, 0))
            for nm, y in (("far1", 9), ("far2", 149)):
                t = Image.open(os.path.join(out, nm + ".png"))
                pv.alpha_composite(t, (0, y)); pv.alpha_composite(t.crop((0, 0, 320, t.height)), (640, y))
            g = Image.open(os.path.join(out, "ground.png"))
            for x in range(0, 960, GROUND_W):
                pv.alpha_composite(g.crop((0, 0, GROUND_W, 281)), (x, 259))
            fg = Image.open(os.path.join(out, "foreground.png")); pv.alpha_composite(fg, (0, 540 - FG_H)); pv.alpha_composite(fg.crop((0, 0, 320, FG_H)), (640, 540 - FG_H))
            pv.convert("RGB").save(os.path.join(a.preview, sid + ".png"))
    print("gotowe")

if __name__ == "__main__":
    main()
