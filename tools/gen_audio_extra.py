"""Knife, gore and dread sounds.

  knife_flip, knife_catch, knife_swing      offhand knife tricks and slashes
  knife_stab, gut_slice, gut_spill, knife_pull, gut_drip    the gutting finisher
  heartbeat                                  low-health heartbeat
  creep_whisper_a/b/c                        the user's voice lines, reversed,
                                             slowed and drowned in reverb
  creep_drone, creep_knock, creep_breath, creep_scrape   dread stingers

Run: python3 tools/gen_audio_extra.py   (needs numpy + scipy)
"""
import os
import wave
import numpy as np
from scipy import signal

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sounds")
VOICES = os.path.join(ROOT, "tools", "user_audio")
SR = 22050
R = np.random.default_rng(4242)


def t_(d):
    return np.arange(int(SR * d)) / SR


def save(name, x, gain=0.9):
    x = np.asarray(x, np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    f = min(128, len(x) // 4)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    print("wrote", name, "%.2fs" % (len(x) / SR))


def noise(d):
    return R.uniform(-1, 1, int(SR * d))


def env(n, a=0.002, d=0.1, curve=4.0):
    x = np.arange(n) / SR
    return np.clip(x / max(a, 1e-5), 0, 1) * np.exp(-np.maximum(x - a, 0) * curve / max(d, 1e-5))


def lp(x, fc, order=2):
    b, a = signal.butter(order, np.clip(fc, 20, SR / 2 - 100) / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR / 2 - 200) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def mix(*xs):
    n = max(len(x) for x in xs)
    out = np.zeros(n)
    for x in xs:
        out[:len(x)] += x
    return out


def at(x, sec, n=None):
    pad = np.zeros(int(sec * SR))
    y = np.concatenate([pad, x])
    if n is not None:
        y = np.concatenate([y, np.zeros(max(0, n - len(y)))])[:n]
    return y


def reverb(x, dur=2.0, wet=0.5, damp=3000):
    ir = noise(dur) * np.exp(-t_(dur) * 3.2 / dur * 2.0)
    ir = lp(ir, damp)
    y = signal.fftconvolve(x, ir)[:len(x) + len(ir)]
    y = y / (np.max(np.abs(y)) + 1e-9)
    xx = np.concatenate([x, np.zeros(len(y) - len(x))])
    return xx * (1 - wet) + y * wet * np.max(np.abs(x))


def squelch(d, f0=300, seed=0):
    """Wet, slapping squish: band-limited noise with fast random wobble."""
    r = np.random.default_rng(seed)
    n = int(SR * d)
    x = r.uniform(-1, 1, n)
    wob = lp(r.uniform(-1, 1, n), 30) * 40
    x = bp(x, f0 * 0.5, f0 * 3)
    x *= 1 + wob
    return np.tanh(x * 2.5)


def load_voice(name):
    with wave.open(os.path.join(VOICES, name)) as w:
        sr, ch, n = w.getframerate(), w.getnchannels(), w.getnframes()
        x = np.frombuffer(w.readframes(n), np.int16).astype(np.float64).reshape(-1, ch).mean(1) / 32768.0
    return signal.resample_poly(x, SR, sr)


# ------------------------------------------------------------------ knife
def knife():
    # flip: airy whoosh that rises and falls
    d = 0.32
    n = noise(d)
    tt = t_(d)
    sweep = np.sin(np.pi * tt / d) ** 2
    x = bp(n, 900, 5000) * sweep * (0.6 + 0.4 * np.sin(tt * 2 * np.pi * 18))
    save("knife_flip", x, 0.55)
    # catch: leather slap + small metal tick
    slap = lp(noise(0.08), 1500) * env(int(SR * 0.08), 0.001, 0.02, 5)
    tick = np.sin(2 * np.pi * 3100 * t_(0.12)) * env(int(SR * 0.12), 0.0005, 0.04, 6)
    tick += np.sin(2 * np.pi * 4700 * t_(0.12)) * env(int(SR * 0.12), 0.0005, 0.03, 6) * 0.5
    save("knife_catch", mix(slap, tick * 0.35), 0.7)
    # swing: fast whoosh
    d = 0.22
    tt = t_(d)
    x = bp(noise(d), 600, 6000) * np.sin(np.pi * tt / d) ** 3
    save("knife_swing", x, 0.7)


# ------------------------------------------------------------------ gore
def gore():
    # stab: dull thud into meat, a crunch, then a wet squish
    thud = np.sin(2 * np.pi * np.cumsum(90 + 140 * np.exp(-t_(0.3) * 25)) / SR) * env(int(SR * 0.3), 0.001, 0.08, 4)
    crunch = hp(noise(0.06), 1800) * env(int(SR * 0.06), 0.0005, 0.02, 5)
    wet = squelch(0.35, 420, 1) * env(int(SR * 0.35), 0.01, 0.15, 3)
    save("knife_stab", mix(thud * 1.2, crunch * 0.5, at(wet * 0.8, 0.03)), 0.95)
    # slice: long tearing rip with wet crackles
    d = 0.95
    tt = t_(d)
    tear = bp(noise(d), 500, 3500) * (0.4 + 0.6 * np.abs(lp(noise(d), 12) * 6).clip(0, 1))
    crack = np.zeros(int(SR * d))
    for k in range(40):
        p = int(R.uniform(0, d - 0.02) * SR)
        crack[p:p + 60] += R.uniform(-1, 1, 60) * np.exp(-np.arange(60) / 10)
    sl = squelch(d, 260, 2) * 0.6
    x = (tear * 0.7 + hp(crack, 1200) * 0.6 + sl) * np.clip(tt / 0.05, 0, 1) * np.exp(-np.maximum(tt - 0.7, 0) * 6)
    save("gut_slice", x, 0.9)
    # spill: heavy slop of guts hitting the floor, bubbling after
    slops = []
    for k, (tm, f) in enumerate([(0.0, 180), (0.18, 140), (0.33, 220), (0.52, 120)]):
        s = squelch(0.3, f, 10 + k) * env(int(SR * 0.3), 0.004, 0.1, 3)
        thump = np.sin(2 * np.pi * np.cumsum(60 + 80 * np.exp(-t_(0.25) * 20)) / SR) * env(int(SR * 0.25), 0.002, 0.08, 4)
        slops.append(at(mix(s * 0.8, thump * 0.7), tm))
    bub = np.zeros(int(SR * 1.3))
    for k in range(18):
        p = int(R.uniform(0.3, 1.2) * SR)
        f = R.uniform(250, 700)
        ln = int(SR * 0.05)
        bub[p:p + ln] += np.sin(2 * np.pi * f * (1 + np.arange(ln) / ln) * np.arange(ln) / SR) * np.exp(-np.arange(ln) / (ln / 4))
    save("gut_spill", mix(*slops, bub * 0.35), 0.95)
    # pull: suction release
    d = 0.3
    x = squelch(d, 500, 3) * env(int(SR * d), 0.02, 0.08, 3)
    pop = np.sin(2 * np.pi * np.cumsum(400 + 900 * t_(0.08)) / SR) * env(int(SR * 0.08), 0.001, 0.03, 4)
    save("knife_pull", mix(x, at(pop * 0.6, 0.12)), 0.85)
    # drip
    ln = int(SR * 0.12)
    tt = np.arange(ln) / SR
    x = np.sin(2 * np.pi * (900 + 1800 * tt / 0.12) * tt) * np.exp(-tt * 40)
    save("gut_drip", x, 0.5)


# ------------------------------------------------------------------ dread
def dread():
    # heartbeat: lub-dub
    def beat(f, d):
        tt = t_(d)
        return np.sin(2 * np.pi * np.cumsum(f + 30 * np.exp(-tt * 30)) / SR) * env(len(tt), 0.004, 0.06, 3)
    hb = mix(beat(48, 0.25), at(beat(40, 0.25) * 0.7, 0.2))
    save("heartbeat", lp(np.concatenate([hb, np.zeros(int(SR * 0.3))]), 200), 0.9)
    # whispers: the voice lines, reversed, slowed, smeared in reverb
    for i, (src, k) in enumerate([("canthide.wav", 0.72), ("runpig.wav", 0.66), ("seeyou.wav", 0.78)]):
        v = load_voice(src)[::-1]
        v = signal.resample(v, int(len(v) / k))
        v = hp(v, 180)
        v = reverb(v, 2.4, 0.65, 2500)
        save("creep_whisper_" + "abc"[i], v, 0.6)
    # drone stinger: dissonant swell of detuned low tones
    d = 4.5
    tt = t_(d)
    sw = np.clip(tt / 3.0, 0, 1) ** 2 * np.exp(-np.maximum(tt - 3.4, 0) * 4)
    x = np.zeros(len(tt))
    for f in (55.0, 58.3, 77.8, 82.4, 116.5):
        x += np.sin(2 * np.pi * f * tt + 0.3 * np.sin(2 * np.pi * 0.3 * tt))
    x += bp(noise(d), 200, 900) * 0.4
    save("creep_drone", lp(np.tanh(x * 0.6), 1400) * sw, 0.7)
    # three knocks on a far door
    knock = lp(noise(0.12), 500) * env(int(SR * 0.12), 0.001, 0.03, 5)
    body = np.sin(2 * np.pi * 95 * t_(0.2)) * env(int(SR * 0.2), 0.001, 0.06, 4)
    k1 = mix(knock, body * 0.8)
    x = mix(k1, at(k1 * 0.9, 0.42), at(k1, 0.8))
    save("creep_knock", reverb(x, 1.6, 0.45, 1800), 0.7)
    # heavy breathing close by
    d = 2.6
    tt = t_(d)
    e = np.clip(np.sin(2 * np.pi * tt / 1.3), 0, 1) ** 1.5
    x = bp(noise(d), 300, 2400) * e + bp(noise(d), 120, 500) * e * 0.5
    save("creep_breath", x, 0.55)
    # metal scrape somewhere in the dark
    d = 1.8
    tt = t_(d)
    f = 340 + 60 * np.sin(2 * np.pi * 0.7 * tt) + R.normal(0, 4, len(tt)).cumsum() * 0.02
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.5 + 0.5 * lp(noise(d), 25) * 8).clip(0, 1)
    x += bp(noise(d), 2000, 6000) * 0.25
    save("creep_scrape", reverb(x * np.sin(np.pi * tt / d), 2.0, 0.55, 2200), 0.55)


# ------------------------------------------------------------------ contracts
def contract():
    # target terminated: a cash register ka-ching over a filthy low stab
    clunk = lp(noise(0.05), 2500) * env(int(SR * 0.05), 0.0005, 0.015, 5)
    tt = t_(0.9)
    bell = (np.sin(2 * np.pi * 2350 * tt) + 0.6 * np.sin(2 * np.pi * 3520 * tt) + 0.3 * np.sin(2 * np.pi * 5870 * tt)) * np.exp(-tt * 6)
    d = 1.4
    tt = t_(d)
    chord = np.zeros(len(tt))
    for f in (55.0, 65.4, 82.4, 110.0):
        ph = 2 * np.pi * f * tt
        chord += (ph / np.pi % 2 - 1)                      # saw
    chord = lp(np.tanh(chord * 1.4), 1800) * np.clip(tt / 0.01, 0, 1) * np.exp(-tt * 2.2)
    x = mix(clunk * 0.8, at(bell * 0.55, 0.03), at(chord * 0.7, 0.08))
    save("contract_done", x, 0.9)
    # the briefing: a fax machine handshake
    d = 1.1
    tt = t_(d)
    f = np.where(tt < 0.35, 1100, np.where(tt < 0.7, 2100, 1650)) + 40 * np.sin(2 * np.pi * 9 * tt)
    x = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.4 + bp(noise(d), 800, 3000) * 0.25
    save("contract_fax", lp(x, 3500) * np.clip(tt / 0.02, 0, 1) * np.clip((d - tt) / 0.05, 0, 1), 0.45)


# ------------------------------------------------------------------ bystanders
def bystanders():
    # mumbles: gibberish syllables, a buzzy glottal source through two vowel formants
    vowels = [(730, 1090), (270, 2290), (300, 870), (530, 1840), (640, 1190), (390, 1990)]
    for i, (pitch, n_syl) in enumerate([(150, 7), (210, 6), (120, 8)]):
        r = np.random.default_rng(900 + i)
        out = []
        for k in range(n_syl):
            d = r.uniform(0.07, 0.15)
            tt = t_(d)
            f0 = pitch * (1 + 0.25 * np.sin(np.pi * tt / d)) * r.uniform(0.85, 1.25)
            src = (np.cumsum(f0) / SR % 1.0) * 2 - 1
            f1, f2 = vowels[r.integers(0, len(vowels))]
            v = bp(src, f1 * 0.8, f1 * 1.25) + 0.6 * bp(src, f2 * 0.85, f2 * 1.15)
            v *= np.sin(np.pi * tt / d) ** 0.7
            out.append(v)
            out.append(np.zeros(int(SR * r.uniform(0.01, 0.06))))
        save("civ_mumble_" + "abc"[i], np.tanh(np.concatenate(out) * 2.0), 0.6)
    # screams: a strained glide up, wobbling, with breath
    for i, (f_lo, f_hi, d) in enumerate([(500, 900, 0.9), (380, 760, 1.1)]):
        tt = t_(d)
        f = f_lo + (f_hi - f_lo) * np.clip(tt / 0.25, 0, 1) + 25 * np.sin(2 * np.pi * 7 * tt) + R.normal(0, 6, len(tt)).cumsum() * 0.01
        src = (np.cumsum(f) / SR % 1.0) * 2 - 1
        v = bp(src, 700, 1300) + 0.7 * bp(src, 2200, 3200) + bp(noise(d), 1500, 4000) * 0.3
        v *= np.clip(tt / 0.03, 0, 1) * np.exp(-np.maximum(tt - d * 0.6, 0) * 6)
        save("civ_scream_" + "ab"[i], np.tanh(v * 2.5), 0.7)


if __name__ == "__main__":
    knife()
    gore()
    dread()
    contract()
    bystanders()
