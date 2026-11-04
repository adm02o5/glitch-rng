"""Second SFX batch: [REDACTED] cutscene one-shots, biome stingers, UI/NPC extras and
ambience loops.

REGISTRY  maps name -> (builder, peak dBFS, stereo?, opts) like sfx_defs (opts: trim, fade_out).
LOOPS     maps name -> builder returning a finished, seamless stereo loop (no trim).
"""
from __future__ import annotations

import math

import numpy as np

from .dsp import (
    SR, TAU, adsr, chirp_sine, compress, crush, db, delay, drive, fade, filt, fit, fm,
    interp_curve, limiter, mix, mtof, noise, ns, pan, perc, phase, pink, place, pulse,
    reverb, rms_db, saw, sine, square, stutter, supersaw, sweep, swell, to_mono,
    to_stereo, tri, widen, zeros, gate_pattern, chorus, smooth,
)
from .instruments import bell, brass, choir, clap, crash, hat, kick, snare, sparkle, sub_drop, thunder, tom


def _st(x, r, ms=11.0):
    """Mono -> decorrelated stereo."""
    x = to_mono(x)
    d = np.roll(x, ns(ms / 1000))
    side = filt(d - x, "hp", 250) * 0.35
    return np.stack([x + side, x - side])


def loopify(x: np.ndarray, L: int, xf: int) -> np.ndarray:
    """x has >= L + xf samples and is continuous across L. Equal-power crossfade of
    x[L:L+xf] into the head so out[L-1] -> out[0] is seamless."""
    out = x[..., :L].copy()
    k = np.linspace(0, 1, xf)
    fi, fo = np.sin(k * math.pi / 2), np.cos(k * math.pi / 2)
    out[..., :xf] = x[..., :xf] * fi + x[..., L : L + xf] * fo
    return out


def finish_loop(x, rms_target, ceiling=-1.5):
    x = filt(x, "hp", 20.0, 0.6, circular=True)
    x = x * db(rms_target - rms_db(x))
    return limiter(x, ceiling, attack=0.003, release=0.1, circular=True)


# ----------------------------------------------------------------------------
# [REDACTED] cutscene
# ----------------------------------------------------------------------------
def redacted_drone(r):
    L, xf = 8.0, 2.5
    d = L + xf
    n, t = ns(d), np.arange(ns(d)) / SR
    out = np.zeros((2, n))
    # low cluster: A0/A1 + Bb1 rub + E2, detuned saw stacks, lowpassed and breathing
    for m, g in ((33, 0.9), (45, 0.7), (46, 0.22), (52, 0.35)):
        s = supersaw(mtof(m), n, r, 5, 0.12, 1.0) * g
        out += s
    breath = 0.5 - 0.5 * np.cos(TAU * t / 4.0)  # 2 cycles per loop
    out = sweep(out, "lp", 160 + 520 * breath, 1.8, frame=2048)
    sub = sine(mtof(33), n) * (0.8 + 0.2 * breath)
    out += to_stereo(drive(sub * 1.2, 1.4)) * 0.8
    # metallic overtone whine (very quiet, slow tremolo)
    wh = fm(mtof(81) * 1.01, n, 1.414, 0.6 + 0.4 * np.sin(TAU * t / 8)) * (0.5 + 0.5 * np.sin(TAU * t / 2.0 + 1))
    out += pan(filt(wh, "lp", 3000), 0.4 * np.sin(TAU * t / 8)) * 0.045
    # dark wind / data static
    wind = sweep(np.stack([pink(n, r), pink(n, r)]), "bp", 300 + 900 * (0.5 + 0.5 * np.sin(TAU * t / 8 + 2)), 1.6, frame=2048)
    out += wind * 0.18
    # rare static crackles
    for _ in range(14):
        p = r.integers(0, n - ns(0.08))
        c = crush(filt(noise(ns(0.06), r), "bp", r.uniform(1500, 5000), 2.0), 4, 3) * perc(0.06, 0.001, 0.015)
        place(out, pan(c, r.uniform(-0.9, 0.9)), p, 0.05)
    out = reverb(out, wet=0.45, rt60=4.0, size=1.6, lp=3000, damp=0.6, predelay=0.03)
    out = fit(out, n)
    x = loopify(out, ns(L), ns(xf))
    return finish_loop(x, -17.0, -2.0)


