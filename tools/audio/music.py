"""Seamless music loops (synthwave / cyberpunk family).

Each song is rendered over its loop length plus a tail; the tail (reverb, delay
repeats, note releases) is then wrapped into the head, which is exactly what the
start of the loop sounds like on every repeat after the first, so the loop point
is sample-accurate and click free. Master processing after the wrap is circular.
"""
from __future__ import annotations

import math

import numpy as np

from .dsp import (
    SR, TAU, adsr, chorus, compress, convolve, crush, db, delay, drive, eq, fade, filt,
    fit, fm, limiter, mix, mtof, noise, normalize, ns, pan, perc, phase, pink, place,
    pulse, reverb_ir, rms_db, saw, sine, smooth, square, supersaw, sweep, to_mono,
    to_stereo, tri, widen,
)
from .instruments import (
    bell, clap, crash, decay_env, hat, kick, line_arrays, note_env, snare, thunder, tom,
)


class Song:
    def __init__(self, bpm: float, bars: int, rng, tail: float = 5.0):
        self.bpm = bpm
        self.bars = bars
        self.spb = 60.0 / bpm
        self.bar = 4 * self.spb
        self.sec = bars * self.bar
        self.L = int(round(self.sec * SR))
        self.T = ns(tail)
        self.N = self.L + self.T
        self.r = rng
        self.buses: dict[str, np.ndarray] = {}
        self.kicks: list[float] = []

    # time helpers
    def t(self, bar: float, step: float = 0.0) -> float:
        """Seconds for bar + 16th step."""
        return bar * self.bar + step * self.spb / 4.0

    def bus(self, name: str) -> np.ndarray:
        if name not in self.buses:
            self.buses[name] = np.zeros((2, self.N))
        return self.buses[name]

    def hit(self, name: str, sample, sec: float, gain=1.0, p=0.0, jitter=0.0):
        if jitter:
            sec += self.r.uniform(-jitter, jitter)
        s = sample if sample.ndim == 2 else pan(sample, p)
        place(self.bus(name), s, ns(sec), gain)

    def auto(self, points, kind="lin") -> np.ndarray:
        """Automation over the whole render, points in (bar, value)."""
        tt = np.arange(self.N) / SR / self.bar
        bs = np.array([p[0] for p in points], float)
        vs = np.array([p[1] for p in points], float)
        if kind == "exp":
            return np.exp(np.interp(tt, bs, np.log(np.maximum(vs, 1e-6))))
        return np.interp(tt, bs, vs)

    def duck(self, depth=0.6, tau=0.14, attack=0.004) -> np.ndarray:
        """Sidechain gain curve from recorded kick times (periodic across the loop)."""
        g = np.ones(self.N)
        k = np.arange(ns(tau * 5)) / SR
        shape = 1.0 - depth * np.exp(-k / tau) * np.minimum(k / attack + 0.3, 1.0)
        times = list(self.kicks) + [x + self.sec for x in self.kicks if x + self.sec < self.N / SR]
        for tsec in times:
            s = ns(tsec)
            m = min(len(shape), self.N - s)
            if m > 0:
                g[s : s + m] = np.minimum(g[s : s + m], shape[:m])
        return g

    def wrap(self, x: np.ndarray) -> np.ndarray:
        loop = x[:, : self.L].copy()
        loop[:, : self.T] += x[:, self.L : self.L + self.T]
        return loop


