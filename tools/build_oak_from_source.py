#!/usr/bin/env python3
"""Dęby (tree_oak) i krzewy (bush) z obrazu wzorcowego autora.

Źródło: assets/stages/source/elements/stage1_road/tree_oak/oak_reference_autor.png
(duże drzewo pixel-art na czarnym tle, 1024x1536). Skrypt:
  1. usuwa czarne tło (zalewanie od krawędzi, wewnętrzne ciemne szczeliny zostają jako kontur),
  2. tnie drzewo na koronę i pień, z nich składa 6 wariantów dębu (inna sylwetka korony, wysokość pnia,
     pochylenie, odcień) w rozmiarze docelowym etapu,
  3. z kęp liści korony wycina 6 krzewów 50x32 (ten sam styl, te same piksele liści),
  4. dopasowuje wszystko do palety 256 (alfa 0/255), dodaje ciemny kontur i zapisuje
     assets/stages/<etap>/props/tree_oak*.png i bush*.png (+ 4x powiększone podglądy w elements/.../*_source.png).

    python3 tools/build_oak_from_source.py                # przebudowa
    python3 tools/build_oak_from_source.py --preview DIR  # + arkusze podglądu

Gra wczytuje automatycznie <nazwa>.png oraz <nazwa>_2.png ... <nazwa>_6.png i losowo je odbija w poziomie.
"""
import argparse, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_props as BP

HERE = BP.HERE
SRC = os.path.join(HERE, "assets/stages/source/elements/stage1_road/tree_oak/oak_reference_autor.png")
OUTLINE = BP.OUTLINE

# etap: (rozmiar dębu, korekcja barw (nasycenie, jasność, ciepło))
STAGES = {
    "stage1_road":          ((100, 150), (0.62, 0.80, 0.00)),
    "stage3_fields_forest": ((110, 150), (0.55, 0.70, -0.03)),
}
BUSH_SIZE = (50, 32)

