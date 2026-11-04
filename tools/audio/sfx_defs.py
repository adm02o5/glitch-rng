"""One-shot sound effects. Each builder takes a seeded rng and returns raw audio;
REGISTRY maps name -> (builder, peak dBFS, stereo?)."""
from __future__ import annotations

import math

import numpy as np

from .dsp import (
    SR, TAU, adsr, at, chirp_sine, crush, delay, drive, fade, filt, fit, fm, interp_curve,
    mix, mtof, noise, ns, pan, perc, phase, pulse, reverb, saw, sine, square, stutter,
    supersaw, sweep, swell, to_mono, to_stereo, tri, tvec, widen, zeros, place, gate_pattern,
    chorus, smooth,
)
from .instruments import bell, brass, choir, crash, kick, sparkle, sub_drop, thunder, tom


def _t(d):
    return tvec(d)


# ----------------------------------------------------------------------------
# UI
# ----------------------------------------------------------------------------
def hover(r):
    d = 0.075
    n, t = ns(d), _t(d)
    f = 2300 * (1 + 0.16 * (1 - np.exp(-t / 0.012)))
    x = sine(f, n) * perc(d, 0.0018, 0.017, n)
    x += sine(f * 2, n) * perc(d, 0.0012, 0.006, n) * 0.22
    x += tri(f * 0.5, n) * perc(d, 0.002, 0.02, n) * 0.18
    x += filt(noise(n, r), "bp", 7000, 2.0) * perc(d, 0.0003, 0.002, n) * 0.08
    return filt(x, "lp", 9500)


def click(r):
    d = 0.17
    n, t = ns(d), _t(d)
    tr = filt(noise(n, r), "bp", 4600, 1.1) * perc(d, 0.0002, 0.0024, n)
    body = fm(1900, n, 1.0, 1.6 * np.exp(-t / 0.008)) * perc(d, 0.0004, 0.011, n)
    tf = 1760 * (1 + 0.06 * np.minimum(t / 0.04, 1))
    tail = (sine(tf, n) + 0.25 * sine(tf * 2, n)) * at(perc(0.12, 0.002, 0.038), 0.007, d)
    low = sine(520, n) * perc(d, 0.0005, 0.01, n) * 0.4
    x = tr * 0.8 + body * 0.55 + tail * 0.42 + low
    x = x * 0.85 + crush(x, 9) * 0.15
    return to_mono(delay(x, 0.034, 0.2, 0.18, lp=6000, tail=0.08))


def _glitch_tick(r, d=0.03, f=2600.0, reps=3):
    n = ns(d)
    one = square(f, ns(0.006)) * perc(0.006, 0.0003, 0.002)
    out = np.zeros(n)
    for k in range(reps):
        s = ns(0.0075 * k)
        g = 1.0 - 0.22 * k
        seg = one * g if k % 2 == 0 else square(f * 1.5, ns(0.006)) * perc(0.006, 0.0003, 0.002) * g
        place(out, seg, s)
    return crush(out, 5, 3)


def _holo(r, up=True):
    d = 0.44
    n, t = ns(d), _t(d)
    if up:
        fc = interp_curve([(0, 380), (0.3, 6800), (d, 8500)], d, "exp")
        cf = interp_curve([(0, 260), (0.3, 1150), (d, 1250)], d, "exp")
        env = swell(d, 0.25, 1.7)
        tick_at = 0.27
    else:
        fc = interp_curve([(0, 8000), (0.14, 5500), (d, 320)], d, "exp")
        cf = interp_curve([(0, 1150), (d, 230)], d, "exp")
        env = swell(d, 0.1, 1.4) * np.exp(-t / 0.25)
        tick_at = 0.012
    wh = sweep(noise(n, r), "bp", fc, 2.6, frame=512, nfft=2048) * env
    air = sweep(noise(n, r), "hp", fc * 0.8, 0.7, frame=512, nfft=2048) * env * 0.25
    ch = fm(cf, n, 2.0, 0.9) * env * 0.33 + sine(cf * 3.01, n) * env * 0.06
    x = wh * 1.1 + air + ch
    x = x + at(_glitch_tick(r, f=2900 if up else 2100), tick_at, d) * 0.45
    x = reverb(x, wet=0.16, rt60=0.5, size=0.4, predelay=0.004)
    return to_mono(x)


