"""Uciekające zwierzęta lasu (etap 3) w stylu rysunków na marginesach średniowiecznych rękopisów:
gruby atramentowy kontur, płaskie plamy koloru, śmieszne detale (zając w hełmie, jeleń z szalikiem, nietoperz w mitrze).
Dwie klatki na zwierzę -> assets/stages/stage3_fields_forest/critters/<nazwa>_1.png, _2.png (zwierzę zwrócone w lewo,
pivot = środek dolnej krawędzi). Uruchom: python3 tools/build_critters.py [--preview katalog]"""
import argparse, os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixart import Canvas, RAMPS, OUTLINE
import build_props as BP

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "assets/stages/stage3_fields_forest/critters")
RAMPS["vellum"] = [(120, 96, 64), (170, 140, 96), (214, 190, 140), (240, 224, 180)]
RAMPS["hare"] = [(96, 70, 48), (150, 112, 74), (196, 158, 108), (226, 200, 150)]
RAMPS["deer"] = [(88, 48, 20), (140, 84, 34), (186, 120, 52), (222, 160, 80)]
RAMPS["ink"] = [(10, 7, 8), (21, 16, 17), (42, 34, 36), (70, 56, 58)]
RAMPS["batc"] = [(26, 10, 42), (47, 19, 65), (68, 28, 88), (109, 45, 133)]

def limb(c, p0, p1, w, ramp, sh):
    c.paint(c.line(p0, p1, w), ramp, sh, 0.15)

def hare(f):
    W, H = 52, 40
    c = Canvas(W, H)
    run = f == 1
    base = H - 3
    # tylne łapy (wyciągnięte w skoku / podkulone)
    if run:
        limb(c, (36, base - 12), (46, base - 2), 5, "hare", 0.35)
        limb(c, (30, base - 12), (38, base - 1), 5, "hare", 0.45)
        limb(c, (16, base - 12), (6, base - 3), 3, "hare", 0.4)
    else:
        limb(c, (34, base - 10), (30, base - 1), 5, "hare", 0.35)
        limb(c, (29, base - 10), (24, base - 1), 5, "hare", 0.45)
        limb(c, (16, base - 10), (13, base - 1), 3, "hare", 0.4)
    body = c.ellipse(28, base - 15, 13, 8.5) | c.ellipse(34, base - 14, 8, 8)
    c.volume(body, "hare", bulge=6, noise=0.12, base=0.55)
    c.paint(c.ellipse(26, base - 11, 9, 4), "vellum", 0.8, 0.1)               # jasny brzuch
    tail = c.ellipse(44, base - 18, 4, 4)
    c.paint(tail, "vellum", 0.95, 0.1)
    head = c.ellipse(14, base - 20, 7, 6) | c.ellipse(8, base - 18, 4.5, 3.5)
    c.volume(head, "hare", bulge=4, noise=0.1, base=0.6)
    ear1 = c.poly([(13, base - 24), (17, base - 38), (20, base - 36), (18, base - 24)])
    ear2 = c.poly([(16, base - 24), (24, base - 36), (26, base - 33), (20, base - 23)])
    c.paint(ear1, "hare", 0.5, 0.1); c.paint(ear2, "hare", 0.35, 0.1)
    c.paint(c.poly([(15, base - 26), (17.5, base - 35), (19, base - 34), (17, base - 26)]), "vellum", 0.8, 0.0)
    # przednie łapy
    if run:
        limb(c, (18, base - 12), (6, base - 5), 3, "hare", 0.45)
    else:
        limb(c, (18, base - 11), (14, base - 1), 3, "hare", 0.45)
    # hełm garnczkowy z czerwonym pióropuszem + oko ze strachem
    helm = c.ellipse(14, base - 25, 6.5, 4.5) & c.rect(0, 0, W, base - 22)
    c.volume(helm, "iron" if "iron" in RAMPS else "stone", bulge=3, noise=0.1, base=0.6)
    c.paint(c.poly([(14, base - 29), (20, base - 36), (22, base - 32), (16, base - 27)]), "red", 0.7, 0.1)
    c.flat(c.ellipse(10.5, base - 21, 1.6, 1.8), (240, 232, 210)); c.flat(c.ellipse(10, base - 21, 0.8, 1.0), OUTLINE)
    c.flat(c.ellipse(3.5, base - 19.5, 1.2, 1.0), (150, 60, 60))
    c.outline()
    return c.image()

