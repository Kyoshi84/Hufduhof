#!/usr/bin/env python3
"""Dopasowuje PNG do wspólnej palety 256 kolorów (najbliższy kolor w Lab, bez ditheringu, alfa binarna).
  python3 tools/quantize_png.py wejscie.png [wejscie2.png | folder ...] --out KATALOG
Oryginały NIE są zmieniane (wynik trafia do --out, nazwy zachowane). Gra i tak dopasowuje obraz do palety
shaderem, więc to krok opcjonalny: daje podgląd i przewidywalny wynik."""
import argparse, os, sys
import numpy as np
from PIL import Image
import importlib.util
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("mp", os.path.join(HERE, "tools/make_palette.py"))
mp = importlib.util.module_from_spec(spec); spec.loader.exec_module(mp)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inputs", nargs="+"); ap.add_argument("--out", required=True)
    a = ap.parse_args()
    P = np.array(Image.open(os.path.join(HERE, "assets/palette/hufduhof_256.png")).convert("RGB")).reshape(-1, 3)
    plab = mp.srgb2lab(P)
    files = []
    for i in a.inputs:
        if os.path.isdir(i):
            for r, _, fs in os.walk(i):
                files += [os.path.join(r, f) for f in fs if f.endswith(".png")]
        else: files.append(i)
    os.makedirs(a.out, exist_ok=True)
    for f in files:
        im = np.array(Image.open(f).convert("RGBA"))
        idx = ((mp.srgb2lab(im[..., :3].astype(float))[..., None, :] - plab[None, None]) ** 2).sum(-1).argmin(-1)
        out = np.zeros_like(im); out[..., :3] = P[idx]; out[..., 3] = np.where(im[..., 3] >= 128, 255, 0)
        dst = os.path.join(a.out, os.path.basename(f))
        if os.path.abspath(dst) == os.path.abspath(f):
            sys.exit("--out wskazuje ten sam plik: oryginały nie są nadpisywane")
        Image.fromarray(out).save(dst); print("zapisano", dst)

if __name__ == "__main__":
    main()