def open_(r):
    return _holo(r, True)


def close(r):
    return _holo(r, False)


def roll_start(r):
    d = 1.0
    n, t = ns(d), _t(d)
    T = 0.8
    p = np.clip(t / T, 0, 1)
    f = 70 * (900 / 70) ** (p**1.5)
    width = 0.3 + 0.18 * np.sin(TAU * 3 * t)
    core = saw(f, n) * 0.5 + pulse(f * 1.006, n, width) * 0.38 + fm(f * 0.5, n, 2.0, 1.4) * 0.3
    cut = interp_curve([(0, 220), (T, 7500), (d, 4000)], d, "exp")
    core = sweep(core, "lp", cut, 2.6, frame=512, nfft=2048)
    rate = 6 + 38 * p**1.3
    trem = 0.58 + 0.42 * np.sin(TAU * phase(rate, n))
    amp = np.where(t < T, 0.15 + 0.85 * p**1.25, np.exp(-(t - T) / 0.05))
    core = core * trem * amp
    core = core * 0.75 + crush(core, 6, 2) * 0.25
    nz = sweep(noise(n, r), "hp", interp_curve([(0, 500), (T, 6500)], d, "exp"), 0.8, frame=512, nfft=2048)
    nz = nz * np.where(t < T, p**2, np.exp(-(t - T) / 0.03)) * 0.22
    ping = at(bell(1760, 0.2, bright=0.7, tau=0.06) + bell(2637, 0.2, bright=0.5, tau=0.05) * 0.5, T - 0.005, d)
    sub = sine(f * 0.5, n) * amp * 0.25
    return mix(core, nz, ping * 0.5, sub)


def tick(r):
    d = 0.05
    n = ns(d)
    f = 1650
    x = sine(f, n) * perc(d, 0.0008, 0.009, n)
    x += sine(f * 2.01, n) * perc(d, 0.0005, 0.004, n) * 0.3
    x += filt(noise(n, r), "bp", 5200, 1.6) * perc(d, 0.0002, 0.0014, n) * 0.25
    return filt(x, "lp", 8500)


def land(r):
    d = 0.7
    n, t = ns(d), _t(d)
    k = kick(r, d, f_hi=210, f_lo=56, pitch_tau=0.02, amp_tau=0.11, click=0.7, punch=1.5, sub=0.2)
    knock = filt(noise(n, r), "bp", 720, 2.0) * perc(d, 0.0008, 0.028, n) * 0.6
    knock += sine(330 * (1 + 0.3 * np.exp(-t / 0.01)), n) * perc(d, 0.001, 0.035, n) * 0.35
    latch = np.zeros(n)
    for off, g in ((0.0, 1.0), (0.019, 0.7)):
        c = filt(noise(ns(0.03), r), "bp", 3300, 4.0) * perc(0.03, 0.0002, 0.0035) + square(2400, ns(0.03)) * perc(0.03, 0.0002, 0.0015) * 0.2
        place(latch, c, ns(off), g)
    ring = fm(1180, n, 1.414, 1.2 * np.exp(-t / 0.05)) * perc(d, 0.001, 0.09, n) * 0.16
    x = k * 0.9 + knock + latch * 0.5 + ring
    return to_mono(reverb(x, wet=0.18, rt60=0.6, size=0.5, lp=5000))


# ----------------------------------------------------------------------------
# reveal stingers
# ----------------------------------------------------------------------------
def _soft_pad(midis, d, r, a=0.25, rel=1.2, cutoff=3200.0):
    n = ns(d)
    acc = np.zeros(n)
    for m in midis:
        f = mtof(m)
        acc += tri(f * 0.997, n, r.uniform()) + tri(f * 1.003, n, r.uniform()) + 0.4 * sine(f * 2, n)
    acc = filt(acc, "lp", cutoff) * adsr(d, a, 0.6, 0.65, rel, n=n) / len(midis)
    return chorus(acc, 0.5, 2.5, 10, 0.6)


