"""Petit échantillonneur orchestral (numpy) pour les sons de Bloomward.
Échantillons : VSCO 2 Community Edition (Versilian Studios), CC0.
"""
import os, re, glob
import numpy as np
import soundfile as sf
from scipy.signal import fftconvolve, butter, sosfilt

SR = 44100
VSCO = os.environ.get("VSCO", "/tmp/claude-0/audio_src/VSCO-2-CE")
NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

def midi(name):
    m = re.fullmatch(r"([A-G])(#|b)?(-?\d)", name)
    v = NOTE[m.group(1)] + (1 if m.group(2) == "#" else -1 if m.group(2) == "b" else 0)
    return v + 12 * (int(m.group(3)) + 1)

def detect_midi(x):
    """Hauteur fondamentale par autocorrélation sur le milieu du son."""
    mono = x.mean(axis=1)
    a = int(len(mono) * 0.15); seg = mono[a:a + 16384]
    if len(seg) < 4096: seg = mono[:16384]
    seg = seg - seg.mean()
    spec = np.fft.rfft(seg * np.hanning(len(seg)), 1 << 16)
    ac = np.fft.irfft(np.abs(spec) ** 2)
    lo, hi = int(SR / 2500), int(SR / 28)
    lag = lo + np.argmax(ac[lo:hi])
    # préfère le plus petit décalage presque aussi bon (évite l'octave du dessous)
    best = ac[lag]
    for div in (2, 3, 4):
        l2 = int(round(lag / div))
        if l2 >= lo and ac[l2 - 2:l2 + 3].max() > 0.85 * best:
            lag = l2 - 2 + int(np.argmax(ac[l2 - 2:l2 + 3]))
    return 69 + 12 * np.log2(SR / lag / 440.0)

class Instrument:
    def __init__(self, folder, pattern="*.wav", prefer=None, gain=1.0, attack=0.01, release=0.25):
        self.gain, self.attack, self.release = gain, attack, release
        self.samples = {}
        files = sorted(glob.glob(os.path.join(VSCO, folder, pattern)))
        if prefer:
            pref = [f for f in files if prefer in os.path.basename(f)]
            files = pref or files
        offs = []
        raw = []
        for f in files:
            m = re.search(r"_([A-G]#?-?\d)(_|\.)", os.path.basename(f))
            if not m: continue
            x, sr = sf.read(f, always_2d=True, dtype="float32")
            assert sr == SR
            if x.shape[1] == 1: x = np.repeat(x, 2, axis=1)
            # coupe le silence initial
            env = np.abs(x).max(axis=1)
            thr = env.max() * 0.02
            start = max(0, int(np.argmax(env > thr)) - 64)
            x = x[start:]
            x = x / (np.sqrt((x[:SR] ** 2).mean()) + 1e-6) * 0.1
            named = midi(m.group(1))
            raw.append((named, x))
            offs.append(detect_midi(x) - named)
        self.octave = int(round(np.median(offs) / 12.0)) * 12
        for named, x in raw:
            self.samples.setdefault(named + self.octave, x)
        self.keys = np.array(sorted(self.samples))

    def note(self, m, dur, vel=1.0):
        k = int(self.keys[np.argmin(np.abs(self.keys - m))])
        x = self.samples[k]
        ratio = 2 ** ((m - k) / 12.0)
        n = int((dur + self.release) * SR)
        idx = np.arange(n) * ratio
        if idx[-1] >= len(x) - 1:
            idx = idx[idx < len(x) - 1]
        i0 = idx.astype(int); fr = (idx - i0)[:, None]
        y = x[i0] * (1 - fr) + x[i0 + 1] * fr
        e = np.ones(len(y), dtype=np.float32)
        a = max(1, int(self.attack * SR)); r = max(1, min(int(self.release * SR), len(y) - 1))
        e[:a] *= np.linspace(0, 1, a) ** 1.5
        e[-r:] *= np.linspace(1, 0, r) ** 2
        return y * e[:, None] * vel * self.gain

class Track:
    def __init__(self, seconds):
        self.buf = np.zeros((int(seconds * SR), 2), dtype=np.float32)
        self.rng = np.random.default_rng(7)

    def add(self, inst, m, t, dur, vel=1.0, pan=0.0, human=0.012):
        t = max(0.0, t + self.rng.normal(0, human))
        vel = vel * (1 + self.rng.normal(0, 0.06))
        y = inst.note(m, dur, vel)
        g = np.array([np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)]) * 1.414
        s = int(t * SR); e = min(len(self.buf), s + len(y))
        self.buf[s:e] += y[:e - s] * g

def reverb_ir(seconds=2.6, seed=3):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = rng.normal(0, 1, (n, 2)) * np.exp(-t * 6.9 / seconds)[:, None]
    sos = butter(2, [180, 5200], btype="band", fs=SR, output="sos")
    ir = sosfilt(sos, ir, axis=0)
    ir[: int(0.012 * SR)] *= 0.0
    return (ir / np.sqrt((ir ** 2).sum())).astype(np.float32)

def finish(buf, loop_len, wet=0.30, seed=3):
    """Réverbération + repli de la queue sur le début pour une boucle sans couture."""
    ir = reverb_ir(seed=seed)
    wetsig = np.stack([fftconvolve(buf[:, c], ir[:, c]) for c in (0, 1)], axis=1)
    out = np.zeros((max(len(buf), len(wetsig)), 2), dtype=np.float32)
    out[: len(buf)] += buf * (1 - wet * 0.4)
    out[: len(wetsig)] += wetsig * wet * 1.6
    n = int(loop_len * SR)
    loop = out[:n].copy()
    tail = out[n:]
    if len(tail):
        loop[: len(tail)] += tail[:n]
    return loop
