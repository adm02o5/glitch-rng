"""Synth voices and drum kit shared by SFX and music."""
from __future__ import annotations

import math

import numpy as np

from .dsp import (
    SR, TAU, adsr, drive, filt, fit, fm, mtof, noise, ns, pan, perc, phase, pulse,
    saw, sine, smooth, square, supersaw, sweep, tri, formant, to_mono, mix, chorus,
)


# ----------------------------------------------------------------------------
# drums
# ----------------------------------------------------------------------------
def kick(rng, dur=0.5, f_hi=170.0, f_lo=46.0, pitch_tau=0.032, amp_tau=0.22, click=0.5, punch=1.8, sub=0.25):
    n = ns(dur)
    t = np.arange(n) / SR
    f = f_lo + (f_hi - f_lo) * np.exp(-t / pitch_tau)
    body = np.sin(TAU * phase(f, n))
    env = np.exp(-t / amp_tau) * np.minimum(t / 0.0015, 1)
    tail = np.sin(TAU * phase(f_lo * 0.98, n)) * np.exp(-t / (amp_tau * 1.6)) * sub
    x = body * env + tail * np.minimum(t / 0.02, 1)
    cl = filt(noise(n, rng), "hp", 2500) * perc(dur, 0.0002, 0.0035, n) * click
    cl += np.sin(TAU * 1100 * t) * perc(dur, 0.0002, 0.006, n) * click * 0.6
    x = drive(x * punch + cl, 1.6)
    k = min(n, ns(0.02))
    x[-k:] *= np.linspace(1, 0, k)
    return x


def snare(rng, dur=0.42, tone=190.0, snap=1.0, body=0.8, tau=0.11):
    n = ns(dur)
    t = np.arange(n) / SR
    f = tone * (1 + 0.5 * np.exp(-t / 0.01))
    tn = np.sin(TAU * phase(f, n)) * np.exp(-t / 0.045) + 0.6 * np.sin(TAU * phase(f * 1.72, n)) * np.exp(-t / 0.03)
    nz = noise(n, rng)
    wires = filt(nz, "bp", 3800, 0.6) * 0.8 + filt(nz, "hp", 6500) * 0.5 + filt(nz, "bp", 1800, 1.2) * 0.6
    wires *= perc(dur, 0.0008, tau, n) * snap
    x = tn * body * np.minimum(t / 0.001, 1) + wires
    return drive(x * 1.3, 1.4)


def clap(rng, dur=0.45, tau=0.13):
    n = ns(dur)
    t = np.arange(n) / SR
    nz = filt(noise(n, rng), "bp", 1300, 1.4) + filt(noise(n, rng), "bp", 2600, 1.2) * 0.5
    env = np.zeros(n)
    for k, off in enumerate([0.0, 0.011, 0.021, 0.034]):
        tt = t - off
        env += np.where(tt >= 0, np.exp(-np.maximum(tt, 0) / (0.007 if k < 3 else tau)), 0) * (1.0 if k == 3 else 0.8)
    return drive(nz * env * 1.5, 1.2)


_METAL = [205.3, 304.4, 369.6, 522.7, 540.0, 800.0]


def hat(rng, dur=0.07, tau=0.018, tone=1.0, bright=8500.0):
    n = ns(dur)
    m = np.zeros(n)
    for f in _METAL:
        m += square(f * 1.47 * tone, n, rng.uniform())
    m = filt(m, "bp", bright * 1.2, 1.2)
    nz = filt(noise(n, rng), "hp", bright)
    x = filt(m * 0.6 + nz * 0.7, "hp", 6500, 0.7, order=2)
    return x * perc(dur, 0.0004, tau, n)


def crash(rng, dur=2.6, tau=0.8):
    n = ns(dur)
    m = np.zeros(n)
    for f in _METAL:
        m += square(f * 2.13, n, rng.uniform()) + square(f * 3.07, n, rng.uniform()) * 0.6
    nz = noise(n, rng)
    x = filt(m * 0.25 + nz, "hp", 4200, 0.7, order=2)
    x = filt(x, "peak", 9000, 0.8, gain_db=4)
    env = perc(dur, 0.002, tau, n) * 0.7 + perc(dur, 0.0005, 0.06, n) * 0.5
    return x * env