def reveal1(r):
    d = 3.0
    out = zeros(d, True)
    notes = [65, 69, 72, 76, 79]  # Fmaj9 strum
    for i, m in enumerate(notes):
        b = bell(mtof(m), 2.0, bright=0.8, tau=0.65)
        place(out, pan(b, -0.6 + 0.3 * i), ns(0.04 * i), 0.42)
    place(out, _soft_pad([53, 60, 64, 69], 2.4, r), 0, 0.5)
    place(out, sparkle(2.0, r, 20, 3000, 9500, 0.05, 1.1), 0, 0.2)
    place(out, sine(mtof(41), ns(2.0)) * perc(2.0, 0.01, 0.5), 0, 0.3)
    shim = sweep(noise(ns(1.2), r), "bp", interp_curve([(0, 3000), (1.2, 11000)], 1.2, "exp"), 3.0) * swell(1.2, 0.15, 1.5)
    place(out, pan(shim, 0.0), 0, 0.06)
    return reverb(out, wet=0.38, rt60=2.0, size=0.9, predelay=0.02, lp=9000)


def reveal2(r):
    d = 3.4
    out = zeros(d, True)
    chord = [69, 73, 76, 81, 83]  # A add9, bright
    n = ns(2.6)
    tt = np.arange(n) / SR
    saws = np.zeros((2, n))
    for m in chord:
        saws += supersaw(mtof(m), n, r, 5, 0.18, 0.9)
    cut = 600 + 7000 * (1 - np.exp(-tt / 0.08)) * np.exp(-tt / 1.2) + 1200
    saws = sweep(saws, "lp", cut, 1.3) * adsr(2.6, 0.004, 0.5, 0.35, 1.0, n=n) * 0.35
    # glitch stutter on the transient
    saws = stutter(saws, 0.0, 0.045, 6, 0.92, shrink=0.82)
    gl = crush(saws, 5, 6) * gate_pattern(n, 0.03, [1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 0, 0] + [0] * 60)
    place(out, saws, 0)
    place(out, gl, 0, 0.35)
    for i, m in enumerate(chord):
        place(out, pan(bell(mtof(m + 12), 1.8, bright=0.9, tau=0.5), 0.8 - 0.4 * i), ns(0.03 * i + 0.25), 0.3)
    place(out, sparkle(2.4, r, 34, 3500, 11000, 0.15, 1.4), 0, 0.22)
    ch = chirp_sine(400, 3200, 0.25) * swell(0.25, 0.2)
    place(out, pan(ch, 0), 0, 0.12)
    place(out, sub_drop(1.2, 80, 40, 0.4, 1.2), 0, 0.35)
    place(out, _soft_pad([57, 64, 69, 71], 3.0, r, 0.15, 1.4, 4000), 0, 0.4)
    return reverb(out, wet=0.36, rt60=2.4, size=1.0, predelay=0.018)


def _impact(r, d=1.2, lp=5000.0, tau=0.25, amt=3.0):
    n = ns(d)
    x = filt(noise(n, r), "lp", lp) * perc(d, 0.0008, tau, n)
    x = drive(x * 1.5, amt)
    return x


def reveal3(r):
    d = 4.2
    out = zeros(d, True)
    chord = [46, 53, 58, 62, 65, 69]  # Bbmaj7 heroic stack
    b = brass([mtof(m) for m in chord], 3.0, r, attack=0.05, cutoff=(500, 5200, 2000), detune=0.14)
    place(out, b, 0, 0.9)
    b2 = brass([mtof(m + 12) for m in chord[2:]], 2.4, r, attack=0.12, cutoff=(800, 6000, 2600), detune=0.1)
    place(out, b2, ns(0.02), 0.35)
    place(out, sub_drop(2.0, 95, 30, 0.9, 1.8), 0, 0.95)
    place(out, kick(r, 0.8, 190, 42, 0.03, 0.3, 0.6, 1.6), 0, 0.7)
    place(out, pan(_impact(r, 1.0, 4500, 0.2, 2.5), 0), 0, 0.3)
    place(out, crash(r, 2.6, 0.7), 0, 0.12)
    place(out, sparkle(3.0, r, 30, 3000, 10000, 0.1, 1.6), 0, 0.15)
    place(out, pan(bell(mtof(81), 2.5, bright=0.7, tau=0.8), -0.3), ns(0.06), 0.2)
    place(out, pan(bell(mtof(84), 2.5, bright=0.7, tau=0.8), 0.3), ns(0.12), 0.18)
    return reverb(out, wet=0.42, rt60=2.8, size=1.1, predelay=0.02, lp=8500)