# ----------------------------------------------------------------------------
# instrument renderers working on a whole song
# ----------------------------------------------------------------------------
def render_mono_line(song: Song, notes, osc="bass", cutoff=(180.0, 1600.0), q=1.3, ftau=0.12,
                     env=(0.003, 0.15, 0.55, 0.04), glide=0.008, lfo=None, drive_amt=1.5) -> np.ndarray:
    n = song.N
    if not notes:
        return np.zeros(n)
    f = line_arrays(notes, n, glide)
    t = np.arange(n) / SR
    r = song.r
    if osc == "bass":
        x = saw(f, n) * 0.55 + pulse(f * 0.5, n, 0.5) * 0.45 + sine(f * 0.5, n) * 0.35
    elif osc == "reese":
        x = saw(f * 2 ** (11 / 1200), n, 0.1) * 0.5 + saw(f * 2 ** (-11 / 1200), n, 0.6) * 0.5 + sine(f * 0.5, n) * 0.6
    elif osc == "arp":
        w = 0.5 + 0.32 * np.sin(TAU * 0.13 * t)
        x = pulse(f, n, w) * 0.6 + saw(f * 2.0 * 1.002, n) * 0.25 + sine(f, n) * 0.2
    elif osc == "arpsaw":
        x = saw(f, n) * 0.5 + saw(f * 1.006, n, 0.3) * 0.4 + square(f * 0.5, n) * 0.2
    elif osc == "lead":
        vib = 1 + 0.0045 * np.sin(TAU * 5.4 * t) * np.clip(decay_env(notes, n, 0.25) * -1 + 1, 0, 1)
        x = saw(f * vib, n) * 0.5 + saw(f * vib * 1.004, n, 0.4) * 0.35 + pulse(f * vib * 0.5, n, 0.3) * 0.2
    elif osc == "siren":
        x = square(f, n) * 0.6 + saw(f * 1.003, n) * 0.4
    else:
        raise ValueError(osc)
    c0, c1 = cutoff
    cut = c0 + (c1 - c0) * decay_env(notes, n, ftau)
    if lfo is not None:
        rate, depth = lfo
        cut = cut * (1 + depth * np.sin(TAU * rate * t))
    x = sweep(x, "lp", cut, q)
    a, d, s, rl = env
    x = x * note_env(notes, n, a, d, s, rl)
    return drive(x, drive_amt)


def render_pad(song: Song, chords, cutoff=(800.0, 2600.0), voices=5, detune=0.22, attack=0.45,
               release=1.1, ftau=1.0) -> np.ndarray:
    """chords = [(start_s, dur_s, [midis], gain)] -> stereo bus (per-chord supersaws)."""
    out = np.zeros((2, song.N))
    r = song.r
    for (st, du, ms, g) in chords:
        L = du + release
        n = ns(L)
        tt = np.arange(n) / SR
        acc = np.zeros((2, n))
        for m in ms:
            acc += supersaw(mtof(m), n, r, voices, detune, 0.95)
        c0, c1 = cutoff
        cut = c1 - (c1 - c0) * np.exp(-tt / ftau)
        acc = sweep(acc, "lp", cut, 0.8, frame=2048, nfft=4096)
        acc = acc * adsr(L, attack, 0.8, 0.85, release, n=n) / math.sqrt(len(ms))
        place(out, acc, ns(st), g)
    return out


def vinyl(n: int, r, amount=1.0) -> np.ndarray:
    """Crackle + hiss + slow wow rumble texture (stereo)."""
    out = np.zeros((2, n))
    hiss = np.stack([pink(n, r), pink(n, r)])
    hiss = filt(hiss, "hp", 2500) * 0.05
    out += hiss
    cnt = int(n / SR * 9)
    pos = r.integers(0, n - 400, cnt)
    imp = np.zeros((2, n))
    for p in pos:
        ch = r.integers(0, 2)
        imp[ch, p] += r.choice([-1, 1]) * r.uniform(0.2, 1.0) ** 2
    imp = filt(imp, "bp", 3200, 0.6) * 1.4
    pops = np.zeros((2, n))
    for p in r.integers(0, n - 400, int(n / SR * 0.6)):
        pops[:, p] += r.uniform(0.4, 1.0)
    pops = filt(pops, "lp", 900) * 0.5
    out += imp + pops
    return out * amount


def master(song: Song, mixbus: np.ndarray, target_rms=-20.0, ceiling=-3.0) -> np.ndarray:
    x = song.wrap(mixbus)
    x = eq(x, [("hp", 28.0, 0.7, 0), ("lowshelf", 90.0, 0.7, 1.0), ("peak", 350.0, 0.9, -1.5), ("highshelf", 9000.0, 0.7, 1.0)], circular=True)
    x = compress(x, -16.0, 2.0, 0.01, 0.2, 0.0, circular=True)
    x = x * db(target_rms - rms_db(x))
    x = limiter(x, ceiling, attack=0.003, release=0.12, circular=True)
    x = filt(x, "hp", 18.0, 0.6, circular=True)
    return x


def _arp_notes(song, bars, chords_per_bar, pattern, length=0.9, vel_fn=None, octave=0, step_div=4):
    notes = []
    steps = 4 * step_div
    for b in bars:
        ch = chords_per_bar(b)
        tones = sorted(ch) + [m + 12 for m in sorted(ch)]
        for s in range(steps):
            m = tones[pattern[s % len(pattern)] % len(tones)] + octave
            v = vel_fn(b, s) if vel_fn else (1.0 if s % 4 == 0 else 0.75)
            notes.append((song.t(b, s * 4 / step_div), song.spb / step_div * length, m, v))
    return notes