def redacted_stamp(r):
    d = 2.2
    out = zeros(d, True)
    t0 = 0.035
    # hand-down swish
    sw = sweep(noise(ns(0.09), r), "bp", interp_curve([(0, 800), (0.09, 2600)], 0.09, "exp"), 1.2) * swell(0.09, 0.085, 2.0)
    place(out, pan(sw, 0), 0, 0.6)
    # heavy rubber thud
    n = ns(1.0)
    tt = np.arange(n) / SR
    f = 42 + 70 * np.exp(-tt / 0.03)
    thud = np.sin(TAU * phase(f, n)) * perc(1.0, 0.0008, 0.16, n)
    thud += filt(noise(n, r), "bp", 380, 1.0) * perc(1.0, 0.0003, 0.03, n) * 0.9
    thud += filt(noise(n, r), "bp", 1200, 1.5) * perc(1.0, 0.0002, 0.012, n) * 0.6
    place(out, pan(drive(thud * 1.6, 2.2), 0), ns(t0), 1.0)
    # metal plate clank (inharmonic)
    m = np.zeros(ns(1.6))
    tm = np.arange(len(m)) / SR
    for fr, g, tau in ((612, 1.0, 0.35), (941, 0.7, 0.25), (1537, 0.5, 0.18), (2210, 0.4, 0.12), (3390, 0.25, 0.08)):
        m += np.sin(TAU * fr * tm + r.uniform(0, 6)) * np.exp(-tm / tau) * g
    m *= np.minimum(tm / 0.0005, 1)
    place(out, _st(m, r), ns(t0 + 0.002), 0.22)
    # ink-pad squelch + lift
    sq = filt(noise(ns(0.12), r), "bp", 650, 3.0) * swell(0.12, 0.03, 1.5)
    place(out, pan(sq, 0.1), ns(t0 + 0.05), 0.15)
    place(out, sub_drop(0.9, 70, 32, 0.35, 1.4), ns(t0), 0.45)
    return reverb(out, wet=0.28, rt60=1.1, size=0.6, lp=6000, damp=0.5, predelay=0.006)


def redacted_riser(r):
    d = 6.0
    n, t = ns(d), np.arange(ns(d)) / SR
    p = t / d
    out = np.zeros((2, n))
    # noise sweep
    nz = np.stack([noise(n, r), noise(n, r)])
    nz = sweep(nz, "bp", 180 * (10000 / 180) ** (p**1.3), 1.0 + 4 * p, frame=1024)
    out += nz * (0.05 + 0.9 * p**2.2)
    # shepard-ish rising tones (3 octaves, cross-faded)
    for k in range(4):
        pp = (p + k / 4.0)
        f = 55 * 2 ** (pp * 3.0)
        g = np.sin(np.clip(pp / 1.0, 0, 1) * math.pi) ** 2
        tone = supersaw(f, n, r, 5, 0.2, 0.9) * g[None, :]
        out += sweep(tone, "lp", 300 + 7000 * p**1.5, 1.2) * 0.22
    # string-like tension cluster (minor 2nds) swelling
    for m in (57, 58, 64, 65):
        out += pan(saw(mtof(m) * (1 + 0.003 * np.sin(TAU * 5.5 * t + m)), n), (m - 61) / 8) * p**1.8 * 0.08
    # accelerating snare/pulse roll
    SN = snare(r, 0.2, 210, 1.0, 0.5, 0.05)
    tt, i = 0.0, 0
    while tt < d - 0.02:
        rate = 0.5 * (1 - p[min(ns(tt), n - 1)]) ** 1.6 + 0.035
        place(out, pan(SN, (-0.3 if i % 2 else 0.3) * p[min(ns(tt), n - 1)]), ns(tt), 0.08 + 0.55 * (tt / d) ** 2)
        tt += rate
        i += 1
    # heartbeat-ish sub pulses early on
    for bt in np.arange(0.0, 3.5, 0.75):
        place(out, sub_drop(0.5, 70, 38, 0.15, 1.2), ns(bt), 0.35 * (1 - bt / 4))
    # tremolo + crush toward the top
    rate = 4 + 28 * p**1.5
    trem = 1.0 - (0.1 + 0.5 * p) * (0.5 + 0.5 * np.sin(TAU * phase(rate, n)))
    out = out * trem
    out = out + crush(out, 6, 3) * p**4 * 0.5
    out = widen(out, 0.8 + 0.9 * p)
    # peak: bright reverse-cymbal swell slams into the end
    cr = crash(r, 1.2, 0.6)[::-1]
    place(out, _st(cr, r), n - len(cr), 0.6)
    out = out * (0.12 + 0.88 * p**1.8)
    out[:, -ns(0.006):] *= np.linspace(1, 0, ns(0.006))
    return out