def reveal4(r):
    d = 6.5
    out = zeros(d, True)
    t2 = _t(2.4)
    # distorted power chord hit
    n = ns(2.4)
    pw = np.zeros(n)
    for m in (38, 45, 50, 57):
        pw += saw(mtof(m), n, r.uniform()) + saw(mtof(m) * 1.004, n, r.uniform())
    pw = drive(pw * 0.6, 5.0)
    pw = sweep(pw, "lp", 300 + 5000 * np.exp(-t2 / 0.35), 1.2) * perc(2.4, 0.002, 0.7, n)
    place(out, widen(chorus(pw, 0.4, 3, 9, 0.5), 1.3), 0, 0.42)
    place(out, kick(r, 1.0, 230, 38, 0.035, 0.45, 0.8, 2.0, 0.4), 0, 0.85)
    place(out, sub_drop(3.0, 110, 28, 1.3, 2.0), 0, 0.9)
    imp = _impact(r, 2.0, 7000, 0.4, 4.0)
    place(out, np.stack([imp, np.roll(imp, 37)]), 0, 0.38)
    place(out, crash(r, 4.0, 1.4), 0, 0.2)
    # choir-like pad
    ch = choir([mtof(m) for m in (62, 65, 69, 74, 76)], 5.0, r, "a", attack=0.35, release=2.0, voices=4)
    ch2 = choir([mtof(m) for m in (50, 57)], 5.0, r, "o", attack=0.5, release=2.0, voices=3)
    place(out, ch, ns(0.05), 0.9)
    place(out, ch2, ns(0.05), 0.5)
    # glitch flare
    gl = crush(to_mono(out[:, : ns(0.6)]), 4, 8) * gate_pattern(ns(0.6), 0.025, [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0])
    place(out, pan(gl, 0.4), ns(0.35), 0.25)
    place(out, sparkle(4.0, r, 40, 2500, 10000, 0.2, 2.6, tau=0.2), 0, 0.12)
    return reverb(out, wet=0.5, rt60=4.0, size=1.3, predelay=0.025, lp=7500, damp=0.4)


