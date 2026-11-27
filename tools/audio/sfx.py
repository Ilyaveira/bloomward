"""Bruitages et ambiances de Bloomward : synthèse (bruit filtré, sinus) et
quelques notes d'instruments VSCO 2 CE (CC0). Tout est original."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np, soundfile as sf
from scipy.signal import butter, sosfilt, fftconvolve
from sampler import *

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(11)
N = midi

def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], btype="band", fs=SR, output="sos"), x, axis=0)
def lp(x, f, order=2):
    return sosfilt(butter(order, f, btype="low", fs=SR, output="sos"), x, axis=0)
def noise(sec, ch=1):
    return rng.normal(0, 1, (int(sec * SR), ch)).astype(np.float32)
def save(name, x, peak=0.8):
    x = np.asarray(x, dtype=np.float32)
    if x.ndim == 1: x = x[:, None]
    x = x / (np.abs(x).max() + 1e-9) * peak
    sf.write(os.path.join(OUT, name + ".wav"), x, SR, subtype="PCM_16")
def seamless(x, fade=1.5):
    """Boucle sans couture : fondu enchaîné de la fin sur le début."""
    f = int(fade * SR); w = np.linspace(0, 1, f)[:, None] ** 0.5
    body = x[f:].copy()
    body[-f:] = body[-f:] * (1 - w ** 2) ** 0.5 + x[:f] * w
    return body
def slow(sec, rate, depth=1.0, seed=0):
    """Modulation lente et aléatoire entre 1-depth et 1."""
    r = np.random.default_rng(seed)
    pts = r.random(int(sec * rate) + 3)
    t = np.arange(int(sec * SR)) / SR * rate
    i = t.astype(int); f = t - i; f = f * f * (3 - 2 * f)
    return (1 - depth) + depth * (pts[i] * (1 - f) + pts[i + 1] * f)

# --- pas dans l'herbe : 5 variantes
for k in range(5):
    n = noise(0.22)[:, 0]; t = np.arange(len(n)) / SR
    swish = bp(n, 900 + 250 * k, 5200) * np.exp(-t * 26) * (1 - np.exp(-t * 400))
    thump = lp(noise(0.22)[:, 0], 160) * np.exp(-t * 38) * 2.2
    crackle = bp(noise(0.22)[:, 0], 2500, 9000) * (rng.random(len(n)) > 0.985) * np.exp(-t * 14) * 3
    save("pas_%d" % (k + 1), swish + thump + crackle, 0.5)

# --- pierre qui tourne : grondement + frottement
sec = 0.9; t = np.arange(int(sec * SR)) / SR
env = np.sin(np.pi * np.clip(t / sec, 0, 1)) ** 0.7
rumble = lp(noise(sec)[:, 0], 140, 4) * 3.0
grind = bp(noise(sec)[:, 0], 350, 1800) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 23 * t + 3 * np.sin(2 * np.pi * 3 * t))))
clack = np.zeros_like(t); c0 = int(0.78 * SR)
cl_n = bp(noise(0.1)[:, 0], 500, 3500) * np.exp(-np.arange(int(0.1 * SR)) / SR * 60) * 4
clack[c0:c0 + len(cl_n)] = cl_n[: len(clack) - c0]
save("pierre", (rumble + grind * 0.6) * env + clack, 0.7)

# --- petites notes d'interface et de jeu (instruments réels)
harp = Instrument("Strings/Harp", attack=0.002, release=1.0)
gl = Instrument("Percussion/Glock", attack=0.001, release=1.2)
pz = Instrument("Strings/Cello Section/pizzT", prefer="_v1", attack=0.001, release=0.5)
vln = Instrument("Strings/Violin Section/susVib", prefer="_v1", attack=0.5, release=1.6)
vc = Instrument("Strings/Cello Section/susvib", prefer="_v1", attack=0.5, release=1.6)
def phrase(events, sec, wet=0.3):
    tr = Track(sec)
    for inst, note, t0, dur, vel, pan in events:
        tr.add(inst, N(note), t0, dur, vel, pan, human=0.0)
    ir = reverb_ir(1.8)
    w = np.stack([fftconvolve(tr.buf[:, c], ir[:, c])[: len(tr.buf)] for c in (0, 1)], axis=1)
    return tr.buf + w * wet * 1.6

save("clic", phrase([(harp, "A5", 0, 0.5, 0.8, 0)], 0.9, 0.15), 0.45)
save("dalle", phrase([(gl, "A5", 0, 1.0, 0.7, 0), (harp, "D4", 0.0, 1.2, 0.6, 0)], 2.0), 0.6)
save("refus", phrase([(pz, "E3", 0, 0.4, 0.8, 0), (pz, "C#3", 0.16, 0.5, 0.7, 0)], 1.2, 0.2), 0.55)
save("accord", phrase([(harp, "D4", 0, 2, 0.7, -0.2), (harp, "A4", 0.09, 2, 0.7, 0), (harp, "D5", 0.18, 2, 0.75, 0.2),
                       (gl, "F#6", 0.27, 1.5, 0.5, 0.3)], 3.2), 0.65)
# --- la zone revit : glissando de harpe, accord de cordes qui s'ouvre, éclats
ev = []
scale = ["D3", "F#3", "A3", "B3", "D4", "E4", "F#4", "A4", "B4", "D5", "E5", "F#5", "A5", "B5", "D6", "F#6"]
for i, n in enumerate(scale):
    ev.append((harp, n, 0.05 + i * 0.075 * (1 + i * 0.012), 2.5, 0.5 + i * 0.03, -0.4 + i * 0.05))
for n, p in (("D3", 0.2), ("A3", 0.1), ("F#4", -0.2), ("A4", -0.3), ("D5", -0.35)):
    ev.append(((vc if n in ("D3", "A3") else vln), n, 0.9, 4.2, 0.6, p))
for i, n in enumerate(["A6", "F#6", "D7", "A6"]):
    ev.append((gl, n, 1.6 + i * 0.32, 1.5, 0.45, 0.3 - 0.2 * i))
save("eclosion", phrase(ev, 8.0, 0.4), 0.8)

# --- ambiance flétrie : vent sec, en boucle
sec = 24.0
w = noise(sec, 2)
wind = bp(w, 180, 900) * slow(sec, 0.22, 0.75, 1)[:, None] + bp(noise(sec, 2), 900, 2600) * 0.25 * slow(sec, 0.4, 0.95, 2)[:, None] ** 2
save("ambiance_vent", seamless(wind), 0.5)

# --- ambiance restaurée : brise dans les feuilles + chants d'oiseaux synthétiques
sec = 32.0
leaves = bp(noise(sec, 2), 1800, 7000) * 0.18 * slow(sec, 0.3, 0.8, 5)[:, None] ** 2 + bp(noise(sec, 2), 200, 700) * 0.12
birds = np.zeros((int(sec * SR), 2), dtype=np.float32)
def chirp(f0, f1, dur, vib=0.0):
    t = np.arange(int(dur * SR)) / SR
    f = f0 + (f1 - f0) * (t / dur) ** 0.7 + vib * np.sin(2 * np.pi * 28 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) + 0.25 * np.sin(2 * ph)) * np.sin(np.pi * t / dur) ** 1.5
br = np.random.default_rng(21)
t0 = 1.5
while t0 < sec - 4.5:
    kind = br.integers(0, 3); pan = br.uniform(-0.8, 0.8); vol = br.uniform(0.25, 0.7)
    g = np.array([np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)])
    notes = []
    if kind == 0:   # trille descendant
        base = br.uniform(3200, 4200)
        notes = [(i * 0.11, chirp(base * (1 - 0.04 * i), base * (0.88 - 0.04 * i), 0.08)) for i in range(br.integers(3, 6))]
    elif kind == 1: # deux notes sifflées
        base = br.uniform(2200, 2900)
        notes = [(0, chirp(base, base * 1.18, 0.22)), (0.3, chirp(base * 1.25, base * 1.02, 0.3, 40))]
    else:           # pépiements rapides
        base = br.uniform(4200, 5400)
        notes = [(i * 0.07 + br.uniform(0, 0.02), chirp(base * br.uniform(0.9, 1.1), base * br.uniform(1.05, 1.3), 0.045)) for i in range(br.integers(4, 9))]
    for dt, c in notes:
        s = int((t0 + dt) * SR)
        birds[s:s + len(c)] += c[:, None] * g * vol
    t0 += br.uniform(1.2, 3.8)
ir = reverb_ir(2.2, seed=9)
birds_w = np.stack([fftconvolve(birds[:, c], ir[:, c])[: len(birds)] for c in (0, 1)], axis=1)
save("ambiance_vie", seamless(leaves + (birds * 0.5 + birds_w * 0.9) * 0.16), 0.5)

# --- eau de la source : clapotis en boucle (mono, placé dans l'espace par le jeu)
sec = 12.0
n1 = bp(noise(sec)[:, 0], 500, 3200) * slow(sec, 9.0, 0.6, 31) * slow(sec, 0.8, 0.4, 32)
n2 = bp(noise(sec)[:, 0], 2500, 8000) * 0.35 * slow(sec, 14.0, 0.8, 33) ** 2
bub = np.zeros(int(sec * SR), dtype=np.float32)
for _ in range(110):
    s = rng.integers(0, len(bub) - 4000); d = rng.uniform(0.02, 0.06); f = rng.uniform(450, 1500)
    tt = np.arange(int(d * SR)) / SR
    bub[s:s + len(tt)] += np.sin(2 * np.pi * (f + f * 0.9 * tt / d) * tt) * np.sin(np.pi * tt / d) ** 2 * rng.uniform(0.3, 1)
save("eau", seamless((n1 + n2 + bub * 0.35)[:, None], 1.0), 0.6)
for f in sorted(os.listdir(OUT)):
    i = sf.info(os.path.join(OUT, f)); print(f, round(i.duration, 2), "s", i.channels, "canal(aux)")