def tom(rng, freq=110.0, dur=0.5):
    n = ns(dur)
    t = np.arange(n) / SR
    f = freq * (1 + 0.6 * np.exp(-t / 0.05))
    x = np.sin(TAU * phase(f, n)) * perc(dur, 0.001, 0.16, n)
    x += filt(noise(n, rng), "bp", freq * 4, 1.5) * perc(dur, 0.0005, 0.03, n) * 0.4
    return drive(x * 1.2, 1.3)


def thunder(rng, dur=5.0):
    """Distant rumble: brown-ish noise with crackle bursts."""
    n = ns(dur)
    nz = noise(n, rng)
    br = np.cumsum(nz)
    br = filt(br - smooth(br, 0.05), "lp", 240, 0.7)
    br /= np.abs(br).max() + 1e-9
    env = np.zeros(n)
    t = np.arange(n) / SR
    for _ in range(6):
        t0 = rng.uniform(0, dur * 0.5)
        env += np.where(t >= t0, np.exp(-np.maximum(t - t0, 0) / rng.uniform(0.4, 1.4)), 0) * rng.uniform(0.3, 1.0)
    env *= np.minimum(t / 0.05, 1)
    crack = filt(noise(n, rng), "bp", 900, 0.8) * perc(dur, 0.002, 0.25, n) * 0.25
    return (br * env + crack) / max(1.0, env.max())


# ----------------------------------------------------------------------------
# melodic voices (one-shot notes)
# ----------------------------------------------------------------------------
def bell(freq, dur=1.5, rng=None, bright=1.0, tau=0.5):
    """Glassy FM bell (ratio 3.5 inharmonic partial + 1:1 body)."""
    n = ns(dur)
    t = np.arange(n) / SR
    idx = bright * (2.2 * np.exp(-t / 0.15) + 0.4)
    a = fm(freq, n, 3.5, idx)
    b = fm(freq * 2.0, n, 1.0, 0.8 * np.exp(-t / 0.3)) * 0.35
    env = perc(dur, 0.0015, tau, n)
    return (a + b) * env


def pluck(freq, dur=0.6, cutoff=3500.0, tau=0.18, width=0.35, rng=None):
    n = ns(dur)
    x = pulse(freq, n, width) * 0.6 + saw(freq * 1.003, n) * 0.5
    env_f = cutoff * (0.25 + 0.75 * np.exp(-np.arange(n) / SR / 0.08))
    x = sweep(x, "lp", env_f, 1.2, frame=512, nfft=2048)
    return x * perc(dur, 0.002, tau, n)


def brass(freqs, dur, rng, attack=0.08, cutoff=(400.0, 4200.0, 1800.0), detune=0.12, voices=5):
    """Synth brass chord: detuned saws, filter envelope with swell + settle. Stereo."""
    n = ns(dur)
    t = np.arange(n) / SR
    out = np.zeros((2, n))
    for f in np.atleast_1d(freqs):
        vib = 1 + 0.003 * np.sin(TAU * 5.2 * t + rng.uniform(0, 6)) * np.clip((t - 0.3) / 0.4, 0, 1)
        out += supersaw(f * vib, n, rng, voices, detune, 0.8)
    c0, c1, c2 = cutoff
    fenv = np.where(t < attack, c0 + (c1 - c0) * (t / attack) ** 0.7, c2 + (c1 - c2) * np.exp(-(t - attack) / 0.35))
    out = sweep(out, "lp", fenv, 1.6, frame=1024)
    out = out * adsr(dur, attack * 0.6, 0.3, 0.8, min(0.5, dur * 0.4), n=n)
    return out / max(1, len(np.atleast_1d(freqs))) ** 0.5


