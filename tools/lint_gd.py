#!/usr/bin/env python3
"""Prosty lint GDScript (heurystyka ostrzeżeń edytora Godota): nieużyte zmienne lokalne i parametry,
dzielenie liczb całkowitych, nazwy przesłaniające wbudowane właściwości. Uruchom: python3 tools/lint_gd.py"""
import re, sys, glob
OBJECT = {"tr", "get", "set", "free", "notification"}
NODE = OBJECT | {"name", "owner", "process_mode"}
CANVAS = NODE | {"visible", "modulate", "material", "z_index", "show", "hide", "draw"}
NODE2D = CANVAS | {"position", "scale", "rotation", "transform", "global_position"}
CONTROL = CANVAS | {"size", "position", "scale", "rotation", "theme"}
probs = []
for f in sorted(glob.glob("scripts/**/*.gd", recursive=True)):
    src = open(f).read()
    lines = src.split("\n")
    ext = (re.search(r'^extends (\w+)', src, re.M) or [None, "RefCounted"])[1]
    BUILTIN = OBJECT
    if ext in ("Node", "CanvasLayer"):
        BUILTIN = NODE
    elif ext in ("Node2D", "CharacterBody2D", "Sprite2D", "StaticBody2D", "Interactable", "Actor", "Level"):
        BUILTIN = NODE2D
    elif ext in ("Control", "VBoxContainer", "HBoxContainer", "PanelContainer"):
        BUILTIN = CONTROL
    funcs = []
    cur = None
    for i, l in enumerate(lines):
        m = re.match(r'^(\t*)(static )?func (\w+)\((.*)\)', l)
        if m:
            cur = {"indent": len(m.group(1)), "start": i, "params": m.group(4), "body": []}
            funcs.append(cur)
            continue
        if cur is not None:
            if l.strip() and (len(l) - len(l.lstrip("\t"))) <= cur["indent"] and not l.startswith("\t" * (cur["indent"] + 1)):
                cur = None
            else:
                cur["body"].append((i, l))
    for fn in funcs:
        body = "\n".join(l for _, l in fn["body"])
        for p in [x.strip() for x in fn["params"].split(",") if x.strip()]:
            pn = re.match(r'(\w+)', p).group(1)
            if pn.isdigit():
                continue
            if not pn.startswith("_") and not re.search(r'\b%s\b' % pn, body):
                probs.append("%s:%d parametr '%s' nieużyty" % (f, fn["start"] + 1, pn))
            if pn in BUILTIN:
                probs.append("%s:%d parametr '%s' przesłania wbudowaną nazwę" % (f, fn["start"] + 1, pn))
        for idx, (i, l) in enumerate(fn["body"]):
            m = re.match(r'^\s*var (\w+)', l)
            if m:
                vn = m.group(1)
                rest = "\n".join(x for _, x in fn["body"][idx + 1:]) + l.split("=", 1)[-1] if "=" in l else ""
                after = "\n".join(x for _, x in fn["body"][idx + 1:])
                if not vn.startswith("_") and not re.search(r'\b%s\b' % vn, after):
                    probs.append("%s:%d zmienna '%s' nieużyta" % (f, i + 1, vn))
                if vn in BUILTIN:
                    probs.append("%s:%d zmienna '%s' przesłania wbudowaną nazwę" % (f, i + 1, vn))
    for i, l in enumerate(lines):
        code = l.split("#")[0]
        for m in re.finditer(r'(\w+\(\)|\b\w+\.size\(\)|\b[a-z_]\w*)\s*/\s*(\d+)\b(?!\.)', code):
            if "float(" in code or re.search(r'\d\.\d', m.group(0)):
                continue
            probs.append("%s:%d możliwe dzielenie całkowite: %s" % (f, i + 1, m.group(0).strip()))
print("\n".join(probs) if probs else "brak podejrzeń")
