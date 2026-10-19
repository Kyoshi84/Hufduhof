"""Buduje 3 zapętlone motywy w stylu automatów z lat 90. na podstawie MELODII piosenki
"Oath of the Carroburg Guard" (Przysięga Szkarłatnej Gwardii). Z piosenki wzięte są wyłącznie:
tonacja (c-moll), tempo (136 BPM), progresja akordów (c - As - Es - B) i linia melodyczna wokalu,
wyłuskana z nagrania i oczyszczona ręcznie (zapis poniżej). Brzmienie jest w 100% syntezowane.

    python3 tools/build_music.py            # -> assets/audio/music/{menu,stage,boss}_theme.ogg
    python3 tools/build_music.py --wav      # dodatkowo zostawia WAV-y (podgląd)

Wymaga: numpy, scipy, ffmpeg (libvorbis).
"""
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from chipsynth import (SR, Track, midi_hz, fm_voice, pulse, kick, snare, hat, tom, crash, orch_hit,
                       echo_loop, reverb_loop, bitcrush, lowpass, noise)

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "assets", "audio", "music")

# ------------------------------------------------------------------ materiał z piosenki
# Akordy: (nazwa) -> (pryma MIDI, interwały)
CHORDS = {
    "Cm": (48, (0, 3, 7)), "Ab": (44, (0, 4, 7)), "Eb": (51, (0, 4, 7)), "Bb": (46, (0, 4, 7)),
    "G": (43, (0, 4, 7)), "Gm": (43, (0, 3, 7)), "Fm": (41, (0, 3, 7)), "Db": (49, (0, 4, 7)),
}

# Melodia refrenu ("I am the fire that drives out evil, the light that brings the dawn...").
# (nuta MIDI | None = pauza, długość w ósemkach); 8 ósemek = 1 takt.
CHORUS = [
    [(72, 6), (70, 1), (72, 1)],
    [(74, 1), (75, 1), (70, 6)],
    [(72, 1), (74, 7)],
    [(72, 1), (74, 1), (75, 2), (72, 4)],
    [(70, 1), (72, 5), (71, 1), (72, 1)],
    [(74, 1), (75, 1), (70, 3), (67, 3)],
    [(72, 1), (74, 4), (71, 1), (74, 1), (75, 1)],
    [(75, 1), (74, 1), (72, 6)],
]
CHORUS_CH = ["Ab", "Eb", "Bb", "Cm", "Ab", "Eb", "G", "Cm"]

# Melodia zwrotki ("Chaos is coming - and so begins my fight...").
VERSE = [
    [(72, 1), (72, 1), (75, 2), (75, 1), (77, 1), (75, 1), (71, 1)],
    [(72, 1), (70, 1), (79, 3), (77, 1), (75, 1), (77, 1)],
    [(77, 2), (70, 2), (79, 1), (74, 1), (72, 1), (74, 1)],
    [(75, 1), (74, 1), (75, 1), (71, 1), (72, 4)],
    [(79, 3), (77, 1), (79, 1), (75, 1), (75, 1), (72, 1)],
    [(74, 2), (72, 2), (74, 1), (75, 1), (77, 1), (79, 1)],
    [(79, 3), (77, 1), (75, 1), (72, 3)],
    [(71, 4), (74, 2), (79, 2)],
]
VERSE_CH = ["Cm", "Ab", "Eb", "Bb", "Cm", "Bb", "Cm", "G"]

SCALE_CM = [0, 2, 3, 5, 7, 8, 10]  # c-moll naturalny


def third_below(n, chord):
    """Druga linia (tercja niżej) w c-moll; nad G-dur używa h (harmoniczny moll)."""
    pc = n % 12
    sc = list(SCALE_CM)
    if chord == "G":
        sc[6] = 11
    if pc not in sc:
        return n - 3
    i = sc.index(pc)
    j = i - 2
    oct_ = 0
    if j < 0:
        j += 7
        oct_ = -12
    return n - pc + sc[j] + oct_


# ------------------------------------------------------------------ instrumenty

