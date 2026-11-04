"""Core DSP for the Glitch RNG sound synthesizer (numpy only).

Conventions
-----------
* Sample rate SR = 44100.
* Mono signals are 1-D float arrays, stereo signals are (2, n) arrays.
* Every filter works along the last axis, so mono and stereo both work.
* Heavy recursive structures (biquads, damped combs, allpasses, feedback delays)
  are evaluated as exact transfer functions in the frequency domain, which keeps
  everything vectorised and fast without scipy.
"""
from __future__ import annotations

import math
import zlib

import numpy as np

SR = 44100
TAU = 2.0 * math.pi


# ----------------------------------------------------------------------------
# basics
# ----------------------------------------------------------------------------
def ns(sec: float) -> int:
    """Seconds -> samples."""
    return max(0, int(round(sec * SR)))


def tvec(dur: float) -> np.ndarray:
    return np.arange(ns(dur)) / SR


def mtof(m):
    return 440.0 * 2.0 ** ((np.asarray(m, dtype=float) - 69.0) / 12.0)


def db(x: float) -> float:
    return 10.0 ** (x / 20.0)


def rng_for(name: str, salt: int = 0) -> np.random.Generator:
    return np.random.default_rng(zlib.crc32(name.encode()) + salt * 7919)


def next_pow2(n: int) -> int:
    return 1 << max(1, int(n - 1).bit_length())


def zeros(dur_or_n, stereo=False):
    n = dur_or_n if isinstance(dur_or_n, (int, np.integer)) else ns(dur_or_n)
    return np.zeros((2, n)) if stereo else np.zeros(n)


def length(x) -> int:
    return x.shape[-1]


def fit(x: np.ndarray, n: int) -> np.ndarray:
    """Pad with zeros / cut to exactly n samples (last axis)."""
    m = x.shape[-1]
    if m == n:
        return x
    if m > n:
        return x[..., :n]
    pad = [(0, 0)] * (x.ndim - 1) + [(0, n - m)]
    return np.pad(x, pad)


def pad(x: np.ndarray, sec: float) -> np.ndarray:
    return fit(x, x.shape[-1] + ns(sec))


def to_stereo(x: np.ndarray) -> np.ndarray:
    return x if x.ndim == 2 else np.stack([x, x])


def to_mono(x: np.ndarray) -> np.ndarray:
    return x if x.ndim == 1 else x.mean(axis=0)


def mix(*parts) -> np.ndarray:
    """Sum signals of different lengths / channel counts (result stereo if any is)."""
    parts = [p for p in parts if p is not None]
    n = max(p.shape[-1] for p in parts)
    stereo = any(p.ndim == 2 for p in parts)
    out = zeros(n, stereo)
    for p in parts:
        if stereo:
            out[:, : p.shape[-1]] += to_stereo(p)
        else:
            out[: p.shape[-1]] += p
    return out


def place(buf: np.ndarray, sig: np.ndarray, start: int, gain: float = 1.0) -> None:
    """Add sig into buf at sample offset start (clipped at both ends)."""
    n = buf.shape[-1]
    if start >= n:
        return
    s0 = 0
    if start < 0:
        s0 = -start
        start = 0
    m = min(sig.shape[-1] - s0, n - start)
    if m <= 0:
        return
    if buf.ndim == 2:
        buf[:, start : start + m] += to_stereo(sig)[:, s0 : s0 + m] * gain
    else:
        buf[start : start + m] += to_mono(sig)[s0 : s0 + m] * gain


def at(sig: np.ndarray, sec: float, total: float | None = None) -> np.ndarray:
    """Return sig delayed by sec (zero padded in front)."""
    out = fit(np.zeros(sig.shape[:-1] + (0,)), 0)
    pre = ns(sec)
    padw = [(0, 0)] * (sig.ndim - 1) + [(pre, 0)]
    out = np.pad(sig, padw)
    if total is not None:
        out = fit(out, ns(total))
    return out


def pan(x: np.ndarray, p) -> np.ndarray:
    """Equal power pan, p in [-1, 1] (scalar or per-sample array)."""
    x = to_mono(x)
    a = (np.asarray(p, dtype=float) + 1.0) * (math.pi / 4.0)
    return np.stack([x * np.cos(a), x * np.sin(a)])