def redacted_hit(r):
    d = 7.0
    out = zeros(d, True)
    n = ns(5.5)
    tt = np.arange(n) / SR
    f = 24 + 46 * np.exp(-tt / 0.18)
    sub = drive(np.sin(TAU * phase(f, n)) * perc(5.5, 0.002, 1.8, n) * 1.4, 2.4)
    place(out, sub, 0, 1.0)
    place(out, kick(r, 1.0, 220, 38, 0.03, 0.45, 1.0, 2.2, 0.35), 0, 0.7)
    # distorted mid impact + crushed glitch burst
    imp = filt(noise(ns(1.4), r), "lp", 4500) * perc(1.4, 0.0005, 0.22)
    imp = drive(imp * 2.0, 4.0)
    place(out, _st(imp, r), 0, 0.45)
    gl = crush(supersaw(mtof(np.array([33, 34, 45])).mean(), ns(0.5), r, 5, 0.6), 4, 8) * perc(0.5, 0.001, 0.15)
    gl = stutter(gl, 0.0, 0.04, 5, 0.85, shrink=0.8)
    place(out, gl, 0, 0.25)
    # dark brass stab (dissonant)
    place(out, brass([mtof(m) for m in (33, 40, 45, 46)], 2.5, r, attack=0.01, cutoff=(300, 2600, 700), detune=0.2), 0, 0.55)
    th = thunder(r, 6.0)
    place(out, np.stack([th, np.roll(th, 307)]), ns(0.05), 0.55)
    rum = filt(noise(ns(5.0), r), "lp", 120, 0.8, order=2) * perc(5.0, 0.02, 1.6)
    place(out, pan(rum, -0.4) + pan(np.roll(rum, 113), 0.4), 0, 0.8)
    place(out, _st(crash(r, 4.0, 1.3), r), 0, 0.25)
    return reverb(out, wet=0.5, rt60=4.5, size=1.8, lp=2400, damp=0.6, predelay=0.02)


def redacted_tear(r):
    d = 1.6
    n = ns(1.1)
    t = np.arange(n) / SR
    out = zeros(d, True)
    # paper-like fibre rip: noise through jittering band-pass, crackle amplitude
    jit = np.exp(np.cumsum(r.normal(0, 0.06, n)) * 0.02)
    fc = np.clip(interp_curve([(0, 900), (0.6, 3800), (1.1, 1800)], 1.1, "exp") * jit, 300, 12000)
    rip = sweep(noise(n, r), "bp", fc, 1.4, frame=256, nfft=1024)
    grain = (r.random(n) < 0.004).astype(float)
    grain = filt(grain, "lp", 2500) * 30
    ampl = smooth(np.abs(r.normal(0, 1, n)), 0.004) * swell(1.1, 0.12, 1.2) * (0.6 + grain)
    rip = rip * ampl
    place(out, pan(rip, interp_curve([(0, -0.7), (1.1, 0.7)], 1.1)), 0, 1.0)
    # data glitch: bit-crushed stutters + pitched blips
    dig = crush(saw(interp_curve([(0, 1800), (0.5, 220)], 0.5, "exp"), ns(0.5)), 3, 12) * perc(0.5, 0.001, 0.2)
    dig = stutter(dig, 0.0, 0.03, 7, 0.9, rng=r, shrink=0.9)
    place(out, pan(dig, -0.3), ns(0.05), 0.35)
    for k in range(9):
        s = r.uniform(0.0, 0.9)
        b = square(r.uniform(700, 4000), ns(0.025)) * perc(0.025, 0.0005, 0.008)
        place(out, pan(crush(b, 4, 2), r.uniform(-1, 1)), ns(s), 0.18)
    gate = gate_pattern(ns(d), 0.022, list((r.random(80) > 0.2).astype(int)))
    out = out * (0.4 + 0.6 * gate)
    place(out, pan(sub_drop(0.6, 120, 45, 0.18, 1.5), 0), 0, 0.4)
    return reverb(out, wet=0.18, rt60=0.8, size=0.5, lp=8000)


