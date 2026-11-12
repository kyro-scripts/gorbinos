"""Knife, gore and dread sounds.

  knife_flip, knife_catch, knife_swing      offhand knife tricks and slashes
  knife_stab, gut_slice, gut_spill, knife_pull, gut_drip    the gutting finisher
  heartbeat                                  low-health heartbeat
  creep_whisper_a/b/c                        the user's voice lines, reversed,
                                             slowed and drowned in reverb
  creep_drone, creep_knock, creep_breath, creep_scrape   dread stingers
  trout_fire, trout_slap, trout_flop         the trout launcher

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


# ------------------------------------------------------------------ gorbino talk
def _bubbles(r, d, n, lo=180, hi=700):
    out = np.zeros(int(SR * d))
    for _ in range(n):
        p = int(r.uniform(0, d - 0.06) * SR)
        f = r.uniform(lo, hi)
        ln = int(SR * r.uniform(0.02, 0.05))
        tt = np.arange(ln) / SR
        out[p:p + ln] += np.sin(2 * np.pi * f * (1 + tt / (ln / SR) * 1.2) * tt) * np.exp(-tt * 90) * r.uniform(0.3, 1.0)
    return out


def _gorb_syllable(r, pitch, vowel, roll, d):
    """One wet 'gorb'/'blub' syllable: a plosive pop, a buzzy vowel through two
    formants, an optional rolled r, and a lip-smack closure."""
    tt = t_(d)
    f0 = pitch * (1.0 + 0.18 * np.sin(np.pi * tt / d)) * (1 + 0.04 * np.sin(2 * np.pi * r.uniform(5, 8) * tt))
    f0 *= 1 + 0.012 * R.normal(0, 1, len(tt)).cumsum() / np.sqrt(np.arange(1, len(tt) + 1))
    src = (np.cumsum(f0) / SR % 1.0) * 2 - 1
    src = src + 0.35 * np.sign(src) * (np.abs(src) > 0.7)
    f1, f2 = vowel
    v = bp(src, f1 * 0.75, f1 * 1.3) + 0.55 * bp(src, f2 * 0.8, f2 * 1.2) + 0.25 * lp(src, 250)
    env_ = np.clip(tt / 0.012, 0, 1) * np.clip((d - tt) / 0.03, 0, 1)
    if roll:
        # rolled r in the back half: the throat flaps at ~28 Hz
        rr = np.where(tt > d * 0.45, 0.55 + 0.45 * np.sin(2 * np.pi * 28 * tt), 1.0)
        env_ = env_ * rr
    v *= env_
    pop = lp(noise(0.02), 900) * env(int(SR * 0.02), 0.0005, 0.006, 5)
    smack = lp(noise(0.015), 1800) * env(int(SR * 0.015), 0.0005, 0.004, 5)
    return mix(pop * 0.6, at(v, 0.008), at(smack * 0.4, d - 0.01))


def gorbino_talk():
    vowels = {"o": (480, 820), "u": (320, 760), "a": (680, 1100), "e": (420, 1750), "oo": (290, 640)}
    keys = list(vowels.keys())
    for i, (pitch, n) in enumerate([(105, 5), (135, 4), (90, 6), (160, 5), (120, 7), (98, 4)]):
        r = np.random.default_rng(1300 + i)
        parts = []
        for k in range(n):
            d = r.uniform(0.11, 0.22)
            vw = vowels[keys[r.integers(0, len(keys))]] if k % 2 else vowels[["o", "u", "oo"][r.integers(0, 3)]]
            parts.append(_gorb_syllable(r, pitch * r.uniform(0.85, 1.2), vw, r.random() < 0.55, d))
            parts.append(np.zeros(int(SR * r.uniform(0.015, 0.07))))
        x = np.concatenate(parts)
        x = x + _bubbles(r, len(x) / SR, 9) * 0.22
        x = lp(np.tanh(x * 2.2), 3800)
        save("gorb_talk_" + "abcdef"[i], reverb(x, 0.35, 0.18, 2500), 0.62)
    # yelps: a gurgling squeal that runs up and cracks
    for i, (f_lo, f_hi, d) in enumerate([(260, 720, 0.75), (200, 560, 0.95)]):
        r = np.random.default_rng(1400 + i)
        tt = t_(d)
        f = f_lo + (f_hi - f_lo) * np.clip(tt / 0.22, 0, 1) ** 0.6 + 40 * np.sin(2 * np.pi * 11 * tt)
        f = np.where((tt > d * 0.55) & (tt < d * 0.62), f * 1.6, f)
        src = (np.cumsum(f) / SR % 1.0) * 2 - 1
        v = bp(src, 500, 1200) + 0.6 * bp(src, 1500, 2600)
        v *= np.clip(tt / 0.02, 0, 1) * np.exp(-np.maximum(tt - d * 0.55, 0) * 7) * (0.7 + 0.3 * np.sin(2 * np.pi * 30 * tt))
        v = v + _bubbles(r, d, 14, 300, 1100) * 0.4
        save("gorb_yelp_" + "ab"[i], np.tanh(v * 2.6), 0.7)


# ------------------------------------------------------------------ new toys
def toys():
    # whip: a rising swish, a hard crack and a wet slap
    d = 0.18
    tt = t_(d)
    swish = bp(noise(d), 800, 5000) * np.clip(tt / d, 0, 1) ** 2
    crack = hp(noise(0.03), 2500) * env(int(SR * 0.03), 0.0003, 0.006, 5)
    slap = squelch(0.12, 600, 21) * env(int(SR * 0.12), 0.002, 0.04, 4)
    save("whip_crack", mix(swish * 0.5, at(crack * 1.4, d - 0.01), at(slap * 0.6, d)), 0.9)
    # yank: stretchy wet rubber, a twang that drops
    d = 0.42
    tt = t_(d)
    f = 190 * np.exp(-tt * 3.0) + 60 + 8 * np.sin(2 * np.pi * 14 * tt)
    tw = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 5)
    x = mix(tw * 0.8, squelch(d, 380, 22) * env(int(SR * d), 0.01, 0.15, 3) * 0.7)
    save("whip_yank", np.tanh(x * 1.5), 0.85)
    # flamethrower: a whoosh to start, a roar that loops, a whoomp when
    # something catches, and the sizzle of something burning
    d = 0.5
    tt = t_(d)
    nz = noise(d)
    k = np.clip(tt / 0.3, 0, 1)
    x = (lp(nz, 600) * (1 - k) + lp(nz, 3000) * k) * np.clip(tt / 0.05, 0, 1) * np.exp(-np.maximum(tt - 0.3, 0) * 5)
    save("flame_start", x, 0.8)
    d = 1.2
    n = int(SR * d)
    roar = bp(noise(d), 180, 1800) * (0.75 + 0.25 * lp(noise(d), 9) * 6).clip(0.4, 1.2) + lp(noise(d), 160) * 1.2
    for _ in range(50):
        p = int(R.uniform(0, d - 0.01) * SR)
        roar[p:p + 40] += R.uniform(-1, 1, 40) * np.exp(-np.arange(40) / 8) * 1.5
    fade = int(SR * 0.1)
    roar[:fade] = roar[:fade] * np.linspace(0, 1, fade) + roar[-fade:] * np.linspace(1, 0, fade)
    roar = roar[:n - fade]
    save("flame_loop", roar, 0.7)
    d = 0.6
    tt = t_(d)
    thump = np.sin(2 * np.pi * np.cumsum(70 + 90 * np.exp(-tt * 15)) / SR) * env(len(tt), 0.003, 0.15, 3)
    swell = lp(noise(d), 1500) * np.sin(np.pi * np.clip(tt / d, 0, 1)) ** 2
    save("flame_ignite", mix(thump, swell * 0.6), 0.9)
    d = 0.9
    tt = t_(d)
    sz = hp(noise(d), 3000) * (0.5 + 0.5 * (R.random(len(tt)) < 0.04)) * np.exp(-tt * 1.5)
    save("burn_sizzle", sz, 0.5)
    # slide: grit dragged along the floor
    d = 0.55
    tt = t_(d)
    x = bp(noise(d), 500, 3500) * (0.7 + 0.3 * lp(noise(d), 30) * 5).clip(0.3, 1.3) * np.clip(tt / 0.02, 0, 1) * np.exp(-tt * 3)
    x += lp(noise(d), 200) * np.exp(-tt * 4) * 0.8
    save("slide", x, 0.7)
    # frenzy: a filthy rising stinger
    d = 1.4
    tt = t_(d)
    f = 80 * 2 ** (tt / d * 2.5)
    saw = (np.cumsum(f) / SR % 1.0) * 2 - 1
    saw2 = (np.cumsum(f * 1.5) / SR % 1.0) * 2 - 1
    dist = np.tanh((saw + saw2 * 0.7) * 2.5)
    x = (lp(dist, 900) * (1 - tt / d) + lp(dist, 3900) * (tt / d)) * np.clip(tt / 0.02, 0, 1) * np.exp(-np.maximum(tt - 1.0, 0) * 8)
    hit = lp(noise(0.3), 2500) * env(int(SR * 0.3), 0.001, 0.08, 4)
    save("frenzy_on", mix(x, at(hit, 1.0)), 0.9)


def trout():
    """The trout launcher: a wet pneumatic thwoomp, the slap of a trout
    across a face, and the soft flop of one landing on the floor."""
    # fire: a hollow tube thump, a burst of air, a wet slither out
    d = 0.5
    tt = t_(d)
    thump = np.sin(2 * np.pi * np.cumsum(55 + 140 * np.exp(-tt * 22)) / SR) * env(len(tt), 0.002, 0.12, 3)
    air = bp(noise(d), 300, 2500) * env(len(tt), 0.004, 0.09, 4)
    slither = squelch(0.22, 500, 31) * env(int(SR * 0.22), 0.01, 0.1, 3)
    save("trout_fire", mix(thump * 1.1, air * 0.6, at(slither * 0.5, 0.05)), 0.9)
    # slap: a sharp wet crack with a meaty body under it
    d = 0.32
    tt = t_(d)
    crack = hp(noise(0.02), 1800) * env(int(SR * 0.02), 0.0002, 0.006, 5)
    body = squelch(d, 260, 32) * env(len(tt), 0.001, 0.08, 4)
    low = np.sin(2 * np.pi * np.cumsum(90 + 60 * np.exp(-tt * 30)) / SR) * env(len(tt), 0.001, 0.07, 4)
    save("trout_slap", mix(crack * 1.6, body * 0.9, low * 0.7), 0.95)
    # flop: a soft wet thud and a little wriggle
    d = 0.22
    tt = t_(d)
    thud = lp(noise(d), 500) * env(len(tt), 0.002, 0.05, 4)
    wrig = squelch(d, 700, 33) * env(len(tt), 0.01, 0.07, 3)
    save("trout_flop", mix(thud, wrig * 0.5), 0.7)


if __name__ == "__main__":
    knife()
    gore()
    dread()
    gorbino_talk()
    toys()
    trout()