def fade(x: np.ndarray, fin: float = 0.0, fout: float = 0.0) -> np.ndarray:
    x = x.copy()
    n = x.shape[-1]
    a, b = min(ns(fin), n), min(ns(fout), n)
    if a > 0:
        x[..., :a] *= np.sin(np.linspace(0, math.pi / 2, a)) ** 2
    if b > 0:
        x[..., n - b :] *= np.cos(np.linspace(0, math.pi / 2, b)) ** 2
    return x


def interp_curve(points, dur: float, kind: str = "lin") -> np.ndarray:
    """Breakpoint automation. points = [(t, v), ...]; kind 'lin' or 'exp' (geometric)."""
    t = tvec(dur)
    ts = np.array([p[0] for p in points], dtype=float)
    vs = np.array([p[1] for p in points], dtype=float)
    if kind == "exp":
        return np.exp(np.interp(t, ts, np.log(np.maximum(vs, 1e-9))))
    return np.interp(t, ts, vs)


def smooth(a: np.ndarray, sec: float) -> np.ndarray:
    """Centered moving average (edge padded)."""
    w = max(1, ns(sec)) | 1
    if w <= 1:
        return a
    h = w // 2
    p = np.pad(a, (h + 1, h), mode="edge")
    c = np.cumsum(p)
    return (c[w:] - c[:-w]) / w


# ----------------------------------------------------------------------------
# envelopes
# ----------------------------------------------------------------------------
def adsr(dur: float, a=0.005, d=0.1, s=0.7, r=0.1, curve=5.0, n: int | None = None) -> np.ndarray:
    """ADSR where total length = dur and the gate closes at dur - r.

    Attack is a fast concave rise, decay/release are exponential (curve = how many
    time constants fit in d / r)."""
    n = ns(dur) if n is None else n
    t = np.arange(n) / SR
    gate = max(dur - r, 0.0)
    a = max(a, 1e-4)
    att = np.clip(t / a, 0, 1)
    att = 1.0 - (1.0 - att) ** 2.2
    dec = s + (1.0 - s) * np.exp(-curve * np.clip(t - a, 0, None) / max(d, 1e-4))
    env = np.where(t < a, att, dec)
    gi = min(ns(gate), n - 1) if n else 0
    gv = env[gi] if n else 0.0
    rel = gv * np.exp(-curve * np.clip(t - gate, 0, None) / max(r, 1e-4))
    env = np.where(t < gate, env, rel)
    k = min(n, 64)
    if k:
        env[-k:] *= np.linspace(1, 0, k)
    return env