def _beat(r, f0=58.0, g=1.0):
    n = ns(0.6)
    t = np.arange(n) / SR
    f = f0 * (1 + 0.5 * np.exp(-t / 0.025))
    x = np.sin(TAU * phase(f, n)) * perc(0.6, 0.006, 0.13, n)
    x += filt(noise(n, r), "lp", 180) * perc(0.6, 0.004, 0.06, n) * 0.6
    return drive(x * 1.3 * g, 1.5)


def redacted_heartbeat(r):
    d = 1.8
    out = zeros(d, True)
    place(out, pan(_beat(r, 56, 1.0), 0), 0, 1.0)
    place(out, pan(_beat(r, 50, 0.72), 0), ns(0.27), 0.8)
    out = filt(out, "lp", 900)
    return reverb(out, wet=0.22, rt60=1.4, size=0.8, lp=1200, damp=0.7)


def redacted_denied(r):
    d = 1.3
    out = zeros(d)

    def buzz(L):
        n = ns(L)
        tt = np.arange(n) / SR
        f = 98 * (1 - 0.04 * tt / L)
        x = square(f, n) + saw(f * 1.059, n) * 0.8 + square(f * 2.01, n) * 0.4
        x = x * (0.75 + 0.25 * square(31, n))
        x = drive(x * 1.5, 3.5)
        x = filt(x, "peak", 1300, 1.0, gain_db=7) * adsr(L, 0.004, 0.05, 0.9, 0.03, n=n)
        return x * 0.7 + crush(x, 4, 3) * 0.3

    place(out, buzz(0.26), 0)
    place(out, buzz(0.52), ns(0.33))
    out = filt(out, "lp", 6500)
    st = _st(out, r, 9)
    return reverb(st, wet=0.14, rt60=0.7, size=0.5)


def redacted_granted(r):
    d = 3.2
    out = zeros(d, True)
    for i, m in enumerate((72, 76, 79, 84, 88)):
        b = bell(mtof(m), 1.8, bright=0.9, tau=0.55)
        place(out, pan(b, -0.6 + 0.3 * i), ns(0.065 * i), 0.38)
    place(out, pan(sine(mtof(96), ns(1.5)) * perc(1.5, 0.004, 0.5), 0.3), ns(0.3), 0.1)
    acc = np.zeros(ns(2.6))
    for m in (60, 64, 67, 71):
        acc += tri(mtof(m), len(acc), r.uniform()) + 0.3 * sine(mtof(m) * 2, len(acc))
    pad = filt(acc, "lp", 3500) * adsr(2.6, 0.12, 0.6, 0.6, 1.2) / 4
    place(out, chorus(pad, 0.5, 2.5, 10, 0.6), 0, 0.45)
    place(out, sparkle(2.4, r, 36, 3500, 12000, 0.08, 1.3), 0, 0.24)
    sh = sweep(noise(ns(0.9), r), "bp", interp_curve([(0, 2500), (0.9, 12000)], 0.9, "exp"), 3.0) * swell(0.9, 0.1, 1.5)
    place(out, pan(sh, 0), 0, 0.07)
    place(out, pan(chirp_sine(500, 2400, 0.12) * perc(0.12, 0.002, 0.06), 0), 0, 0.12)
    return reverb(out, wet=0.38, rt60=2.2, size=1.0, predelay=0.02, lp=10000)