def reveal5(r):
    d = 10.5
    out = zeros(d, True)
    tt = _t(d)
    # massive sub boom
    n = ns(6.0)
    t6 = np.arange(n) / SR
    f = 26 + 42 * np.exp(-t6 / 0.18)
    boom = np.sin(TAU * phase(f, n)) * perc(6.0, 0.003, 2.0, n)
    boom = drive(boom * 1.4, 2.2)
    place(out, boom, 0, 0.95)
    place(out, kick(r, 1.2, 260, 36, 0.04, 0.5, 1.0, 2.2, 0.5), 0, 0.7)
    rum = filt(noise(ns(5.0), r), "lp", 180, 0.8, order=2) * perc(5.0, 0.01, 1.6)
    place(out, np.stack([rum, filt(noise(ns(5.0), r), "lp", 180, 0.8, order=2) * perc(5.0, 0.01, 1.6)]), 0, 0.9)
    imp = _impact(r, 2.5, 8000, 0.5, 4.5)
    place(out, np.stack([imp, np.roll(imp, 53)]), 0, 0.3)
    place(out, crash(r, 6.0, 2.2), 0, 0.22)
    # metallic cyber hit
    n2 = ns(4.0)
    t4 = np.arange(n2) / SR
    met = fm(220, n2, 1.414, 4 * np.exp(-t4 / 0.4) + 0.3) * perc(4.0, 0.001, 1.3, n2)
    place(out, haas(met, 9, 0.8), 0, 0.12)
    # shimmering supersaw chord (D major add9 — triumphant)
    chord = [50, 57, 62, 66, 69, 76]
    ns_ = ns(8.0)
    t8 = np.arange(ns_) / SR
    ss = np.zeros((2, ns_))
    for m in chord:
        ss += supersaw(mtof(m), ns_, r, 9, 0.33, 1.0)
    cut = interp_curve([(0, 700), (0.25, 3000), (1.6, 9000), (8.0, 4000)], 8.0, "exp")
    ss = sweep(ss, "lp", cut, 0.9)
    ss = ss * adsr(8.0, 0.12, 1.5, 0.6, 3.5, n=ns_) * (0.85 + 0.15 * np.sin(TAU * 0.4 * t8))
    # cyber stutter inside the chord at ~2.6s
    g = np.ones(ns_)
    s0 = ns(2.6)
    gp = gate_pattern(ns(0.36), 0.03, [1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1])
    g[s0 : s0 + len(gp)] = 0.35 + 0.65 * gp
    ss = ss * g
    place(out, widen(ss, 1.5), ns(0.01), 0.36)
    # octave shimmer bed
    shim = np.zeros((2, ns_))
    for i, m in enumerate(chord[2:]):
        for o in (12, 24):
            ff = mtof(m + o)
            v = (sine(ff * 1.002, ns_, r.uniform()) + 0.5 * tri(ff * 0.998, ns_, r.uniform()))
            trem = 0.6 + 0.4 * np.sin(TAU * r.uniform(3.0, 7.0) * t8 + r.uniform(0, 6))
            shim += pan(v * trem, r.uniform(-1, 1))
    shim = shim * adsr(8.0, 0.8, 1.0, 0.8, 4.0, n=ns_) / 8
    place(out, shim, 0, 0.32)
    ch = choir([mtof(m) for m in (62, 66, 69, 74)], 7.5, r, "a", attack=0.6, release=3.5, voices=4)
    place(out, ch, ns(0.1), 0.6)
    place(out, sparkle(7.0, r, 70, 2500, 12000, 0.1, 5.0, tau=0.25), 0, 0.16)
    for i, m in enumerate([74, 78, 81, 86, 90]):
        place(out, pan(bell(mtof(m), 3.0, bright=0.8, tau=1.0), -0.7 + 0.35 * i), ns(0.35 + 0.07 * i), 0.18)
    wet = reverb(out, wet=0.55, rt60=6.5, size=1.6, predelay=0.03, lp=8000, damp=0.3, width=1.3)
    wet = fit(wet, ns(d))
    return fade(wet, 0, 2.0)


def haas(x, ms, amount):
    from .dsp import haas as _h
    return _h(x, ms, amount)


# ----------------------------------------------------------------------------
# effects
# ----------------------------------------------------------------------------
def glitch(r):
    d = 0.75
    out = zeros(d, True)
    pos = 0.0
    prev = None
    while pos < d - 0.12:
        L = float(r.choice([0.012, 0.02, 0.03, 0.045, 0.06]))
        n = ns(L)
        kind = r.choice(["tone", "noise", "fm", "rest", "repeat", "tone"])
        if kind == "repeat" and prev is not None:
            seg = np.tile(prev, int(r.integers(2, 5)))
        elif kind == "rest":
            seg = np.zeros(n)
        elif kind == "tone":
            f = math.exp(r.uniform(math.log(180), math.log(3200)))
            seg = crush(pulse(f, n, r.uniform(0.1, 0.5)), int(r.integers(3, 7)), int(r.integers(1, 6)))
        elif kind == "noise":
            seg = crush(noise(n, r), int(r.integers(2, 5)), int(r.integers(4, 24)))
        else:
            f = math.exp(r.uniform(math.log(80), math.log(900)))
            seg = fm(f, n, r.uniform(1.5, 7.0), r.uniform(2, 9))
        seg = fade(seg * r.uniform(0.5, 1.0), 0.0008, 0.0015)
        if kind != "repeat":
            prev = seg
        place(out, pan(seg, r.uniform(-0.85, 0.85)), ns(pos))
        pos += seg.shape[-1] / SR
    # power-down chirp tail
    dn = chirp_sine(1400, 70, 0.12) * perc(0.12, 0.001, 0.08)
    place(out, pan(crush(dn, 5, 2), 0), ns(d - 0.13), 0.7)
    out = filt(out, "hp", 70)
    return out