# ---------------------------------------------------------------- wczytanie i wycięcie tła
def load_source():
    a = np.array(Image.open(SRC).convert("RGB")).astype(float)
    dark = a.max(2) < 34
    lab, _ = ndimage.label(dark)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    # drobne prześwity w koronie (czarne, połączone z tłem tylko cienką szczeliną) też są tłem
    alpha = ~bg
    alpha = ndimage.binary_opening(alpha, iterations=2)
    lab2, n = ndimage.label(alpha)
    if n > 1:
        sizes = ndimage.sum(alpha, lab2, range(1, n + 1))
        alpha = lab2 == (1 + int(np.argmax(sizes)))
    ys, xs = np.where(alpha)
    a, alpha = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1], alpha[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return a, alpha

def trunk_top_row(a, alpha):
    """Pierwszy wiersz od dołu, w którym zaczyna się zieleń korony (pień = brąz)."""
    g = (a[..., 1] > a[..., 0] * 1.05) & alpha
    rows = g.sum(1)
    h = a.shape[0]
    for y in range(h - 1, 0, -1):
        if rows[y] > 25:
            return y
    return int(h * 0.55)

# ---------------------------------------------------------------- barwy
def grade(rgb, sat, val, warm):
    lum = (rgb * [0.299, 0.587, 0.114]).sum(-1, keepdims=True)
    out = lum + (rgb - lum) * sat
    out = out * val
    out[..., 0] *= 1 + warm; out[..., 2] *= 1 - warm
    return np.clip(out, 0, 255)

def tint_leaves(rgb, alpha, shift):
    """Przesunięcie odcienia liści: shift>0 cieplej/żółciej (stary dąb), <0 chłodniej/ciemniej."""
    g = (rgb[..., 1] > rgb[..., 0]) & alpha
    out = rgb.copy()
    if shift > 0:
        out[g, 0] = np.clip(out[g, 0] + shift * out[g, 1] * 0.45, 0, 255)
        out[g, 2] *= 1 - 0.3 * shift
    else:
        s = -shift
        out[g, 0] *= 1 - 0.35 * s; out[g, 1] *= 1 - 0.18 * s; out[g, 2] = np.clip(out[g, 2] * (1 + 0.5 * s) + 6 * s, 0, 255)
    return out

# ---------------------------------------------------------------- operacje na obrazie RGBA (float)
def rgba(rgb, alpha):
    return np.dstack([rgb, alpha.astype(float) * 255])

def resize(im, w, h):
    """Skalowanie premultiplied BOX (źródło ma ~11 px na piksel gry, więc BOX daje czyste piksele)."""
    prem = im.copy(); prem[..., :3] *= prem[..., 3:4] / 255.0
    ch = [np.array(Image.fromarray(prem[..., i].astype(np.float32), "F").resize((w, h), Image.BOX)) for i in range(4)]
    r = np.dstack(ch)
    al = r[..., 3:4]
    r[..., :3] = np.where(al > 1, r[..., :3] / np.maximum(al / 255.0, 1e-3), 0)
    return r

def mirror_half(im, alpha, cx, keep_left, rng):
    """Korona złożona z jednej połowy i jej odbicia względem osi pnia; szew poszarpany (bez prostej linii)."""
    h, w = alpha.shape
    pad = w
    im = np.pad(im, ((0, 0), (pad, pad), (0, 0))); alpha = np.pad(alpha, ((0, 0), (pad, pad)))
    cx += pad
    if not keep_left:          # prawa połowa = lewa połowa obrazu odbitego
        im, alpha = im[:, ::-1], alpha[:, ::-1]; cx = im.shape[1] - 1 - cx
    W2 = im.shape[1]
    seam = cx + rng.integers(-10, 11, size=h // 22 + 2).repeat(22)[:h]
    out = im.copy(); oa = alpha.copy()
    for y in range(h):
        sx = seam[y]
        n = W2 - sx
        src = np.clip(2 * cx - np.arange(sx, W2), 0, W2 - 1)
        out[y, sx:] = im[y, src]; oa[y, sx:] = alpha[y, src]
    ys, xs = np.where(oa)
    out, oa = out[:, xs.min():xs.max() + 1], oa[:, xs.min():xs.max() + 1]
    cx -= xs.min()
    if not keep_left:
        out, oa = out[:, ::-1], oa[:, ::-1]; cx = out.shape[1] - 1 - cx
    return out, oa, cx

def shear(im, k):
    """Pochylenie: przesunięcie wierszy o k*(odległość od dołu) (dół zostaje w miejscu)."""
    h, w = im.shape[:2]
    pad = int(abs(k) * h) + 2
    out = np.zeros((h, w + 2 * pad, 4))
    for y in range(h):
        dx = int(round(k * (h - 1 - y)))
        out[y, pad + dx:pad + dx + w] = im[y]
    return out

def trim(im):
    m = im[..., 3] > 127
    ys, xs = np.where(m)
    return im[ys.min():ys.max() + 1, xs.min():xs.max() + 1]

def place(im, W, H):
    """Wstawia obraz na płótno WxH: środek dolnej krawędzi = pivot. Zmniejsza, jeśli się nie mieści."""
    im = trim(im)
    h, w = im.shape[:2]
    s = min(1.0, (W - 2) / w, (H - 1) / h)
    if s < 1.0:
        im = resize(im, max(1, round(w * s)), max(1, round(h * s))); h, w = im.shape[:2]
    out = np.zeros((H, W, 4))
    x0 = (W - w) // 2
    out[H - h:, x0:x0 + w] = im
    return out

def finish(im, P, plab):
    im = im.copy()
    im[..., 3] = np.where(im[..., 3] >= 128, 255, 0)
    img = Image.fromarray(np.clip(im, 0, 255).astype(np.uint8), "RGBA")
    img = BP.dark_edge(img)
    return BP.quantize(img, P, plab)

# ---------------------------------------------------------------- dęby
def build_tree(a, alpha, ty, W, H, v):
    """v = numer wariantu 0..5. a/alpha w rozdzielczości źródła."""
    rng = np.random.default_rng(100 + v)
    h, w = alpha.shape
    rgb = a.copy()
    crown, calpha = rgb[:ty + 30].copy(), alpha[:ty + 30].copy()
    trunk, talpha = rgb[ty + 30:].copy(), alpha[ty + 30:].copy()
    tcols = np.where(talpha.any(0))[0]
    cx = int(np.median(np.where(talpha[talpha.shape[0] // 2])[0])) if talpha.any() else w // 2

    # wysokość docelowa całości (w pikselach gry) i proporcja pnia
    spec = [  # (wysokość, skala pnia, lustro korony, pochylenie, odcień liści, spłaszczenie korony)
        (146, 1.00, None, 0.00, 0.0, 1.0),     # 1: wierny oryginałowi
        (140, 0.70, "L", 0.00, 0.0, 1.0),      # 2: krępy, symetryczna korona z lewej połowy
        (148, 1.35, None, 0.00, -0.3, 0.9),    # 3: wysoki pień, chłodniejsze liście
        (124, 0.85, None, 0.08, 0.35, 1.0),    # 4: młodszy, pochylony, cieplejszy
        (128, 0.80, None, -0.05, 0.6, 0.72),   # 5: stary rozłożysty dąb, żółknące liście
        (112, 0.75, "L", 0.03, -0.25, 1.0),    # 6: niski, ciemny
    ][v]
    TH, tscale, mir, lean, tint, squash = spec
    ccx = cx
    if mir:
        crown, calpha, ccx = mirror_half(crown, calpha, cx, mir == "L", rng)
    if tint:
        crown = tint_leaves(crown, calpha, tint)
    if squash != 1.0:
        cr = resize(rgba(crown, calpha), crown.shape[1], int(crown.shape[0] * squash))
        crown, calpha = cr[..., :3], cr[..., 3] > 127
    # pień: przeskalowanie w pionie (dłuższy/krótszy pień)
    nth = max(40, int(trunk.shape[0] * tscale))
    T = resize(rgba(trunk, talpha), trunk.shape[1], nth)
    C = rgba(crown, calpha)
    left = max(cx, ccx); right = max(w - cx, C.shape[1] - ccx)
    full = np.zeros((C.shape[0] + nth - 30, left + right, 4))
    # najpierw pień, potem korona (korona przykrywa górę pnia)
    tx = left - cx
    full[C.shape[0] - 30:, tx:tx + w] = T
    cm = C[..., 3] > 127
    cxo = left - ccx
    reg = full[:C.shape[0], cxo:cxo + C.shape[1]]
    reg[cm] = C[cm]
    if lean:
        full = shear(full, lean)
        full = trim(full)
    full = trim(full)
    s = TH / full.shape[0]
    tw = max(1, round(full.shape[1] * s))
    if tw > W - 2:
        s = (W - 2) / full.shape[1]; tw = W - 2
    sm = resize(full, tw, max(1, round(full.shape[0] * s)))
    return place(sm, W, H)

# ---------------------------------------------------------------- krzewy
def lumpy_dome(w, h, rng):
    """Maska kopuły krzewu złożona z kilku kół (obrys z 'kęp')."""
    m = np.zeros((h, w), bool)
    yy, xx = np.mgrid[0:h, 0:w]
    n = rng.integers(4, 7)
    for i in range(n):
        t = (i + 0.5) / n
        cx = 0.12 * w + t * 0.76 * w + rng.uniform(-0.04, 0.04) * w
        r = rng.uniform(0.17, 0.25) * w
        top = h * (0.10 + 0.55 * abs(t - 0.5) ** 1.3 * 2) + rng.uniform(-0.04, 0.06) * h
        cy = top + r
        m |= (xx - cx) ** 2 + ((yy - cy) * 1.15) ** 2 <= r * r
    m[int(h * 0.78):, int(w * 0.06):int(w * 0.94)] = True
    return m

def build_bush(a, alpha, ty, v):
    """Wycinek kęp liści z korony (w rozdzielczości źródła) -> 50x32."""
    rng = np.random.default_rng(300 + v)
    BW, BH = BUSH_SIZE
    h, w = alpha.shape
    # okna w koronie (ułamki szerokości/wysokości korony): x0, y0, szerokość
    wins = [(0.02, 0.18, 0.46), (0.40, 0.02, 0.50), (0.50, 0.28, 0.50),
            (0.10, 0.03, 0.42), (0.00, 0.36, 0.52), (0.30, 0.40, 0.44)]
    fx, fy, fw = wins[v]
    cw = int(fw * w); ch = int(cw * BH / BW)
    x0 = int(fx * w); y0 = int(fy * ty)
    x0 = min(x0, w - cw); y0 = min(y0, ty - ch)
    rgb = a[y0:y0 + ch, x0:x0 + cw].copy()
    al = alpha[y0:y0 + ch, x0:x0 + cw].copy()
    # tylko liście (bez pnia/gałęzi wystających w oknie)
    leaf = rgb[..., 1] >= rgb[..., 0] * 0.95
    al &= ndimage.binary_closing(leaf | (rgb.max(2) < 60), iterations=3)
    dome = np.array(Image.fromarray(lumpy_dome(BW * 4, BH * 4, rng).astype(np.uint8) * 255)
                    .resize((cw, ch), Image.NEAREST)) > 0
    al &= dome
    lab, n = ndimage.label(al)
    if n > 1:
        al = lab == (1 + int(np.argmax(ndimage.sum(al, lab, range(1, n + 1)))))
    # cień przy ziemi: dolne 20% ściemnione stopniowo
    yy = np.linspace(0, 1, ch)[:, None, None]
    shade = np.clip((yy - 0.72) / 0.28, 0, 1) * 0.55
    rgb = rgb * (1 - shade)
    tint = [0.0, -0.3, 0.25, 0.0, -0.15, 0.45][v]
    if tint:
        rgb = tint_leaves(rgb, al, tint)
    im = resize(rgba(rgb, al), BW - 2, BH - 1)
    return place(im, BW, BH)

# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default=None)
    args = ap.parse_args()
    P = np.array(Image.open(os.path.join(HERE, "assets/palette/hufduhof_256.png")).convert("RGB")).reshape(-1, 3)
    plab = BP.mp.srgb2lab(P)
    a0, alpha = load_source()
    ty = trunk_top_row(a0, alpha)
    sheets = {}
    for stage, ((W, H), (sat, val, warm)) in STAGES.items():
        a = grade(a0, sat, val, warm)
        pdir = os.path.join(HERE, "assets/stages", stage, "props")
        for name, maker, n in (("tree_oak", lambda v: build_tree(a, alpha, ty, W, H, v), 6),
                               ("bush", lambda v: build_bush(a, alpha, ty, v), 6)):
            sdir = os.path.join(HERE, "assets/stages/source/elements", stage, name)
            os.makedirs(sdir, exist_ok=True)
            for v in range(n):
                q = finish(maker(v), P, plab)
                fn = f"{name}.png" if v == 0 else f"{name}_{v + 1}.png"
                q.save(os.path.join(pdir, fn))
                q.resize((q.width * 4, q.height * 4), Image.NEAREST).save(
                    os.path.join(sdir, f"{name}_source.png" if v == 0 else f"{name}_{v + 1}_source.png"))
                sheets.setdefault(stage, []).append((fn, q))
                print(f"{stage}/props/{fn} {q.width}x{q.height}")
    if args.preview:
        os.makedirs(args.preview, exist_ok=True)
        for stage, items in sheets.items():
            sc = 3
            Wd = sum(q.width * sc + 14 for _, q in items[:6]) + 8
            Hd = max(q.height for _, q in items[:6]) * sc + max(q.height for _, q in items[6:]) * sc + 40
            sheet = Image.new("RGBA", (Wd, Hd), (70, 96, 52, 255))
            x = 8
            for fn, q in items[:6]:
                sheet.alpha_composite(q.resize((q.width * sc, q.height * sc), Image.NEAREST), (x, 8)); x += q.width * sc + 14
            x = 8; y = 8 + 150 * sc + 16
            for fn, q in items[6:]:
                sheet.alpha_composite(q.resize((q.width * sc, q.height * sc), Image.NEAREST), (x, y)); x += q.width * sc + 14
            sheet.convert("RGB").save(os.path.join(args.preview, f"oak_bush_{stage}.png"))

if __name__ == "__main__":
    main()