def redacted_choir(r):
    d = 13.0
    out = zeros(d, True)
    L = 10.0
    # D minor add9 / b6 colour, wide low voicing
    chord = [38, 45, 50, 53, 57, 58, 64]
    ch = choir([mtof(m) for m in chord], L + 1.5, r, "o", attack=4.5, release=3.0, voices=4)
    ch2 = choir([mtof(m) for m in (62, 65, 69)], L + 1.5, r, "a", attack=6.0, release=3.0, voices=4)
    place(out, ch, 0, 1.0)
    place(out, ch2, ns(1.0), 0.5)
    # synth layer under the voices: dark supersaw pad opening up
    n = ns(L + 1.5)
    tt = np.arange(n) / SR
    pad = np.zeros((2, n))
    for m in (38, 45, 50, 53):
        pad += supersaw(mtof(m), n, r, 6, 0.22, 1.0)
    pad = sweep(pad, "lp", 200 + 2600 * np.clip(tt / 9.0, 0, 1) ** 2, 1.1, frame=2048) * adsr(L + 1.5, 4.0, 1.0, 1.0, 2.5, n=n) / 2
    place(out, pad, 0, 0.45)
    sub = sine(mtof(26), n) * adsr(L + 1.5, 3.0, 1.0, 1.0, 2.5, n=n)
    place(out, pan(sub, 0), 0, 0.45)
    # timpani-like rumble swell into the peak
    rum = filt(noise(n, r), "lp", 140, 0.8, order=2) * swell(L + 1.5, 8.5, 2.5)
    place(out, _st(rum, r), 0, 0.5)
    place(out, sparkle(4.0, r, 18, 3000, 9000, 0.0, 3.0), ns(6.5), 0.1)
    out = out * swell(d, 9.0, 1.6)[None, :] ** 0.6
    # low opening hit so the swell starts from a felt impact, not from silence
    place(out, pan(sub_drop(3.0, 80, 28, 1.2, 1.4), 0), 0, 0.5)
    place(out, _st(filt(noise(ns(2.5), r), "lp", 400) * perc(2.5, 0.003, 0.8), r), 0, 0.35)
    return reverb(out, wet=0.65, rt60=5.0, size=2.0, lp=6000, damp=0.45, predelay=0.04, width=1.3)