def lead_brass(hz, n, gate):
    return fm_voice(hz, n, ratio=1.0, index=3.2, index_decay=0.12, fb=0.6, vib=1.0, vib_delay=0.15,
                    a=0.006, d=0.35, s=0.75, r=0.10, gate=gate) * 0.55 + \
        pulse(hz, n, duty=0.25, a=0.004, d=0.2, s=0.5, r=0.08, gate=gate, vib=0.6) * 0.12


def lead_bell(hz, n, gate):
    return fm_voice(hz, n, ratio=3.5, index=2.0, index_decay=0.06, a=0.002, d=0.25, s=0.25, r=0.25, gate=gate)


def lead_square(hz, n, gate):
    return pulse(hz, n, duty=0.125, a=0.003, d=0.15, s=0.55, r=0.06, gate=gate, vib=0.8) * 0.5


def bass_fm(hz, n, gate):
    return np.tanh(fm_voice(hz, n, ratio=1.0, index=2.2, index_decay=0.05, fb=0.4, a=0.002, d=0.12, s=0.55,
                            r=0.04, gate=gate) * 1.6)


def pad_fm(hz, n, gate):
    return fm_voice(hz, n, ratio=2.0, index=0.7, index_decay=0.6, vib=0.4, a=0.08, d=0.6, s=0.8, r=0.3, gate=gate)


# ------------------------------------------------------------------ pisanie partii

def write_melody(tr, bus, bars, start_bar, inst, gain, transpose=0, pan=0.0, legato=0.92, harmony=None, chords=None):
    st = tr.step
    for bi, bar in enumerate(bars):
        pos = (start_bar + bi) * 16
        for note, ln in bar:
            steps = ln * 2
            if note is not None:
                n = note + transpose
                total = tr.steps_to_samples(steps) + int(0.35 * SR)
                gate = int(tr.steps_to_samples(steps) * legato)
                tr.add(bus, inst(midi_hz(n), total, gate), pos, gain, pan)
                if harmony is not None:
                    h = third_below(note, chords[bi % len(chords)]) + transpose
                    tr.add(bus, inst(midi_hz(h), total, gate), pos, gain * harmony, -pan)
            pos += steps


def write_bass(tr, chords, start_bar, pattern="drive", gain=0.5):
    for bi, ch in enumerate(chords):
        root, _ = CHORDS[ch]
        r = root - 12 if root >= 48 else root
        base = (start_bar + bi) * 16
        if pattern == "drive":       # ósemki z oktawą - klasyczny bas z automatów
            seq = [(0, r), (2, r + 12), (4, r), (6, r + 12), (8, r), (10, r + 12), (12, r + 7), (14, r + 12)]
            ln = 2
        elif pattern == "gallop":    # galop (boss)
            seq = []
            for k in range(4):
                seq += [(k * 4, r), (k * 4 + 2, r), (k * 4 + 3, r + (12 if k % 2 else 0))]
            ln = 1
        else:                        # spokojny (intro)
            seq = [(0, r), (6, r), (8, r + 7), (12, r + 12)]
            ln = 4
        for s, nt in seq:
            n = tr.steps_to_samples(ln) + int(0.05 * SR)
            tr.add("bass", bass_fm(midi_hz(nt), n, int(tr.steps_to_samples(ln) * 0.8)), base + s, gain)


