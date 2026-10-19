"""Mały zestaw narzędzi do rysowania pikselowych rekwizytów w stylu panoramy Hufduhofu (ciemne kontury,
rampy kolorów, dithering Bayera). Używane przez tools/build_props.py. Rysujemy w rozmiarze docelowym (1 px = 1 px gry)."""
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

OUTLINE = (14, 9, 8)

# rampy: od najciemniejszego do najjaśniejszego (kolory próbkowane z panoramy)
RAMPS = {
    "wood":   [(22, 13, 9), (46, 28, 16), (78, 50, 26), (116, 76, 38), (164, 112, 56)],
    "woodpale": [(40, 26, 14), (78, 52, 28), (122, 86, 44), (170, 128, 70), (212, 170, 96)],
    "stone":  [(20, 23, 32), (42, 48, 60), (72, 78, 90), (108, 114, 124), (150, 154, 160)],
    "moss":   [(16, 28, 14), (32, 50, 20), (56, 74, 28), (90, 102, 38)],
    "oak":    [(12, 26, 24), (24, 50, 38), (42, 80, 44), (72, 112, 54), (118, 148, 70)],
    "pine":   [(8, 22, 28), (16, 42, 50), (28, 68, 68), (50, 96, 82), (84, 126, 100)],
    "bush":   [(14, 28, 18), (28, 52, 26), (50, 78, 30), (84, 108, 40), (128, 142, 58)],
    "dry":    [(24, 18, 12), (50, 38, 22), (86, 66, 36), (124, 98, 52)],
    "red":    [(36, 8, 12), (86, 14, 22), (138, 22, 30), (184, 46, 40)],
    "straw":  [(66, 46, 16), (116, 82, 26), (168, 126, 40), (216, 174, 70)],
    "iron":   [(14, 14, 18), (36, 38, 46), (66, 70, 80), (106, 110, 120), (150, 154, 164)],
    "purple": [(26, 10, 42), (68, 28, 88), (109, 45, 133), (150, 62, 178), (192, 80, 224)],
    "chaosfire": [(88, 36, 110), (150, 62, 178), (192, 80, 224), (255, 128, 192), (255, 226, 245)],
    "green":  [(8, 28, 16), (20, 64, 34), (54, 128, 52), (112, 192, 80), (192, 244, 140)],
    "bone":   [(52, 44, 36), (110, 98, 82), (172, 160, 138), (222, 212, 184)],
    "fire":   [(120, 30, 10), (214, 84, 20), (255, 150, 40), (255, 214, 96), (255, 246, 190)],
    "glass":  [(60, 6, 12), (130, 14, 24), (200, 30, 36), (236, 80, 64)],
    "cloth":  [(52, 40, 28), (98, 80, 54), (146, 122, 84), (190, 164, 118)],
    "char":   [(8, 7, 7), (22, 18, 16), (40, 32, 28), (66, 54, 44)],
}

def bayer(h, w):
    b = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], float) / 16.0
    return np.tile(b, (h // 4 + 1, w // 4 + 1))[:h, :w]

class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.rgb = np.zeros((h, w, 3), np.uint8)
        self.a = np.zeros((h, w), bool)
        self.bay = bayer(h, w)
        self.rng = np.random.default_rng(0)

    # ---- maski
    def poly(self, pts):
        m = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(m).polygon([tuple(map(float, p)) for p in pts], fill=255)
        return np.array(m) > 0

    def ellipse(self, cx, cy, rx, ry):
        m = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(m).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
        return np.array(m) > 0

    def rect(self, x0, y0, x1, y1):
        m = np.zeros((self.h, self.w), bool)
        m[max(0, int(y0)):max(0, int(y1)), max(0, int(x0)):max(0, int(x1))] = True
        return m

    def line(self, p0, p1, width):
        m = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(m).line([tuple(p0), tuple(p1)], fill=255, width=int(width))
        return np.array(m) > 0

    # ---- malowanie
    def paint(self, mask, ramp, shade, noise=0.10, solid=None):
        """shade: tablica 0..1 (0 ciemno, 1 jasno) albo liczba. Dither Bayera między poziomami rampy."""
        r = RAMPS[ramp] if isinstance(ramp, str) else ramp
        n = len(r)
        s = np.broadcast_to(np.asarray(shade, float), (self.h, self.w)).copy()
        if noise:
            s += (self.rng.random((self.h, self.w)) - 0.5) * noise
        x = np.clip(s, 0, 0.9999) * (n - 1)
        lo = np.floor(x).astype(int)
        frac = x - lo
        idx = np.where(frac > self.bay, lo + 1, lo).clip(0, n - 1)
        col = np.array(r, np.uint8)[idx]
        self.rgb[mask] = col[mask]
        self.a |= mask

    def flat(self, mask, color):
        self.rgb[mask] = color
        self.a |= mask

    def volume(self, mask, ramp, light=(-0.55, -0.8), bulge=3.0, noise=0.12, base=0.55):
        """Kształt z cieniowaniem 'wypukłym': jasno od strony światła, ciemniej przy krawędzi pod światło."""
        d = ndimage.distance_transform_edt(mask)
        h = np.minimum(d, bulge) / bulge
        hs = ndimage.gaussian_filter(h, 1.2)
        gy, gx = np.gradient(hs)
        lit = -(gx * light[0] + gy * light[1]) * 2.2
        s = base + lit + (h - 0.5) * 0.25
        self.paint(mask, ramp, s, noise)

    def outline(self, color=OUTLINE, inner=False):
        """Ciemny 1-pikselowy kontur dookoła kształtu (na zewnątrz; płótno ma margines 1 px)."""
        grown = ndimage.binary_dilation(self.a, structure=np.ones((3, 3)) * 0)  # placeholder, niżej właściwa
        st = ndimage.generate_binary_structure(2, 1)
        grown = ndimage.binary_dilation(self.a, structure=st)
        edge = grown & ~self.a
        self.rgb[edge] = color
        self.a |= edge

    def inner_edge(self, mask, color):
        """Ciemny kontur na brzegu maski (wewnątrz)."""
        st = ndimage.generate_binary_structure(2, 1)
        er = ndimage.binary_erosion(mask, structure=st)
        e = mask & ~er
        self.rgb[e] = color
        self.a |= e

    def image(self):
        out = np.zeros((self.h, self.w, 4), np.uint8)
        out[..., :3] = self.rgb
        out[..., 3] = np.where(self.a, 255, 0)
        return Image.fromarray(out, "RGBA")
