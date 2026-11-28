"""Musique originale de Bloomward, rendue en deux pistes synchronisées :
  - base  : harpe + cordes graves (zone flétrie, menu)
  - bloom : mélodie et cordes aiguës, ajoutées à mesure que la zone revit
Composition originale ; échantillons VSCO 2 CE (CC0).
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np, soundfile as sf
from sampler import *

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
BPM = 72.0; BEAT = 60.0 / BPM; BAR = 4 * BEAT; BARS = 32; LEN = BARS * BAR
N = midi

harp = Instrument("Strings/Harp", gain=1.0, attack=0.002, release=1.2)
vln = Instrument("Strings/Violin Section/susVib", prefer="_v1", gain=0.55, attack=0.35, release=0.9)
vla = Instrument("Strings/Viola Section/susvib", prefer="_v1", gain=0.5, attack=0.4, release=0.9)
vc = Instrument("Strings/Cello Section/susvib", prefer="_v1", gain=0.6, attack=0.4, release=1.0)
cb = Instrument("Strings/Solo Contrabass/SusVib", prefer="_v1", gain=0.5, attack=0.3, release=0.9)
fl = Instrument("Woodwinds/Flute/susvib", gain=0.8, attack=0.06, release=0.35)
hn = Instrument("Brass/F Horn/sus", prefer="_v1", gain=0.6, attack=0.12, release=0.5)
cl = Instrument("Woodwinds/Clarinet/susLong", prefer="_v1", gain=0.55, attack=0.08, release=0.4)
ob = Instrument("Woodwinds/Oboe/Vib", prefer="_v1", gain=0.5, attack=0.06, release=0.35)
gl = Instrument("Percussion/Glock", gain=0.35, attack=0.001, release=1.5)
pz = Instrument("Strings/Violin Section/Pizz", prefer="_v1_rr1", gain=0.7, attack=0.001, release=0.3)

# accord : (basse, [notes de l'accord autour du do central])
CH = {
    "D":    ("D2",  ["D3", "A3", "D4", "F#4", "A4"]),
    "A/C#": ("C#2", ["C#3", "A3", "C#4", "E4", "A4"]),
    "Bm":   ("B1",  ["B2", "F#3", "B3", "D4", "F#4"]),
    "G":    ("G1",  ["G2", "D3", "G3", "B3", "D4"]),
    "D/F#": ("F#2", ["F#3", "A3", "D4", "F#4", "A4"]),
    "Em7":  ("E2",  ["E3", "B3", "D4", "G4", "B4"]),
    "Em":   ("E2",  ["E3", "B3", "E4", "G4", "B4"]),
    "A":    ("A1",  ["A2", "E3", "A3", "C#4", "E4"]),
    "Asus": ("A1",  ["A2", "E3", "A3", "D4", "E4"]),
    "F#m":  ("F#2", ["F#3", "C#4", "F#4", "A4", "C#5"]),
}
SEC_A = ["D", "A/C#", "Bm", "G", "D/F#", "G", "Em7", "A"]
SEC_B = ["Bm", "F#m", "G", "D", "Em", "G", "Asus", "A"]
PROG = SEC_A + SEC_A + SEC_B + SEC_A

MEL_A = [("F#5", 3), ("A5", 1), ("E5", 2), ("C#5", 1), ("E5", 1), ("D5", 3), ("F#5", 1), ("B4", 2), ("D5", 2),
         ("A5", 3), ("F#5", 1), ("G5", 2), ("B5", 1), ("A5", 1), ("G5", 1), ("F#5", 1), ("E5", 2), ("E5", 3), (None, 1)]
MEL_A3 = MEL_A[:14] + [("G5", 1), ("F#5", 1), ("E5", 1), ("D5", 1), ("E5", 4)]
MEL_B = [("B4", 1), ("D5", 1), ("F#5", 2), ("E5", 1), ("C#5", 1), ("A4", 2), ("G4", 1), ("B4", 1), ("D5", 2),
         ("F#5", 3), ("E5", 1), ("G5", 2), ("E5", 2), ("B5", 2), ("G5", 2), ("A5", 2), ("G5", 1), ("D5", 1),
         ("E5", 2), ("C#5", 1), ("E5", 1)]
for m in (MEL_A, MEL_A3, MEL_B):
    assert sum(b for _, b in m) == 32, sum(b for _, b in m)

def melody(track, inst, mel, bar0, transpose=0, vel=1.0, pan=0.0, legato=0.96, skip=(0, 99)):
    t = 0.0
    for name, beats in mel:
        if name and skip[0] <= t / 4 < skip[1]:
            track.add(inst, N(name) + transpose, bar0 * BAR + t * BEAT, beats * BEAT * legato, vel, pan)
        t += beats

base = Track(LEN + 6); bloom = Track(LEN + 6)

for b, name in enumerate(PROG):
    bass, tones = CH[name]
    t0 = b * BAR
    sec = b // 8
    tn = [N(x) for x in tones]
    # --- harpe (piste de base) : arpèges en croches, plus dépouillés au début
    pattern = [0, 1, 2, 3, 4, 3, 2, 1]
    for i, p in enumerate(pattern):
        if sec == 0 and i in (5, 7): continue
        if sec == 2 and i % 2 == 1 and i != 3: continue
        v = 0.75 if i == 0 else 0.5 + 0.08 * (i % 2 == 0)
        base.add(harp, tn[p] + (12 if sec == 3 and i in (3, 4) else 0), t0 + i * BEAT / 2, 1.6, v, pan=-0.25 + 0.1 * p)
    if sec in (1, 3):
        base.add(harp, tn[4] + 12, t0 + 2 * BEAT, 2.0, 0.4, pan=0.2)
    # --- cordes graves (piste de base)
    base.add(cb, N(bass), t0, BAR * 0.98, 0.55, pan=0.3, human=0.0)
    base.add(vc, N(bass) + 12, t0, BAR * 0.98, 0.5, pan=0.2, human=0.0)
    base.add(vla, tn[1] if tn[1] >= 48 else tn[1] + 12, t0, BAR * 0.98, 0.33, pan=0.05, human=0.0)
    # --- violons (piste d'éclosion) : nappe à deux voix
    hi = 12 if sec == 3 else 0
    bloom.add(vln, tn[3] + hi, t0, BAR * 0.98, 0.42 if sec != 3 else 0.5, pan=-0.35, human=0.0)
    bloom.add(vln, tn[4] + hi if tn[4] + hi <= 86 else tn[4], t0, BAR * 0.98, 0.36, pan=-0.15, human=0.0)
    bloom.add(vla, tn[2], t0, BAR * 0.98, 0.32, pan=0.1, human=0.0)
    # --- pizzicati légers dans la section centrale
    if sec == 2:
        for i in (1, 2, 3):
            bloom.add(pz, tn[2 + (i % 2)] + 12, t0 + i * BEAT, 0.4, 0.5, pan=-0.3)
    # --- glockenspiel : éclats sur le premier temps dans la reprise finale
    if sec == 3 or (sec == 1 and b % 2 == 0):
        bloom.add(gl, tn[3] + 24, t0, 1.5, 0.5, pan=0.35)
        if sec == 3:
            bloom.add(gl, tn[4] + 24, t0 + 2.5 * BEAT, 1.5, 0.35, pan=0.4)

# --- mélodies (piste d'éclosion)
melody(bloom, fl, MEL_A, 0, vel=0.8, pan=0.1)
melody(bloom, hn, MEL_A, 8, transpose=-12, vel=0.7, pan=-0.2, skip=(0, 4))
melody(bloom, fl, MEL_A, 8, vel=0.85, pan=0.1, skip=(4, 8))
melody(bloom, ob, MEL_B, 16, vel=0.75, pan=0.15)
melody(bloom, fl, MEL_B, 16, transpose=12, vel=0.4, pan=0.1, skip=(4, 8))
melody(bloom, fl, MEL_A3, 24, vel=0.9, pan=0.1)
melody(bloom, vln, MEL_A3, 24, vel=0.55, pan=-0.3, legato=1.0)
# cor : contrechant tenu dans la reprise finale
for b, name in enumerate(SEC_A):
    bloom.add(hn, N(CH[name][1][2]), (24 + b) * BAR, BAR * 0.95, 0.4, pan=-0.2, human=0.0)
# --- clarinette (piste de base) : la section centrale garde une voix, même zone flétrie
melody(base, cl, MEL_B, 16, transpose=-12, vel=0.5, pan=-0.1)

a = finish(base.buf, LEN, wet=0.34, seed=3)
c = finish(bloom.buf, LEN, wet=0.34, seed=4)
peak = np.abs(a + c).max()
g = 0.84 / peak
a *= g; c *= g
os.makedirs(OUT, exist_ok=True)
sf.write(os.path.join(OUT, "musique_base.wav"), a, SR, subtype="PCM_16")
sf.write(os.path.join(OUT, "musique_eclosion.wav"), c, SR, subtype="PCM_16")
def db(x): return round(20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-9), 1)
print("durée", round(LEN, 3), "s ; RMS base", db(a), "dB ; éclosion", db(c), "dB ; somme", db(a + c), "dB ; crête base", round(np.abs(a).max(), 2))