# ----------------------------------------------------------------------------
# biome stingers
# ----------------------------------------------------------------------------
def _stinger(r, chord, kind):
    d = 3.0
    out = zeros(d, True)
    if kind == "storm":  # rain of green digital blips over a rising chord
        for i in range(40):
            s = 0.6 * (i / 40) ** 0.7 + r.uniform(0, 0.05)
            m = chord[r.integers(0, len(chord))] + 12 * r.integers(1, 3)
            b = pulse(mtof(m), ns(0.09), 0.25) * perc(0.09, 0.001, 0.03)
            place(out, pan(b, r.uniform(-0.9, 0.9)), ns(s), 0.12)
        pd = supersaw(mtof(chord[0]), ns(2.4), r, 5, 0.2) + supersaw(mtof(chord[2]), ns(2.4), r, 5, 0.2)
        pd = sweep(pd, "lp", interp_curve([(0, 400), (0.7, 5000), (2.4, 1500)], 2.4, "exp"), 1.3) * adsr(2.4, 0.05, 0.6, 0.5, 1.2)
        place(out, pd, ns(0.6), 0.25)
        th = thunder(r, 2.5)
        place(out, np.stack([th, np.roll(th, 150)]), ns(0.6), 0.35)
        place(out, kick(r, 0.6, 180, 45), ns(0.6), 0.45)
    elif kind == "over":  # engine rev + overdriven power chord
        n = ns(0.75)
        tt = np.arange(n) / SR
        f = 40 * (160 / 40) ** ((tt / 0.75) ** 1.5)
        rev = drive(saw(f, n) + square(f * 0.5, n) * 0.6, 3.5) * (0.3 + 0.7 * swell(0.75, 0.7, 1.4))
        place(out, pan(filt(rev, "lp", 2500), 0), 0, 0.35)
        pc = np.zeros(ns(2.2))
        for m in chord[:3]:
            pc += saw(mtof(m), len(pc)) + saw(mtof(m) * 1.005, len(pc))
        pc = filt(drive(pc * 0.6, 5.0), "lp", 4200) * adsr(2.2, 0.003, 0.4, 0.6, 1.0)
        place(out, _st(pc, r), ns(0.75), 0.3)
        place(out, kick(r, 0.7, 200, 44), ns(0.75), 0.55)
        place(out, _st(crash(r, 2.2, 0.7), r), ns(0.75), 0.18)
        sp = (r.random(ns(1.5)) < 0.003).astype(float)
        place(out, _st(filt(sp, "hp", 3000) * 6 * perc(1.5, 0.001, 0.5), r), ns(0.75), 0.25)
    elif kind == "black":  # power-down whine, silence, deep hit
        n = ns(1.0)
        tt = np.arange(n) / SR
        f = 2400 * (80 / 2400) ** (tt / 1.0)
        pw = (sine(f, n) + 0.3 * saw(f, n)) * (1 - tt / 1.0) ** 0.5
        place(out, pan(filt(pw, "lp", 4000), 0), 0, 0.3)
        hum = saw(60, ns(1.0)) * (1 - tt) ** 2
        place(out, pan(filt(hum, "lp", 400), 0), 0, 0.2)
        place(out, pan(_beat(r, 46, 1.2), 0), ns(1.15), 0.9)
        place(out, pan(_beat(r, 42, 0.8), 0), ns(1.42), 0.6)
        dk = choir([mtof(m) for m in chord], 1.8, r, "u", attack=0.3, release=1.0, voices=3)
        place(out, dk, ns(1.15), 0.35)
    else:  # panic: alarm wail + glitch hits
        n = ns(1.6)
        tt = np.arange(n) / SR
        lfo = 0.5 - 0.5 * np.cos(TAU * tt / 0.4)
        f = 700 * (1200 / 700) ** lfo
        al = drive(square(f, n) + saw(f * 1.01, n), 2.5) * adsr(1.6, 0.02, 0.2, 0.8, 0.3, n=n)
        place(out, pan(filt(al, "bp", 1600, 0.8), 0), 0, 0.25)
        for k in range(3):
            g = crush(supersaw(mtof(chord[k]), ns(0.25), r, 5, 0.6), 4, 6) * perc(0.25, 0.001, 0.09)
            place(out, g, ns(0.2 + 0.18 * k), 0.3)
            place(out, kick(r, 0.4, 210, 50), ns(0.2 + 0.18 * k), 0.4)
        place(out, _st(drive(filt(noise(ns(1.4), r), "lp", 3000) * perc(1.4, 0.001, 0.3), 3.0), r), ns(0.74), 0.35)
        place(out, sub_drop(1.5, 110, 30, 0.6, 1.8), ns(0.74), 0.55)
    return reverb(out, wet=0.33, rt60=2.0, size=1.1, lp=7000)


def bs_datastorm(r):
    return _stinger(r, [57, 60, 64, 71], "storm")


def bs_overclock(r):
    return _stinger(r, [40, 47, 52], "over")


def bs_blackout(r):
    return _stinger(r, [38, 41, 44, 49], "black")


def bs_kernelpanic(r):
    return _stinger(r, [37, 43, 49], "panic")


# ----------------------------------------------------------------------------
# UI / NPC
# ----------------------------------------------------------------------------
def npc_talk(r):
    d = 0.09
    n = ns(d)
    f = r.choice([620, 700, 760]) * (1 + 0.06 * np.exp(-np.arange(n) / SR / 0.01))
    x = (square(f, n) * 0.4 + sine(f, n) * 0.6) * perc(d, 0.002, 0.03, n)
    x = filt(x, "lp", 3000)
    return x * 0.8 + crush(x, 6, 2) * 0.2


