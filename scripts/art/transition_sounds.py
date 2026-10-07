"""Bakes the transition sounds (docs/UI.md, "Transitions") into sound/ui/transition/*.wav.

One sound family for the garage shutter and the tires: thud, clank, rattle, screech, hiss, plus a
few variations (skid, whoosh, pop, rev). Everything is synthesised here, so change this file and
re-run it rather than editing the WAVs:  python scripts/art/transition_sounds.py
"""
import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "sound", "ui", "transition")


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def noise(n, seed):
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def biquad(samples, kind, freq, q=0.707):
    """RBJ cookbook filter; freq may be a number or a function of the sample index."""
    out = []
    x1 = x2 = y1 = y2 = 0.0
    for i, x in enumerate(samples):
        f = freq(i) if callable(freq) else freq
        w = 2 * math.pi * min(f, RATE * 0.45) / RATE
        alpha = math.sin(w) / (2 * q)
        cw = math.cos(w)
        if kind == "low":
            b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
        elif kind == "high":
            b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
        else:  # band
            b0, b1, b2 = alpha, 0.0, -alpha
        a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
        y = (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1, y2, y1 = x1, x, y1, y
        out.append(y)
    return out


def envelope(n, attack, decay, peak=1.0):
    a = max(1, int(attack * RATE))
    out = []
    for i in range(n):
        if i < a:
            out.append(peak * i / a)
        else:
            t = (i - a) / RATE
            out.append(peak * math.exp(-5.0 * t / max(decay, 1e-3)))
    return out


def osc(kind, freq, n, phase=0.0):
    out = []
    for i in range(n):
        f = freq(i) if callable(freq) else freq
        phase += f / RATE
        p = phase % 1.0
        if kind == "sine":
            out.append(math.sin(2 * math.pi * p))
        elif kind == "saw":
            out.append(2 * p - 1)
        else:  # square
            out.append(1.0 if p < 0.5 else -1.0)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def gain(a, g):
    return [x * g for x in a]


def write(name, samples, level=0.9):
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = level / peak
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        tail = int(0.01 * RATE)
        frames = bytearray()
        for i, s in enumerate(samples):
            fade = min(1.0, (len(samples) - i) / tail)
            frames += struct.pack("<h", int(max(-1.0, min(1.0, s * scale * fade)) * 32767))
        w.writeframes(bytes(frames))


def thud(v=1.0, seed=1):
    n = int(0.45 * RATE)
    body = mul(osc("sine", lambda i: 38 + 57 * math.exp(-i / (0.08 * RATE)), n), envelope(n, 0.004, 0.34, 0.9 * v))
    knock = mul(biquad(noise(n, seed), "low", 380), envelope(n, 0.002, 0.14, 0.7 * v))
    return mix(body, knock)


def clank(seed=2):
    n = int(0.32 * RATE)
    parts = []
    for k, f in enumerate([233, 371, 529]):
        tone = biquad(osc("square", f, n), "band", f * 2, 6)
        parts.append(mul(tone, envelope(n, 0.002, 0.2 - k * 0.04, 0.5)))
    tick = mul(biquad(noise(n, seed), "high", 2500), envelope(n, 0.001, 0.06, 0.6))
    return mix(*parts, tick)


def rattle(dur=0.5, seed=3):
    n = int(dur * RATE)
    gate = []
    step = int(0.032 * RATE)
    for i in range(n):
        gate.append(math.exp(-((i % step) / RATE) / 0.008) * 0.8)
    clatter = mul(biquad(noise(n, seed), "band", 1700, 2), gate)
    motor = mul(biquad(osc("saw", 55, n), "low", 300), envelope(n, 0.05, dur, 0.25))
    return mix(clatter, motor)


def screech(dur=0.4, v=1.0, seed=4):
    n = int(dur * RATE)
    f = lambda i: 1750 - 300 * i / n + 140 * math.sin(2 * math.pi * 31 * i / RATE)
    squeal = mul(biquad(osc("saw", f, n), "band", 2100, 5), envelope(n, 0.02, dur, 0.6 * v))
    hissy = mul(biquad(noise(n, seed), "band", 2600, 3), envelope(n, 0.02, dur, 0.9 * v))
    return mix(squeal, hissy)


def hiss(dur=0.55, seed=5):
    n = int(dur * RATE)
    return mul(biquad(noise(n, seed), "band", 3400, 0.8), envelope(n, 0.03, dur))


def whoosh(dur=0.4, seed=6):
    n = int(dur * RATE)
    sweep = biquad(noise(n, seed), "band", lambda i: 300 * (6 ** min(1.0, i / (n * 0.6))), 1.2)
    env = [math.sin(math.pi * min(1.0, i / n)) ** 1.5 for i in range(n)]
    return mul(sweep, env)


def pop(seed=7):
    n = int(0.3 * RATE)
    burst = mul(biquad(noise(n, seed), "band", 700, 1.2), envelope(n, 0.001, 0.06))
    return mix(gain(thud(0.45, seed), 1.0), burst)


def rev(dur=0.45, seed=8):
    n = int(dur * RATE)
    f = lambda i: 60 + 130 * math.sin(math.pi * min(1.0, i / (n * 0.85)))
    engine = mul(biquad(osc("saw", f, n), "low", 800), envelope(n, 0.03, dur, 0.7))
    rumble = mul(biquad(noise(n, seed), "low", 300), envelope(n, 0.03, dur, 0.5))
    return mix(engine, rumble)


if __name__ == "__main__":
    write("thud", thud())
    write("clank", clank(), 0.7)
    write("rattle", rattle(), 0.6)
    write("screech", screech(), 0.55)
    write("skid", screech(0.18, 0.7, 9), 0.5)
    write("hiss", hiss(), 0.45)
    write("whoosh", whoosh(), 0.6)
    write("pop", pop(), 0.7)
    write("rev", rev(), 0.6)
    print("baked", sorted(os.listdir(OUT)))