def boom(r):
    d = 5.0
    out = zeros(d, True)
    n = ns(4.0)
    t = np.arange(n) / SR
    f = 28 + 32 * np.exp(-t / 0.22)
    b = drive(np.sin(TAU * phase(f, n)) * perc(4.0, 0.002, 1.5, n) * 1.3, 2.0)
    place(out, b, 0, 1.0)
    place(out, kick(r, 0.9, 200, 40, 0.03, 0.4, 0.9, 2.0, 0.3), 0, 0.6)
    th = thunder(r, 4.5)
    place(out, np.stack([th, np.roll(th, 211)]), 0, 0.5)
    rum = filt(noise(ns(3.0), r), "lp", 160, 0.8, order=2) * perc(3.0, 0.01, 1.0)
    place(out, pan(rum, -0.3) + pan(np.roll(rum, 97), 0.3), 0, 0.8)
    place(out, pan(_impact(r, 1.2, 3000, 0.2, 2.5), 0), 0, 0.25)
    return reverb(out, wet=0.4, rt60=3.0, size=1.4, lp=2600, damp=0.55, predelay=0.015)


def riser(r):
    d = 3.0
    n, t = ns(d), _t(d)
    p = t / d
    fc = 250 * (9000 / 250) ** p
    nz = np.stack([noise(n, r), noise(n, r)])
    nz = sweep(nz, "bp", fc, 1.0 + 3.0 * p, frame=1024)
    f = 90 * (1400 / 90) ** (p**1.2)
    tone = supersaw(f, n, r, 5, 0.3, 0.8) * 0.5 + to_stereo(saw(f * 2.0, n)) * 0.18
    tone = sweep(tone, "lp", 400 + 9000 * p**1.6, 1.4)
    rate = 3 + 27 * p**1.5
    trem = 1.0 - (0.15 + 0.55 * p) * (0.5 + 0.5 * np.sin(TAU * phase(rate, n)))
    x = (nz * 1.1 + tone) * trem
    x = x + crush(x, 6, 3) * p**4 * 0.5
    sub = sine(f * 0.5, n) * 0.25 * p
    x = mix(x, sub)
    x = widen(x, 0.6 + 1.0 * p.mean() * 2)
    amp = 0.07 + 0.93 * p**2.3
    x = x * amp
    x[:, -ns(0.006):] *= np.linspace(1, 0, ns(0.006))
    return x


def type_(r):
    d = 0.085
    n, t = ns(d), _t(d)
    c1 = filt(noise(n, r), "bp", 5200, 1.5) * perc(d, 0.0002, 0.0018, n) + square(3100, n) * perc(d, 0.0002, 0.0011, n) * 0.25
    bo = filt(noise(n, r), "bp", 430, 1.2) * perc(d, 0.0005, 0.011, n) * 0.9
    bo += sine(260 * (1 - 0.3 * np.minimum(t / 0.02, 1)), n) * perc(d, 0.001, 0.015, n) * 0.55
    bo += filt(noise(n, r), "bp", 2300, 8.0) * perc(d, 0.0005, 0.02, n) * 0.3
    up = filt(noise(n, r), "bp", 4200, 2.0) * perc(d, 0.0002, 0.0015, n) * 0.35
    x = c1 * 0.8 + at(bo, 0.009, d) + at(up, 0.05, d)
    return x


def error(r):
    d = 0.55
    out = zeros(d)

    def beep(f, L):
        n = ns(L)
        x = square(f, n) + square(f * 1.06, n) * 0.7 + saw(f * 2, n) * 0.2
        x = x * adsr(L, 0.002, 0.05, 0.8, 0.02, n=n)
        x = x * 0.6 + crush(x, 5, 2) * 0.4
        return filt(drive(x * 0.7, 2.5), "lp", 5000)

    place(out, beep(330, 0.13), 0)
    place(out, beep(247, 0.2), ns(0.17))
    return out