# ----------------------------------------------------------------------------
# MusicMain — dark synthwave, D minor, 100 BPM, 32 bars (76.8 s)
# ----------------------------------------------------------------------------
def music_main(r) -> np.ndarray:
    S = Song(100, 32, r)
    prog = [  # (bass root, pad voicing) per 2 bars
        (38, [60, 62, 65, 69]),  # Dm7
        (34, [58, 62, 65, 69]),  # Bbmaj7
        (41, [57, 60, 64, 65]),  # Fmaj7
        (36, [55, 60, 62, 64]),  # Cadd9
    ]
    ch_of = lambda b: prog[(b // 2) % 4]
    # --- drums
    K = [kick(r, 0.5, 165, 45, 0.03, 0.24, 0.45, 1.7, 0.25) for _ in range(2)]
    SN = snare(r, 0.5, 185, 1.0, 0.8, 0.13)
    CL = clap(r, 0.5, 0.15)
    HC = [hat(r, 0.07, 0.016, 1.0 + 0.02 * i) for i in range(3)]
    HO = hat(r, 0.4, 0.13, 1.0)
    CR = crash(r, 3.0, 0.9)
    TM = [tom(r, f, 0.5) for f in (150, 120, 95)]

    def groove(b, ghost=False, fill=False):
        for s in (0, 8):
            S.hit("kick", K[0], S.t(b, s), 1.0)
            S.kicks.append(S.t(b, s))
        if b % 2 == 1:
            S.hit("kick", K[1], S.t(b, 11), 0.75)
            S.kicks.append(S.t(b, 11))
        for s in (4, 12):
            S.hit("snare", SN, S.t(b, s), 0.85)
            S.hit("snare", CL, S.t(b, s) + 0.006, 0.45)
        for s in range(0, 16, 2):
            acc = 1.0 if s % 4 == 2 else 0.6
            S.hit("hats", HC[r.integers(0, 3)], S.t(b, s), 0.5 * acc, 0.25, 0.002)
        if ghost:
            for s in range(1, 16, 2):
                S.hit("hats", HC[r.integers(0, 3)], S.t(b, s), 0.16, 0.3, 0.003)
        if b % 2 == 1:
            S.hit("hats", HO, S.t(b, 14), 0.35, -0.2)
        if fill:
            for i, s in enumerate((12, 13, 14, 15)):
                S.hit("drums_fx", TM[min(i, 2)], S.t(b, s), 0.6, -0.4 + 0.3 * i)

    for b in range(32):
        if b < 8:
            groove(b, ghost=False)
        elif b < 16:
            groove(b, ghost=True)
        elif b < 22:
            for s in (0, 4, 8, 12):
                S.hit("hats", HC[0], S.t(b, s), 0.22, 0.3)
            if b >= 20:
                S.hit("kick", K[0], S.t(b, 0), 0.6)
                S.kicks.append(S.t(b, 0))
        elif b < 24:
            # build: snare roll
            rate = 2 if b == 22 else 1
            for s in range(0, 16, rate):
                g = 0.25 + 0.55 * ((b - 22) * 16 + s) / 32.0
                S.hit("snare", SN, S.t(b, s), g * 0.7, 0.0)
            for s in range(0, 16, 4):
                S.hit("kick", K[0], S.t(b, s), 0.7)
                S.kicks.append(S.t(b, s))
        else:
            groove(b, ghost=True, fill=(b == 31))
    for b in (0, 8, 24):
        S.hit("crash", CR, S.t(b), 0.5)
    # --- bass
    bass_pat = [(0, 0, 1.8), (2, 0, 0.9), (4, 12, 0.9), (6, 0, 0.9), (8, 0, 1.8), (10, 0, 0.9), (11, 12, 0.9), (12, 0, 0.9), (14, 12, 0.9)]
    bass_notes = []
    for b in range(32):
        if 16 <= b < 20:
            continue
        root = ch_of(b)[0]
        for (s, o, L) in bass_pat:
            v = 1.0 if s in (0, 8) else 0.8
            bass_notes.append((S.t(b, s), L * S.spb / 4, root + o, v))
    bass = render_mono_line(S, bass_notes, "bass", (160, 1500), 1.6, 0.11, (0.003, 0.18, 0.6, 0.05))
    bass_cut = S.auto([(0, 1), (16, 1), (20, 0.35), (23.9, 0.9), (24, 1), (32, 1)])
    bass = filt(bass, "lp", 4000) * (0.55 + 0.45 * bass_cut)
    S.bus("bass")[:] += pan(bass, 0)
    # --- pad
    chords = [(S.t(b), S.bar * 2, ch_of(b)[1], 1.0) for b in range(0, 32, 2)]
    pad = render_pad(S, chords, (700, 2400), 5, 0.24, 0.5, 1.2)
    S.bus("pad")[:] += pad
    # --- arp (enters bar 4)
    arp_pat = [0, 2, 4, 3, 5, 4, 6, 5, 7, 6, 4, 5, 3, 4, 2, 1]
    arp_notes = _arp_notes(S, range(4, 32), lambda b: ch_of(b)[1], arp_pat, 0.6)
    arp = render_mono_line(S, arp_notes, "arp", (900, 4200), 2.2, 0.07, (0.002, 0.09, 0.25, 0.04), glide=0.0, lfo=(0.05, 0.25), drive_amt=1.2)
    arp_level = S.auto([(0, 0), (4, 0.0), (4.01, 0.7), (8, 1.0), (16, 1.0), (17, 0.55), (22, 0.8), (24, 1.0), (32, 1.0)])
    S.bus("arp")[:] += pan(arp * arp_level, 0.15)
    # --- lead (bars 8-15, 24-31)
    phrase_a = [(0, 1.5, 69), (1.5, .5, 65), (2, 1, 67), (3, 1, 69), (4, 2, 74), (6, 1, 72), (7, 1, 69),
                (8, 3, 70), (11, .5, 69), (11.5, .5, 67), (12, 2, 65), (14, 1, 67), (15, 1, 69),
                (16, 1.5, 72), (17.5, .5, 69), (18, 1, 72), (19, 1, 77), (20, 2, 76), (22, 1, 74), (23, 1, 72),
                (24, 2, 76), (26, 1, 74), (27, 1, 72), (28, 3, 67)]
    phrase_b = phrase_a[:-4] + [(24, 1, 76), (25, 1, 79), (26, 1, 76), (27, 1, 74), (28, 2, 72), (30, 2, 74)]
    lead_notes = []
    for start, ph in ((8, phrase_a), (12, phrase_b), (24, phrase_a), (28, phrase_b)):
        for (bt, L, m) in ph:
            lead_notes.append((S.t(start) + bt * S.spb, L * S.spb * 0.95, m, 0.9))
    lead = render_mono_line(S, lead_notes, "lead", (1200, 3600), 1.0, 0.3, (0.012, 0.3, 0.75, 0.18), glide=0.03, drive_amt=1.3)
    S.bus("lead")[:] += chorus(lead, 0.7, 2.0, 11, 0.45)
    # --- build riser (bars 22-24)
    rn = ns(S.bar * 2)
    rp = np.arange(rn) / rn
    rz = sweep(np.stack([noise(rn, r), noise(rn, r)]), "bp", 300 * (8000 / 300) ** rp, 1.5) * rp**2.5
    place(S.bus("fx"), rz, ns(S.t(22)), 0.35)
    # --- mix
    duck = S.duck(0.55, 0.16)
    dsend = np.zeros((2, S.N))
    out = np.zeros((2, S.N))
    gains = {"kick": 0.9, "snare": 0.55, "hats": 0.35, "crash": 0.3, "drums_fx": 0.5, "bass": 0.55,
             "pad": 0.32, "arp": 0.22, "lead": 0.24, "fx": 0.4}
    for k, v in S.buses.items():
        g = gains.get(k, 0.5)
        if k in ("bass", "pad", "arp", "lead"):
            v = v * duck
        out += v * g
    # sends
    arp_d = delay(S.buses["arp"] * duck, S.spb * 0.75, 0.38, 1.0, lp=3500, pingpong=True, tail=0)
    lead_d = delay(S.buses["lead"], S.spb * 0.75, 0.32, 1.0, lp=4000, pingpong=True, tail=0)
    out += (fit(arp_d, S.N) - S.buses["arp"] * duck) * 0.22 * 0.45
    out += (fit(lead_d, S.N) - S.buses["lead"]) * 0.24 * 0.35
    rsend = S.buses["snare"] * 0.5 + S.buses["pad"] * 0.35 + S.buses["arp"] * 0.25 + S.buses["lead"] * 0.3 + S.buses.get("drums_fx", 0) * 0.3
    ir = reverb_ir(2.6, 1.2, 0.4, 0.02, 7000, 200)
    out += fit(convolve(rsend, ir), S.N) * 0.11
    x = master(S, out, -20.0, -3.0)
    x += vinyl(S.L, r, 1.0) * db(-38)
    x = limiter(x, -3.0, circular=True)
    return x


# ----------------------------------------------------------------------------
# MusicStorm — driving, A minor, 128 BPM, 32 bars (60 s)
# ----------------------------------------------------------------------------
def music_storm(r) -> np.ndarray:
    S = Song(128, 32, r)
    prog = [
        (33, [57, 60, 64, 71]),  # Am(add9)
        (29, [57, 60, 65, 69]),  # F
        (36, [55, 60, 64, 67]),  # C
        (31, [55, 59, 62, 67]),  # G
    ]
    ch_of = lambda b: prog[(b // 2) % 4]
    K = kick(r, 0.42, 180, 48, 0.026, 0.19, 0.6, 1.9, 0.2)
    SN = snare(r, 0.4, 200, 1.1, 0.7, 0.1)
    CL = clap(r, 0.45, 0.12)
    HC = [hat(r, 0.06, 0.013, 1.0 + 0.03 * i, 9000) for i in range(3)]
    HO = hat(r, 0.3, 0.09, 1.02, 8000)
    CR = crash(r, 2.8, 0.8)
    TM = [tom(r, f, 0.45) for f in (170, 135, 105, 85)]

    def groove(b, ghosts=True, fill=False, kick_on=True):
        if kick_on:
            for s in (0, 4, 8, 12):
                S.hit("kick", K, S.t(b, s), 1.0)
                S.kicks.append(S.t(b, s))
        for s in (4, 12):
            S.hit("snare", SN, S.t(b, s), 0.75)
            S.hit("snare", CL, S.t(b, s) + 0.004, 0.55)
        for s in range(16):
            if s % 4 == 2:
                S.hit("hats", HO, S.t(b, s), 0.32, -0.15, 0.001)
            elif ghosts or s % 2 == 0:
                acc = 0.55 if s % 2 == 0 else 0.3
                S.hit("hats", HC[r.integers(0, 3)], S.t(b, s), acc, 0.25, 0.002)
        if fill:
            for i, s in enumerate((8, 10, 12, 13, 14, 15)):
                S.hit("drums_fx", TM[min(i // 2 + (i > 3), 3)], S.t(b, s), 0.6, -0.5 + 0.2 * i)

    for b in range(32):
        if b < 16:
            groove(b, ghosts=b >= 4, fill=(b == 15))
        elif b < 20:
            for s in range(0, 16, 2):
                S.hit("hats", HC[0], S.t(b, s), 0.25, 0.3)
        elif b < 24:
            groove(b, ghosts=False, kick_on=True)
            if b >= 22:
                for s in range(0, 16, 1 if b == 23 else 2):
                    S.hit("snare", SN, S.t(b, s), 0.2 + 0.5 * ((b - 22) * 16 + s) / 32)
        else:
            groove(b, ghosts=True, fill=(b == 31))
    for b in (0, 8, 16, 24):
        S.hit("crash", CR, S.t(b), 0.5)
    # rolling bass
    bass_notes = []
    for b in range(32):
        if 16 <= b < 20:
            for s in (0, 8):
                bass_notes.append((S.t(b, s), S.spb * 1.8, ch_of(b)[0], 0.7))
            continue
        root = ch_of(b)[0]
        for s in range(16):
            if s % 4 == 0:
                continue  # leave room for the kick
            o = 12 if s % 4 == 2 and s in (6, 14) else 0
            v = 1.0 if s % 4 == 2 else 0.78
            bass_notes.append((S.t(b, s), S.spb / 4 * 0.8, root + o + 12, v))
    bass = render_mono_line(S, bass_notes, "bass", (200, 2200), 1.8, 0.07, (0.002, 0.08, 0.5, 0.03), glide=0.004, drive_amt=2.0)
    S.bus("bass")[:] += pan(bass, 0)
    chords = [(S.t(b), S.bar * 2, ch_of(b)[1], 1.0) for b in range(0, 32, 2)]
    S.bus("pad")[:] += render_pad(S, chords, (900, 3200), 5, 0.26, 0.3, 1.0, 0.8)
    arp_pat = [0, 4, 2, 5, 1, 6, 3, 7, 4, 2, 6, 3, 5, 1, 7, 2]
    arp_notes = _arp_notes(S, range(32), lambda b: ch_of(b)[1], arp_pat, 0.55, octave=12)
    arp = render_mono_line(S, arp_notes, "arpsaw", (1200, 6000), 2.4, 0.05, (0.001, 0.06, 0.2, 0.03), glide=0.0, lfo=(0.0625, 0.3), drive_amt=1.2)
    arp_lvl = S.auto([(0, 0.7), (4, 0.9), (16, 1.0), (24, 1.0), (32, 0.7)])
    S.bus("arp")[:] += pan(arp * arp_lvl, -0.2)
    # offbeat chord stabs (B and D sections)
    stab = []
    for b in list(range(8, 16)) + list(range(24, 32)):
        for s in (2, 6, 10, 14):
            st = S.t(b, s)
            stab.append((st, ch_of(b)[1]))
    sb = S.bus("stab")
    for (st, ms) in stab:
        n = ns(0.25)
        acc = np.zeros((2, n))
        for m in ms:
            acc += supersaw(mtof(m + 12), n, r, 3, 0.15, 0.8)
        tt = np.arange(n) / SR
        acc = sweep(acc, "lp", 800 + 5000 * np.exp(-tt / 0.05), 1.2, frame=512, nfft=2048) * perc(0.25, 0.002, 0.07, n)
        place(sb, acc, ns(st), 0.5)
    # lead motif (D section)
    motif = [(0, .5, 76), (.5, .5, 74), (1, 1, 72), (2, .5, 71), (2.5, 1, 72), (3.5, .5, 74),
             (4, 1.5, 76), (5.5, .5, 79), (6, 2, 77),
             (8, .5, 76), (8.5, .5, 74), (9, 1, 72), (10, .5, 71), (10.5, 1, 69), (11.5, .5, 67), (12, 4, 69)]
    lead_notes = []
    for start in (24, 28):
        for (bt, L, m) in motif:
            lead_notes.append((S.t(start) + bt * S.spb, L * S.spb * 0.95, m, 0.9))
    lead = render_mono_line(S, lead_notes, "lead", (1500, 4500), 1.1, 0.25, (0.01, 0.25, 0.8, 0.15), glide=0.025, drive_amt=1.5)
    S.bus("lead")[:] += chorus(lead, 0.8, 2.2, 10, 0.45)
    # storm FX: wind bed + thunder
    n = S.N
    tt = np.arange(n) / SR
    wind_c = 600 * (1 + 0.6 * np.sin(TAU * tt / 9.37)) * (1 + 0.3 * np.sin(TAU * tt / 3.1))
    wind = sweep(np.stack([noise(n, r), noise(n, r)]), "bp", wind_c, 2.5, frame=2048)
    wind *= 0.6 + 0.4 * np.sin(TAU * tt / 7.3 + 1.0)
    S.bus("fx")[:] += wind * 0.25
    for b in (3, 13, 18, 27):
        th = thunder(r, 4.5)
        S.hit("fx", np.stack([th, np.roll(th, 150)]), S.t(b, 6), 0.8)
    # build riser
    rn = ns(S.bar * 2)
    rp = np.arange(rn) / rn
    rz = sweep(np.stack([noise(rn, r), noise(rn, r)]), "bp", 300 * (9000 / 300) ** rp, 1.5) * rp**2.5
    place(S.bus("fx"), rz, ns(S.t(22)), 0.6)
    duck = S.duck(0.6, 0.12)
    gains = {"kick": 0.95, "snare": 0.5, "hats": 0.32, "crash": 0.28, "drums_fx": 0.5, "bass": 0.5,
             "pad": 0.26, "arp": 0.2, "stab": 0.2, "lead": 0.24, "fx": 0.35}
    out = np.zeros((2, S.N))
    for k, v in S.buses.items():
        if k in ("bass", "pad", "arp", "stab", "lead"):
            v = v * duck
        out += v * gains.get(k, 0.5)
    arp_d = delay(S.buses["arp"] * duck, S.spb * 0.75, 0.35, 1.0, lp=4000, pingpong=True, tail=0)
    out += (fit(arp_d, S.N) - S.buses["arp"] * duck) * 0.2 * 0.4
    lead_d = delay(S.buses["lead"], S.spb * 0.5, 0.35, 1.0, lp=4500, pingpong=True, tail=0)
    out += (fit(lead_d, S.N) - S.buses["lead"]) * 0.24 * 0.35
    rsend = S.buses["snare"] * 0.45 + S.buses["pad"] * 0.3 + S.buses["stab"] * 0.4 + S.buses["lead"] * 0.3
    ir = reverb_ir(2.2, 1.1, 0.4, 0.015, 7500, 200)
    out += fit(convolve(rsend, ir), S.N) * 0.1
    x = master(S, out, -19.0, -3.0)
    x += vinyl(S.L, r, 0.6) * db(-42)
    return limiter(x, -3.0, circular=True)


# ----------------------------------------------------------------------------
# MusicPanic — tense, distorted, F phrygian, 140 BPM half-time, 40 bars
# ----------------------------------------------------------------------------
def music_panic(r) -> np.ndarray:
    S = Song(140, 40, r)
    roots = [29, 29, 30, 30, 29, 29, 25, 24]  # F F Gb Gb F F Db C
    pads = [[53, 56, 60, 63], [53, 56, 60, 63], [54, 58, 61, 65], [54, 58, 61, 65],
            [53, 56, 60, 63], [53, 56, 60, 65], [53, 56, 61, 65], [52, 55, 60, 64]]
    K = kick(r, 0.6, 150, 40, 0.035, 0.3, 0.5, 2.2, 0.4)
    KH = kick(r, 0.4, 90, 38, 0.03, 0.14, 0.1, 1.4, 0.2)  # heartbeat
    SN = snare(r, 0.6, 175, 1.2, 0.9, 0.17)
    CL = clap(r, 0.5, 0.18)
    HC = [hat(r, 0.05, 0.011, 1.0 + 0.04 * i, 9500) for i in range(3)]
    HO = hat(r, 0.3, 0.08, 0.97, 8000)
    CR = crash(r, 3.0, 1.0)
    TM = [tom(r, f, 0.5) for f in (140, 110, 85)]

    def drums(b, full=True, fill=False):
        ks = (0, 7, 10) if b % 2 == 0 else (0, 3, 10, 14)
        for s in ks:
            S.hit("kick", K, S.t(b, s), 1.0 if s == 0 else 0.8)
            S.kicks.append(S.t(b, s))
        S.hit("snare", SN, S.t(b, 8), 0.9)
        S.hit("snare", CL, S.t(b, 8) + 0.005, 0.5)
        if full and b % 4 == 3:
            S.hit("snare", SN, S.t(b, 15), 0.3)
        for s in range(16):
            acc = 0.55 if s % 4 == 0 else (0.38 if s % 2 == 0 else 0.22)
            S.hit("hats", HC[r.integers(0, 3)], S.t(b, s), acc, 0.3, 0.002)
        if full and b % 2 == 1:
            S.hit("hats", HO, S.t(b, 6), 0.3, -0.2)
        if fill:
            for i, s in enumerate((10, 11, 12, 13, 14, 15)):
                S.hit("drums_fx", TM[min(i // 2, 2)], S.t(b, s), 0.65, -0.4 + 0.16 * i)

    for b in range(40):
        if b < 8:
            for s in range(16):
                S.hit("hats", HC[r.integers(0, 3)], S.t(b, s), 0.4 if s % 4 == 0 else 0.2, 0.3, 0.002)
            if b >= 4:
                S.hit("kick", K, S.t(b, 0), 0.8)
                S.kicks.append(S.t(b, 0))
        elif b < 24:
            drums(b, True, fill=(b == 23))
        elif b < 28:
            for s in range(0, 16, 2):
                S.hit("hats", HC[0], S.t(b, s), 0.25, 0.3)
            for s in (0, 8):
                S.hit("kick", KH, S.t(b, s), 0.8)
                S.hit("kick", KH, S.t(b, s) + 0.17, 0.55)
        elif b < 32:
            drums(b, False)
            for s in range(0, 16, 2 if b < 30 else 1):
                S.hit("snare", SN, S.t(b, s), 0.15 + 0.5 * ((b - 28) * 16 + s) / 64)
        else:
            drums(b, True, fill=(b == 39))
    for b in (0, 8, 16, 32):
        S.hit("crash", CR, S.t(b), 0.5)
    # reese bass
    bp = [(0, 0, 6), (7, 0, 2), (10, 12, 2), (13, 1, 3)]
    bass_notes = []
    for b in range(40):
        root = roots[b % 8] + 12
        if 24 <= b < 28:
            bass_notes.append((S.t(b), S.bar * 0.95, root, 0.6))
            continue
        for (s, o, L) in bp:
            bass_notes.append((S.t(b, s), L * S.spb / 4 * 0.92, root + o, 1.0 if s == 0 else 0.85))
    bass = render_mono_line(S, bass_notes, "reese", (180, 1100), 2.0, 0.2, (0.004, 0.25, 0.75, 0.06), glide=0.012,
                            lfo=(S.bpm / 60 / 2, 0.35), drive_amt=3.0)
    bass = bass * 0.8 + crush(bass, 7, 2) * 0.2
    S.bus("bass")[:] += pan(filt(bass, "lp", 3500), 0)
    chords = [(S.t(b), S.bar, pads[b % 8], 1.0) for b in range(40)]
    pad = render_pad(S, chords, (500, 1600), 5, 0.3, 0.6, 1.2, 1.5)
    S.bus("pad")[:] += pad
    # tense arp with minor seconds, bit crushed
    arp_pat = [0, 1, 0, 2, 0, 1, 3, 2, 0, 1, 0, 4, 0, 1, 5, 3]

    def arp_chord(b):
        root = roots[b % 8] + 36
        return [root, root + 1, root + 3, root + 7, root + 8]
    arp_notes = _arp_notes(S, list(range(8, 24)) + list(range(28, 40)), arp_chord, arp_pat, 0.5)
    arp = render_mono_line(S, arp_notes, "arp", (700, 3500), 3.0, 0.05, (0.001, 0.05, 0.2, 0.02), glide=0.0, drive_amt=2.0)
    arp = crush(arp, 6, 3) * 0.6 + arp * 0.4
    S.bus("arp")[:] += pan(arp, 0.25)
    # alarm motif: tritone two-tone siren (sections C and E)
    al_notes = []
    for b in list(range(16, 24)) + list(range(32, 40)):
        if b % 2 == 0:
            for i in range(4):
                al_notes.append((S.t(b, i * 2), S.spb / 2 * 0.9, 80 if i % 2 == 0 else 74, 0.9))
    al = render_mono_line(S, al_notes, "siren", (2000, 5000), 1.5, 0.1, (0.005, 0.1, 0.8, 0.05), glide=0.01, drive_amt=4.0)
    S.bus("alarm")[:] += pan(al, -0.25)
    # klaxon swell in the breakdown
    for b in (24, 26):
        n = ns(S.bar * 2)
        tt = np.arange(n) / SR
        f = 440 * (1 + 0.25 * (0.5 - 0.5 * np.cos(TAU * tt / (S.bar))))
        kx = filt(saw(f, n) + saw(f * 1.01, n), "bp", 1100, 1.0) * adsr(S.bar * 2, 0.8, 0.5, 0.8, 0.9, n=n)
        S.hit("alarm", drive(kx, 2.0), S.t(b), 0.5, 0.2)
    # metallic stabs (section C / E offbeats)
    for b in list(range(16, 24)) + list(range(32, 40)):
        for s in (6, 14):
            n = ns(0.4)
            tt = np.arange(n) / SR
            st = fm(mtof(roots[b % 8] + 48), n, 1.414, 5 * np.exp(-tt / 0.04) + 0.5) * perc(0.4, 0.001, 0.09, n)
            S.hit("stab", st, S.t(b, s), 0.6, r.uniform(-0.6, 0.6))
    # build riser
    rn = ns(S.bar * 4)
    rp = np.arange(rn) / rn
    rz = sweep(np.stack([noise(rn, r), noise(rn, r)]), "bp", 250 * (8000 / 250) ** rp, 1.0 + 3 * rp) * rp**2.5
    rz = rz + to_stereo(saw(80 * (900 / 80) ** rp, rn)) * 0.15 * rp**2
    place(S.bus("fx"), rz, ns(S.t(28)), 0.5)
    duck = S.duck(0.5, 0.15)
    gains = {"kick": 1.0, "snare": 0.6, "hats": 0.3, "crash": 0.3, "drums_fx": 0.5, "bass": 0.42,
             "pad": 0.3, "arp": 0.14, "alarm": 0.12, "stab": 0.22, "fx": 0.45}
    out = np.zeros((2, S.N))
    for k, v in S.buses.items():
        if k in ("bass", "pad", "arp"):
            v = v * duck
        out += v * gains.get(k, 0.5)
    al_d = delay(S.buses["alarm"], S.spb * 0.75, 0.45, 1.0, lp=3000, pingpong=True, tail=0)
    out += (fit(al_d, S.N) - S.buses["alarm"]) * 0.12 * 0.5
    rsend = S.buses["snare"] * 0.6 + S.buses["pad"] * 0.3 + S.buses["alarm"] * 0.4 + S.buses["stab"] * 0.5
    ir = reverb_ir(3.0, 1.3, 0.45, 0.02, 6500, 220)
    out += fit(convolve(rsend, ir), S.N) * 0.12
    x = master(S, out, -19.5, -3.0)
    x += vinyl(S.L, r, 0.5) * db(-44)
    return limiter(x, -3.0, circular=True)


REGISTRY = {
    "MusicMain": music_main,
    "MusicStorm": music_storm,
    "MusicPanic": music_panic,
}
