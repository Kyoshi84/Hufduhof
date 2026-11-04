"""Borubar z obrazu autora -> pixel-art do gry (kwantyzowany do wspólnej palety 256 kolorów).

Źródło: assets/characters/borubar/source/borubar_painting.jpg (Borubar z beczką nad głową, jasne tło).
Wynik:
  assets/minigame/borubar.png          sprite do minigry w karczmie (beczka = "koszyk" na kufle)
  assets/minigame/borubar_dizzy.png    to samo, oczy "X", otwarte usta (ogłuszony po rozbitym kuflu)
  assets/ui/story/portraits/borubar.png  portret do czarnego okna na planszy "las" (254x144 => 2x = 508x288)
Uruchom: python3 tools/build_borubar.py [--preview katalog]

Geometria sprite'a (stałe w scripts/minigame/tavern_game.gd: BORU_PIVOT, CATCH_DX, CATCH_Y, STARS_Y) jest wypisywana na końcu.
"""
import argparse, json, os, sys
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
from scipy import ndimage
import importlib.util

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(HERE, "assets/characters/borubar/source/borubar_painting.jpg")
spec = importlib.util.spec_from_file_location("mp", os.path.join(HERE, "tools/make_palette.py"))
mp = importlib.util.module_from_spec(spec); spec.loader.exec_module(mp)

OUTLINE = (14, 9, 8)
S_WORLD = 4.0 / 3.0                 # jednostek świata na piksel grafiki (jak w reszcie gry)
SPRITE_H = 142                      # wysokość postaci w pikselach (bez konturu)
# punkty charakterystyczne na obrazie źródłowym (px oryginału)
PIVOT_X = 730                       # środek ciała nad stopami
FEET_Y = 1350                       # spód buta
MOUTH = (548, 135)                  # środek otworu beczki
HAT_TOP = 600                       # czubek czapki
EYES = ((670, 666), (722, 659))
MOUTH_FACE = (712, 712)


def load_cutout():
    """RGB + maska postaci: tło jest jasnoszare i neutralne, cień i podpis pod stopami są szare."""
    a = np.asarray(Image.open(SRC).convert("RGB")).astype(int)
    h, w = a.shape[:2]
    sat = a.max(-1) - a.min(-1)
    lum = a.mean(-1)
    lab, n = ndimage.label((sat < 20) & (lum > 200))
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    bg = np.isin(lab, [i + 1 for i in range(n) if sizes[i] > 300])   # tło, także prześwity między rękami a głową
    yy = np.mgrid[0:h, 0:w][0]
    bg |= (yy > 1250) & (sat < 22)                  # cień na podłodze i podpis
    fg = ndimage.binary_opening(~bg, iterations=2)
    lab, n = ndimage.label(fg)
    sizes = ndimage.sum(fg, lab, range(1, n + 1))
    fg = lab == (int(np.argmax(sizes)) + 1)
    fg = ndimage.binary_erosion(fg, iterations=3)                    # bez jasnej obwódki z tła
    return a.astype(np.uint8), fg


def grade(rgb):
    """Lekko mocniejszy kontrast i nasycenie + wyostrzenie: po zmniejszeniu detale nie rozmywają się w błoto."""
    im = Image.fromarray(rgb)
    im = im.filter(ImageFilter.UnsharpMask(radius=4, percent=90, threshold=2))
    im = ImageEnhance.Contrast(im).enhance(1.12)
    im = ImageEnhance.Color(im).enhance(1.12)
    return np.asarray(im)


def downscale(rgb, mask, box, size):
    """Średnia po powierzchni z premultiplikowaną alfą (brzegi nie łapią koloru tła)."""
    x0, y0, x1, y1 = box
    r = rgb[y0:y1, x0:x1].astype(float)
    m = mask[y0:y1, x0:x1].astype(float)
    pre = np.dstack([r * m[..., None], m * 255.0]).astype(np.float32)
    chans = [Image.fromarray(pre[..., i], "F").resize(size, Image.BOX) for i in range(4)]
    arr = np.dstack([np.asarray(c) for c in chans])
    al = arr[..., 3] / 255.0
    col = arr[..., :3] / np.maximum(al[..., None], 1e-4)
    return np.clip(col, 0, 255), al