def biome(r):
    d = 2.6
    out = zeros(d, True)
    for i, m in enumerate([74, 77, 81, 86]):
        f = mtof(m)
        b = bell(f, 1.2, bright=1.0, tau=0.35) + pulse(f, ns(1.2), 0.25) * perc(1.2, 0.002, 0.12) * 0.25
        place(out, pan(b, -0.5 + 0.33 * i), ns(0.11 * i), 0.4)
    # siren wail
    n = ns(1.8)
    t = np.arange(n) / SR
    lfo = 0.5 - 0.5 * np.cos(TAU * t / 0.8)
    f = 620 * (930 / 620) ** lfo
    sir = saw(f, n) * 0.5 + pulse(f * 1.003, n, 0.35) * 0.5
    sir = filt(sir, "bp", 1400, 0.8) * adsr(1.8, 0.15, 0.3, 0.8, 0.5, n=n)
    sir = sir * (0.75 + 0.25 * np.sin(TAU * 12 * t))
    place(out, delay(sir, 0.18, 0.3, 0.3, lp=3500, pingpong=True, tail=0.6), ns(0.42), 0.32)
    dr = (saw(mtof(38), ns(2.2)) + saw(mtof(38) * 1.005, ns(2.2))) * adsr(2.2, 0.3, 0.4, 0.8, 1.0)
    place(out, pan(filt(dr, "lp", 500), 0), 0, 0.3)
    place(out, sub_drop(1.0, 70, 38, 0.4, 1.3), 0, 0.3)
    return reverb(out, wet=0.32, rt60=1.8, size=1.0)


def announce(r):
    d = 2.0
    out = zeros(d, True)
    arp = [62, 66, 69, 74]
    for i, m in enumerate(arp):
        nb = brass([mtof(m)], 0.25, r, attack=0.01, cutoff=(1500, 6000, 2500), detune=0.08, voices=3)
        place(out, nb, ns(0.07 * i), 0.5)
        place(out, pan(bell(mtof(m + 12), 0.5, bright=0.6, tau=0.15), -0.4 + 0.27 * i), ns(0.07 * i), 0.22)
    L0 = 0.28
    ch = brass([mtof(m) for m in (62, 66, 69, 74, 78)], 1.3, r, attack=0.03, cutoff=(900, 6500, 2600), detune=0.12)
    place(out, ch, ns(L0), 0.75)
    place(out, tom(r, 95, 0.6), ns(L0), 0.45)
    place(out, sparkle(1.4, r, 22, 3500, 11000, 0.0, 0.8), ns(L0), 0.18)
    place(out, crash(r, 1.6, 0.5), ns(L0), 0.08)
    return reverb(out, wet=0.33, rt60=1.6, size=0.9)


def craft(r):
    d = 2.0
    out = zeros(d)
    for i, (off, f) in enumerate(((0.0, 410.0), (0.21, 470.0), (0.42, 355.0))):
        n = ns(0.5)
        t = np.arange(n) / SR
        hit = fm(f, n, 1.41, 3.0 * np.exp(-t / 0.05) + 0.4) * perc(0.5, 0.0005, 0.11, n)
        hit += filt(noise(n, r), "bp", 3200, 1.5) * perc(0.5, 0.0003, 0.008, n) * 0.6
        hit += fit(kick(r, 0.3, 160, 70, 0.015, 0.05, 0.3, 1.0, 0.0), n) * 0.5
        place(out, hit, ns(off), 0.55)
    n = ns(0.7)
    t = np.arange(n) / SR
    wf = 180 * (430 / 180) ** (t / 0.7)
    whir = filt(saw(wf, n) + 0.5 * square(wf * 1.5, n), "bp", 900, 3.0) * swell(0.7, 0.45, 1.3)
    place(out, whir, 0, 0.25)
    for k in range(14):
        tt0 = 0.06 + k * 0.04 + r.uniform(-0.008, 0.008)
        f = float(r.choice([1046, 1318, 1568, 2093, 2637]))
        bl = crush(square(f, ns(0.012)) * perc(0.012, 0.0005, 0.005), 6, 2)
        place(out, bl, ns(tt0), 0.12)
    s = 0.68
    for i, m in enumerate([81, 85, 88, 93, 97]):
        place(out, bell(mtof(m), 1.1, bright=0.7, tau=0.35), ns(s + 0.045 * i), 0.25)
    place(out, to_mono(sparkle(1.2, r, 18, 3500, 11000, 0.0, 0.7)), ns(s), 0.3)
    place(out, to_mono(_soft_pad([69, 73, 76], 1.2, r, 0.08, 0.8, 5000)), ns(s), 0.35)
    sw = sweep(noise(ns(0.5), r), "bp", interp_curve([(0, 1500), (0.5, 9000)], 0.5, "exp"), 3.0) * swell(0.5, 0.4)
    place(out, sw, ns(s - 0.35), 0.15)
    return to_mono(reverb(out, wet=0.28, rt60=1.5, size=0.8))


