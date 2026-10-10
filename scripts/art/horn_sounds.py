"""Bakes each car's horn (the Horn action; docs/CAR_ART.md, "Horn") into sound/horn/<car>.wav.

Everything is synthesised here with transition_sounds.py's helpers, so change this file and re-run it
rather than editing the WAVs:  python scripts/art/horn_sounds.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import transition_sounds as ts  # noqa: E402

RATE = ts.RATE
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "sound", "horn")


def hold(n, attack=0.012, release=0.05, peak=1.0):
    """Up fast, held, down at the end: a horn is pressed, not struck"""
    a, r = max(1, int(attack * RATE)), max(1, int(release * RATE))
    return [peak * min(1.0, i / a, (n - i) / r) for i in range(n)]


def blast(freqs, dur, kind="saw", cutoff=2200, sag=0.0, vibrato=0.0, level=1.0):
    """Detuned tones through a low-pass: one press of a horn. `sag` drops the pitch by that share over the
    blast (a tired horn), `vibrato` wobbles it."""
    n = int(dur * RATE)
    tones = []
    for k, f0 in enumerate(freqs):
        f = (lambda f0: lambda i: f0 * (1.0 - sag * i / n) * (1.0 + vibrato * math.sin(2 * math.pi * 6.0 * i / RATE)))(f0)
        tones.append(ts.osc(kind, f, n, phase=0.13 * k))
    body = ts.biquad(ts.mix(*tones), "low", cutoff)
    return ts.gain(ts.mul(body, hold(n)), level)


def then(*parts):
    out = []
    for p in parts: out += p
    return out


def sweep(f, dur, kind="sine", cutoff=4000):
    n = int(dur * RATE)
    tone = ts.mix(ts.osc(kind, f, n), ts.gain(ts.osc("square", lambda i: f(i) * 1.005, n), 0.35))
    return ts.mul(ts.biquad(tone, "low", cutoff), hold(n, 0.01, 0.06))


HORNS = {
    "sedan": lambda: blast([330, 415], 0.36, "saw", 1700, sag=0.08),                       # a tired bleat
    "van": lambda: blast([262, 330], 0.42, "square", 1400),                                 # a low honk
    "taxi": lambda: then(blast([440, 554], 0.13), ts.silence(0.06), blast([440, 554], 0.2)),  # honk-honk
    "pickup": lambda: then(blast([520, 655], 0.1, "square", 2600), ts.silence(0.07), blast([520, 655], 0.1, "square", 2600)),
    "supercar": lambda: blast([700, 880], 0.26, "saw", 3800),                                   # sharp and high
    "racer": lambda: blast([820, 1035], 0.17, "saw", 4200, vibrato=0.01),                  # a quick chirp
    "police": lambda: sweep(lambda i: 600 + 800 * math.sin(math.pi * min(1.0, i / (0.42 * RATE))), 0.45),  # whoop
    "ambulance": lambda: sweep(lambda i: 720 if (i // int(0.085 * RATE)) % 2 == 0 else 1000, 0.5, "square", 3000),  # yelp
    "semi": lambda: blast([155, 196, 233], 0.95, "saw", 1150, vibrato=0.004),              # the air horn
}


def write(name, samples, level=0.85):
    ts.OUT = OUT
    ts.write(name, samples, level)


if __name__ == "__main__":
    for car, make in HORNS.items():
        write(car, make())
    print("baked", sorted(os.listdir(OUT)))