class Pal:
    def __init__(self):
        self.P = np.array(Image.open(os.path.join(HERE, "assets/palette/hufduhof_256.png")).convert("RGB")).reshape(-1, 3)
        self.lab = mp.srgb2lab(self.P)

    def nearest(self, rgb, dither=0.0):
        a = rgb.astype(float)
        h, w = a.shape[:2]
        if dither > 0:
            b4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
            a = np.clip(a + (np.tile(b4, (h // 4 + 1, w // 4 + 1))[:h, :w, None] - 0.5) * dither * 2, 0, 255)
        idx = np.zeros((h, w), int)
        for y0 in range(0, h, 24):
            blk = mp.srgb2lab(a[y0:y0 + 24])
            idx[y0:y0 + 24] = ((blk[..., None, :] - self.lab[None, None]) ** 2).sum(-1).argmin(-1)
        return self.P[idx].astype(np.uint8)


def sprite(rgb, mask, pal):
    ys, xs = np.nonzero(mask)
    y0, y1 = int(ys.min()), FEET_Y + 1
    k = SPRITE_H / (y1 - y0)                        # px sprite'a na px oryginału
    # szerokość: symetrycznie wokół pivotu, żeby pivot wypadał na środku obrazka
    half = max(PIVOT_X - int(xs.min()), int(xs.max()) - PIVOT_X) + 4
    x0, x1 = PIVOT_X - half, PIVOT_X + half
    W = int(round((x1 - x0) * k))
    W += W % 2
    col, al = downscale(rgb, mask, (x0, y0, x1, y1), (W, SPRITE_H))
    inside = al >= 0.5
    q = pal.nearest(col)
    # płótno z marginesem 1 px na kontur
    cw, ch = W + 2, SPRITE_H + 2
    out = np.zeros((ch, cw, 4), np.uint8)
    out[1:-1, 1:-1, :3] = q
    a = np.zeros((ch, cw), bool)
    a[1:-1, 1:-1] = inside
    edge = ndimage.binary_dilation(a, structure=ndimage.generate_binary_structure(2, 1)) & ~a
    out[a, 3] = 255
    out[edge, :3] = OUTLINE
    out[edge, 3] = 255

    def to_px(p):
        return (1 + (p[0] - x0) * k, 1 + (p[1] - y0) * k)

    geo = {
        "size": [cw, ch],
        "pivot": list(to_px((PIVOT_X, FEET_Y))),
        "mouth": list(to_px(MOUTH)),
        "hat_top": list(to_px((PIVOT_X, HAT_TOP))),
        "eyes": [list(to_px(e)) for e in EYES],
        "face_mouth": list(to_px(MOUTH_FACE)),
    }
    return out, geo


def dizzy(img, geo):
    """Ogłuszony: oczy "X" i otwarte usta."""
    out = img.copy()
    dark = (20, 12, 10, 255)
    for ex, ey in geo["eyes"]:
        ex, ey = int(round(ex)), int(round(ey))
        for d in (-1, 0, 1):
            out[ey + d, ex + d] = dark
            out[ey - d, ex + d] = dark
    mx, my = int(round(geo["face_mouth"][0])), int(round(geo["face_mouth"][1]))
    out[my:my + 2, mx - 1:mx + 2] = (60, 14, 14, 255)
    return out


def portrait(rgb, mask, pal):
    """Popiersie Borubara (z dnem beczki nad głową) na tle dogasającej wsi przy ścianie lasu, 254x144."""
    W, H = 254, 144
    box_h = 400                                     # od dłoni do brzucha
    x_c, y_top = 700, 510
    box_w = int(box_h * W / H)
    box = (x_c - box_w // 2, y_top, x_c + box_w // 2, y_top + box_h)
    col, al = downscale(rgb, mask, box, (W, H))
    # tło: zmierzch, łuna pożaru nisko, czarna ściana lasu
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    t = yy / H
    sky_top = np.array([18, 20, 34.0])
    sky_mid = np.array([58, 34, 40.0])
    glow = np.array([150, 62, 26.0])
    bgc = sky_top + (sky_mid - sky_top) * np.clip(t * 1.4, 0, 1)[..., None]
    g = np.exp(-((t - 0.78) / 0.14) ** 2) * (0.55 + 0.45 * np.exp(-((xx - W * 0.22) / 70.0) ** 2))
    bgc = bgc + (glow - bgc) * g[..., None]
    # sylwetka lasu
    rng = np.random.default_rng(5)
    ridge = H * 0.66 + np.convolve(rng.normal(0, 6, W + 40), np.ones(7) / 7, "same")[20:20 + W]
    x = 0
    while x < W:                                     # czubki świerków o różnej wysokości i rozstawie
        hw, ht = int(rng.integers(3, 7)), rng.uniform(6, 18)
        for d in range(-hw, hw + 1):
            if 0 <= x + d < W:
                ridge[x + d] = min(ridge[x + d], ridge[x + d] - ht * (1 - abs(d) / (hw + 1)))
        x += int(rng.integers(5, 12))
    forest = yy > ridge[None, :]
    bgc[forest] = np.array([12, 12, 16.0]) + (bgc[forest] - np.array([12, 12, 16.0])) * 0.12
    # dym
    smoke = np.exp(-((xx - W * 0.2 - (H - yy) * 0.35) / 22.0) ** 2) * np.clip((H * 0.8 - yy) / (H * 0.8), 0, 1)
    bgc = bgc + (np.array([90, 80, 82.0]) - bgc) * (smoke * 0.35)[..., None]
    # ciepłe światło z lewej na postaci (łuna)
    warm = np.clip(1.0 - xx / W, 0, 1) * 0.12
    fig = col * (1 - warm[..., None]) + np.array([255, 140, 70.0]) * warm[..., None]
    a = np.clip((al - 0.2) / 0.6, 0, 1)[..., None]
    comp = bgc * (1 - a) + fig * a
    q_bg = pal.nearest(comp, dither=7.0)
    q_fg = pal.nearest(comp)
    inside = al >= 0.5
    out = np.where(inside[..., None], q_fg, q_bg)
    edge = ndimage.binary_dilation(inside, structure=ndimage.generate_binary_structure(2, 1)) & ~inside
    out[edge] = OUTLINE
    # winieta przy krawędziach
    v = np.clip(1.0 - (((xx - W / 2) / (W * 0.62)) ** 2 + ((yy - H / 2) / (H * 0.75)) ** 2), 0, 1) ** 0.35
    out = pal.nearest(out * (0.55 + 0.45 * v[..., None]))
    return np.dstack([out, np.full((H, W), 255, np.uint8)])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default=None)
    args = ap.parse_args()
    pal = Pal()
    rgb, mask = load_cutout()
    rgb = grade(rgb)
    spr, geo = sprite(rgb, mask, pal)
    files = {
        "assets/minigame/borubar.png": spr,
        "assets/minigame/borubar_dizzy.png": dizzy(spr, geo),
        "assets/ui/story/portraits/borubar.png": portrait(rgb, mask, pal),
    }
    for rel, arr in files.items():
        im = Image.fromarray(arr, "RGBA")
        im.save(os.path.join(HERE, rel))
        print(f"{rel} {im.width}x{im.height}")
        if args.preview:
            os.makedirs(args.preview, exist_ok=True)
            im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(os.path.join(args.preview, rel.replace('/', '_')))
    w, h = geo["size"]
    px, py = geo["pivot"]
    print("geometria sprite'a (świat = px * %.4f):" % S_WORLD)
    print("  pivot (stopy) px: (%.1f, %.1f)" % (px, py))
    print("  otwór beczki: dx = %.1f, dy = %.1f świata" % ((geo["mouth"][0] - px) * S_WORLD, (geo["mouth"][1] - py) * S_WORLD))
    print("  czubek czapki: dy = %.1f świata" % ((geo["hat_top"][1] - py) * S_WORLD))
    print(json.dumps(geo))


if __name__ == "__main__":
    main()
