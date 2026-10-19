#!/usr/bin/env python3
"""Walidator folderów grafik: co jest, czego brakuje, co jest źle.
  python3 tools/check_assets.py            # cały projekt
  python3 tools/check_assets.py --root DIR # inny katalog z assets/ (np. kopia robocza)
Kod wyjścia 1 = są BŁĘDY (zły rozmiar klatki, nieciągła numeracja); ostrzeżenia nie przerywają.
Brak pliku to nie błąd: gra używa wtedy grafiki zapasowej."""
import json, os, sys, argparse
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_spec as S

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
errors = 0; warns = 0

def say(kind, msg):
    global errors, warns
    if kind == "ERR": errors += 1
    if kind == "WARN": warns += 1
    print(f"  [{kind}] {msg}")

def palette(root):
    p = os.path.join(root, "assets/palette/hufduhof_256.png")
    if not os.path.exists(p): return None
    a = np.array(Image.open(p).convert("RGB")).reshape(-1, 3)
    return {tuple(c) for c in a}

def image_checks(path, im, pal, label, size=None, tile=False, edge=True):
    a = np.array(im.convert("RGBA"))
    if size and im.size != tuple(size):
        say("ERR", f"{label}: rozmiar {im.size[0]}x{im.size[1]}, oczekiwano {size[0]}x{size[1]}")
    al = a[..., 3]
    if ((al > 0) & (al < 255)).any():
        say("WARN", f"{label}: półprzezroczyste piksele (alfa 1-254); zalecane alfa 0/255")
    if pal is not None:
        px = a[al > 0][:, :3]
        if len(px):
            u = np.unique(px, axis=0)
            out = sum(1 for c in u if tuple(c) not in pal)
            if out:
                say("INFO", f"{label}: {out} kolorów spoza palety (gra dopasuje je do palety; `tools/quantize_png.py` robi to z góry)")
    if edge and (al[:, 0].any() or al[:, -1].any() or al[0].any()):
        say("WARN", f"{label}: sylwetka dotyka krawędzi płótna (ucięta broń?)")
    if tile:
        diff = np.abs(a[:, 0, :3].astype(int) - a[:, -1, :3].astype(int)).mean()
        if diff > 40:
            say("WARN", f"{label}: widoczny szew przy powtarzaniu poziomym (różnica lewej i prawej krawędzi {diff:.0f}/255)")

def frames_of(d, name):
    out = []
    i = 0
    while os.path.exists(os.path.join(d, f"{name}_{i:02d}.png")):
        out.append(os.path.join(d, f"{name}_{i:02d}.png")); i += 1
    extra = [f for f in os.listdir(d) if f.endswith(".png")] if os.path.isdir(d) else []
    return out, len(extra)

def check_characters(root, pal):
    for cid in S.CHARACTERS:
        mp = os.path.join(root, "assets/characters", cid, "character.json")
        print(f"\n== postać: {cid}")
        if not os.path.exists(mp):
            say("WARN", "brak character.json (uruchom tools/make_asset_folders.py)"); continue
        m = json.load(open(mp, encoding="utf-8"))
        have = 0
        for name, spec in m["animations"].items():
            d = os.path.join(root, "assets/characters", cid, "anim", name)
            fr, n_png = frames_of(d, name)
            if n_png > len(fr):
                say("ERR", f"anim/{name}: numeracja nieciągła ({n_png} plików PNG, ciągłych od _00: {len(fr)})")
            if not fr:
                print(f"  - {name:10s} brak (zapas)"); continue
            have += 1
            status = "OK" if len(fr) >= spec["frames"] else f"mniej niż zalecane ({spec['frames']})"
            print(f"  + {name:10s} {len(fr)} klatek, {status}")
            if "contact" in spec and spec["contact"][1] >= len(fr):
                say("ERR", f"{name}: klatka kontaktu {spec['contact']} poza liczbą klatek ({len(fr)})")
            for k, f in enumerate(fr):
                im = Image.open(f)
                image_checks(f, im, pal, f"{name}_{k:02d}", size=m["frame_size"], edge=True)
                if name in ("idle", "run") and k == 0:
                    al = np.array(im.convert("RGBA"))[..., 3]
                    rows = np.nonzero(al.any(1))[0]
                    if len(rows) and abs(int(rows.max()) - m["pivot"][1]) > 6:
                        say("WARN", f"{name}: stopy kończą się w y={rows.max()}, pivot w y={m['pivot'][1]}")
        if have == 0:
            print("  (brak animacji; postać używa grafiki zapasowej)")

def check_stages(root, pal):
    for sid in S.STAGES:
        mp = os.path.join(root, "assets/stages", sid, "stage.json")
        print(f"\n== etap: {sid}")
        if not os.path.exists(mp):
            say("WARN", "brak stage.json (uruchom tools/make_asset_folders.py)"); continue
        m = json.load(open(mp, encoding="utf-8"))
        for lname, spec in m["layers"].items():
            f = os.path.join(root, "assets/stages", sid, spec["file"])
            if not os.path.exists(f):
                print(f"  - warstwa {lname:10s} brak (zapas)"); continue
            im = Image.open(f)
            print(f"  + warstwa {lname:10s} {im.size[0]}x{im.size[1]}")
            image_checks(f, im, pal, spec["file"], tile=True, edge=False)
            if lname == "foreground" and im.size[1] > 67:
                say("WARN", "foreground wyższy niż 67 px: wejdzie w pas walki")
        for pname in m["props"]:
            base = os.path.join(root, "assets/stages", sid, "props")
            found = [f for f in [pname + ".png"] + [f"{pname}_{i}.png" for i in range(2, 7)] if os.path.exists(os.path.join(base, f))]
            if found:
                print(f"  + rekwizyt {pname:14s} {len(found)} wariant(y)")
                for f in found:
                    image_checks(f, Image.open(os.path.join(base, f)), pal, f"props/{f}", edge=True)
            else:
                print(f"  - rekwizyt {pname:14s} brak (zapas)")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=HERE)
    a = ap.parse_args()
    pal = palette(a.root) or palette(HERE)
    check_characters(a.root, pal)
    check_stages(a.root, pal)
    print(f"\nBłędy: {errors}, ostrzeżenia: {warns}")
    sys.exit(1 if errors else 0)

if __name__ == "__main__":
    main()