def choir(freqs, dur, rng, vowel="a", attack=0.6, release=1.2, voices=4):
    """Choir-like pad: vibrato'd pulse/saw ensemble through vowel formants. Stereo."""
    n = ns(dur)
    t = np.arange(n) / SR
    out = np.zeros((2, n))
    for f in np.atleast_1d(freqs):
        for v in range(voices):
            rate = rng.uniform(4.6, 5.8)
            vib = 1 + 0.006 * np.sin(TAU * rate * t + rng.uniform(0, 6)) + rng.uniform(-0.004, 0.004)
            src = saw(f * vib, n, rng.uniform()) * 0.6 + pulse(f * vib, n, 0.3, rng.uniform()) * 0.4
            out += pan(src, rng.uniform(-0.8, 0.8))
    out = formant(out, vowel, 8.0)
    out = filt(out, "lp", 6000)
    env = adsr(dur, attack, 0.4, 0.9, release, n=n)
    return out * env / (len(np.atleast_1d(freqs)) * voices) ** 0.5


def sparkle(dur, rng, count=24, f_lo=2500.0, f_hi=9000.0, start=0.0, spread=None, tau=0.12):
    """Random glassy high pings scattered in time (stereo)."""
    n = ns(dur)
    out = np.zeros((2, n))
    spread = spread if spread is not None else dur * 0.8
    for _ in range(count):
        t0 = start + spread * rng.uniform() ** 1.6  # front-loaded scatter
        f = math.exp(rng.uniform(math.log(f_lo), math.log(f_hi)))
        L = min(0.35, dur - t0)
        if L <= 0.01:
            continue
        p = bell(f, L, bright=0.4, tau=tau * rng.uniform(0.6, 1.4)) * rng.uniform(0.3, 1.0)
        s = ns(t0)
        seg = pan(p, rng.uniform(-0.9, 0.9))
        m = min(seg.shape[1], n - s)
        out[:, s : s + m] += seg[:, :m]
    return out


def sub_drop(dur=1.5, f0=95.0, f1=32.0, tau=0.7, drive_amt=1.6):
    n = ns(dur)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t / (dur * 0.25))
    x = np.sin(TAU * phase(f, n)) * perc(dur, 0.004, tau, n)
    return drive(x * 1.2, drive_amt)


# ----------------------------------------------------------------------------
# continuous monophonic / polyphonic lines for music
# ----------------------------------------------------------------------------
def line_arrays(notes, n, glide=0.006, default_midi=48):
    """notes = [(start_s, dur_s, midi, vel)]. Returns (freq, gate_start_mask, note_index arrays)."""
    # piecewise-constant log-frequency: each note holds until the next one starts
    first = math.log(mtof(notes[0][2] if notes else default_midi))
    marks = np.zeros(n, dtype=np.int64)
    vals = [first]
    for k, (s, d, m, v) in enumerate(sorted(notes, key=lambda q: q[0])):
        a = ns(s)
        if a < n:
            marks[a] = len(vals)
            vals.append(math.log(mtof(m)))
    idx = np.maximum.accumulate(marks)
    logf = np.asarray(vals)[idx]
    if glide > 0:
        logf = smooth(logf, glide)
    return np.exp(logf)


def note_env(notes, n, a=0.003, d=0.12, s=0.6, r=0.04, curve=5.0):
    env = np.zeros(n)
    for (st, du, m, v) in notes:
        k = ns(st)
        if k >= n:
            continue
        e = adsr(du + r, a, d, s, r, curve) * v
        m_ = min(len(e), n - k)
        env[k : k + m_] = np.maximum(env[k : k + m_], e[:m_])
    return env


def decay_env(notes, n, tau=0.12):
    """Per-note decaying contour 1 -> 0 (for filter envelopes)."""
    env = np.zeros(n)
    t = np.arange(ns(4 * tau + 0.05)) / SR
    shape = np.exp(-t / tau)
    for (st, du, m, v) in notes:
        k = ns(st)
        if k >= n:
            continue
        mm = min(len(shape), n - k)
        env[k : k + mm] = np.maximum(env[k : k + mm], shape[:mm] * v)
    return env