def quest_done(r):
    d = 2.6
    out = zeros(d, True)
    seq = [(0.0, 67), (0.09, 71), (0.18, 74), (0.27, 79)]
    for i, (s, m) in enumerate(seq):
        b = bell(mtof(m), 1.4, bright=0.8, tau=0.4) + pulse(mtof(m), ns(1.4), 0.3) * perc(1.4, 0.002, 0.08) * 0.2
        place(out, pan(b, -0.45 + 0.3 * i), ns(s), 0.35)
    ch = brass([mtof(m) for m in (55, 62, 67, 71, 74)], 1.4, r, attack=0.03, cutoff=(900, 5000, 2200), detune=0.1)
    place(out, ch, ns(0.36), 0.55)
    place(out, sparkle(1.8, r, 26, 3500, 11000, 0.0, 1.0), ns(0.36), 0.2)
    place(out, sine(mtof(43), ns(1.3)) * perc(1.3, 0.01, 0.4), ns(0.36), 0.25)
    return reverb(out, wet=0.32, rt60=1.7, size=0.9)


def buy(r):
    d = 1.3
    out = zeros(d, True)
    # data-register: two quick digital blips + coin-like FM ching + drawer thunk
    for i, (s, f) in enumerate(((0.0, 1320), (0.06, 1760))):
        b = square(f, ns(0.05)) * perc(0.05, 0.0005, 0.02)
        place(out, pan(crush(b, 5, 2), -0.2 + 0.4 * i), ns(s), 0.25)
    n = ns(1.0)
    tt = np.arange(n) / SR
    ching = fm(2637, n, 1.41, 2.0 * np.exp(-tt / 0.04) + 0.3) * perc(1.0, 0.0005, 0.25, n)
    ching += fm(3520, n, 2.76, 1.2 * np.exp(-tt / 0.03)) * perc(1.0, 0.0005, 0.18, n) * 0.6
    place(out, _st(ching, r), ns(0.12), 0.35)
    th = filt(noise(ns(0.2), r), "bp", 300, 1.0) * perc(0.2, 0.001, 0.04) + sine(90, ns(0.2)) * perc(0.2, 0.002, 0.05)
    place(out, pan(th, 0), ns(0.12), 0.45)
    place(out, sparkle(0.8, r, 10, 5000, 11000, 0.0, 0.3), ns(0.14), 0.12)
    return reverb(out, wet=0.2, rt60=0.9, size=0.6)


# ----------------------------------------------------------------------------
# ambience loops
# ----------------------------------------------------------------------------
def amb_city(r):
    L, xf = 20.0, 3.0
    d = L + xf
    n = ns(d)
    t = np.arange(n) / SR
    out = np.zeros((2, n))
    # mains hum + transformer harmonics (integer cycles in 20 s => periodic anyway)
    hum = sine(60, n) * 0.5 + sine(120, n) * 0.35 + sine(180, n) * 0.12 + saw(60, n) * 0.04
    out += to_stereo(filt(hum, "lp", 500)) * 0.25
    # low city rumble
    rum = np.stack([pink(n, r), pink(n, r)])
    out += filt(rum, "lp", 260, 0.7, order=2) * 0.9
    out += filt(np.stack([pink(n, r), pink(n, r)]), "bp", 900, 0.5) * 0.07
    # distant traffic: passing cars = band-passed noise swells with doppler-ish pan
    for k in range(9):
        s = r.uniform(0, L)
        dur = r.uniform(3.0, 6.0)
        m = ns(dur)
        tt = np.arange(m) / SR
        car = filt(noise(m, r), "bp", r.uniform(300, 700), 0.9) + saw(r.uniform(40, 70) * (1.02 - 0.04 * tt / dur), m) * 0.25
        car = filt(car, "lp", 1200) * np.sin(np.pi * tt / dur) ** 2
        dirn = r.choice([-1, 1])
        place(out, pan(car, dirn * np.linspace(-0.8, 0.8, m)), ns(s), r.uniform(0.15, 0.3))
    # far horn / siren once
    m = ns(3.0)
    tt = np.arange(m) / SR
    sir = saw(600 + 180 * np.sin(TAU * tt / 1.2), m) * np.sin(np.pi * tt / 3.0) ** 2
    place(out, pan(filt(sir, "bp", 900, 1.0), 0.6), ns(r.uniform(4, 14)), 0.03)
    # neon buzz flickers
    for _ in range(6):
        s = r.uniform(0, L)
        m = ns(r.uniform(0.3, 1.2))
        bz = filt(saw(120, m) + square(240, m) * 0.3, "bp", 2400, 2.0) * (r.random(m) < 0.6) * perc(m / SR, 0.01, 0.5, m)
        place(out, pan(smooth(bz, 0.0005), r.uniform(-0.7, 0.7)), ns(s), 0.03)
    out = reverb(out, wet=0.35, rt60=2.8, size=1.6, lp=3000, damp=0.6)
    out = fit(out, n)
    # wrap anything placed past L back to the head before crossfading
    x = loopify(out, ns(L), ns(xf))
    return finish_loop(x, -26.0, -6.0)