def equip(r):
    d = 0.9
    out = zeros(d)
    c = filt(noise(ns(0.03), r), "bp", 2600, 3.0) * perc(0.03, 0.0002, 0.004) + square(1900, ns(0.03)) * perc(0.03, 0.0002, 0.002) * 0.3
    place(out, c, 0, 0.9)
    n = ns(0.85)
    t = np.arange(n) / SR
    f = 40 + 15 * (1 - np.exp(-t / 0.08))
    hum = saw(f, n) + 0.5 * saw(f * 2, n) + 0.3 * pulse(f * 3, n, 0.3) + 0.25 * sine(120, n)
    hum = sweep(hum, "lp", interp_curve([(0, 150), (0.3, 2600), (0.85, 900)], 0.85, "exp"), 1.5, frame=512, nfft=2048)
    hum = hum * adsr(0.85, 0.05, 0.25, 0.45, 0.45, n=n)
    place(out, hum, ns(0.02), 0.5)
    wh = sine(1500 * (4200 / 1500) ** np.minimum(t / 0.35, 1), n) * perc(0.85, 0.02, 0.18, n)
    place(out, wh, ns(0.02), 0.1)
    place(out, bell(mtof(88), 0.4, bright=0.5, tau=0.1), ns(0.3), 0.15)
    return to_mono(reverb(out, wet=0.15, rt60=0.7, size=0.6))


def whoosh(r):
    d = 0.48
    n, t = ns(d), _t(d)
    fc = interp_curve([(0, 600), (0.2, 4800), (d, 1300)], d, "exp")
    env = swell(d, 0.19, 1.6)
    a = sweep(noise(n, r), "bp", fc, 1.4, frame=512, nfft=2048) * env
    b = sweep(noise(n, r), "hp", fc * 1.3, 0.7, frame=512, nfft=2048) * env * 0.3
    tf = interp_curve([(0, 300), (0.2, 720), (d, 330)], d, "exp")
    tone = filt(saw(tf, n), "lp", 1500) * env * 0.12
    x = a + b + tone
    return x * 0.85 + crush(x, 7, 2) * 0.15


REGISTRY = {
    "Hover": (hover, -8.0, False),
    "Click": (click, -6.0, False),
    "Open": (open_, -6.0, False),
    "Close": (close, -6.0, False),
    "RollStart": (roll_start, -5.0, False),
    "Tick": (tick, -7.0, False),
    "Land": (land, -4.0, False),
    "Reveal1": (reveal1, -3.0, True),
    "Reveal2": (reveal2, -2.0, True),
    "Reveal3": (reveal3, -1.5, True),
    "Reveal4": (reveal4, -1.0, True),
    "Reveal5": (reveal5, -1.0, True),
    "Glitch": (glitch, -3.0, True),
    "Boom": (boom, -1.0, True),
    "Riser": (riser, -1.5, True),
    "Type": (type_, -6.0, False),
    "Error": (error, -8.0, False),
    "Biome": (biome, -3.0, True),
    "Announce": (announce, -3.0, True),
    "Craft": (craft, -5.0, False),
    "Equip": (equip, -5.0, False),
    "Whoosh": (whoosh, -5.0, False),
}
