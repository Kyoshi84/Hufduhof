"""Mały syntezator w stylu automatów z lat 90. (FM jak YM2151 / CPS-1, kwadraty, szum).
Używany przez tools/build_music.py. Wszystko liczone w numpy, bez próbek z zewnątrz."""
import numpy as np

SR = 44100


def midi_hz(n):
    return 440.0 * 2.0 ** ((n - 69) / 12.0)


def adsr(n, a, d, s, r, sr=SR, gate=None):
    """Obwiednia o długości n próbek; gate = długość trzymania (próbki)."""
    gate = n if gate is None else min(gate, n)
    env = np.zeros(n)
    A = max(1, int(a * sr)); D = max(1, int(d * sr)); R = max(1, int(r * sr))
    t = np.arange(n)
    env = np.where(t < A, t / A, s + (1 - s) * np.exp(-(t - A) / D * 3.0))
    rel = t >= gate
    if rel.any():
        level = env[min(gate, n - 1)]
        env[rel] = level * np.exp(-(t[rel] - gate) / R * 4.0)
    return env


def fm_voice(hz, n, ratio=1.0, index=2.5, index_decay=0.25, fb=0.0, vib=0.0, vib_rate=5.5, vib_delay=0.18,
             a=0.004, d=0.25, s=0.7, r=0.12, gate=None, sr=SR):
    """2-operatorowe FM: modulator (ratio) -> nośna. index opada w czasie (typowy 'dzwoniący' atak)."""
    t = np.arange(n) / sr
    vibd = np.clip((t - vib_delay) / 0.25, 0, 1) * vib
    f = hz * (1 + vibd * np.sin(2 * np.pi * vib_rate * t) * 0.012)
    ph = np.cumsum(2 * np.pi * f / sr)
    idx = index * (0.35 + 0.65 * np.exp(-t / max(index_decay, 1e-3)))
    mod = np.sin(ph * ratio)
    if fb:
        mod = np.sin(ph * ratio + fb * mod)
    y = np.sin(ph + idx * mod)
    return y * adsr(n, a, d, s, r, sr, gate)


def pulse(hz, n, duty=0.5, a=0.002, d=0.1, s=0.6, r=0.05, gate=None, sr=SR, vib=0.0):
    t = np.arange(n) / sr
    f = hz * (1 + vib * np.sin(2 * np.pi * 6 * t) * 0.01)
    ph = np.cumsum(f / sr) % 1.0
    y = np.where(ph < duty, 1.0, -1.0)
    return y * adsr(n, a, d, s, r, sr, gate)


_rng = np.random.default_rng(1990)


def noise(n):
    return _rng.uniform(-1, 1, n)


def lowpass(x, cutoff, sr=SR):
    a = np.exp(-2 * np.pi * cutoff / sr)
    from scipy.signal import lfilter
    return lfilter([1 - a], [1, -a], x)


def highpass(x, cutoff, sr=SR):
    return x - lowpass(x, cutoff, sr)


def kick(sr=SR):
    n = int(0.28 * sr); t = np.arange(n) / sr
    f = 45 + 120 * np.exp(-t * 28)
    y = np.sin(np.cumsum(2 * np.pi * f / sr)) * np.exp(-t * 11)
    y += noise(n) * np.exp(-t * 120) * 0.25
    return np.tanh(y * 1.6)


def snare(sr=SR):
    n = int(0.22 * sr); t = np.arange(n) / sr
    tone = np.sin(np.cumsum(2 * np.pi * (190 - 60 * t) / sr)) * np.exp(-t * 22)
    nz = highpass(noise(n), 900) * np.exp(-t * 16)
    return np.tanh((tone * 0.6 + nz * 0.9) * 1.3)


def hat(open_=False, sr=SR):
    n = int((0.18 if open_ else 0.05) * sr); t = np.arange(n) / sr
    return highpass(noise(n), 6500) * np.exp(-t * (14 if open_ else 70)) * 0.6