def amb_storm(r):
    L, xf = 20.0, 3.0
    d = L + xf
    n = ns(d)
    t = np.arange(n) / SR
    out = np.zeros((2, n))
    # rain bed
    rain = np.stack([noise(n, r), noise(n, r)])
    out += filt(filt(rain, "hp", 800), "lp", 9000) * 0.18
    out += filt(np.stack([pink(n, r), pink(n, r)]), "lp", 500) * 0.4
    # droplets: dense tiny ticks
    drops = (r.random((2, n)) < 0.0025).astype(float) * r.random((2, n))
    out += filt(drops, "bp", 3500, 1.0) * 1.2
    # digital rain: falling pitched blips in A minor pentatonic
    pent = [69, 72, 74, 76, 79, 81, 84, 86, 88, 91]
    for _ in range(int(L * 6)):
        s = r.uniform(0, L)
        m = pent[r.integers(0, len(pent))]
        Lb = r.uniform(0.04, 0.12)
        f = mtof(m) * (1 - 0.15 * np.arange(ns(Lb)) / ns(Lb))
        b = (pulse(f, ns(Lb), 0.25) * 0.5 + sine(f, ns(Lb))) * perc(Lb, 0.001, Lb * 0.3)
        b = crush(b, 6, 2)
        place(out, pan(b, r.uniform(-1, 1)), ns(s), r.uniform(0.02, 0.06))
    # distant thunder twice
    for s in (r.uniform(1, 6), r.uniform(11, 16)):
        th = thunder(r, 4.5)
        place(out, np.stack([th, np.roll(th, 200)]), ns(s), 0.5)
    out = reverb(out, wet=0.3, rt60=2.2, size=1.4, lp=6000)
    out = fit(out, n)
    x = loopify(out, ns(L), ns(xf))
    return finish_loop(x, -24.0, -5.0)


REGISTRY = {
    "RedactedStamp": (redacted_stamp, -1.0, True, {}),
    "RedactedRiser": (redacted_riser, -1.5, True, {"trim": False, "fade_out": 0.006}),
    "RedactedHit": (redacted_hit, -0.8, True, {}),
    "RedactedTear": (redacted_tear, -2.0, True, {}),
    "RedactedHeartbeat": (redacted_heartbeat, -1.5, True, {}),
    "RedactedDenied": (redacted_denied, -5.0, True, {}),
    "RedactedGranted": (redacted_granted, -3.0, True, {}),
    "RedactedChoir": (redacted_choir, -1.5, True, {}),
    "BiomeStart_DataStorm": (bs_datastorm, -3.0, True, {}),
    "BiomeStart_Overclock": (bs_overclock, -3.0, True, {}),
    "BiomeStart_Blackout": (bs_blackout, -3.0, True, {}),
    "BiomeStart_KernelPanic": (bs_kernelpanic, -3.0, True, {}),
    "NpcTalk": (npc_talk, -10.0, False, {}),
    "QuestDone": (quest_done, -3.0, True, {}),
    "Buy": (buy, -5.0, True, {}),
}

LOOPS = {
    "RedactedDrone": redacted_drone,
    "AmbCity": amb_city,
    "AmbStorm": amb_storm,
}