def deer(f):
    W, H = 78, 70
    c = Canvas(W, H)
    run = f == 1
    base = H - 3
    legs = [((52, base - 24), (64, base - 3) if run else (56, base - 2), (68, base - 6) if run else (58, base - 1)),
            ((46, base - 24), (58, base - 5) if run else (50, base - 2), (60, base - 7) if run else (51, base - 1)),
            ((26, base - 24), (14, base - 4) if run else (22, base - 2), (8, base - 7) if run else (20, base - 1)),
            ((20, base - 24), (10, base - 2) if run else (16, base - 2), (4, base - 5) if run else (14, base - 1))]
    for (hip, knee, foot) in legs:
        c.paint(c.line(hip, knee, 4) | c.line(knee, foot, 3), "deer", 0.35, 0.15)
    body = c.ellipse(38, base - 30, 20, 11)
    c.volume(body, "deer", bulge=7, noise=0.12, base=0.55)
    c.paint(c.ellipse(36, base - 24, 15, 4), "vellum", 0.85, 0.1)
    c.paint(c.ellipse(58, base - 33, 3, 4), "vellum", 0.95, 0.0)                       # biała plama ogona
    neck = c.poly([(24, base - 36), (16, base - 52), (22, base - 54), (31, base - 38)])
    c.volume(neck, "deer", bulge=4, noise=0.12, base=0.6)
    head = c.ellipse(13, base - 56, 6.5, 5) | c.ellipse(6, base - 53, 5, 3.4)
    c.volume(head, "deer", bulge=4, noise=0.1, base=0.65)
    c.paint(c.ellipse(1.5, base - 53, 1.8, 1.5), "ink", 0.2, 0.0)                      # nos
    c.paint(c.poly([(14, base - 60), (20, base - 66), (21, base - 62), (17, base - 58)]), "deer", 0.4, 0.1)  # ucho
    # rozłożyste, przesadnie ozdobne rogi
    for (x0, y0, x1, y1) in ((14, base - 60, 18, base - 69), (18, base - 69, 14, base - 74), (18, base - 69, 24, base - 72),
                             (16, base - 63, 24, base - 67), (24, base - 67, 29, base - 64)):
        c.paint(c.line((x0, y0), (x1, y1), 2), "vellum", 0.5, 0.1)
    # szalik rycerski i oko
    c.paint(c.line((19, base - 50), (30, base - 42), 4), "red", 0.65, 0.1)
    c.paint(c.line((30, base - 42), (36, base - 36), 3), "red", 0.45, 0.1)
    c.flat(c.ellipse(10, base - 57, 1.8, 1.9), (240, 232, 210)); c.flat(c.ellipse(9.4, base - 57, 0.9, 1.1), OUTLINE)
    c.outline()
    return c.image()

def bat(f):
    W, H = 52, 34
    c = Canvas(W, H)
    up = f == 0
    cx, cy = 26, 18
    for sgn in (-1, 1):
        tip = (cx + sgn * 24, cy - (12 if up else -6))
        mid = (cx + sgn * 14, cy - (4 if up else 8))
        w = c.poly([(cx + sgn * 3, cy - 2), (cx + sgn * 10, cy - (9 if up else 3)), tip,
                    (cx + sgn * 20, cy + (3 if up else 10)), (cx + sgn * 14, cy + (4 if up else 11)),
                    (cx + sgn * 9, cy + (2 if up else 8)), (cx + sgn * 3, cy + 5)])
        c.volume(w, "batc", bulge=4, noise=0.15, base=0.5)
        c.paint(c.line((cx + sgn * 3, cy), tip, 1), "ink", 0.3, 0.0)
        c.paint(c.line((cx + sgn * 3, cy), mid, 1), "ink", 0.3, 0.0)
    body = c.ellipse(cx, cy, 6, 8)
    c.volume(body, "batc", bulge=4, noise=0.1, base=0.6)
    head = c.ellipse(cx, cy - 8, 5.5, 5)
    c.volume(head, "batc", bulge=3, noise=0.1, base=0.65)
    c.paint(c.poly([(cx - 5, cy - 11), (cx - 7, cy - 18), (cx - 2, cy - 12)]), "batc", 0.5, 0.0)
    c.paint(c.poly([(cx + 5, cy - 11), (cx + 7, cy - 18), (cx + 2, cy - 12)]), "batc", 0.5, 0.0)
    # mitra biskupia i szeroki uśmiech z kłami
    c.paint(c.poly([(cx - 4, cy - 12), (cx, cy - 22), (cx + 4, cy - 12)]), "gold", 0.8, 0.0)
    c.flat(c.rect(cx - 3, cy - 14, cx + 3, cy - 12), (170, 40, 40))
    c.flat(c.ellipse(cx - 2.2, cy - 9, 1.5, 1.7), (240, 232, 210)); c.flat(c.ellipse(cx + 2.2, cy - 9, 1.5, 1.7), (240, 232, 210))
    c.flat(c.rect(cx - 3, cy - 5, cx + 3, cy - 4), (200, 60, 60))
    c.flat(c.rect(cx - 2, cy - 4, cx - 1, cy - 2), (240, 232, 210)); c.flat(c.rect(cx + 1, cy - 4, cx + 2, cy - 2), (240, 232, 210))
    c.outline()
    return c.image()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default=None)
    a = ap.parse_args()
    P = np.array(Image.open(os.path.join(HERE, "assets/palette/hufduhof_256.png")).convert("RGB")).reshape(-1, 3)
    plab = BP.mp.srgb2lab(P)
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.new("RGBA", (600, 260), (70, 96, 52, 255)); x = 6
    for name, fn, frames in (("hare", hare, (0, 1)), ("deer", deer, (0, 1)), ("bat", bat, (0, 1))):
        for f in frames:
            q = BP.quantize(fn(f), P, plab)
            q.save(os.path.join(OUT, f"{name}_{f + 1}.png"))
            print(f"critters/{name}_{f + 1}.png {q.width}x{q.height}")
            sheet.alpha_composite(q.resize((q.width * 2, q.height * 2), Image.NEAREST), (x, 6)); x += q.width * 2 + 10
    if a.preview:
        os.makedirs(a.preview, exist_ok=True)
        sheet.convert("RGB").save(os.path.join(a.preview, "critters.png"))

if __name__ == "__main__":
    main()