def perc(dur: float, a=0.001, tau=0.1, n: int | None = None) -> np.ndarray:
    """Percussive envelope: tiny attack then exponential decay with time constant tau."""
    n = ns(dur) if n is None else n
    t = np.arange(n) / SR
    env = np.minimum(t / max(a, 1e-5), 1.0) * np.exp(-np.maximum(t - a, 0) / tau)
    k = min(n, max(64, n // 4))  # smooth tail-out so long hits never end with an edge
    if k:
        env[-k:] *= np.cos(np.linspace(0, math.pi / 2, k)) ** 2
    return env


def swell(dur: float, peak_at: float, power=2.0) -> np.ndarray:
    """Rise to 1 at peak_at then fall back to 0 at dur (smooth bell)."""
    t = tvec(dur)
    up = np.clip(t / max(peak_at, 1e-4), 0, 1) ** power
    down = np.clip((dur - t) / max(dur - peak_at, 1e-4), 0, 1) ** power
    return np.where(t < peak_at, up, down)


# ----------------------------------------------------------------------------
# oscillators (band limited with PolyBLEP where it matters)
# ----------------------------------------------------------------------------
def _freq(freq, n):
    f = np.asarray(freq, dtype=float)
    if f.ndim == 0:
        return np.full(n, float(f))
    return fit(f, n) if len(f) != n else f


def phase(freq, n: int, ph0: float = 0.0) -> np.ndarray:
    f = _freq(freq, n)
    ph = np.cumsum(f) / SR
    return ph - f[0] / SR + ph0 if n else ph


def _blep(t, dt):
    out = np.zeros_like(t)
    m = t < dt
    if m.any():
        x = t[m] / dt[m]
        out[m] = x + x - x * x - 1.0
    m = t > 1.0 - dt
    if m.any():
        x = (t[m] - 1.0) / dt[m]
        out[m] = x * x + x + x + 1.0
    return out


def saw(freq, n: int, ph0: float = 0.0) -> np.ndarray:
    f = _freq(freq, n)
    t = phase(f, n, ph0) % 1.0
    dt = np.clip(np.abs(f) / SR, 1e-6, 0.49)
    return 2.0 * t - 1.0 - _blep(t, dt)


def pulse(freq, n: int, width=0.5, ph0: float = 0.0) -> np.ndarray:
    f = _freq(freq, n)
    t = phase(f, n, ph0) % 1.0
    w = np.clip(_freq(width, n), 0.03, 0.97)
    dt = np.clip(np.abs(f) / SR, 1e-6, 0.49)
    v = np.where(t < w, 1.0, -1.0)
    v = v + _blep(t, dt) - _blep((t - w) % 1.0, dt)
    return v - (2.0 * w - 1.0)  # remove PWM DC


def square(freq, n: int, ph0: float = 0.0) -> np.ndarray:
    return pulse(freq, n, 0.5, ph0)


def sine(freq, n: int, ph0: float = 0.0) -> np.ndarray:
    return np.sin(TAU * phase(freq, n, ph0))


def tri(freq, n: int, ph0: float = 0.0) -> np.ndarray:
    t = phase(freq, n, ph0 + 0.25) % 1.0
    return 2.0 * np.abs(2.0 * t - 1.0) - 1.0


def fm(freq, n: int, ratio=2.0, index=1.0, fb=0.0, ph0=0.0) -> np.ndarray:
    """2-operator FM (phase modulation). index may be an envelope array."""
    f = _freq(freq, n)
    mod = np.sin(TAU * phase(f * ratio, n))
    if fb:
        mod = np.sin(TAU * phase(f * ratio, n) + fb * mod)
    return np.sin(TAU * phase(f, n, ph0) + _freq(index, n) * mod)


def noise(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, n)


def pink(n: int, rng: np.random.Generator) -> np.ndarray:
    N = next_pow2(n + 16)
    spec = np.fft.rfft(rng.standard_normal(N))
    f = np.arange(len(spec))
    f[0] = 1
    spec /= np.sqrt(f)
    x = np.fft.irfft(spec, N)[:n]
    return x / (np.abs(x).max() + 1e-12)


def supersaw(freq, n: int, rng, voices=7, detune=0.25, width=1.0) -> np.ndarray:
    """JP-8000 style supersaw, stereo. detune 0..1 (≈ ±0.0..±1.1 semitone spread)."""
    f = _freq(freq, n)
    offs = np.linspace(-1.0, 1.0, voices)
    curve = np.sign(offs) * np.abs(offs) ** 1.4
    out = np.zeros((2, n))
    for i, o in enumerate(curve):
        cents = o * detune * 65.0
        v = saw(f * 2 ** (cents / 1200.0), n, rng.uniform())
        g = 1.0 if abs(o) < 1e-6 else 0.72
        p = o * width if voices > 1 else 0.0
        out += pan(v * g, p)
    return out / math.sqrt(voices)


def chirp_sine(f0, f1, dur, kind="exp") -> np.ndarray:
    n = ns(dur)
    if kind == "exp":
        f = f0 * (f1 / f0) ** (np.arange(n) / max(n - 1, 1))
    else:
        f = np.linspace(f0, f1, n)
    return sine(f, n)


# ----------------------------------------------------------------------------
# biquad filters (RBJ cookbook) evaluated in the frequency domain
# ----------------------------------------------------------------------------
def biquad_H(kind: str, f0, Q, w, gain_db=0.0):
    f0 = np.clip(np.asarray(f0, dtype=float), 5.0, SR * 0.49)
    Q = np.maximum(np.asarray(Q, dtype=float), 0.05)
    w0 = TAU * f0 / SR
    c, s = np.cos(w0), np.sin(w0)
    al = s / (2.0 * Q)
    z1 = np.exp(-1j * w)
    z2 = z1 * z1
    A = 10.0 ** (np.asarray(gain_db, dtype=float) / 40.0)
    if kind == "lp":
        b0 = (1 - c) / 2; b1 = 1 - c; b2 = b0
        a0 = 1 + al; a1 = -2 * c; a2 = 1 - al
    elif kind == "hp":
        b0 = (1 + c) / 2; b1 = -(1 + c); b2 = b0
        a0 = 1 + al; a1 = -2 * c; a2 = 1 - al
    elif kind == "bp":
        b0 = al; b1 = 0.0 * c; b2 = -al
        a0 = 1 + al; a1 = -2 * c; a2 = 1 - al
    elif kind == "notch":
        b0 = 1.0 + 0 * c; b1 = -2 * c; b2 = 1.0 + 0 * c
        a0 = 1 + al; a1 = -2 * c; a2 = 1 - al
    elif kind == "peak":
        b0 = 1 + al * A; b1 = -2 * c; b2 = 1 - al * A
        a0 = 1 + al / A; a1 = -2 * c; a2 = 1 - al / A
    elif kind in ("lowshelf", "highshelf"):
        sq = 2 * np.sqrt(A) * al
        if kind == "lowshelf":
            b0 = A * ((A + 1) - (A - 1) * c + sq); b1 = 2 * A * ((A - 1) - (A + 1) * c)
            b2 = A * ((A + 1) - (A - 1) * c - sq); a0 = (A + 1) + (A - 1) * c + sq
            a1 = -2 * ((A - 1) + (A + 1) * c); a2 = (A + 1) + (A - 1) * c - sq
        else:
            b0 = A * ((A + 1) + (A - 1) * c + sq); b1 = -2 * A * ((A - 1) + (A + 1) * c)
            b2 = A * ((A + 1) + (A - 1) * c - sq); a0 = (A + 1) - (A - 1) * c + sq
            a1 = 2 * ((A - 1) - (A + 1) * c); a2 = (A + 1) - (A - 1) * c - sq
    else:
        raise ValueError(kind)
    return (b0 + b1 * z1 + b2 * z2) / (a0 + a1 * z1 + a2 * z2)


def filt(x: np.ndarray, kind: str, f0, Q=0.707, order: int = 1, gain_db=0.0, circular=False) -> np.ndarray:
    """Static biquad (cascaded `order` times). circular=True treats x as one period of a loop."""
    n = x.shape[-1]
    N = n if circular else next_pow2(n + SR // 3)
    X = np.fft.rfft(x, N, axis=-1)
    w = TAU * np.arange(X.shape[-1]) / N
    H = biquad_H(kind, f0, Q, w, gain_db) ** order
    return np.fft.irfft(X * H, N, axis=-1)[..., :n]


def eq(x, bands, circular=False):
    """bands = [(kind, f0, Q, gain_db), ...] applied in one FFT pass."""
    n = x.shape[-1]
    N = n if circular else next_pow2(n + SR // 3)
    X = np.fft.rfft(x, N, axis=-1)
    w = TAU * np.arange(X.shape[-1]) / N
    H = np.ones_like(w, dtype=complex)
    for kind, f0, Q, g in bands:
        H = H * biquad_H(kind, f0, Q, w, g)
    return np.fft.irfft(X * H, N, axis=-1)[..., :n]


def sweep(x: np.ndarray, kind: str, f0, Q=0.707, order: int = 1, gain_db=0.0, frame: int = 1024, nfft: int = 4096) -> np.ndarray:
    """Time-varying biquad: f0 / Q are scalars or per-sample arrays.

    Implemented as short-time overlap-add convolution (Hann frames, 50% overlap,
    zero-padded FFT so that the filter's ringing does not wrap)."""
    if x.ndim == 2:
        return np.stack([sweep(c, kind, f0, Q, order, gain_db, frame, nfft) for c in x])
    n = len(x)
    if n == 0:
        return x.copy()
    f0a = _freq(f0, n)
    Qa = _freq(Q, n)
    hop = frame // 2
    win = np.hanning(frame + 1)[:-1]
    xp = np.concatenate([np.zeros(hop), x, np.zeros(frame + hop)])
    nfr = (n + hop) // hop + 1
    starts = np.arange(nfr) * hop
    out = np.zeros(len(xp) + nfft)
    w = TAU * np.arange(nfft // 2 + 1) / nfft
    ar = np.arange(frame)
    for c0 in range(0, nfr, 256):
        st = starts[c0 : c0 + 256]
        fr = xp[st[:, None] + ar[None, :]] * win
        F = np.fft.rfft(fr, nfft, axis=1)
        cen = np.clip(st + hop - hop, 0, n - 1)  # frame centre in x coordinates
        H = biquad_H(kind, f0a[cen][:, None], Qa[cen][:, None], w[None, :], gain_db) ** order
        y = np.fft.irfft(F * H, nfft, axis=1)
        for k, s in enumerate(st):
            out[s : s + nfft] += y[k]
    return out[hop : hop + n]


def formant(x: np.ndarray, vowel: str = "a", q: float = 9.0, shift: float = 1.0) -> np.ndarray:
    """Vowel formant filter bank (parallel band passes) for choir-like tones."""
    table = {
        "a": [(800, 0), (1150, -6), (2900, -14), (3900, -18), (4950, -26)],
        "o": [(450, 0), (800, -10), (2830, -20), (3800, -24), (4950, -32)],
        "u": [(325, 0), (700, -14), (2530, -28), (3500, -32), (4950, -38)],
        "e": [(400, 0), (1600, -12), (2700, -14), (3300, -18), (4950, -26)],
        "i": [(300, 0), (2200, -18), (3000, -20), (3800, -26), (4950, -30)],
    }
    n = x.shape[-1]
    N = next_pow2(n + SR // 3)
    X = np.fft.rfft(x, N, axis=-1)
    w = TAU * np.arange(X.shape[-1]) / N
    H = np.zeros_like(w, dtype=complex)
    for f, g in table[vowel]:
        H = H + db(g) * biquad_H("bp", f * shift, q * f / 1000.0 + 2.0, w)
    return np.fft.irfft(X * H, N, axis=-1)[..., :n] * 2.0


# ----------------------------------------------------------------------------
# non-linear / glitch
# ----------------------------------------------------------------------------
def drive(x, amount=2.0, asym=0.0):
    """tanh saturation, gain compensated; asym adds even harmonics."""
    k = max(amount, 1e-3)
    y = np.tanh(k * (x + asym)) - np.tanh(k * asym)
    return y / math.tanh(k)


def fold(x, amount=2.0):
    """Sine wavefolder."""
    return np.sin(x * amount * math.pi / 2.0)


def crush(x, bits=8, hold: int = 1):
    """Bit depth reduction + sample-and-hold rate reduction."""
    y = x
    if hold > 1:
        idx = (np.arange(x.shape[-1]) // hold) * hold
        y = y[..., idx]
    q = 2.0 ** (bits - 1)
    return np.round(y * q) / q


def stutter(x, start: float, slice_len: float, repeats: int, decay=1.0, rng=None, shrink=1.0):
    """Repeat a slice beginning at `start` `repeats` times (classic glitch retrigger)."""
    out = x.copy()
    s = ns(start)
    pos = s
    L = ns(slice_len)
    g = 1.0
    for _ in range(repeats):
        L = max(32, int(L))
        seg = fade(x[..., s : s + L], 0.0005, 0.0015) * g
        end = min(pos + L, out.shape[-1])
        out[..., pos:end] = seg[..., : end - pos]
        pos += L
        g *= decay
        L *= shrink
        if pos >= out.shape[-1]:
            break
    return out


def gate_pattern(n: int, step: float, pattern) -> np.ndarray:
    """Rhythmic gate (pattern of 0..1 levels per step), smoothed edges."""
    st = ns(step)
    g = np.repeat(np.asarray(pattern, dtype=float), st)
    g = fit(g, n) if len(g) >= n else np.pad(g, (0, n - len(g)), constant_values=pattern[-1])
    return smooth(g, 0.0015)


# ----------------------------------------------------------------------------
# time based effects
# ----------------------------------------------------------------------------
def delay(x, time: float, fb=0.4, mix_=0.3, lp=5000.0, hp=120.0, pingpong=False, tail: float = 1.5, circular=False):
    """Feedback delay evaluated exactly in the frequency domain.

    Each repeat passes once more through a LP/HP pair. pingpong alternates L/R.
    Returns stereo if pingpong or input stereo. circular=True wraps repeats inside the loop."""
    n = x.shape[-1]
    total = n if circular else n + ns(tail)
    N = total if circular else next_pow2(total + SR // 4)
    D = ns(time)
    src = to_mono(x) if pingpong else x
    X = np.fft.rfft(src, N, axis=-1)
    w = TAU * np.arange(X.shape[-1]) / N
    Hf = biquad_H("lp", lp, 0.6, w) * biquad_H("hp", hp, 0.6, w)
    z = np.exp(-1j * w * D)
    k_max = int(math.ceil(math.log(1e-3) / math.log(max(fb, 1e-3)))) + 1
    acc_odd = np.zeros_like(w, dtype=complex)
    acc_even = np.zeros_like(w, dtype=complex)
    step = Hf * z
    term = np.ones_like(w, dtype=complex)
    g = 1.0
    for k in range(1, min(k_max, 60) + 1):
        term = term * step
        if k > 1:
            g *= fb
        if k % 2:
            acc_odd += term * g
        else:
            acc_even += term * g
    if pingpong:
        L = np.fft.irfft(X * acc_odd, N)[:total]
        R = np.fft.irfft(X * acc_even, N)[:total]
        wet = np.stack([L * 0.85 + R * 0.15, R * 0.85 + L * 0.15])
        dry = to_stereo(fit(x, total))
    else:
        wet = np.fft.irfft(X * (acc_odd + acc_even), N, axis=-1)[..., :total]
        dry = fit(x, total)
    return dry + wet * mix_


_IR_CACHE: dict = {}

_COMBS = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617, 1733, 1811, 1907, 2011]
_APS = [556, 441, 341, 225, 179]


def reverb_ir(rt60=2.0, size=1.0, damp=0.35, predelay=0.012, lp=10000.0, hp=120.0, spread=23, er=0.35, seed=1):
    """Stereo Freeverb-style impulse response (parallel lowpass-damped combs into
    series allpasses), computed exactly from the transfer function in the
    frequency domain, plus a cluster of early reflections. Cached."""
    key = (round(rt60, 3), round(size, 3), round(damp, 3), round(predelay, 4), round(lp), round(hp), spread, round(er, 3), seed)
    if key in _IR_CACHE:
        return _IR_CACHE[key]
    scale = size * SR / 44100.0
    longest = int(max(_COMBS) * scale) + spread
    N = next_pow2(int(SR * rt60 * 1.6) + longest * 4)
    w = TAU * np.arange(N // 2 + 1) / N
    z1 = np.exp(-1j * w)
    lpf = (1.0 - damp) / (1.0 - damp * z1)  # one-pole damping inside each comb loop
    chans = []
    rng = np.random.default_rng(seed)
    for ch in range(2):
        off = spread * ch
        Hc = np.zeros_like(w, dtype=complex)
        for i, d0 in enumerate(_COMBS):
            D = int(d0 * scale) + off
            g = 10.0 ** (-3.0 * D / (SR * rt60))
            sign = 1.0 if i % 2 == 0 else -1.0
            Hc += sign / (1.0 - g * np.exp(-1j * w * D) * lpf)
        for d0 in _APS:
            D = int(d0 * scale) + off
            gz = np.exp(-1j * w * D)
            Hc *= (-1.0 + 1.5 * gz) / (1.0 - 0.5 * gz)
        ir = np.fft.irfft(Hc, N)
        n_keep = min(N, int(SR * rt60 * 1.25) + longest)
        ir = ir[:n_keep]
        # smooth onset of the diffuse tail, fade the very end
        ir *= np.minimum(1.0, np.arange(n_keep) / (SR * 0.004) + 0.05)
        ir = fade(ir, 0, min(0.25, rt60 * 0.1))
        ir /= math.sqrt(np.sum(ir**2)) + 1e-12
        # early reflections
        if er > 0:
            erv = np.zeros(ns(0.08))
            for _ in range(14):
                tt = rng.uniform(0.004, 0.075) * size
                k = ns(tt)
                if k < len(erv):
                    erv[k] += rng.choice([-1, 1]) * (1.0 - tt / 0.09) * rng.uniform(0.4, 1.0)
            erv = filt(erv, "lp", 7000)
            erv /= math.sqrt(np.sum(erv**2)) + 1e-12
            ir = mix(erv * er, ir * (1.0 - er * 0.5))
        chans.append(ir)
    n = max(len(c) for c in chans)
    ir = np.stack([fit(c, n) for c in chans])
    ir = filt(ir, "lp", lp, 0.6)
    ir = filt(ir, "hp", hp, 0.6)
    ir = at(ir, predelay)
    ir /= math.sqrt(np.sum(ir**2) / 2.0) + 1e-12
    _IR_CACHE[key] = ir
    return ir


def convolve(x: np.ndarray, ir: np.ndarray, circular=False) -> np.ndarray:
    """Convolve x (mono/stereo) with stereo ir -> stereo. circular wraps the tail into the head."""
    n = x.shape[-1]
    m = ir.shape[-1]
    xs = to_stereo(x)
    if circular:
        N = n
        if m > n:
            ir = ir[..., :n]
        Y = np.fft.rfft(xs, N, axis=-1) * np.fft.rfft(ir, N, axis=-1)
        return np.fft.irfft(Y, N, axis=-1)
    N = next_pow2(n + m)
    Y = np.fft.rfft(xs, N, axis=-1) * np.fft.rfft(ir, N, axis=-1)
    return np.fft.irfft(Y, N, axis=-1)[:, : n + m - 1]


def reverb(x, wet=0.3, dry=1.0, rt60=2.0, size=1.0, damp=0.35, predelay=0.012, lp=10000.0, hp=150.0, er=0.35, width=1.0, circular=False, seed=1):
    ir = reverb_ir(rt60, size, damp, predelay, lp, hp, 23, er, seed)
    w = convolve(x, ir, circular) * (wet * 0.5)
    if width != 1.0:
        w = widen(w, width)
    d = to_stereo(x) * dry
    return mix(d, w)


def widen(x: np.ndarray, amount=1.5) -> np.ndarray:
    """Mid/side width (1 = unchanged, 0 = mono, >1 wider)."""
    x = to_stereo(x)
    m = (x[0] + x[1]) * 0.5
    s = (x[0] - x[1]) * 0.5 * amount
    return np.stack([m + s, m - s])


def haas(x: np.ndarray, ms: float = 12.0, amount=0.5) -> np.ndarray:
    """Decorrelate a mono source into stereo with a filtered short-delay side signal."""
    x = to_mono(x)
    d = at(x, ms / 1000.0)[: len(x)]
    side = filt(d - x, "hp", 300) * amount * 0.5
    return np.stack([x + side, x - side])


def chorus(x: np.ndarray, rate=0.6, depth_ms=3.0, base_ms=12.0, mix_=0.5) -> np.ndarray:
    """Stereo chorus with two quadrature-modulated fractional delay lines."""
    x = to_mono(x)
    n = len(x)
    t = np.arange(n) / SR
    out = []
    for ph in (0.0, math.pi / 2):
        dly = (base_ms + depth_ms * np.sin(TAU * rate * t + ph)) * SR / 1000.0
        idx = np.arange(n) - dly
        i0 = np.floor(idx).astype(int)
        fr = idx - i0
        i0c = np.clip(i0, 0, n - 1)
        i1c = np.clip(i0 + 1, 0, n - 1)
        y = x[i0c] * (1 - fr) + x[i1c] * fr
        y[i0 < 0] = 0
        out.append(x * (1 - mix_ * 0.5) + y * mix_)
    return np.stack(out)


# ----------------------------------------------------------------------------
# dynamics / mastering
# ----------------------------------------------------------------------------
def _slide_min(a: np.ndarray, w: int) -> np.ndarray:
    """out[i] = min(a[i:i+w]) (van Herk / Gil-Werman, vectorised)."""
    n = len(a)
    m = -(-n // w) * w
    p = np.full(m, np.inf)
    p[:n] = a
    B = p.reshape(-1, w)
    pre = np.minimum.accumulate(B, axis=1).ravel()
    suf = np.minimum.accumulate(B[:, ::-1], axis=1)[:, ::-1].ravel()
    i = np.arange(n - w + 1)
    return np.minimum(suf[i], pre[i + w - 1])


def _centered_min(a, h, circular):
    if h < 1:
        return a
    mode = "wrap" if circular else "edge"
    p = np.pad(a, (h, h), mode=mode)
    return _slide_min(p, 2 * h + 1)


def _centered_avg(a, h, circular):
    if h < 1:
        return a
    w = 2 * h + 1
    mode = "wrap" if circular else "edge"
    p = np.pad(a, (h + 1, h), mode=mode)
    c = np.cumsum(p)
    return (c[w:] - c[:-w]) / w


def limiter(x: np.ndarray, ceiling_db=-1.0, attack=0.004, release=0.09, circular=False) -> np.ndarray:
    """Look-ahead brickwall-ish limiter (zero latency: gain computed non-causally).

    Gain = min-filter then moving average, so the smoothed gain never exceeds the
    instantaneous requirement -> output stays under the ceiling, then a gentle
    soft clip catches inter-sample residue."""
    c = db(ceiling_db)
    a = np.abs(x).max(axis=0) if x.ndim == 2 else np.abs(x)
    g = np.minimum(1.0, c / np.maximum(a, 1e-12))
    if g.min() >= 1.0:
        return x.copy()
    ha, hr = max(1, ns(attack)), max(1, ns(release))
    g1 = _centered_avg(_centered_min(g, ha, circular), ha, circular)
    g2 = _centered_avg(_centered_min(g1, hr, circular), hr, circular)
    g = np.minimum(g1, g2 * 0.35 + g1 * 0.65)
    y = x * g
    return soft_clip(y, ceiling_db)


def soft_clip(x, ceiling_db=-0.5, knee=0.85):
    """Linear below knee*ceiling, smooth tanh shoulder above, never exceeds ceiling."""
    c = db(ceiling_db)
    k = c * knee
    ax = np.abs(x)
    over = ax > k
    y = x.copy()
    if over.any():
        y[over] = np.sign(x[over]) * (k + (c - k) * np.tanh((ax[over] - k) / (c - k)))
    return y


def compress(x, thresh_db=-18.0, ratio=3.0, attack=0.005, release=0.12, makeup_db=0.0, circular=False):
    """Feed-forward RMS-ish compressor (smoothed envelope, non-causal but symmetric)."""
    a = np.abs(x).max(axis=0) if x.ndim == 2 else np.abs(x)
    env = _centered_avg(a, max(1, ns(attack)), circular)
    env = np.maximum(env, _centered_avg(env, max(1, ns(release)), circular))
    lv = 20 * np.log10(np.maximum(env, 1e-9))
    over = np.maximum(lv - thresh_db, 0)
    gdb = -over * (1 - 1 / ratio) + makeup_db
    return x * 10 ** (gdb / 20)


def dc_block(x, circular=False):
    return filt(x, "hp", 18.0, 0.6, circular=circular)


def normalize(x, peak_db=-1.0):
    p = np.abs(x).max()
    return x * (db(peak_db) / p) if p > 0 else x


def rms_db(x):
    return 20 * math.log10(math.sqrt(np.mean(x**2)) + 1e-12)


def trim_tail(x, floor_db=-72.0, min_len=0.0, fade_out=0.02):
    """Cut trailing silence below floor and fade the last few ms."""
    a = np.abs(x).max(axis=0) if x.ndim == 2 else np.abs(x)
    thr = db(floor_db) * max(a.max(), 1e-12)
    idx = np.nonzero(a > thr)[0]
    end = int(idx[-1]) + ns(0.01) if len(idx) else x.shape[-1]
    end = max(end, ns(min_len))
    end = min(end, x.shape[-1])
    return fade(x[..., :end], 0.0, fade_out)


def finish(x, peak_db=-6.0, stereo=None, trim=True, min_len=0.0, fade_out=0.015, fade_in=0.0005, limit=True):
    """Final stage for one-shot SFX: DC block, (optional) limit, peak normalise, trim."""
    if stereo is False:
        x = to_mono(x)
    elif stereo is True:
        x = to_stereo(x)
    x = dc_block(x)
    if trim:
        x = trim_tail(x, -70.0, min_len, fade_out)
    x = fade(x, fade_in, 0)
    x = normalize(x, peak_db + 0.8)
    if limit:
        x = limiter(x, peak_db, attack=0.0015, release=0.03)
    x = normalize(x, peak_db)
    if not np.all(np.isfinite(x)):
        raise ValueError("non-finite samples")
    return x