def write_arp(tr, chords, start_bar, gain=0.13, octave=12, rate=1, pan=0.35):
    for bi, ch in enumerate(chords):
        root, iv = CHORDS[ch]
        notes = [root + octave + i for i in iv] + [root + octave + 12]
        order = [0, 1, 2, 3, 2, 1]
        base = (start_bar + bi) * 16
        for s in range(0, 16, rate):
            nt = notes[order[(s // rate) % len(order)]]
            n = tr.steps_to_samples(rate) + int(0.02 * SR)
            tr.add("arp", pulse(midi_hz(nt), n, duty=0.5, a=0.001, d=0.05, s=0.3, r=0.03,
                                gate=int(tr.steps_to_samples(rate) * 0.6)), base + s, gain, pan * (1 if s % 2 else -1))


def write_pad(tr, chords, start_bar, gain=0.07):
    for bi, ch in enumerate(chords):
        root, iv = CHORDS[ch]
        ln = tr.steps_to_samples(16)
        for i in iv:
            n = root + 12 + i
            tr.add("pad", pad_fm(midi_hz(n), ln + int(0.3 * SR), ln), (start_bar + bi) * 16, gain, (i - 3) / 10)


DRUMS = {}


def drum(name):
    if name not in DRUMS:
        DRUMS[name] = {"k": kick, "s": snare, "h": lambda: hat(False), "o": lambda: hat(True), "c": crash,
                       "t1": lambda: tom(180), "t2": lambda: tom(130), "t3": lambda: tom(95)}[name]()
    return DRUMS[name]


PATTERNS = {
    # 16 kroków: k=stopa, s=werbel, h=hi-hat, o=otwarty hat
    "rock":  {"k": [0, 8, 10], "s": [4, 12], "h": [0, 2, 4, 6, 8, 10, 12, 14], "o": [14]},
    "drive": {"k": [0, 3, 8, 10, 11], "s": [4, 12], "h": list(range(0, 16, 2)), "o": [6, 14]},
    "half":  {"k": [0, 10], "s": [8], "h": [0, 4, 8, 12]},
    "boss":  {"k": [0, 2, 3, 6, 8, 10, 11, 14], "s": [4, 12, 15], "h": list(range(16)), "o": []},
    "light": {"k": [0, 8], "s": [], "h": [4, 12]},
}


def write_drums(tr, pattern, start_bar, bars, gain=0.6, fill_last=True, crash_first=True):
    p = PATTERNS[pattern]
    for b in range(bars):
        base = (start_bar + b) * 16
        last = fill_last and b == bars - 1
        for name, steps in p.items():
            for s in steps:
                if last and s >= 8 and name in ("s", "k"):
                    continue
                g = {"k": 1.0, "s": 0.75, "h": 0.22, "o": 0.25}[name] * gain
                if name == "h" and s % 4 == 2:
                    g *= 0.6
                tr.add("drums", drum(name), base + s, g, 0.2 if name in "ho" else 0.0)
        if last:  # przejście na tomach i werblu
            for s, nm in ((8, "s"), (10, "t1"), (11, "t1"), (12, "t2"), (13, "t2"), (14, "t3"), (15, "s")):
                tr.add("drums", drum(nm), base + s, gain * 0.7, {"t1": -0.3, "t2": 0.0, "t3": 0.3}.get(nm, 0))
        if crash_first and b == 0:
            tr.add("drums", drum("c"), base, gain * 0.55, -0.3)


def hits(tr, steps_and_roots, gain=0.35):
    for pos, root in steps_and_roots:
        tr.add("fx", orch_hit(root), pos, gain)


# ------------------------------------------------------------------ miks

def mixdown(tr, gains, lead_echo=0.30, crush=12):
    out = np.zeros((tr.n, 2))
    for name, buf in tr.buses.items():
        x = buf * gains.get(name, 1.0)
        if name == "lead":
            x = echo_loop(x, tr.step * 3, 0.35, lead_echo)
        out += x
    out = reverb_loop(out, mix=0.16)
    out = np.stack([lowpass(out[:, 0], 12000), lowpass(out[:, 1], 12000)], axis=1)
    out = bitcrush(out, bits=crush, rate_div=1)
    peak = np.max(np.abs(out)) + 1e-9
    out = np.tanh(out / peak * 1.3) / np.tanh(1.3) * 0.89
    return out


def save(name, audio, keep_wav):
    import soundfile as sf
    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join(OUT, name + ".wav")
    ogg = os.path.join(OUT, name + ".ogg")
    sf.write(wav, audio, SR, subtype="PCM_16")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
    if not keep_wav:
        os.remove(wav)
    print("%-12s %5.1f s -> %s" % (name, len(audio) / SR, os.path.relpath(ogg, ROOT)))


# ------------------------------------------------------------------ utwory

def build_menu():
    """Motyw menu: pełna melodia refrenu i zwrotki, najbardziej 'heroiczne' brzmienie. 28 taktów."""
    intro = ["Cm", "Ab", "Eb", "Bb"]
    tr = Track(136, 28 * 16)
    # 0-3 intro: uderzenia orkiestry + pad + bas spokojny
    write_pad(tr, intro, 0, 0.09)
    write_bass(tr, intro, 0, "calm", 0.45)
    hits(tr, [(0, 48), (6, 48), (12, 48), (16, 44), (32, 51), (48, 46), (56, 46), (60, 46)])
    write_drums(tr, "half", 0, 4, 0.55, crash_first=False)
    # 4-11 refren (fanfara z drugim głosem)
    write_melody(tr, "lead", CHORUS, 4, lead_brass, 0.55, harmony=0.45, chords=CHORUS_CH)
    write_bass(tr, CHORUS_CH, 4, "drive")
    write_arp(tr, CHORUS_CH, 4, 0.10)
    write_pad(tr, CHORUS_CH, 4, 0.06)
    write_drums(tr, "rock", 4, 8)
    # 12-19 zwrotka (kwadrat, lżej)
    write_melody(tr, "lead", VERSE, 12, lead_square, 0.6, pan=-0.15)
    write_melody(tr, "lead", VERSE, 12, lead_bell, 0.12, transpose=12, pan=0.3, legato=0.5)
    write_bass(tr, VERSE_CH, 12, "drive", 0.45)
    write_arp(tr, VERSE_CH, 12, 0.08, rate=2)
    write_drums(tr, "drive", 12, 8, 0.55)
    # 20-27 refren oktawę wyżej, pełne tutti
    write_melody(tr, "lead", CHORUS, 20, lead_brass, 0.5, harmony=0.5, chords=CHORUS_CH)
    write_melody(tr, "lead", CHORUS, 20, lead_bell, 0.10, transpose=12, legato=0.4)
    write_bass(tr, CHORUS_CH, 20, "drive")
    write_arp(tr, CHORUS_CH, 20, 0.11)
    write_pad(tr, CHORUS_CH, 20, 0.07)
    write_drums(tr, "rock", 20, 8)
    hits(tr, [(27 * 16 + 12, 48)], 0.3)
    return mixdown(tr, {"lead": 1.0, "bass": 0.9, "arp": 1.0, "pad": 1.0, "drums": 0.85, "fx": 1.0})


def build_stage():
    """Tło rozgrywki etapów 1-4: dynamiczne, melodia schowana głębiej, dużo 'groove'. 44 takty."""
    groove = ["Cm", "Ab", "Eb", "Bb"]
    tr = Track(136, 44 * 16)
    # 0-3 rytm + bas + arpeggio
    write_bass(tr, groove, 0, "drive", 0.5)
    write_arp(tr, groove, 0, 0.10)
    write_drums(tr, "drive", 0, 4, 0.55, crash_first=False)
    # 4-11 zwrotka (kwadrat), 12-19 zwrotka (FM, z drugim głosem)
    write_melody(tr, "lead", VERSE, 4, lead_square, 0.42)
    write_bass(tr, VERSE_CH, 4, "drive", 0.5)
    write_arp(tr, VERSE_CH, 4, 0.08, rate=2)
    write_drums(tr, "drive", 4, 8, 0.55)
    write_melody(tr, "lead", VERSE, 12, lead_brass, 0.36, harmony=0.4, chords=VERSE_CH)
    write_bass(tr, VERSE_CH, 12, "drive", 0.5)
    write_arp(tr, VERSE_CH, 12, 0.09)
    write_pad(tr, VERSE_CH, 12, 0.05)
    write_drums(tr, "drive", 12, 8, 0.6)
    # 20-27 przerywnik: motyw refrenu na dzwonkach, bez melodii głównej (mniej męczy przy długiej walce)
    brk = ["Cm", "Cm", "Ab", "Ab", "Eb", "Eb", "G", "G"]
    motif = [CHORUS[0], [(None, 8)], CHORUS[1], [(None, 8)], CHORUS[2], [(None, 8)], CHORUS[7], [(None, 8)]]
    write_melody(tr, "lead", motif, 20, lead_bell, 0.22, transpose=12, legato=0.6)
    write_bass(tr, brk, 20, "drive", 0.5)
    write_arp(tr, brk, 20, 0.10, octave=0, pan=0.5)
    write_drums(tr, "rock", 20, 8, 0.55)
    # 28-35 refren (schowany), 36-43 groove + pojedyncze uderzenia (przejście do pętli)
    write_melody(tr, "lead", CHORUS, 28, lead_brass, 0.34, harmony=0.4, chords=CHORUS_CH)
    write_bass(tr, CHORUS_CH, 28, "drive", 0.5)
    write_arp(tr, CHORUS_CH, 28, 0.09)
    write_pad(tr, CHORUS_CH, 28, 0.05)
    write_drums(tr, "rock", 28, 8, 0.6)
    outro = groove * 2
    write_bass(tr, outro, 36, "drive", 0.5)
    write_arp(tr, outro, 36, 0.10, rate=2)
    write_drums(tr, "drive", 36, 8, 0.55)
    hits(tr, [(36 * 16, 48), (40 * 16, 48), (43 * 16 + 8, 46), (43 * 16 + 12, 46)], 0.25)
    return mixdown(tr, {"lead": 1.0, "bass": 1.0, "arp": 1.0, "pad": 1.0, "drums": 0.9, "fx": 1.0}, lead_echo=0.22)


def build_boss():
    """Walka z Czempionem Chaosu: szybciej (152 BPM), galopujący bas, refren w mrocznej reharmonizacji. 32 takty."""
    tr = Track(152, 32 * 16)
    dark = ["Cm", "Db", "Cm", "Db", "Cm", "Ab", "Fm", "G"]
    # 0-7 ostinato + uderzenia
    write_bass(tr, dark, 0, "gallop", 0.55)
    write_arp(tr, dark, 0, 0.09, octave=12)
    write_drums(tr, "boss", 0, 8, 0.6, crash_first=False)
    hits(tr, [(b * 16, CHORDS[c][0]) for b, c in enumerate(dark)], 0.3)
    # 8-15 refren (pierwsze 4 takty) x2, ostro
    ch4 = CHORUS[:4]
    write_melody(tr, "lead", ch4 + ch4, 8, lead_brass, 0.5, harmony=0.5, chords=CHORUS_CH[:4] * 2)
    write_bass(tr, CHORUS_CH[:4] * 2, 8, "gallop", 0.55)
    write_arp(tr, CHORUS_CH[:4] * 2, 8, 0.09)
    write_drums(tr, "boss", 8, 8, 0.6)
    # 16-23 zwrotka na kwadracie z echem + ostinato
    write_melody(tr, "lead", VERSE, 16, lead_square, 0.5)
    write_melody(tr, "lead", VERSE, 16, lead_bell, 0.12, transpose=12, legato=0.4)
    write_bass(tr, VERSE_CH, 16, "gallop", 0.55)
    write_pad(tr, VERSE_CH, 16, 0.06)
    write_drums(tr, "boss", 16, 8, 0.6)
    # 24-31 pełny refren - kulminacja
    write_melody(tr, "lead", CHORUS, 24, lead_brass, 0.5, harmony=0.55, chords=CHORUS_CH)
    write_melody(tr, "lead", CHORUS, 24, lead_bell, 0.1, transpose=12, legato=0.4)
    write_bass(tr, CHORUS_CH, 24, "gallop", 0.55)
    write_arp(tr, CHORUS_CH, 24, 0.1)
    write_pad(tr, CHORUS_CH, 24, 0.06)
    write_drums(tr, "boss", 24, 8, 0.62)
    return mixdown(tr, {"lead": 1.0, "bass": 0.95, "arp": 1.0, "pad": 1.0, "drums": 0.85, "fx": 1.0}, crush=11)


if __name__ == "__main__":
    keep = "--wav" in sys.argv
    save("menu_theme", build_menu(), keep)
    save("stage_theme", build_stage(), keep)
    save("boss_theme", build_boss(), keep)