def tom(hz, sr=SR):
    n = int(0.3 * sr); t = np.arange(n) / sr
    f = hz * (1 + 0.6 * np.exp(-t * 20))
    return np.sin(np.cumsum(2 * np.pi * f / sr)) * np.exp(-t * 9)


def crash(sr=SR):
    n = int(1.4 * sr); t = np.arange(n) / sr
    return highpass(noise(n), 4000) * np.exp(-t * 3.2) * 0.5


def orch_hit(root, sr=SR):
    """Klasyczny 'orchestra hit' z automatów: akord FM z szybkim spadkiem."""
    n = int(0.6 * sr)
    y = np.zeros(n)
    for iv in (0, 7, 12, 15, 19):
        y += fm_voice(midi_hz(root + iv), n, ratio=1.0, index=4.0, index_decay=0.05, a=0.001, d=0.12, s=0.15, r=0.2)
    y += highpass(noise(n), 2000) * np.exp(-np.arange(n) / sr * 25) * 0.6
    return y / 4


class Track:
    """Bufor stereo, do którego dodaje się nuty w jednostkach kroków (16-tki)."""

    def __init__(self, bpm, steps, sr=SR):
        self.sr = sr
        self.step = 60.0 / bpm / 4.0
        self.n = int(round(steps * self.step * sr))
        self.buses = {}

    def bus(self, name):
        if name not in self.buses:
            self.buses[name] = np.zeros((self.n, 2))
        return self.buses[name]

    def add(self, name, sig, step_pos, gain=1.0, pan=0.0):
        """Dodaje sygnał; to, co wystaje poza koniec, zawija na początek (bezszwowa pętla)."""
        b = self.bus(name)
        start = int(round(step_pos * self.step * self.sr)) % self.n
        L = np.sqrt(0.5 * (1 - pan)) * gain
        R = np.sqrt(0.5 * (1 + pan)) * gain
        pos = 0
        while pos < len(sig):
            s0 = (start + pos) % self.n
            k = min(len(sig) - pos, self.n - s0)
            b[s0:s0 + k, 0] += sig[pos:pos + k] * L
            b[s0:s0 + k, 1] += sig[pos:pos + k] * R
            pos += k

    def steps_to_samples(self, steps):
        return int(steps * self.step * self.sr)


def echo_loop(x, delay_s, fb, mix, sr=SR, lp=3500):
    """Echo (jak w automatach), liczone cyklicznie, by pętla się nie urywała."""
    d = int(delay_s * sr)
    out = x.copy()
    tap = x.copy()
    for _ in range(int(np.log(0.01) / np.log(fb)) if fb > 0 else 0):
        tap = np.roll(tap, d, axis=0) * fb
        tap = np.stack([lowpass(tap[:, 0], lp), lowpass(tap[:, 1], lp)], axis=1)
        out += tap * mix
    return out


def reverb_loop(x, sr=SR, mix=0.18):
    """Prosty pogłos z kilku cyklicznych opóźnień (Schroeder-light)."""
    out = x.copy()
    for ms, g, sw in ((29.7, 0.55, 1), (37.1, 0.5, -1), (41.1, 0.45, 1), (43.7, 0.42, -1), (61.3, 0.3, 1), (83.9, 0.25, -1)):
        d = int(ms / 1000 * sr)
        tap = x.copy()
        acc = np.zeros_like(x)
        for k in range(1, 8):
            tap = np.roll(tap, d, axis=0) * g
            acc += tap
        acc = acc[:, ::sw] if sw < 0 else acc
        out += acc * mix * 0.3
    return out


def bitcrush(x, bits=12, rate_div=2):
    """Lekkie 'zbrudzenie' jak w starych DAC-ach automatów."""
    q = 2 ** (bits - 1)
    y = np.round(x * q) / q
    if rate_div > 1:
        y = np.repeat(y[::rate_div], rate_div, axis=0)[:len(x)]
    return y
